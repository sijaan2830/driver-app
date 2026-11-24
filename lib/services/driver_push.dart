import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
// FCM registration tokens (getToken/onTokenRefresh) are what the server's
// messaging.send({token}) targets — same as the customer app — so we keep them
// rather than the newer installation-ID API.
// ignore_for_file: deprecated_member_use
import 'package:firebase_messaging/firebase_messaging.dart';
import 'driver_web_notify.dart';

/// "New job" pushes from dispatch. The server (Cloud Function `onJobCreated`)
/// sends to `drivers/{uid}.fcmToken`, which this keeps up to date on both
/// mobile apps and supported web browsers (via Firebase VAPID key).
class DriverPush {
  static const String _webVapidKey =
      'BM7t8Ck2AW9D9G4ysypu4zx3kLdnBCgEHGT7yZxtBGo0mfqpjcHwYJbtNYcYTtDbw0MI-9XWooyDiyKtteFLs1I';

  static StreamSubscription<String>? _refresh;
  static StreamSubscription<RemoteMessage>? _foreground;

  /// Call after the driver signs in. [onMessage] shows foreground messages in the app.
  static Future<void> register(String uid, void Function(String title, String body) onMessage) async {
    final fcm = FirebaseMessaging.instance;
    try {
      if (kIsWeb) {
        await requestDriverWebNotificationPermission();
      } else {
        await fcm.requestPermission(alert: true, badge: true, sound: true);
      }

      final ref = FirebaseFirestore.instance.collection('drivers').doc(uid);
      Future<void> save(String? t) async {
        if (t != null && t.isNotEmpty) {
          await ref.set({
            'fcmToken': t,
            'fcmPlatform': kIsWeb ? 'web' : 'mobile',
            'fcmUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      final token = kIsWeb
          ? await fcm.getToken(vapidKey: _webVapidKey)
          : await fcm.getToken();
      await save(token);

      await _refresh?.cancel();
      _refresh = fcm.onTokenRefresh.listen(save);
      await _foreground?.cancel();
      _foreground = FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n != null) {
          final title = n.title ?? 'New job';
          final body = n.body ?? '';
          onMessage(title, body);
          if (kIsWeb) showDriverWebJobAlert(title, body);
        }
      });
    } catch (_) {
      // Push is a convenience — watchJobs() still streams all jobs & browser alerts live.
    }
  }

  /// Stop pushes to this phone when the driver signs out.
  static Future<void> unregister(String uid) async {
    if (kIsWeb) return;
    await _refresh?.cancel();
    await _foreground?.cancel();
    try {
      await FirebaseFirestore.instance.collection('drivers').doc(uid).update({'fcmToken': FieldValue.delete()});
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }
}
