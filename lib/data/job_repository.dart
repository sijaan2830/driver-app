import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../models.dart';
import 'geo.dart';

/// Proof captured at the door.
class Proof {
  final List<String> bagTags;
  final int bags;
  final Uint8List? photo;
  final Uint8List? signature;
  final String? payment; // 'card' | 'cash' | 'prepaid' (deliveries)
  final String note;
  const Proof({this.bagTags = const [], this.bags = 0, this.photo, this.signature, this.payment, this.note = ''});
}

/// Everything the driver app needs from the backend. Real (Firestore) and demo implementations.
abstract class JobRepository {
  DriverProfile get driver;
  Stream<List<Job>> watchJobs();
  Future<void> setOnline(bool online);
  Future<void> startTrip(Job job);
  Future<void> arrived(Job job);
  Future<void> complete(Job job, Proof proof);
  Future<void> fail(Job job, String reason, {Uint8List? photo});
  Future<void> pushLocation(LatLng me, {double heading = 0, double speed = 0, double accuracy = 0, Job? active});
  Future<void> dispose();
}

String todayKey([DateTime? d]) => DateFormat('yyyy-MM-dd').format(d ?? DateTime.now());

/// ---------------------------------------------------------------------------
/// Firestore implementation
///
/// Collections (see SYSTEM_PLAN.md):
///   jobs/{jobId}                 — created by dispatch in the admin panel
///   orders/{orderDocId}          — customer order (status updated here)
///   orders/{id}/history/{auto}   — timeline shown to the customer
///   live_tracking/{orderId}      — live driver position while en route (deleted after)
///   driver_locations/{uid}       — fleet map in the admin panel
///   bags/{tagId}                 — QR bag tags
/// ---------------------------------------------------------------------------
class FirestoreJobRepository implements JobRepository {
  FirestoreJobRepository(this.driver);

  @override
  final DriverProfile driver;

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  static Future<FirestoreJobRepository> forCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser!;
    DocumentSnapshot<Map<String, dynamic>>? driverDoc;

