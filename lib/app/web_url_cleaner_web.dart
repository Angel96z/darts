import 'dart:js_interop';
import 'package:web/web.dart' as web;

void cleanUrl() {
  final uri = Uri.base;

  if (!uri.queryParameters.containsKey('roomId')) return;

  final clean = Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: '/',
  );

  web.window.history.replaceState(null, '', clean.toString());
}