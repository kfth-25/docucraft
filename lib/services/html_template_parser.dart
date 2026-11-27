// DocuCraft — HTML Template Parser (V3)
// Meng-parse template HTML menjadi objek Slide dengan data SlideElement[]
//
// V3: XML tree traversal — menghitung posisi kumulatif dari parent containers
// (position:absolute + left/top dari parent, margin-top stacking, gap).
// Hasil render mendekati desain asli HTML.

import 'package:flutter/services.dart' show rootBundle;
import 'package:xml/xml.dart';
import '../models/slide.dart';

class HtmlTemplateParser {
  /// Load HTML template from assets and parse into a Slide.
  /// Stores the HTML path in extra['htmlTemplate'] for direct iframe rendering on web.
  static Future<Slide?> loadFromAsset(String assetPath, Map<String, String> data) async {
    try {
      final html = await rootBundle.loadString(assetPath);
      final slide = parse(html, data);
      if (slide != null) {
        // Store template path for direct HTML rendering (web iframe)
        slide.extra ??= {};
        slide.extra!['htmlTemplate'] = assetPath;
      }
      return slide;
    } catch (e) {
      print('Failed to load template $assetPath: $e');
      return null;
    }
  }

  /// Parse an HTML template string into a Slide with elements
  /// data: map of placeholder values e.g. {"TITLE": "My Title", "PARAGRAPH": "..."}
  static Slide? parse(String htmlTemplate, Map<String, String> data) {
    try {
      // Replace all __PLACEHOLDER__ tokens with values
      String populated = htmlTemplate;
      for (final entry in data.entries) {
        populated = populated.replaceAll('__${entry.key}__', entry.value);
      }

      final bgGradient = _extractBgColor(populated);
      final elements = _extractElementsV3(populated);
      print('🎨 Parser V3: bg=$bgGradient, elements=${elements.length}');
      for (final el in elements) {
        print('  → ${el.type.name} (${el.x.round()},${el.y.round()}) ${el.width.round()}x${el.height.round()} "${(el.content ?? '').substring(0, (el.content ?? '').length > 30 ? 30 : (el.content ?? '').length)}"');
      }

      return Slide(
        title: data['TITLE'] ?? 'Untitled',
        subtitle: data['SUBTITLE'] ?? '',
        backgroundGradient: bgGradient,
        elements: elements,
      );
    } catch (e) {
      print('HTML template parse error: $e');
      return null;
    }
  }

  /// Extract background color from HTML
  static String _extractBgColor(String html) {
    final bgMatch = RegExp(r'\.slide\s*\{[^}]*background-color:\s*(#[0-9a-fA-F]{6})').firstMatch(html);
    if (bgMatch != null) {
      return _hexToGradientName(bgMatch.group(1) ?? '#6366F1');
    }
    final inlineMatch = RegExp(r'background-color:\s*(#[0-9a-fA-F]{6})').firstMatch(html);
    if (inlineMatch != null) {
      return _hexToGradientName(inlineMatch.group(1) ?? '#6366F1');
    }
    return 'indigo';
  }

  /// Map hex color to DocuCraft gradient name
  /// Returns 'custom_HEX,HEX' for colors not in the known map
  static String _hexToGradientName(String hex) {
    final h = hex.toUpperCase();
    final cleanHex = h.replaceFirst('#', '');
    const map = {
      '#000000': 'slate',
      '#111827': 'slate',
      '#1A1A2E': 'midnight',
    };
    if (map.containsKey(h)) return map[h]!;
    return 'custom_$cleanHex,$cleanHex';
  }

  // ──────────────────────────────────────────────
  // CSS helpers
  // ──────────────────────────────────────────────

  /// Simple CSS rule parser: returns Map<classOrTag, Map<property, value>>
  static Map<String, Map<String, String>> _parseCssRules(String html) {
    final rules = <String, Map<String, String>>{};
    final pattern = RegExp(r'([.#]?[\w-]+)\s*\{([^}]*)\}');
    for (final m in pattern.allMatches(html)) {
      final selector = m.group(1)!.replaceFirst('.', '');
      final body = m.group(2) ?? '';
      final props = <String, String>{};
      for (final pm in RegExp(r'([\w-]+)\s*:\s*([^;]+);').allMatches(body)) {
        props[pm.group(1)!] = pm.group(2)!.trim();
      }
      rules[selector] = props;
    }
    return rules;
  }

