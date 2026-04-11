import 'dart:js_interop';
import 'package:web/web.dart' as web;

void cleanUrl() {
  final uri = Uri.base;

  // 🔥 sempre pulire, non solo se c'è roomId
  if (uri.queryParameters.isEmpty) return;

  final clean = Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: uri.path, // ⚠️ NON forzare '/'
  );

  web.window.history.replaceState(null, '', clean.toString());
}