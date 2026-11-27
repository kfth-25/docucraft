// DocuCraft — SVG Export Service
// Menghasilkan SVG dengan atribut semantik yang kompatibel dengan ppt-master untuk konversi PPTX native

import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/slide.dart';
import '../widgets/element_painter.dart';
import '../themes/app_theme.dart';

/// SVG element with semantic metadata for ppt-master converter
class SvgElement {
  final String id;
  final String svg;                    // Complete SVG XML string
  final ElementBounds bounds;          // Position in design space (1920x1080)
  final ElementType type;
  final Map<String, String> pptxAttrs; // data-pptx-* attributes
  final Map<String, dynamic> nativePayload; // For chart/table replacement

  SvgElement({
    required this.id,
    required this.svg,
    required this.bounds,
    required this.type,
    this.pptxAttrs = const {},
    this.nativePayload = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'svg': svg,
    'bounds': {
      'x': bounds.x,
      'y': bounds.y,
      'w': bounds.width,
      'h': bounds.height,
    },
    'type': type.name,
    'pptxAttrs': pptxAttrs,
    'nativePayload': nativePayload,
  };
}

/// Slide SVG export result
class SlideSvgExport {
  final String slideId;
  final int slideNum;
  final String viewBox;                 // e.g., "0 0 1280 720"
  final List<SvgElement> elements;
  final String backgroundSvg;           // Background rect SVG
  final Map<String, String> themeAttrs; // Theme mapping attributes

  SlideSvgExport({
    required this.slideId,
    required this.slideNum,
    required this.viewBox,
    required this.elements,
    required this.backgroundSvg,
    this.themeAttrs = const {},
  });

  Map<String, dynamic> toJson() => {
    'slideId': slideId,
    'slideNum': slideNum,
    'viewBox': viewBox,
    'elements': elements.map((e) => e.toJson()).toList(),
    'backgroundSvg': backgroundSvg,
    'themeAttrs': themeAttrs,
  };
}

/// Complete export payload for Python bridge
class SvgExportPayload {
  final String format;                   // ppt169, ppt43, etc.
  final List<SlideSvgExport> slides;
  final bool nativeChartsAndTables;

  SvgExportPayload({
    this.format = 'ppt169',
    required this.slides,
    this.nativeChartsAndTables = true,
  });

  String toJson() => jsonEncode({
    'format': format,
    'nativeChartsAndTables': nativeChartsAndTables,
    'slides': slides.map((s) => s.toJson()).toList(),
  });
}

/// Main SVG Export Service
class SvgExportService {
  static const double DESIGN_WIDTH = 1920.0;
  static const double DESIGN_HEIGHT = 1080.0;
  static const double SLIDE_WIDTH = 1920.0;  // Full HD for better quality
  static const double SLIDE_HEIGHT = 1080.0;
  static const double SCALE_FACTOR = 1.0;

  // Template SVG cache
  static final Map<String, String> _templateCache = {};

  /// Export entire presentation to SVG payload for Python bridge
  static SvgExportPayload exportPresentation(
    List<Slide> slides, {
    String format = 'ppt169',
    bool nativeChartsAndTables = true,
  }) {
    final slideExports = <SlideSvgExport>[];

    for (var i = 0; i < slides.length; i++) {
      final slide = slides[i];
      if (slide.hidden) continue;

      final export = exportSlide(slide, slideNum: slideExports.length + 1);
      slideExports.add(export);
    }

    return SvgExportPayload(
      format: format,
      slides: slideExports,
      nativeChartsAndTables: nativeChartsAndTables,
    );
  }

