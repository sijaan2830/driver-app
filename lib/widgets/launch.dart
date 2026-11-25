import 'package:url_launcher/url_launcher.dart';

import '../models.dart';

Future<bool> callCustomer(Job j) {
  final phone = j.phone.replaceAll(RegExp(r'\s+'), '');
  if (phone.isEmpty) return Future.value(false);
  return launchUrl(Uri(scheme: 'tel', path: phone), mode: LaunchMode.externalApplication);
}

Future<bool> textCustomer(Job j, String body) {
  final phone = j.phone.replaceAll(RegExp(r'\s+'), '');
  if (phone.isEmpty) return Future.value(false);
  return launchUrl(Uri(scheme: 'sms', path: phone, queryParameters: {'body': body}), mode: LaunchMode.externalApplication);
}

/// Opens turn-by-turn navigation in Google Maps (or the phone's default maps app).
Future<void> navigateTo(Job j) {
  final dest = j.hasGeo ? '${j.lat},${j.lng}' : Uri.encodeComponent(j.fullAddress);
  return launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$dest&travelmode=driving'), mode: LaunchMode.externalApplication);
}