  /// Parse inline style="..." menjadi Map property → value
  static Map<String, String> _parseInlineStyle(String? styleAttr) {
    final props = <String, String>{};
    if (styleAttr == null || styleAttr.isEmpty) return props;
    for (final part in styleAttr.split(';')) {
      final idx = part.indexOf(':');
      if (idx > 0) {
        props[part.substring(0, idx).trim()] = part.substring(idx + 1).trim();
      }
    }
    return props;
  }

  static Map<String, String> _cssFor(String classes, String tag, Map<String, Map<String, String>> rules, {String? inlineStyle}) {
    final props = <String, String>{};
    for (final cls in classes.split(RegExp(r'\s+'))) {
      if (cls.isNotEmpty && rules.containsKey(cls)) props.addAll(rules[cls]!);
    }
    if (rules.containsKey(tag)) props.addAll(rules[tag]!);
    // Inline style menang (paling spesifik)
    if (inlineStyle != null) props.addAll(_parseInlineStyle(inlineStyle));
    return props;
  }

  static double? _px(String? v) {
    if (v == null) return null;
    final cleaned = v.replaceAll('px', '').trim();
    return double.tryParse(cleaned);
  }

  static double? _pctOf(String? v, double total) {
    if (v == null || !v.contains('%')) return null;
    final p = double.tryParse(v.replaceAll('%', '').trim());
    return p == null ? null : total * p / 100;
  }

  static int? _hexToInt(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return int.tryParse(h, radix: 16);
  }

  static String _cssAlign(String? align) {
    switch (align) {
      case 'center': return 'center';
      case 'right': return 'right';
      default: return 'left';
    }
  }

  // ──────────────────────────────────────────────
  // V3: XML tree traversal with parent position context
  // ──────────────────────────────────────────────

  /// Result of walking a container: the container's own position/size
  static List<SlideElement> _extractElementsV3(String html) {
    final elements = <SlideElement>[];
    final rules = _parseCssRules(html);

    // ── Pre-process HTML supaya valid XML ──
    // 1. Strip DOCTYPE
    var cleaned = html.replaceFirst(RegExp(r'<!DOCTYPE[^>]*>', caseSensitive: false), '');

    // 2. Self-close semua void tags (meta, link, br, hr, input, img)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'<(meta|link|br|hr|input|img)(\b[^>]*)>', caseSensitive: false),
      (m) => m.group(0)!.endsWith('/>') ? m.group(0)! : '<${m.group(1)}${m.group(2)} />',
    );

    // 3. Parse XML — dengan fallback ke regex-based V2 kalau XML tetap gagal
    XmlDocument? doc;
    try {
      doc = XmlDocument.parse(cleaned);
    } catch (e) {
      print('⚠️ XML parse failed ($e), falling back to regex parser');
      return _fallbackRegexParser(html);
    }
    final root = doc.rootElement;