    // 1. Direct match by user.uid
    final direct = await FirebaseFirestore.instance.collection('drivers').doc(user.uid).get();
    if (direct.exists) {
      driverDoc = direct;
    } else if (user.email != null && user.email!.trim().isNotEmpty) {
      // 2. Match by email in drivers collection
      final q = await FirebaseFirestore.instance
          .collection('drivers')
          .where('email', isEqualTo: user.email!.trim().toLowerCase())
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        driverDoc = q.docs.first;
      }
    }

    Map<String, dynamic> d = {};
    if (driverDoc != null && driverDoc.exists) {
      d = driverDoc.data() ?? {};
      // If doc was found by email under a different id, sync/link it to user.uid
      if (driverDoc.id != user.uid) {
        await FirebaseFirestore.instance.collection('drivers').doc(user.uid).set(d, SetOptions(merge: true));
      }
    } else {
      // 3. Check staff collection
      final staffDoc = await FirebaseFirestore.instance.collection('staff').doc(user.uid).get();
      if (staffDoc.exists) {
        d = staffDoc.data() ?? {};
      } else if (user.email != null && user.email!.trim().isNotEmpty) {
        final sq = await FirebaseFirestore.instance
            .collection('staff')
            .where('email', isEqualTo: user.email!.trim().toLowerCase())
            .limit(1)
            .get();
        if (sq.docs.isNotEmpty) {
          d = sq.docs.first.data();
        }
      }

      // Auto-provision driver record so driver is never blocked
      d = {
        'name': d['name'] ?? user.displayName ?? (user.email != null ? user.email!.split('@').first : 'Driver'),
        'email': user.email ?? '',
        'phone': d['phone'] ?? user.phoneNumber ?? '',
        'vehicle': d['vehicle'] ?? {'make': 'Ford Transit', 'colour': 'White', 'reg': 'DC24 VNN'},
        'isOnline': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('drivers').doc(user.uid).set(d, SetOptions(merge: true));
    }

    final v = (d['vehicle'] as Map?)?.cast<String, dynamic>() ?? const {};
    return FirestoreJobRepository(DriverProfile(
      uid: user.uid,
      name: '${d['name'] ?? user.displayName ?? 'Driver'}',
      phone: '${d['phone'] ?? user.phoneNumber ?? ''}',
      vehicle: [v['colour'], v['make']].where((e) => e != null && '$e'.isNotEmpty).join(' '),
      reg: '${v['reg'] ?? ''}',
    ));
  }

  @override
  Stream<List<Job>> watchJobs() {
    // Single-field query on driverId avoids requiring composite indexes in Firestore
    return _db
        .collection('jobs')
        .where('driverId', isEqualTo: driver.uid)
        .snapshots()
        .asyncMap((snap) async {
      final jobs = <Job>[];
      final today = todayKey();
      for (final d in snap.docs) {
        final m = Map<String, dynamic>.from(d.data());
        final c = m['completedAt'];
        if (c is Timestamp) m['completedAt'] = c.toDate();
        var j = Job.fromMap(d.id, m);

        // Show today's jobs OR any job that is still active/incomplete
        final isToday = j.date.isEmpty || j.date == today;
        if (!isToday && j.isDone) {
          continue; // skip old finished jobs from previous days
        }

        if (!j.hasGeo && j.postcode.isNotEmpty) {
          final p = await Geo.postcode(j.postcode);
          if (p != null) {
            j = j.copyWith(lat: p.latitude, lng: p.longitude);
            d.reference.update({'geo': {'lat': p.latitude, 'lng': p.longitude}}).ignore(); // cache for next time
          }
        }
        jobs.add(j);
      }
      jobs.sort((a, b) => a.sequence.compareTo(b.sequence));
      return jobs;
    });
  }

  DocumentReference<Map<String, dynamic>> _order(Job j) => _db.collection('orders').doc(j.orderDocId);

  void _history(WriteBatch b, Job j, String status, [String note = '']) {
    b.set(_order(j).collection('history').doc(), {
      'status': status,
      'at': FieldValue.serverTimestamp(),
      'byUid': driver.uid,
      'byRole': 'driver',
      'byName': driver.firstName,
      'jobId': j.id,
      if (note.isNotEmpty) 'note': note,
    });
  }

  void _notifyCustomer(WriteBatch b, Job j, String status, String title, String body, {String theme = 'blue', String icon = 'local_shipping'}) {
    if (j.customerUid.isEmpty || j.customerUid == 'website_guest' || j.customerUid == 'dummy') return;
    final ref = _db.collection('users').doc(j.customerUid).collection('notifications').doc();
    b.set(ref, {
      'title': title,
      'body': body,
      'category': 'orders',
      'theme': theme,
      'icon': icon,
      'orderId': j.orderDocId,
      'displayOrderId': j.orderId,
      'status': status,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setOnline(bool online) async {
    final b = _db.batch();
    b.set(_db.collection('drivers').doc(driver.uid), {
      'isOnline': online,
      'onlineChangedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    b.set(_db.collection('driver_locations').doc(driver.uid), {
      'online': online,
      'name': driver.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await b.commit();
  }

  @override
  Future<void> startTrip(Job j) async {
    final status = j.isPickup ? OrderStatus.pickupEnRoute : OrderStatus.outForDelivery;
    final b = _db.batch();
    b.update(_db.collection('jobs').doc(j.id), {
      'status': JobStatus.enRoute,
      'startedAt': FieldValue.serverTimestamp(),
    });
    b.update(_order(j), {
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _history(b, j, status);
    _notifyCustomer(
      b,
      j,
      status,
      j.isPickup ? '${driver.firstName} is on the way' : '${driver.firstName} is bringing your order',
      'Tap to follow your driver live on the map.',
      theme: 'blue',
      icon: 'local_shipping',
    );

    final trackingData = {
      'orderId': j.orderId,
      'orderDocId': j.orderDocId,
      'jobId': j.id,
      'customerUid': j.customerUid,
      'driverUid': driver.uid,
      'driverFirstName': driver.firstName,
      'driverName': driver.name,
      'driverPhone': driver.phone,
      'vehicle': driver.vehicle,
      'regEnding': driver.reg.length >= 3 ? driver.reg.substring(driver.reg.length - 3) : driver.reg,
      'phase': j.isPickup ? 'pickup' : 'delivery',
      'state': 'en_route',
      if (j.hasGeo) 'destination': {'lat': j.lat, 'lng': j.lng},
      'startedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (j.orderId.isNotEmpty) {
      b.set(_db.collection('live_tracking').doc(j.orderId), trackingData);
    }
    if (j.orderDocId.isNotEmpty && j.orderDocId != j.orderId) {
      b.set(_db.collection('live_tracking').doc(j.orderDocId), trackingData);
    }
    await b.commit();
  }

  @override
  Future<void> arrived(Job j) async {
    final status = j.isPickup ? OrderStatus.pickupArrived : OrderStatus.deliveryArrived;
    final b = _db.batch();
    b.update(_db.collection('jobs').doc(j.id), {
      'status': JobStatus.arrived,
      'arrivedAt': FieldValue.serverTimestamp(),
    });
    b.update(_order(j), {
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _history(b, j, status);
    _notifyCustomer(
      b,
      j,
      status,
      'Your driver is outside',
      j.isPickup ? 'Please hand over your bags at the door.' : 'Your clean clothes are at your door.',
      theme: 'mint',
      icon: 'where_to_vote',
    );

    final trackingUpdate = {
      'state': 'arrived',
      'etaMinutes': 0,
      'arrivedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (j.orderId.isNotEmpty) {
      b.set(_db.collection('live_tracking').doc(j.orderId), trackingUpdate, SetOptions(merge: true));
    }
    if (j.orderDocId.isNotEmpty && j.orderDocId != j.orderId) {
      b.set(_db.collection('live_tracking').doc(j.orderDocId), trackingUpdate, SetOptions(merge: true));
    }
    await b.commit();
  }

  Future<String?> _upload(String path, Uint8List? bytes, String type) async {
    if (bytes == null) return null;
    final ref = _storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: type));
    return ref.getDownloadURL();
  }

  @override
  Future<void> complete(Job j, Proof p) async {
    final base = 'pod/${j.orderId}/${j.id}';
    final photoUrl = await _upload('$base-photo.jpg', p.photo, 'image/jpeg');
    final signatureUrl = await _upload('$base-signature.png', p.signature, 'image/png');
    final status = j.isPickup ? OrderStatus.collected : OrderStatus.delivered;
    final b = _db.batch();
    b.update(_db.collection('jobs').doc(j.id), {
      'status': JobStatus.completed,
      'completedAt': FieldValue.serverTimestamp(),
      'bags': p.bags,
      'bagTags': p.bagTags,
      'pod': {'photoUrl': photoUrl, 'signatureUrl': signatureUrl, 'note': p.note, 'payment': p.payment},
    });
    b.update(_order(j), {
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      if (j.isPickup) ...{'bagTags': FieldValue.arrayUnion(p.bagTags), 'bagCount': p.bags, 'collectedAt': FieldValue.serverTimestamp()},
      if (!j.isPickup) ...{'deliveredAt': FieldValue.serverTimestamp(), if (p.payment != null) 'paymentStatus': p.payment == 'prepaid' ? 'paid' : 'paid_on_delivery', if (p.payment != null) 'paymentCollectedBy': p.payment},
    });
    _history(b, j, status, j.isPickup ? '${p.bags} bag${p.bags == 1 ? '' : 's'} collected' : 'Delivered');
    _notifyCustomer(
      b,
      j,
      status,
      j.isPickup ? 'Bags collected' : 'Delivered — thank you!',
      j.isPickup
          ? '${p.bags > 0 ? '${p.bags} bag${p.bags == 1 ? '' : 's'}' : 'Your order'} on the way to our facility.'
          : '#${j.orderId} has been delivered. We hope you love the results.',
      theme: 'mint',
      icon: j.isPickup ? 'inventory' : 'check_circle',
    );
    for (final t in p.bagTags) {
      b.set(_db.collection('bags').doc(t), {
        'orderId': j.orderId,
        'orderDocId': j.orderDocId,
        'status': j.isPickup ? 'with_driver' : 'delivered',
        'lastScan': {'at': FieldValue.serverTimestamp(), 'by': driver.uid, 'place': j.isPickup ? 'customer_pickup' : 'customer_delivery'},
      }, SetOptions(merge: true));
    }
    if (j.orderId.isNotEmpty) {
      b.delete(_db.collection('live_tracking').doc(j.orderId));
    }
    if (j.orderDocId.isNotEmpty && j.orderDocId != j.orderId) {
      b.delete(_db.collection('live_tracking').doc(j.orderDocId));
    }
    await b.commit();
  }

  @override
  Future<void> fail(Job j, String reason, {Uint8List? photo}) async {
    final photoUrl = await _upload('pod/${j.orderId}/${j.id}-failed.jpg', photo, 'image/jpeg');
    final status = j.isPickup ? OrderStatus.pickupFailed : OrderStatus.deliveryFailed;
    final b = _db.batch();
    b.update(_db.collection('jobs').doc(j.id), {
      'status': JobStatus.failed,
      'failReason': reason,
      'failedAt': FieldValue.serverTimestamp(),
      'failPhotoUrl': ?photoUrl,
    });
    b.update(_order(j), {'status': status, 'updatedAt': FieldValue.serverTimestamp()});
    _history(b, j, status, reason);
    _notifyCustomer(
      b,
      j,
      status,
      j.isPickup ? 'We missed you' : 'Delivery missed',
      j.isPickup ? 'We couldn\'t collect #${j.orderId} today. Tap to reschedule.' : 'We couldn\'t deliver #${j.orderId} today. Tap to choose a new time.',
      theme: 'amber',
      icon: 'event_busy',
    );
    if (j.orderId.isNotEmpty) {
      b.delete(_db.collection('live_tracking').doc(j.orderId));
    }
    if (j.orderDocId.isNotEmpty && j.orderDocId != j.orderId) {
      b.delete(_db.collection('live_tracking').doc(j.orderDocId));
    }
    await b.commit();
  }

  @override
  Future<void> pushLocation(LatLng me, {double heading = 0, double speed = 0, double accuracy = 0, Job? active}) async {
    final b = _db.batch();

    // 1. Dispatch map in admin panel
    b.set(_db.collection('driver_locations').doc(driver.uid), {
      'lat': me.latitude,
      'lng': me.longitude,
      'heading': heading,
      'speed': speed,
      'accuracy': accuracy,
      'online': true,
      'name': driver.name,
      'phone': driver.phone,
      'activeJobId': active?.id,
      'activeOrderId': active?.orderId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Profile record
    b.set(_db.collection('drivers').doc(driver.uid), {
      'lastLocation': {
        'lat': me.latitude,
        'lng': me.longitude,
        'heading': heading,
        'speed': speed,
        'accuracy': accuracy,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'isOnline': true,
    }, SetOptions(merge: true));

    // 3. Customer live tracking screen & order status
    if (active != null && active.status == JobStatus.enRoute) {
      final dist = active.hasGeo ? Geo.meters(me, LatLng(active.lat!, active.lng!)) : null;
      final trackingData = {
        'lat': me.latitude,
        'lng': me.longitude,
        'heading': heading,
        'speed': speed,
        'driverUid': driver.uid,
        'driverName': driver.name,
        'driverPhone': driver.phone,
        'updatedAt': FieldValue.serverTimestamp(),
        if (active.hasGeo) 'destination': {'lat': active.lat, 'lng': active.lng},
        if (dist != null) 'distanceMeters': dist.round(),
        if (dist != null) 'etaMinutes': Geo.etaMinutes(dist),
      };

      if (active.orderId.isNotEmpty) {
        b.set(_db.collection('live_tracking').doc(active.orderId), trackingData, SetOptions(merge: true));
      }
      if (active.orderDocId.isNotEmpty && active.orderDocId != active.orderId) {
        b.set(_db.collection('live_tracking').doc(active.orderDocId), trackingData, SetOptions(merge: true));
      }

      // Also set driverLocation on the order document itself
      if (active.orderDocId.isNotEmpty) {
        b.update(_db.collection('orders').doc(active.orderDocId), {
          'driverLocation': {
            'lat': me.latitude,
            'lng': me.longitude,
            'heading': heading,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        });
      }
    }

    await b.commit();
  }

  @override
  Future<void> dispose() async {}
}
