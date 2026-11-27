// DocuCraft — SVG to SlideElements Converter
// Mengurai string SVG (dari AI) dan mengonversinya ke objek SlideElement untuk rendering

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:uuid/uuid.dart';
import '../models/slide.dart';

class SvgToSlideElements {
  static const _uuid = Uuid();

  /// Parse SVG string and return list of SlideElements
  static List<SlideElement> parse(String svg, {
    int sourceCanvasWidth = 1920,
    int sourceCanvasHeight = 1080,
    int targetCanvasWidth = 1920,
    int targetCanvasHeight = 1080,
  }) {
    final elements = <SlideElement>[];

    // Clean SVG - remove newlines and extra spaces
    var cleanSvg = svg.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Strip <defs> blocks (gradients, patterns, etc.)
    cleanSvg = cleanSvg.replaceAll(RegExp(r'<defs>[\s\S]*?</defs>'), '');

    // Strip XML comments
    cleanSvg = cleanSvg.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

    // Extract gradient colors for url(#id) references
    final gradientColors = <String, String>{};
    final gradientRegex = RegExp(r'<linearGradient\s+id="([^"]*)"[^>]*>[\s\S]*?<stop[^>]*style="stop-color:([^"]*)"');
    for (final match in gradientRegex.allMatches(svg)) {
      gradientColors['#${match.group(1)}'] = match.group(2)!;
    }

    final scaleX = targetCanvasWidth / sourceCanvasWidth;
    final scaleY = targetCanvasHeight / sourceCanvasHeight;

    debugPrint('🔍 [SVG Parser] Input: ${svg.length} chars, Scale: ${scaleX.toStringAsFixed(2)}x${scaleY.toStringAsFixed(2)}');

    int zIndexCounter = 0;

    // Helper to get next zIndex
    int nextZIndex() => zIndexCounter++;

    // Helper to extract attribute from tag string
    String? extractAttr(String tag, String attr) {
      final regex = RegExp('$attr\\s*=\\s*"([^"]*)"');
      return regex.firstMatch(tag)?.group(1);
    }

    // Helper to resolve fill color (handles url(#id) references)
    String resolveFill(String? fill) {
      if (fill == null) return '#6366F1';
      if (fill.startsWith('url(#')) {
        final refId = fill.substring(5, fill.length - 1);
        return gradientColors['#$refId'] ?? '#6366F1';
      }
      return fill;
    }

    // Parse <text> elements
    final textRegex = RegExp(r'<text\s+([^>]*?)>(.*?)</text>', dotAll: true);
    for (final match in textRegex.allMatches(cleanSvg)) {
      final tag = match.group(1)!;
      final content = _unescapeXml(match.group(2) ?? '').trim();
      if (content.isEmpty) continue;

      final x = (double.tryParse(extractAttr(tag, 'x') ?? '0') ?? 0) * scaleX;
      final y = (double.tryParse(extractAttr(tag, 'y') ?? '0') ?? 0) * scaleY;
      final fontSize = (double.tryParse(extractAttr(tag, 'font-size') ?? '16') ?? 16) * scaleX;
      final color = extractAttr(tag, 'fill') ?? '#FFFFFF';
      final weight = extractAttr(tag, 'font-weight') ?? 'normal';
      final align = extractAttr(tag, 'text-anchor') ?? 'start';

      elements.add(SlideElement(
        id: _uuid.v7(),
        zIndex: nextZIndex(),
        type: ElementType.text,
        x: x,
        y: y - fontSize,
        width: content.length * fontSize * 0.6,
        height: fontSize * 1.5,
        content: content,
        textStyle: TextStyleData(
          fontSize: fontSize,
          colorValue: _parseColor(color),
          fontWeight: weight == 'bold' ? 'bold' : 'normal',
          textAlign: align == 'middle' ? 'center' : (align == 'end' ? 'right' : 'left'),
        ),
      ));
    }

    // Parse <rect> elements
    final rectRegex = RegExp(r'<rect\s+([^>]*?)/>', dotAll: true);
    for (final match in rectRegex.allMatches(cleanSvg)) {
      final tag = match.group(1)!;
      if (extractAttr(tag, 'data-pptx-replace') != null) continue;

      final x = (double.tryParse(extractAttr(tag, 'x') ?? '0') ?? 0) * scaleX;
      final y = (double.tryParse(extractAttr(tag, 'y') ?? '0') ?? 0) * scaleY;
      final w = (double.tryParse(extractAttr(tag, 'width') ?? '100') ?? 100) * scaleX;
      final h = (double.tryParse(extractAttr(tag, 'height') ?? '100') ?? 100) * scaleY;
      final fill = resolveFill(extractAttr(tag, 'fill'));
      final rx = (double.tryParse(extractAttr(tag, 'rx') ?? '0') ?? 0) * scaleX;
      final opacity = double.tryParse(extractAttr(tag, 'opacity') ?? '1') ?? 1;

      // Skip background rect
      if (x <= 1 && y <= 1 && w >= targetCanvasWidth - 2 && h >= targetCanvasHeight - 2) continue;

      elements.add(SlideElement(
        id: _uuid.v7(),
        zIndex: nextZIndex(),
        type: ElementType.shape, x: x, y: y, width: w, height: h,
        shapeStyle: ShapeStyleData(fillColorValue: _parseColor(fill), borderRadius: rx, opacity: opacity),
      ));
    }

    // Parse <ellipse> elements
    final ellipseRegex = RegExp(r'<ellipse\s+([^>]*?)/>', dotAll: true);
    for (final match in ellipseRegex.allMatches(cleanSvg)) {
      final tag = match.group(1)!;
      final cx = (double.tryParse(extractAttr(tag, 'cx') ?? '0') ?? 0) * scaleX;
      final cy = (double.tryParse(extractAttr(tag, 'cy') ?? '0') ?? 0) * scaleY;
      final rx = (double.tryParse(extractAttr(tag, 'rx') ?? '0') ?? 0) * scaleX;
      final fill = resolveFill(extractAttr(tag, 'fill'));
      final opacity = double.tryParse(extractAttr(tag, 'opacity') ?? '1') ?? 1;

      if (cx - rx <= 1 && cy - rx <= 1 && cx + rx >= targetCanvasWidth - 1 && cy + rx >= targetCanvasHeight - 1) continue;

      elements.add(SlideElement(
        id: _uuid.v7(),
        zIndex: nextZIndex(),
        type: ElementType.shape, x: cx - rx, y: cy - rx, width: rx * 2, height: rx * 2,
        shapeStyle: ShapeStyleData(fillColorValue: _parseColor(fill), shapeType: 'circle', opacity: opacity),
      ));
    }

    // Parse <polygon> elements
    final polygonRegex = RegExp(r'<polygon\s+([^>]*?)/>', dotAll: true);
    for (final match in polygonRegex.allMatches(cleanSvg)) {
      final tag = match.group(1)!;
      final pointsStr = extractAttr(tag, 'points') ?? '';
      final points = pointsStr.split(' ').where((p) => p.isNotEmpty).map((p) {
        final coords = p.split(',');
        return [(double.tryParse(coords[0]) ?? 0) * scaleX, (double.tryParse(coords[1]) ?? 0) * scaleY];
      }).toList();
      if (points.length >= 3) {
        final xs = points.map((p) => p[0]).toList();
        final ys = points.map((p) => p[1]).toList();
        final fill = resolveFill(extractAttr(tag, 'fill'));
        final opacity = double.tryParse(extractAttr(tag, 'opacity') ?? '1') ?? 1;

        elements.add(SlideElement(
          id: _uuid.v7(),
          zIndex: nextZIndex(),
          type: ElementType.shape,
          x: xs.reduce(math.min), y: ys.reduce(math.min),
          width: xs.reduce(math.max) - xs.reduce(math.min),
          height: ys.reduce(math.max) - ys.reduce(math.min),
          shapeStyle: ShapeStyleData(fillColorValue: _parseColor(fill), shapeType: 'polygon', opacity: opacity),
        ));
      }
    }

    // Parse <line> elements (AI sometimes generates these)
    final lineRegex = RegExp(r'<line\s+([^>]*?)/>', dotAll: true);
    for (final match in lineRegex.allMatches(cleanSvg)) {
      final tag = match.group(1)!;
      final x1 = (double.tryParse(extractAttr(tag, 'x1') ?? '0') ?? 0) * scaleX;
      final y1 = (double.tryParse(extractAttr(tag, 'y1') ?? '0') ?? 0) * scaleY;
      final x2 = (double.tryParse(extractAttr(tag, 'x2') ?? '0') ?? 0) * scaleX;
      final y2 = (double.tryParse(extractAttr(tag, 'y2') ?? '0') ?? 0) * scaleY;
      final stroke = resolveFill(extractAttr(tag, 'stroke'));
      final strokeWidth = (double.tryParse(extractAttr(tag, 'stroke-width') ?? '2') ?? 2) * scaleX;

      final minX = math.min(x1, x2);
      final minY = math.min(y1, y2);
      final maxX = math.max(x1, x2);
      final maxY = math.max(y1, y2);

      elements.add(SlideElement(
        id: _uuid.v7(),
        zIndex: nextZIndex(),
        type: ElementType.shape, x: minX, y: minY, width: maxX - minX + strokeWidth, height: maxY - minY + strokeWidth,
        shapeStyle: ShapeStyleData(fillColorValue: _parseColor(stroke), strokeWidth: strokeWidth, opacity: 1),
      ));
    }

    // Parse <circle> elements
    final circleRegex = RegExp(r'<circle\s+([^>]*?)/>', dotAll: true);
    for (final match in circleRegex.allMatches(cleanSvg)) {
      final tag = match.group(1)!;
      final cx = (double.tryParse(extractAttr(tag, 'cx') ?? '0') ?? 0) * scaleX;
      final cy = (double.tryParse(extractAttr(tag, 'cy') ?? '0') ?? 0) * scaleY;
      final r = (double.tryParse(extractAttr(tag, 'r') ?? '0') ?? 0) * scaleX;
      final fill = resolveFill(extractAttr(tag, 'fill'));
      final opacity = double.tryParse(extractAttr(tag, 'opacity') ?? '1') ?? 1;

      if (cx - r <= 1 && cy - r <= 1 && cx + r >= targetCanvasWidth - 1 && cy + r >= targetCanvasHeight - 1) continue;

      elements.add(SlideElement(
        id: _uuid.v7(),
        zIndex: nextZIndex(),
        type: ElementType.shape, x: cx - r, y: cy - r, width: r * 2, height: r * 2,
        shapeStyle: ShapeStyleData(fillColorValue: _parseColor(fill), shapeType: 'circle', opacity: opacity),
      ));
    }

    // Parse <path> elements (convert to polygon-like shape)
    final pathRegex = RegExp(r'<path\s+([^>]*?)/>', dotAll: true);
    for (final match in pathRegex.allMatches(cleanSvg)) {
      final tag = match.group(1)!;
      final d = extractAttr(tag, 'd') ?? '';
      final fill = resolveFill(extractAttr(tag, 'fill'));
      final stroke = resolveFill(extractAttr(tag, 'stroke'));
      final opacity = double.tryParse(extractAttr(tag, 'opacity') ?? '1') ?? 1;

      // Extract all coordinates from path data
      final coords = RegExp(r'[-+]?\d*\.?\d+').allMatches(d).map((m) => double.tryParse(m.group(0)!) ?? 0).toList();
      if (coords.length >= 2) {
        final xs = <double>[];
        final ys = <double>[];
        for (int i = 0; i < coords.length - 1; i += 2) {
          xs.add(coords[i] * scaleX);
          ys.add(coords[i + 1] * scaleY);
        }
        final minX = xs.reduce(math.min);
        final minY = ys.reduce(math.min);
        final maxX = xs.reduce(math.max);
        final maxY = ys.reduce(math.max);

        elements.add(SlideElement(
          id: _uuid.v7(),
          zIndex: nextZIndex(),
          type: ElementType.shape, x: minX, y: minY, width: maxX - minX, height: maxY - minY,
          shapeStyle: ShapeStyleData(fillColorValue: _parseColor(stroke), shapeType: 'polygon', opacity: opacity),
        ));
      }
    }

    // Parse <image> elements
    final imageRegex = RegExp(r'<image\s+([^>]*?)/>', dotAll: true);
    for (final match in imageRegex.allMatches(cleanSvg)) {
      final tag = match.group(1)!;
      final x = (double.tryParse(extractAttr(tag, 'x') ?? '0') ?? 0) * scaleX;
      final y = (double.tryParse(extractAttr(tag, 'y') ?? '0') ?? 0) * scaleY;
      final w = (double.tryParse(extractAttr(tag, 'width') ?? '400') ?? 400) * scaleX;
      final h = (double.tryParse(extractAttr(tag, 'height') ?? '300') ?? 300) * scaleY;
      final src = extractAttr(tag, 'href') ?? extractAttr(tag, 'xlink:href') ?? '';

      elements.add(SlideElement(
        id: _uuid.v7(),
        zIndex: nextZIndex(),
        type: ElementType.image, x: x, y: y, width: w, height: h,
        imageStyle: ImageStyleData(src: src),
      ));
    }

    debugPrint('🔍 [SVG Parser] Total: ${elements.length} elements (${elements.where((e) => e.type == ElementType.text).length} text, ${elements.where((e) => e.type == ElementType.shape).length} shape, ${elements.where((e) => e.type == ElementType.image).length} image)');
    return elements;
  }

