// DocuCraft — HTML Slide Template View
// Render HTML template langsung di canvas via iframe (web) atau fallback (mobile).
// Menampilkan full design asli dari HTML, bukan parsed SlideElements.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' show HtmlElementView;
import '../services/html_viewer_stub.dart' if (dart.library.html) '../services/html_viewer_web.dart';

/// Widget yang render HTML template di dalam canvas slide.
/// Di web: tampilan 1:1 penuh via iframe (resolution 1920×1080).
/// Di mobile: tidak render (elements dari parser dipakai sebagai fallback).
class HtmlSlideTemplateView extends StatelessWidget {
  final String htmlPath;
  const HtmlSlideTemplateView({super.key, required this.htmlPath});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    final viewType = 'html-slide-${htmlPath.hashCode}';
    registerHtmlViewer(viewType, htmlPath);

    return HtmlElementView(viewType: viewType);
  }
}
