import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  static dynamic _jsonSafe(dynamic v) {
    if (v == null || v is num || v is String || v is bool) return v;
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is DateTime) return v.toIso8601String();
    if (v is GeoPoint) return {'latitude': v.latitude, 'longitude': v.longitude};
    if (v is DocumentReference) return v.path;
    if (v is Map) return {for (final e in v.entries) e.key.toString(): _jsonSafe(e.value)};
    if (v is Iterable) return [for (final i in v) _jsonSafe(i)];
    return v.toString();
  }

  static Future<void> sendDeliveredEmail(Map<String, dynamic> order) async {
    final b = order['bookingData'] is Map ? order['bookingData'] as Map : const {};
    final email = (b['email'] ?? order['email'] ?? '').toString().trim();
    if (email.isEmpty || !email.contains('@')) return;
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/send-email'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
        },
        body: jsonEncode({
          'type': 'delivered',
          'recipientEmail': email,
          'order': _jsonSafe(order),
        }),
      ).timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('PushService email: $e');
    }
  }
}