    // Recursive walk with inherited position
    void walk(XmlElement el, double px, double py) {
      final tag = el.name.local.toLowerCase();
      // Skip tag non-content — jangan dirender sebagai elemen slide
      if (tag == 'style' || tag == 'script' || tag == 'title' || tag == 'head' || tag == 'meta' || tag == 'link') return;
      final classes = el.getAttribute('class') ?? '';
      final inlineStyle = el.getAttribute('style');
      final props = _cssFor(classes, tag, rules, inlineStyle: inlineStyle);

      // Compute this element's position
      double x = px, y = py;
      double w = _px(props['width']) ?? _pctOf(props['width'], 1920) ?? 0;
      double h = _px(props['height']) ?? _pctOf(props['height'], 1080) ?? 0;

      if (props['position'] == 'absolute') {
        x = _px(props['left']) ?? px;
        y = _px(props['top']) ?? py;
        // right-based
        final right = _px(props['right']);
        if (right != null && props['left'] == null) {
          final cw = w > 0 ? w : (props['width']?.contains('%') == true ? 1920 * (double.tryParse(props['width']!.replaceAll('%', '')) ?? 30) / 100 : 300);
          x = 1920 - right - cw;
        }
        // bottom-based
        final bottom = _px(props['bottom']);
        if (bottom != null && props['top'] == null) {
          final ch = h > 0 ? h : (props['height']?.contains('%') == true ? 1080 * (double.tryParse(props['height']!.replaceAll('%', '')) ?? 30) / 100 : 50);
          y = 1080 - bottom - ch;
        }
      }

      // Width/height defaults
      if (w <= 0) {
        w = props['width']?.contains('%') == true
            ? 1920 * (double.tryParse(props['width']!.replaceAll('%', '')) ?? 30) / 100
            : 300;
      }
      if (h <= 0) {
        h = props['height']?.contains('%') == true
            ? 1080 * (double.tryParse(props['height']!.replaceAll('%', '')) ?? 30) / 100
            : 50;
      }

      // Margin-top stacking (flow layout inside container)
      final marginTop = _px(props['margin-top']) ?? 0;
      final marginBottom = _px(props['margin-bottom']) ?? 0;

      // ── Leaf content handling ──
      final text = el.innerText.trim();
      final isLeaf = el.childElements.isEmpty || tag == 'img' || tag == 'span' || tag == 'h1' || tag == 'h2' || tag == 'h3' || tag == 'p';

      if (isLeaf && text.isNotEmpty && !text.startsWith('__') && !text.startsWith('_')) {
        // Skip containers that have meaningful children
        final childrenTexts = el.childElements.map((c) => c.innerText.trim()).where((t) => t.isNotEmpty).toList();
        if (childrenTexts.length <= 1) {
          double fontSize = _px(props['font-size']) ?? 16;
          if (tag == 'h1') fontSize = 64;
          if (tag == 'h2') fontSize = 36;
          if (tag == 'p') fontSize = 16;

          final color = _hexToInt(props['color']) ?? 0xFF111827;

          // Width for text: if no explicit width, estimate from content
          final textW = w > 0 && w < 1920 ? w : (text.length * fontSize * 0.6).clamp(100.0, 1200.0);

          elements.add(SlideElement(
            type: ElementType.text,
            x: x,
            y: y + marginTop,
            width: textW,
            height: h > 0 ? h : fontSize * 1.5,
            content: text,
            textStyle: TextStyleData(
              fontSize: fontSize,
              colorValue: color,
              fontWeight: props['font-weight']?.contains('600') == true ||
                         props['font-weight']?.contains('bold') == true ? 'bold' : 'normal',
              fontFamily: props['font-family']?.replaceAll("'", ''),
              letterSpacing: double.tryParse((props['letter-spacing'] ?? '').replaceAll('em', '')),
              lineHeight: _px(props['line-height']),
              textAlign: _cssAlign(props['text-align']),
            ),
          ));
        }
      }

      // ── Image ──
      if (tag == 'img') {
        final src = el.getAttribute('src');
        final alt = el.getAttribute('alt') ?? 'Image';
        if (src != null && !src.startsWith('_')) {
          // img fills its container (image-panel)
          final containerProps = _cssFor(classes, tag, rules);
          double imgW = _px(containerProps['width']) ?? w;
          double imgH = _px(containerProps['height']) ?? h;
          if (imgW <= 0) imgW = 400;
          if (imgH <= 0) imgH = 300;

          elements.add(SlideElement(
            type: ElementType.image,
            x: x,
            y: y,
            width: imgW,
            height: imgH,
            imageStyle: ImageStyleData(
              src: src,
              placeholderLabel: alt,
            ),
          ));
        }
      }

      // ── Decorative shape (div with background-color, no text) ──
      if ((tag == 'div' || tag == 'span') && text.isEmpty) {
        final bg = props['background-color'];
        if (bg != null) {
          elements.add(SlideElement(
            type: ElementType.shape,
            x: x,
            y: y,
            width: w > 0 ? w : 20,
            height: h > 0 ? h : 20,
            shapeStyle: ShapeStyleData(
              fillColorValue: _hexToInt(bg) ?? 0xFF111827,
              borderRadius: 0,
            ),
          ));
        }
      }

      // ── Recurse into children (unconditional — semua elemen) ──
      double childY = y + marginTop;
      final gap = _px(props['gap']) ?? 0;
      for (final child in el.childElements) {
        walk(child, x, childY);
        // Flow stacking: hitung posisi child berikutnya
        final childProps = _cssFor(child.getAttribute('class') ?? '', child.name.local.toLowerCase(), rules);
        final childH = _px(childProps['height']) ?? 0;
        childY += childH > 0 ? childH + gap : 50 + gap;
      }
    }

