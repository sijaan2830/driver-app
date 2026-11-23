import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Continuous GPS for a driver on shift.
/// - Web: Uses browser Geolocation API with resilient polling fallback.
/// - Android: Uses foreground notification service so tracking survives screen-off.
/// - iOS: Uses automotive background location updates.
class LocationTracker {
  StreamSubscription<Position>? _sub;
  Timer? _webFallbackTimer;
  bool get running => _sub != null || _webFallbackTimer != null;

  static const msgGpsOff = 'Turn on location (GPS) on your device to go online.';
  static const msgDenied = 'Location permission is needed so customers can see you on the way.';
  static const msgBlocked = 'Location is blocked. Please enable location permissions for DC Driver.';

  /// One of the messages above — the app offers a button that fixes it.
  static bool isGpsProblem(String m) => m == msgGpsOff || m == msgDenied || m == msgBlocked;

  /// Opens the phone screen that fixes [problem]: GPS switch, or this app's permissions.
  static Future<bool> openFix(String problem) async {
    if (kIsWeb) return false;
    try {
      return problem == msgGpsOff ? await Geolocator.openLocationSettings() : await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// GPS switched on/off in the phone's quick settings while on shift.
  Stream<ServiceStatus> serviceChanges() {
    if (kIsWeb) return const Stream.empty();
    try {
      return Geolocator.getServiceStatusStream();
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Returns null when location is ready, otherwise a message to show the driver.
  Future<String?> ensurePermission() async {
    try {
      if (!kIsWeb) {
        final enabled = await Geolocator.isLocationServiceEnabled();
        if (!enabled) return msgGpsOff;
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied) return msgDenied;
      if (p == LocationPermission.deniedForever) {
        return kIsWeb ? 'Please allow location permission in your browser address bar.' : msgBlocked;
      }
      return null;
    } catch (e) {
      if (kIsWeb) return null; // Web will prompt on first getCurrentPosition
      return 'Could not check location: $e';
    }
  }

  LocationSettings _settings() {
    if (kIsWeb) {
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 4),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'DC Driver — On Shift',
          notificationText: 'Sharing live location with customers on your route',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
  }

  Future<void> start(void Function(Position p) onPosition) async {
    await stop();

    // 1. Immediately request the first current position
    try {
      final first = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 8));
      onPosition(first);
    } catch (_) {
      /* stream below will deliver */
    }

    // 2. Start continuous position stream
    try {
      _sub = Geolocator.getPositionStream(locationSettings: _settings()).listen(
        onPosition,
        onError: (err) {
          debugPrint('Geolocator stream error: $err');
        },
      );
    } catch (e) {
      debugPrint('Geolocator getPositionStream failed: $e');
    }

    // 3. For Web: Add a resilient fallback timer every 4 seconds to guarantee updates
    if (kIsWeb) {
      _webFallbackTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
        try {
          final p = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          ).timeout(const Duration(seconds: 5));
          onPosition(p);
        } catch (_) {}
      });
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _webFallbackTimer?.cancel();
    _webFallbackTimer = null;
  }
}
