import 'package:url_launcher/url_launcher.dart';

import '../models.dart';

Future<void> callCustomer(Job j) => launchUrl(Uri(scheme: 'tel', path: j.phone.replaceAll(' ', '')));

Future<void> textCustomer(Job j, String body) => launchUrl(Uri(scheme: 'sms', path: j.phone.replaceAll(' ', ''), queryParameters: {'body': body}));

/// Opens turn-by-turn navigation in Google Maps (or the phone's default maps app).
Future<void> navigateTo(Job j) {
  final dest = j.hasGeo ? '${j.lat},${j.lng}' : Uri.encodeComponent(j.fullAddress);
  return launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$dest&travelmode=driving'), mode: LaunchMode.externalApplication);
}