    walk(root, 0, 0);
    return elements;
  }

  // ──────────────────────────────────────────────
  // Fallback: regex-based parser V2 (robust untuk HTML non-well-formed)
  // ──────────────────────────────────────────────

  static List<SlideElement> _fallbackRegexParser(String html) {
    final elements = <SlideElement>[];
    final rules = _parseCssRules(html);

    // Match all tags with class and content
    final tagPattern = RegExp(r'<(h[1-6]|p|span|div)\b([^>]*)>([^<]*)</\1>', caseSensitive: false);
    for (final m in tagPattern.allMatches(html)) {
      final tag = m.group(1)!.toLowerCase();
      final attrs = m.group(2) ?? '';
      final content = m.group(3) ?? '';
      if (content.isEmpty || content.startsWith('_') || content.startsWith('__')) continue;

      final classMatch = RegExp(r'class="([^"]*)"').firstMatch(attrs);
      final classes = classMatch?.group(1) ?? '';
      final styleMatch = RegExp(r'style="([^"]*)"').firstMatch(attrs);
      final inlineStyle = styleMatch?.group(1);
      final props = _cssFor(classes, tag, rules, inlineStyle: inlineStyle);

      // Position
      double x = _px(props['left']) ?? 0;
      double y = _px(props['top']) ?? 0;
      final right = _px(props['right']);
      double w = _px(props['width']) ?? _pctOf(props['width'], 1920) ?? 300;
      double h = _px(props['height']) ?? _pctOf(props['height'], 1080) ?? 50;
      if (right != null && props['left'] == null) x = 1920 - right - w;

      // Text
      if (content.isNotEmpty && !content.startsWith('__')) {
        double fontSize = _px(props['font-size']) ?? 16;
        if (tag == 'h1') fontSize = 64;
        if (tag == 'h2') fontSize = 36;
        elements.add(SlideElement(
          type: ElementType.text,
          x: x, y: y,
          width: w > 0 ? w : (content.length * fontSize * 0.6).clamp(100.0, 1200.0),
          height: h > 0 ? h : fontSize * 1.5,
          content: content.trim(),
          textStyle: TextStyleData(
            fontSize: fontSize,
            colorValue: _hexToInt(props['color']) ?? 0xFF111827,
            fontWeight: props['font-weight']?.contains('600') == true ||
                       props['font-weight']?.contains('bold') == true ? 'bold' : 'normal',
            fontFamily: props['font-family']?.replaceAll("'", ''),
          ),
        ));
      }
      // Shape
      else if (content.isEmpty && props['background-color'] != null) {
        elements.add(SlideElement(
          type: ElementType.shape,
          x: x, y: y,
          width: w > 0 ? w : 20,
          height: h > 0 ? h : 20,
          shapeStyle: ShapeStyleData(
            fillColorValue: _hexToInt(props['background-color']) ?? 0xFF111827,
            borderRadius: 0,
          ),
        ));
      }
    }

    // Images
    final imgPattern = RegExp(r'<img\b([^>]+?)(?:\s*/?)\s*>', caseSensitive: false);
    for (final m in imgPattern.allMatches(html)) {
      final attrs = m.group(1) ?? '';
      final srcMatch = RegExp(r'src="([^"]*)"').firstMatch(attrs);
      if (srcMatch == null) continue;
      final classMatch = RegExp(r'class="([^"]*)"').firstMatch(attrs);
      final classes = classMatch?.group(1) ?? '';
      final props = _cssFor(classes, 'img', rules);
      double x = _px(props['left']) ?? 0;
      double y = _px(props['top']) ?? 0;
      double w = _px(props['width']) ?? _pctOf(props['width'], 1920) ?? 400;
      double h = _px(props['height']) ?? _pctOf(props['height'], 1080) ?? 400;
      final right = _px(props['right']);
      if (right != null && props['left'] == null) x = 1920 - right - w;
      elements.add(SlideElement(
        type: ElementType.image,
        x: x, y: y, width: w, height: h,
        imageStyle: ImageStyleData(src: srcMatch.group(1)),
      ));
    }

    return elements;
  }
}
