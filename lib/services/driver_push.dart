import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
// FCM registration tokens (getToken/onTokenRefresh) are what the server's
// messaging.send({token}) targets — same as the customer app — so we keep them
// rather than the newer installation-ID API.
// ignore_for_file: deprecated_member_use
import 'package:firebase_messaging/firebase_messaging.dart';

/// "New job" pushes from dispatch. The server (Cloud Function `onJobCreated`)
/// sends to `drivers/{uid}.fcmToken`, which this keeps up to date.
class DriverPush {
  static StreamSubscription<String>? _refresh;
  static StreamSubscription<RemoteMessage>? _foreground;

  /// Call after the driver signs in. [onMessage] shows foreground messages in the app.
  static Future<void> register(String uid, void Function(String title, String body) onMessage) async {
    final fcm = FirebaseMessaging.instance;
    try {
      await fcm.requestPermission(alert: true, badge: true, sound: true);
      final ref = FirebaseFirestore.instance.collection('drivers').doc(uid);
      Future<void> save(String? t) async {
        if (t != null) await ref.set({'fcmToken': t, 'fcmUpdatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      }

      await save(await fcm.getToken());
      await _refresh?.cancel();
      _refresh = fcm.onTokenRefresh.listen(save);
      await _foreground?.cancel();
      _foreground = FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n != null) onMessage(n.title ?? 'New job', n.body ?? '');
      });
    } catch (_) {
      // Push is a convenience — the job list is live anyway.
    }
  }

  /// Stop pushes to this phone when the driver signs out.
  static Future<void> unregister(String uid) async {
    await _refresh?.cancel();
    await _foreground?.cancel();
    try {
      await FirebaseFirestore.instance.collection('drivers').doc(uid).update({'fcmToken': FieldValue.delete()});
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }
}