  /// Export single slide to SVG
  static SlideSvgExport exportSlide(Slide slide, {required int slideNum}) {
    final elements = <SvgElement>[];

    // 1. Background SVG
    final backgroundSvg = _buildBackgroundSvg(slide);

    // 2. Theme attributes for slide root
    final themeAttrs = _buildThemeAttrs(slide);

    // 3. Elements (either from template or individual elements)
    if (slide.layoutId != null && slide.layoutId!.isNotEmpty) {
      // Template-based slide: use template SVG with slot binding
      elements.addAll(_exportTemplateSlide(slide));
    } else {
      // Element-based slide: export each element individually
      final sorted = List<SlideElement>.from(slide.elements)
        ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

      for (final element in sorted) {
        if (element.width > 0 && element.height > 0) {
          final svgElement = exportElement(element);
          elements.add(svgElement);
        }
      }
    }

    return SlideSvgExport(
      slideId: slide.id,
      slideNum: slideNum,
      viewBox: '0 0 $SLIDE_WIDTH $SLIDE_HEIGHT',
      elements: elements,
      backgroundSvg: backgroundSvg,
      themeAttrs: themeAttrs,
    );
  }

  /// Export a single element to SVG with pptx attributes
  static SvgElement exportElement(SlideElement element) {
    // Scale bounds from design space (1920x1080) to slide space (1280x720)
    final bounds = ElementBounds(
      x: element.x * SCALE_FACTOR,
      y: element.y * SCALE_FACTOR,
      width: element.width * SCALE_FACTOR,
      height: element.height * SCALE_FACTOR,
    );

    // Record element to Picture
    final picture = ElementPainter.recordToPicture(element, bounds);

    // Convert Picture to SVG string
    final svg = _pictureToSvg(picture, bounds);

    // Build pptx semantic attributes
    final pptxAttrs = _buildPptxAttributes(element);
    final nativePayload = _buildNativePayload(element);

    return SvgElement(
      id: element.id,
      svg: svg,
      bounds: bounds,
      type: element.type,
      pptxAttrs: pptxAttrs,
      nativePayload: nativePayload,
    );
  }

  /// Load and bind template SVG with slot data
  static List<SvgElement> _exportTemplateSlide(Slide slide) {
    final templateSvg = _loadTemplateSvg(slide.layoutId!);
    final boundSvg = bindTemplateSvg(templateSvg, slide.templateData ?? {});

    // For template slides, we export as single full-slide SVG element
    // Python converter will handle the full slide SVG
    final bounds = ElementBounds(x: 0, y: 0, width: SLIDE_WIDTH, height: SLIDE_HEIGHT);

    return [
      SvgElement(
        id: 'template-${slide.layoutId}',
        svg: boundSvg,
        bounds: bounds,
        type: ElementType.text, // type doesn't matter for template
        pptxAttrs: {
          'data-pptx-layout': slide.layoutId!,
          'data-pptx-object': 'group',
        },
        nativePayload: slide.templateData ?? {},
      ),
    ];
  }

  /// Load template SVG from assets
  static Future<String> _loadTemplateSvgAsync(String layoutId) async {
    if (_templateCache.containsKey(layoutId)) {
      return _templateCache[layoutId]!;
    }

    // Try multiple paths
    final paths = [
      'assets/templates/layouts/$layoutId.svg',
      'assets/templates/layouts/${layoutId}.svg',
    ];

    for (final path in paths) {
      try {
        final svg = await rootBundle.loadString(path);
        _templateCache[layoutId] = svg;
        return svg;
      } catch (_) {}
    }

    // Fallback: generate minimal template SVG
    return _generateFallbackTemplateSvg(layoutId);
  }

  /// Synchronous version for non-async contexts
  static String _loadTemplateSvg(String layoutId) {
    if (_templateCache.containsKey(layoutId)) {
      return _templateCache[layoutId]!;
    }

    // For now, return fallback - async loading should be used in production
    return _generateFallbackTemplateSvg(layoutId);
  }

