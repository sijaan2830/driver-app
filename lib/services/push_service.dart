import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Calls the free Render push-notification relay so customers get FCM pushes
/// even when their app is completely closed / killed.
/// Best-effort — Firestore real-time listener still covers foreground.
class PushService {
  // ── Set these after deploying dc-push-service on Render ──
  static const String _baseUrl = 'https://dc-push-service.onrender.com';
  static const String _apiKey  = 'dc_push_2026_drycleanplus';

  static Future<void> send({
    required String userId,
    required String title,
    String body = '',
    Map<String, String>? data,
  }) async {
    if (userId.isEmpty || userId == 'website_guest' || userId == 'dummy') return;
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/send-push'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
        },
        body: jsonEncode({
          'userId': userId,
          'title': title,
          'body': body,
          if (data != null) 'data': data,
        }),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('PushService: $e');
    }
  }
}
