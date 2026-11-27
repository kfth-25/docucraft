// DocuCraft — HTML Template Preview
// Render template HTML di Flutter Web via iframe (1:1 Presenton).
// Fallback ke TemplateRenderer (JSON) untuk mobile/desktop.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' show HtmlElementView;

import '../models/template_layout.dart';
import '../models/template_registry.dart';
import '../services/html_viewer_stub.dart' if (dart.library.html) '../services/html_viewer_web.dart';
import '../services/template_renderer.dart';

/// Widget yang render template.
/// Di web: tampilkan HTML asli via iframe (1:1 Presenton).
/// Di mobile: fallback ke JSON TemplateRenderer.
class HtmlTemplatePreview extends StatelessWidget {
  final TemplateLayout layout;
  final double width;
  final double height;

  const HtmlTemplatePreview({
    super.key,
    required this.layout,
    this.width = 400,
    this.height = 225,
  });

  @override
  Widget build(BuildContext context) {
    // Web: coba render HTML
    if (kIsWeb) {
      return _WebHtmlPreview(
        layoutId: layout.layoutId,
        layoutName: layout.name,
        width: width,
        height: height,
      );
    }

    // Mobile: fallback ke JSON TemplateRenderer
    final layoutData = TemplateRegistry.instance.layoutData[layout.layoutId];
    if (layoutData != null) {
      return TemplateRenderer(layout: layoutData, width: width);
    }

    // Fallback terakhir: placeholder
    return _PlaceholderPreview(layout: layout, width: width, height: height);
  }
}

/// Web-only: render HTML via iframe
class _WebHtmlPreview extends StatelessWidget {
  final String layoutId;
  final String layoutName;
  final double width;
  final double height;

  const _WebHtmlPreview({
    required this.layoutId,
    required this.layoutName,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    // Map layoutId ke file HTML
    final htmlPath = _resolveHtmlPath(layoutId);

    if (htmlPath == null) {
      return _PlaceholderPreview(
        layout: TemplateLayout(
          layoutId: layoutId,
          name: layoutName,
          description: '',
          fields: [],
          sampleData: {},
          fileName: '',
        ),
        width: width,
        height: height,
      );
    }

    // Registrasi viewType unik per path
    final viewType = 'html-template-${htmlPath.hashCode}';
    registerHtmlViewer(viewType, htmlPath);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: HtmlElementView(viewType: viewType),
    );
  }

  /// Map layoutId ke path HTML (relative ke web/)
  /// layoutId mengikuti id di JSON registry (lowercase, dari file swift/*.json)
  String? _resolveHtmlPath(String layoutId) {
    // Swift templates — key = layoutId JSON, value = file HTML
    const swiftMap = {
      'intro-slide-layout': 'assets/templates/swift-html/IntroSlideLayout.html',
      'metrics-numbers': 'assets/templates/swift-html/MetricsNumbers.html',
      'simple-bullet-points-layout': 'assets/templates/swift-html/SimpleBulletPointsLayout.html',
      'bullet-with-icons-title-description': 'assets/templates/swift-html/BulletsWithIconsTitleDescription.html',
      'icon-bullet-list-description': 'assets/templates/swift-html/IconBulletListDescription.html',
      'image-list-description': 'assets/templates/swift-html/ImageListDescription.html',
      'table-of-contents': 'assets/templates/swift-html/TableOfContents.html',
      'timeline': 'assets/templates/swift-html/Timeline.html',
      'tableor-chart': 'assets/templates/swift-html/TableorChart.html',
    };
    return swiftMap[layoutId];
  }
}

/// Fallback: placeholder box dengan judul
class _PlaceholderPreview extends StatelessWidget {
  final TemplateLayout layout;
  final double width;
  final double height;

  const _PlaceholderPreview({
    required this.layout,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          layout.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
