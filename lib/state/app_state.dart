import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../data/geo.dart';
import '../data/job_repository.dart';
import '../models.dart';
import '../services/driver_push.dart';
import '../services/location_tracker.dart';
import 'package:geolocator/geolocator.dart' show ServiceStatus;

class AppState extends ChangeNotifier {
  AppState({this.firebaseReady = true});

  final bool firebaseReady;

  JobRepository? repo;
  List<Job> jobs = const [];
  bool online = false;
  LatLng? me;
  double heading = 0;
  String? notice; // short message for the UI (e.g. auto-arrived)
  DateTime? lastSent; // last GPS point that reached the server (customers + dispatch see it)
  bool sendFailing = false;
  bool gpsOff = false; // driver switched GPS off while on shift

  final _tracker = LocationTracker();
  StreamSubscription<List<Job>>? _jobsSub;
  Timer? _heartbeat; // keeps the driver "online" on the map while standing still
  StreamSubscription<ServiceStatus>? _gpsSub;
  DateTime _lastPush = DateTime(2000);
  int _nearHits = 0;
  bool _arriving = false;

  bool get signedIn => repo != null;
  bool get isDemo => false;
  DriverProfile? get driver => repo?.driver;

  Job? get active {
    for (final j in jobs) {
      if (j.isActive) return j;
    }
    return null;
  }

  List<Job> get remaining => jobs.where((j) => !j.isDone).toList();
  List<Job> get completed => jobs.where((j) => j.isDone).toList();
  Job? get next => active ?? (remaining.isEmpty ? null : remaining.first);
  Job? byId(String id) {
    for (final j in jobs) {
      if (j.id == id) return j;
    }
    return null;
  }

  int doneOf(String type) => jobs.where((j) => j.type == type && j.status == JobStatus.completed).length;
  int totalOf(String type) => jobs.where((j) => j.type == type).length;
  double? distanceTo(Job j) => (me != null && j.hasGeo) ? Geo.meters(me!, LatLng(j.lat!, j.lng!)) : null;

  // ---------------------------------------------------------------- session
  Future<void> restore() async {
    if (!firebaseReady) return;
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      await _attach(await FirestoreJobRepository.forCurrentUser());
    } catch (_) {
      await FirebaseAuth.instance.signOut();
    }
  }

  Future<void> signIn(String email, String password) async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.trim(), password: password);
    try {
      await _attach(await FirestoreJobRepository.forCurrentUser());
    } catch (e) {
      await FirebaseAuth.instance.signOut();
      rethrow;
    }
  }

  Future<void> _attach(JobRepository r) async {
    await _jobsSub?.cancel();
    repo = r;
    _jobsSub = r.watchJobs().listen((list) {
      jobs = list;
      notifyListeners();
    });
    DriverPush.register(r.driver.uid, (title, body) {
      notice = body.isEmpty ? title : '$title — $body';
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> signOut() async {
    if (repo != null) await DriverPush.unregister(repo!.driver.uid);
    await setOnline(false);
    await _jobsSub?.cancel();
    await repo?.dispose();
    repo = null;
    jobs = const [];
    me = null;
    if (firebaseReady && FirebaseAuth.instance.currentUser != null) await FirebaseAuth.instance.signOut();
    notifyListeners();
  }

  // ---------------------------------------------------------------- online + GPS
  /// Returns an error message, or null when it worked.
  Future<String?> setOnline(bool value) async {
    if (repo == null) return null;
    if (!value) {
      _heartbeat?.cancel();
      await _gpsSub?.cancel();
      _gpsSub = null;
      gpsOff = false;
      await _tracker.stop();
      online = false;
      notifyListeners();
      await repo!.setOnline(false).catchError((_) {});
      return null;
    }
    final err = await _tracker.ensurePermission();
    if (err != null) return err;
    await _startGps();
    // GPS switched off/on from the phone's quick settings while on shift
    await _gpsSub?.cancel();
    _gpsSub = _tracker.serviceChanges().listen((st) async {
      gpsOff = st == ServiceStatus.disabled;
      notifyListeners();
      if (!gpsOff && online) await _startGps(); // pick up again by itself
    }, onError: (_) {});
      // the phone only reports after moving 15 m; resend the last point every minute so
      // dispatch keeps seeing a driver waiting at the hub as online
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(const Duration(seconds: 60), (_) {
        final p = me;
        if (!online || p == null || gpsOff || DateTime.now().difference(_lastPush) < const Duration(seconds: 55)) return;
        _lastPush = DateTime.now();
        repo?.pushLocation(p, heading: heading, active: active).then((_) {
          lastSent = DateTime.now();
          sendFailing = false;
          notifyListeners();
        }).catchError((_) {
          sendFailing = true;
          notifyListeners();
        });
      });
    online = true;
    notifyListeners();
    await repo!.setOnline(true).catchError((_) {});
    return null;
  }

  Future<void> _startGps() => _tracker.start((p) => _onPosition(LatLng(p.latitude, p.longitude), heading: p.heading, speed: p.speed, accuracy: p.accuracy));

  void _onPosition(LatLng p, {double heading = 0, double speed = 0, double accuracy = 0}) {
    me = p;
    if (heading > 0) this.heading = heading;
    notifyListeners();
    final a = active;
    // throttle: every 5 s while driving to a customer, otherwise every 60 s
    final every = (a != null && a.status == JobStatus.enRoute) ? const Duration(seconds: 5) : const Duration(seconds: 60);
    if (DateTime.now().difference(_lastPush) >= every) {
      _lastPush = DateTime.now();
      repo?.pushLocation(p, heading: this.heading, speed: speed, accuracy: accuracy, active: a).then((_) {
        lastSent = DateTime.now();
        sendFailing = false;
        notifyListeners();
      }).catchError((_) {
        sendFailing = true;
        notifyListeners();
      });
    }
    _checkArrival(a, p);
  }

  void _checkArrival(Job? a, LatLng p) {
    if (a == null || a.status != JobStatus.enRoute || !a.hasGeo || _arriving) return;
    final d = Geo.meters(p, LatLng(a.lat!, a.lng!));
    _nearHits = d <= 100 ? _nearHits + 1 : 0;
    if (_nearHits >= 2) {
      _arriving = true;
      HapticFeedback.heavyImpact();
      notice = 'You have arrived — ${a.firstName} has been told you are outside.';
      arrived(a).whenComplete(() => _arriving = false);
    }
  }

  // ---------------------------------------------------------------- job actions
  Future<String?> startTrip(Job j) async {
    if (!online) {
      final err = await setOnline(true);
      if (err != null) return err;
    }
    final other = active;
    if (other != null && other.id != j.id) return 'Finish ${other.isPickup ? 'the collection' : 'the delivery'} for ${other.firstName} first.';
    await repo!.startTrip(j);
    _nearHits = 0;
    _lastPush = DateTime(2000);
    if (me != null) {
      // send the first live position straight away
      repo!.pushLocation(me!, heading: heading, active: j.copyWith(status: JobStatus.enRoute)).catchError((_) {});
    }
    return null;
  }

  Future<void> arrived(Job j) => repo!.arrived(j);
  Future<void> complete(Job j, Proof p) => repo!.complete(j, p);
  Future<void> fail(Job j, String reason, {Uint8List? photo}) => repo!.fail(j, reason, photo: photo);

  String? takeNotice() {
    final n = notice;
    notice = null;
    return n;
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _gpsSub?.cancel();
    _tracker.stop();
    _jobsSub?.cancel();
    super.dispose();
  }
}
