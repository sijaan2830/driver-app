import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Postcode → coordinates (postcodes.io, free, no key). Cached for the session.
class Geo {
  static final Map<String, LatLng?> _cache = {};
  static const defaultCenter = LatLng(52.4862, -1.8904);
  static const london = defaultCenter;

  static Future<LatLng?> postcode(String pc) async {
    final key = pc.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (key.isEmpty) return null;
    if (_cache.containsKey(key)) return _cache[key];
    try {
      final r = await http.get(Uri.parse('https://api.postcodes.io/postcodes/$key')).timeout(const Duration(seconds: 8));
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final res = j['result'] as Map<String, dynamic>?;
      final p = res == null ? null : LatLng((res['latitude'] as num).toDouble(), (res['longitude'] as num).toDouble());
      _cache[key] = p;
      return p;
    } catch (_) {
      return null;
    }
  }

  static const _distance = Distance();
  static double meters(LatLng a, LatLng b) => _distance.as(LengthUnit.Meter, a, b);

  /// Rough London van ETA (no traffic API): road distance ≈ 1.35 × straight line, ~18 km/h average.
  static int etaMinutes(double meters) => math.max(1, ((meters * 1.35) / 1000 / 18 * 60).round());

  static String km(double meters) => meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)} km';
}