  /// Bind template slots with actual data
  static String bindTemplateSvg(String templateSvg, Map<String, dynamic> slots) {
    String result = templateSvg;

    // Replace {{slot}} placeholders
    for (final entry in slots.entries) {
      final placeholder = '{{${entry.key}}}';
      final value = entry.value?.toString() ?? '';
      result = result.replaceAll(placeholder, _escapeXml(value));
    }

    // Special handling for chart data - inject into metadata
    if (slots.containsKey('chartData') || slots.containsKey('chart')) {
      final chartData = slots['chartData'] ?? slots['chart'];
      if (chartData is Map) {
        final jsonStr = _escapeXml(jsonEncode(chartData));
        result = result.replaceAllMapped(
          RegExp(r'<metadata[^>]*type="application/json"[^>]*>(.*?)</metadata>', dotAll: true),
          (match) => '<metadata type="application/json" data-pptx-kind="chart">$jsonStr</metadata>',
        );
      }
    }

    // Special handling for image URLs
    if (slots.containsKey('imageUrl') || slots.containsKey('image')) {
      final imageUrl = slots['imageUrl'] ?? slots['image'] ?? '';
      result = result.replaceAllMapped(
        RegExp(r'href="\{{2}imageUrl\}{2}"'),
        (match) => 'href="$imageUrl"',
      );
      result = result.replaceAllMapped(
        RegExp(r'href="\{{2}image\}{2}"'),
        (match) => 'href="$imageUrl"',
      );
    }

    return result;
  }

  /// Build background SVG for slide
  static String _buildBackgroundSvg(Slide slide) {
    final gradientColors = AppTheme.gradientFor(slide.backgroundGradient);
    final rect = Rect.fromLTWH(0, 0, SLIDE_WIDTH, SLIDE_HEIGHT);

    if (gradientColors.length >= 2 && gradientColors[0] != gradientColors[1]) {
      return '''<rect x="0" y="0" width="$SLIDE_WIDTH" height="$SLIDE_HEIGHT"
        fill="url(#slideBgGradient)"
        data-pptx-object="shape" data-pptx-prst="rect"/>
<defs>
  <linearGradient id="slideBgGradient" x1="0%" y1="0%" x2="100%" y2="100%">
    <stop offset="0%" stop-color="#${gradientColors[0].toARGB32().toRadixString(16).padLeft(6, '0')}"/>
    <stop offset="100%" stop-color="#${gradientColors[1].toARGB32().toRadixString(16).padLeft(6, '0')}"/>
  </linearGradient>
</defs>''';
    } else {
      final color = gradientColors.first;
      return '''<rect x="0" y="0" width="$SLIDE_WIDTH" height="$SLIDE_HEIGHT"
        fill="#${color.toARGB32().toRadixString(16).padLeft(6, '0')}"
        data-pptx-object="shape" data-pptx-prst="rect"/>''';
    }
  }

  /// Build theme attributes for slide root SVG
  static Map<String, String> _buildThemeAttrs(Slide slide) {
    return {
      'data-pptx-theme-color-primary': 'accent1',
      'data-pptx-theme-font-major': 'major',
      'data-pptx-format': 'ppt169',
    };
  }

  /// Build pptx semantic attributes for element
  static Map<String, String> _buildPptxAttributes(SlideElement element) {
    final attrs = <String, String>{};

    switch (element.type) {
      case ElementType.text:
        attrs['data-pptx-object'] = 'text';
        if (element.templateSlotId != null) {
          attrs['data-pptx-slot'] = element.templateSlotId!;
        }
        // Theme mapping
        attrs['data-pptx-theme-font'] = 'minor';
        attrs['data-pptx-theme-color'] = 'tx1';
        break;

      case ElementType.icon:
        attrs['data-pptx-object'] = 'text'; // Icons rendered as text
        attrs['data-pptx-theme-font'] = 'major';
        break;

      case ElementType.chart:
        attrs['data-pptx-object'] = 'chart';
        attrs['data-pptx-replace-with'] = 'chart';
        break;

      case ElementType.shape:
        attrs['data-pptx-object'] = 'shape';
        final ss = element.shapeStyle;
        if (ss != null) {
          switch (ss.shapeType) {
            case 'circle': attrs['data-pptx-prst'] = 'ellipse'; break;
            case 'diamond': attrs['data-pptx-prst'] = 'diamond'; break;
            case 'triangle': attrs['data-pptx-prst'] = 'triangle'; break;
            default: attrs['data-pptx-prst'] = 'rect'; break;
          }
        } else {
          attrs['data-pptx-prst'] = 'rect';
        }
        break;

      case ElementType.image:
        attrs['data-pptx-object'] = 'image';
        break;

      case ElementType.table:
        attrs['data-pptx-object'] = 'table';
        attrs['data-pptx-replace-with'] = 'table';
        break;

      case ElementType.video:
      case ElementType.audio:
        attrs['data-pptx-object'] = 'media';
        break;

      case ElementType.draw:
        attrs['data-pptx-object'] = 'draw';
        break;
    }

    // Common attributes
    attrs['data-pptx-shape-id'] = _shapeIdFromElementId(element.id);

    return attrs;
  }

