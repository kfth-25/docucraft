// DocuCraft — HTML Template Viewer (WEB)
// Conditional import: file ini dipakai saat kIsWeb == true.
// Render template HTML di dalam iframe platform view.
//
// TODO(migration): Migrasi ke `package:web` + `dart:js_interop` begitu build web
// masuk ke CI matrix reguler. `dart:html` sudah deprecated tapi masih
// berfungsi di Flutter 3.x; migrasi menyentuh `IFrameElement` dan
// registry platform view, serta butuh web runtime untuk verifikasi.
// ignore: avoid_web_libraries_in_flutter
// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

// Cache viewType → iframe element, supaya tidak bikin baru tiap build
final Map<String, html.IFrameElement> _iframeCache = {};

/// Resolve asset path → URL absolut yang bisa di-load iframe.
/// Di Flutter web, asset berada di {baseUri}/assets/...
String resolveAssetUrl(String assetPath) {
  final base = Uri.base;
  final normalized = assetPath.startsWith('/') ? assetPath.substring(1) : assetPath;
  // baseUri sudah berakhir '/', gabung langsung
  return base.resolve(normalized).toString();
}

/// Registrasi satu viewType per path HTML.
/// ViewType diregistrasi sekali (idempotent).
void registerHtmlViewer(String viewType, String htmlPath) {
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final cached = _iframeCache[viewType];
    if (cached != null) return cached;

    final iframe = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.pointerEvents = 'none'
      ..src = resolveAssetUrl(htmlPath);

    _iframeCache[viewType] = iframe;
    return iframe;
  });
}