  /// Parse GenOffice's editable-structure JSON into editable [SlideElement]s.
  ///
  /// GenOffice's `renderSlidesToEditableJson` walks the RenderSlide tree directly
  /// and emits a FLAT list of absolute-positioned elements — no nested `<g
  /// transform>` groups like `stage.toSVG()` produces, so coordinates map 1:1.
  /// The JSON embeds its own source dimensions, so we scale to the target
  /// canvas here rather than trusting caller-supplied numbers.
  static List<SlideElement> parseEditableJson(String json, {
    int targetCanvasWidth = 1920,
    int targetCanvasHeight = 1080,
  }) {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('⚠️ [EditableJSON] jsonDecode failed: $e');
      return const [];
    }

    final srcW = (data['width'] as num?)?.toDouble() ?? targetCanvasWidth.toDouble();
    final srcH = (data['height'] as num?)?.toDouble() ?? targetCanvasHeight.toDouble();
    final scaleX = targetCanvasWidth / srcW;
    final scaleY = targetCanvasHeight / srcH;

    final rawElements = (data['elements'] as List?) ?? const [];
    final elements = <SlideElement>[];
    int z = 0;

    for (final raw in rawElements) {
      if (raw is! Map) continue;
      final e = raw.cast<String, dynamic>();
      final type = e['type']?.toString() ?? 'shape';
      final x = ((e['x'] as num?)?.toDouble() ?? 0) * scaleX;
      final y = ((e['y'] as num?)?.toDouble() ?? 0) * scaleY;
      final w = ((e['w'] as num?)?.toDouble() ?? 0) * scaleX;
      final h = ((e['h'] as num?)?.toDouble() ?? 0) * scaleY;
      final rotation = (e['rotation'] as num?)?.toDouble() ?? 0;

      switch (type) {
        case 'text':
          final fontSize = ((e['fontSize'] as num?)?.toDouble() ?? 24) * scaleX;
          final color = e['color']?.toString() ?? '#1a1a1a';
          final align = e['align']?.toString() ?? 'left';
          // GenOffice resolves Calibri → Carlito (metric-compatible clone) for layout;
          // map it to the bundled Carlito so Flutter wraps at the same points.
          var fontFamily = e['fontFamily']?.toString();
          // GenOffice's default body font is Calibri; when the editable JSON omits
          // fontFamily (theme default), fall back to the metric-compatible Carlito so
          // Flutter wraps/sizes text exactly like GenOffice instead of using Roboto.
          if (fontFamily == null || fontFamily.toLowerCase().startsWith('calibri')) {
            fontFamily = 'Carlito';
          }
          // Text-box insets (bodyPr insets) — use them as the text padding so Flutter
          // wraps at the exact same width as GenOffice (box.w − insets.l − insets.r),
          // avoiding the fixed 4px padding that shifted wrap points and clipped reflow.
          final insetsRaw = (e['insets'] as Map?)?.cast<String, dynamic>();
          final anchor = e['anchor']?.toString() ?? 'top';
          final insetL = ((insetsRaw?['l'] as num?)?.toDouble() ?? 4.0) * scaleX;
          final insetT = ((insetsRaw?['t'] as num?)?.toDouble() ?? 4.0) * scaleY;
          final insetR = ((insetsRaw?['r'] as num?)?.toDouble() ?? 4.0) * scaleX;
          final insetB = ((insetsRaw?['b'] as num?)?.toDouble() ?? 4.0) * scaleY;
          // Vertical text (bodyPr vert) — GenOffice serializes the laid-out runs
          // (position + rotation) instead of the re-joined paragraph. Parse them
          // verbatim (scaled to design space) so the canvas draws them rotated.
          List<VerticalRun>? verticalRuns;
          final runsRaw = e['runs'];
          if (runsRaw is List && runsRaw.isNotEmpty) {
            verticalRuns = runsRaw.whereType<Map>().map((rawRun) {
              final rr = Map<String, dynamic>.from(rawRun);
              var rf = rr['fontFamily']?.toString();
              if (rf == null || rf.toLowerCase().startsWith('calibri')) rf = 'Carlito';
              return VerticalRun(
                text: rr['text']?.toString() ?? '',
                x: ((rr['x'] as num?)?.toDouble() ?? 0) * scaleX,
                y: ((rr['y'] as num?)?.toDouble() ?? 0) * scaleY,
                rotate: (rr['rotate'] as num?)?.toDouble() ?? 0,
                fontSize: ((rr['fontSize'] as num?)?.toDouble() ?? 24) * scaleX,
                colorValue: _parseColor(rr['color']?.toString() ?? '#ffffff'),
                fontWeight: rr['bold'] == true ? 'bold' : 'normal',
                fontStyle: rr['italic'] == true ? 'italic' : 'normal',
                fontFamily: rf,
              );
            }).toList();
          }
          // Mixed-style horizontal runs — parse each run at its own size/color so
          // stat cards keep their huge number + small sub-label styling.
          List<RichRun>? richRuns;
          final richRaw = e['richRuns'];
          if (richRaw is List && richRaw.isNotEmpty) {
            richRuns = richRaw.whereType<Map>().map((rawRun) {
              final rr = Map<String, dynamic>.from(rawRun);
              var rf = rr['fontFamily']?.toString();
              if (rf == null || rf.toLowerCase().startsWith('calibri')) rf = 'Carlito';
              return RichRun(
                text: rr['text']?.toString() ?? '',
                fontSize: ((rr['fontSize'] as num?)?.toDouble() ?? 24) * scaleX,
                colorValue: _parseColor(rr['color']?.toString() ?? '#ffffff'),
                fontWeight: rr['bold'] == true ? 'bold' : 'normal',
                fontStyle: rr['italic'] == true ? 'italic' : 'normal',
                fontFamily: rf,
              );
            }).toList();
          }
          elements.add(SlideElement(
            id: _uuid.v7(),
            zIndex: z++,
            type: ElementType.text,
            x: x, y: y, width: w, height: h,
            rotation: rotation,
            content: e['text']?.toString() ?? '',
            verticalRuns: verticalRuns,
            richRuns: richRuns,
            textStyle: TextStyleData(
              fontSize: fontSize,
              colorValue: _parseColor(color),
              fontWeight: e['bold'] == true ? 'bold' : 'normal',
              fontStyle: e['italic'] == true ? 'italic' : 'normal',
              fontFamily: fontFamily,
              lineHeight: (e['lineHeight'] as num?)?.toDouble(),
              textAlign: align == 'center' ? 'center' : (align == 'right' ? 'right' : 'left'),
              insetL: insetL,
              insetT: insetT,
              insetR: insetR,
              insetB: insetB,
              anchor: anchor,
            ),
          ));
          break;

        case 'image':
          elements.add(SlideElement(
            id: _uuid.v7(),
            zIndex: z++,
            type: ElementType.image,
            x: x, y: y, width: w, height: h,
            rotation: rotation,
            imageStyle: ImageStyleData(src: e['src']?.toString()),
          ));
          break;

        case 'shape':
        default:
          final fill = e['fill']?.toString() ?? '#6366F1';
          final shapeTypeRaw = e['shapeType']?.toString() ?? 'rect';
          var borderRadius = ((e['borderRadius'] as num?)?.toDouble() ?? 0) * scaleX;
          // GenOffice: rect / roundRect / ellipse → Flutter: rect / circle.
          // roundRect's default corner radius is min(w,h)*0.167 when GenOffice emits no
          // explicit radius (NodeBody.tsx:599) — fall back to it so rounded cards don't
          // flatten into sharp rects. 'circle' renders a true oval via ClipOval.
          if (shapeTypeRaw == 'roundRect' && borderRadius <= 0) {
            borderRadius = (w < h ? w : h) * 0.167;
          }
          // Closed-polygon presets (hexagon/diamond/pentagon/star…) — GenOffice emits
          // the flat point list in box-local source px; scale it into design space so
          // the clip path lands inside the (already-scaled) element box.
          List<double>? polygonPoints;
          final ptsRaw = e['polygonPoints'];
          if (ptsRaw is List && ptsRaw.isNotEmpty) {
            polygonPoints = <double>[];
            for (int i = 0; i + 1 < ptsRaw.length; i += 2) {
              polygonPoints.add(((ptsRaw[i] as num?)?.toDouble() ?? 0) * scaleX);
              polygonPoints.add(((ptsRaw[i + 1] as num?)?.toDouble() ?? 0) * scaleY);
            }
          }
          // Curved presets (donut/ring/heart…) — the path string is box-local source
          // px, drawn 1:1 (DocuCraft canvas == GenOffice canvas == 1920×1080).
          final pathData = e['pathData']?.toString();

          String shapeType;
          switch (shapeTypeRaw) {
            case 'ellipse':
              shapeType = 'circle';
              break;
            case 'polygon':
              shapeType = 'polygon';
              break;
            case 'path':
              shapeType = 'path';
              break;
            default:
              shapeType = 'rect';
          }
          elements.add(SlideElement(
            id: _uuid.v7(),
            zIndex: z++,
            type: ElementType.shape,
            x: x, y: y, width: w, height: h,
            rotation: rotation,
            shapeStyle: ShapeStyleData(
              fillColorValue: _parseColor(fill),
              borderRadius: borderRadius,
              opacity: 1,
              shapeType: shapeType,
              polygonPoints: polygonPoints,
              pathData: pathData,
            ),
          ));
          break;
      }
    }

