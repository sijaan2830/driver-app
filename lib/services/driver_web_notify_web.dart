import 'dart:js_interop';

@JS('__dcDriverRequestNotify')
external void _jsRequestNotify();

@JS('__dcDriverNotify')
external void _jsNotify(JSString title, JSString body);

Future<void> requestDriverWebNotificationPermission() async {
  try {
    _jsRequestNotify();
  } catch (_) {}
}

void showDriverWebJobAlert(String title, String body) {
  try {
    _jsNotify(title.toJS, body.toJS);
  } catch (_) {}
}