  /// Build native replacement payload for chart/table
  static Map<String, dynamic> _buildNativePayload(SlideElement element) {
    switch (element.type) {
      case ElementType.chart:
        final cd = element.chartData;
        if (cd == null) return {};
        return {
          'type': cd.chartType,
          'dataSets': cd.dataSets.map((ds) => {
            'label': ds.label,
            'values': ds.values,
            'color': '#${ds.colorValue.toRadixString(16).padLeft(6, '0')}',
          }).toList(),
          'labels': cd.labels,
        };

      case ElementType.table:
        final td = element.tableData;
        if (td == null) return {};
        return {
          'rows': td.rows,
          'cols': td.cols,
          'cells': td.cells,
          'hasHeader': td.hasHeader,
        };

      default:
        return {};
    }
  }

  /// Convert ui.Picture to SVG string
  static String _pictureToSvg(ui.Picture picture, ElementBounds bounds) {
    // Note: Full Picture to SVG conversion requires serialization of drawing commands
    // For now, we generate SVG directly from element data
    // This is a simplified version - production would use a proper Picture to SVG serializer

    final rect = bounds.rect;
    final viewBox = '0 0 ${bounds.width} ${bounds.height}';

    return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="$viewBox" width="${bounds.width}" height="${bounds.height}">
  <!-- Element SVG generated from PictureRecorder -->
  <g transform="translate(${bounds.x} ${bounds.y})">
    <!-- Placeholder - actual implementation uses ElementPainter recording -->
  </g>
</svg>''';
  }

  /// Generate fallback template SVG when asset not found
  static String _generateFallbackTemplateSvg(String layoutId) {
    return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $SLIDE_WIDTH $SLIDE_HEIGHT"
  data-pptx-layout="$layoutId" data-pptx-theme-color-primary="accent1" data-pptx-theme-font-major="major">
  <rect x="0" y="0" width="$SLIDE_WIDTH" height="$SLIDE_HEIGHT" fill="url(#bgGradient)" data-pptx-object="shape" data-pptx-prst="rect"/>
  <text x="96" y="180" data-pptx-slot="title" data-pptx-object="text" data-pptx-theme-font="major" data-pptx-theme-color="dk1" font-size="56" font-weight="bold">{{title}}</text>
  <text x="96" y="280" width="900" data-pptx-slot="paragraph" data-pptx-object="text" data-pptx-theme-font="minor" data-pptx-theme-color="tx1" font-size="20">{{paragraph}}</text>
  <g data-pptx-slot="chart" data-pptx-object="chart" data-pptx-replace-with="chart">
    <metadata type="application/json" data-pptx-kind="chart">{"type":"bar","data":{}}</metadata>
    <rect x="96" y="400" width="500" height="250" fill="#F0F0F0"/>
    <text x="346" y="525" text-anchor="middle" fill="#999">[Chart: {{chartTitle}}]</text>
  </g>
  <image x="800" y="180" width="400" height="300" data-pptx-slot="image" data-pptx-object="image" href="{{imageUrl}}"/>
  <defs>
    <linearGradient id="bgGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="var(--theme-accent1)"/>
      <stop offset="100%" stop-color="var(--theme-dk1)"/>
    </linearGradient>
  </defs>
</svg>''';
  }

  /// Convert element ID to valid shape ID (1-4294967295)
  static String _shapeIdFromElementId(String elementId) {
    // Use hash of element ID to generate consistent shape ID
    int hash = 0;
    for (int i = 0; i < elementId.length; i++) {
      hash = (hash * 31 + elementId.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return (hash % 2147483647 + 2).toString(); // Valid PowerPoint shape ID range
  }

  /// XML escape for slot values
  static String _escapeXml(String text) {
    return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
  }
}