    debugPrint('🔍 [EditableJSON] Parsed ${elements.length} elements (${srcW}x$srcH → $targetCanvasWidth x$targetCanvasHeight, scale ${scaleX.toStringAsFixed(2)})');
    return elements;
  }

  /// Extract the slide background from a GenOffice editable-JSON string and map
  /// it to an `AppTheme.gradientFor` key (`custom_<hex>,<hex>`). GenOffice emits:
  ///   '#RRGGBB' / '#RRGGBBAA' (solid), or {kind:'gradient', stops:[{pos,color}]}.
  /// Returns null when there's no usable background (caller falls back to white).
  static String? parseBackgroundGradient(String json) {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
    final bg = data['background'];
    if (bg is String) {
      final hex = _colorHex(bg);
      if (hex != null) return 'custom_$hex,$hex';
      return null;
    }
    if (bg is Map) {
      final kind = bg['kind']?.toString();
      if (kind == 'gradient') {
        final stops = (bg['stops'] as List?) ?? const [];
        final first = _colorHex(stops.isNotEmpty ? stops.first['color']?.toString() : null);
        final last = _colorHex(stops.length > 1 ? stops.last['color']?.toString() : null);
        if (first != null) return 'custom_$first,${last ?? first}';
      }
      // image backgrounds are not mapped — fall back.
    }
    return null;
  }

  /// Strip '#'/alpha from a hex color to a bare 6-digit string, or null.
  static String? _colorHex(String? hex) {
    if (hex == null) return null;
    var h = hex.startsWith('#') ? hex.substring(1) : hex;
    if (h.startsWith('rgb')) return null;
    if (h.length >= 6) h = h.substring(0, 6);
    if (h.length != 6) return null;
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(h)) return null;
    return h.toUpperCase();
  }

  static int _parseColor(String hex) {
    if (hex.startsWith('#')) hex = hex.substring(1);
    // rgb(r,g,b) / rgba(r,g,b,a) — Konva sometimes emits these.
    final rgbMatch = RegExp(r'rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)').firstMatch(hex);
    if (rgbMatch != null) {
      final r = int.tryParse(rgbMatch.group(1)!) ?? 0;
      final g = int.tryParse(rgbMatch.group(2)!) ?? 0;
      final b = int.tryParse(rgbMatch.group(3)!) ?? 0;
      final a = double.tryParse(rgbMatch.group(4) ?? '1') ?? 1;
      final aInt = (a * 255).round().clamp(0, 255);
      return (aInt << 24) | (r << 16) | (g << 8) | b;
    }
    if (hex.length == 8) {
      // GenOffice render-tree emits CSS 8-digit hex #RRGGBBAA (alpha LAST, e.g.
      // #2E7DFF14 = a faint blue glow). Flutter's Color int is 0xAARRGGBB
      // (alpha FIRST) — move the trailing alpha to the front, else the alpha
      // gets read as the red channel and the colors scramble (green/yellow blobs
      // instead of the intended faint accents).
      hex = hex.substring(6, 8) + hex.substring(0, 6);
    } else if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return int.tryParse(hex, radix: 16) ?? 0xFFFFFFFF;
  }

  static String _unescapeXml(String text) {
    return text.replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&quot;', '"').replaceAll('&apos;', "'").replaceAll('&amp;', '&');
  }
}
