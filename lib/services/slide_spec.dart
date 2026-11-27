// DocuCraft — JSON Slide Spec (terinspirasi GenOffice)
//
// Format JSON terstruktur untuk slide hasil generate AI. Lebih andal daripada
// SVG karena formatnya ketat: model harus mengeluarkan type, x, y, w, h secara eksplisit.
//
// Berdasarkan page-spec.ts milik GenOffice:
//   - Canvas: 1280x720 (HD standar)
//   - Elemen: text, shape, image dengan positioning eksplisit
//   - Shapes: rect, roundRect, ellipse, triangle, arrows, dll.
//   - Teks: paragraf dengan runs (bold/warna/ukuran campuran dalam satu baris)

import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/slide.dart';

const _uuid = Uuid();

/// Canvas dimensions (matches GenOffice's SPEC_CANVAS_W/H)
const specCanvasW = 1280;
const specCanvasH = 720;

const _maxElements = 48;
const _maxImages = 8;

/// Allowed shape kinds (matches GenOffice's SHAPE_KINDS)
const _shapeKinds = {
  'rect', 'roundRect', 'ellipse', 'triangle',
  'rightArrow', 'leftArrow', 'upArrow', 'downArrow',
  'chevron', 'diamond', 'parallelogram', 'trapezoid',
  'hexagon', 'pentagon', 'pie', 'donut', 'star5',
  'heart', 'cloud', 'line', 'lineArrow',
};

// ── Spec Data Classes ─────────────────────────────────────────────

class SpecRun {
  final String text;
  final double? sizePt;
  final bool? bold;
  final bool? italic;
  final String? color;
  final String? font;

  const SpecRun({
    required this.text,
    this.sizePt,
    this.bold,
    this.italic,
    this.color,
    this.font,
  });

  factory SpecRun.fromJson(Map<String, dynamic> json) => SpecRun(
    text: json['text']?.toString() ?? '',
    sizePt: (json['sizePt'] as num?)?.toDouble(),
    bold: json['bold'] as bool?,
    italic: json['italic'] as bool?,
    color: json['color']?.toString(),
    font: json['font']?.toString(),
  );
}

class SpecParagraph {
  final List<SpecRun> runs;
  final String? align;
  final double? lineSpacingPct;
  final double? spaceBeforePt;
  final double? spaceAfterPt;
  final bool? bullet;

  const SpecParagraph({
    required this.runs,
    this.align,
    this.lineSpacingPct,
    this.spaceBeforePt,
    this.spaceAfterPt,
    this.bullet,
  });

  factory SpecParagraph.fromJson(Map<String, dynamic> json) => SpecParagraph(
    runs: (json['runs'] as List<dynamic>?)
        ?.map((r) => SpecRun.fromJson(r as Map<String, dynamic>))
        .toList() ?? [],
    align: json['align']?.toString(),
    lineSpacingPct: (json['lineSpacingPct'] as num?)?.toDouble(),
    spaceBeforePt: (json['spaceBeforePt'] as num?)?.toDouble(),
    spaceAfterPt: (json['spaceAfterPt'] as num?)?.toDouble(),
    bullet: json['bullet'] as bool?,
  );
}

class SpecBase {
  final double x, y, w, h;
  const SpecBase({required this.x, required this.y, required this.w, required this.h});
}

class SpecText extends SpecBase {
  final List<SpecParagraph> paragraphs;
  final String? valign;

  const SpecText({
    required super.x, required super.y, required super.w, required super.h,
    required this.paragraphs,
    this.valign,
  });

  factory SpecText.fromJson(Map<String, dynamic> json) => SpecText(
    x: (json['x'] as num?)?.toDouble() ?? 0,
    y: (json['y'] as num?)?.toDouble() ?? 0,
    w: (json['w'] as num?)?.toDouble() ?? 100,
    h: (json['h'] as num?)?.toDouble() ?? 40,
    paragraphs: (json['paragraphs'] as List<dynamic>?)
        ?.map((p) => SpecParagraph.fromJson(p as Map<String, dynamic>))
        .toList() ?? [],
    valign: json['valign']?.toString(),
  );
}

class SpecShape extends SpecBase {
  final String shape;
  final String? fill;
  final Map<String, dynamic>? stroke;
  final List<SpecParagraph>? paragraphs;
  final String? valign;

  const SpecShape({
    required super.x, required super.y, required super.w, required super.h,
    required this.shape,
    this.fill,
    this.stroke,
    this.paragraphs,
    this.valign,
  });

  factory SpecShape.fromJson(Map<String, dynamic> json) => SpecShape(
    x: (json['x'] as num?)?.toDouble() ?? 0,
    y: (json['y'] as num?)?.toDouble() ?? 0,
    w: (json['w'] as num?)?.toDouble() ?? 100,
    h: (json['h'] as num?)?.toDouble() ?? 100,
    shape: json['shape']?.toString() ?? 'rect',
    fill: json['fill']?.toString(),
    stroke: json['stroke'] as Map<String, dynamic>?,
    paragraphs: (json['paragraphs'] as List<dynamic>?)
        ?.map((p) => SpecParagraph.fromJson(p as Map<String, dynamic>))
        .toList(),
    valign: json['valign']?.toString(),
  );
}

class SpecImage extends SpecBase {
  final String url;
  const SpecImage({
    required super.x, required super.y, required super.w, required super.h,
    required this.url,
  });

  factory SpecImage.fromJson(Map<String, dynamic> json) => SpecImage(
    x: (json['x'] as num?)?.toDouble() ?? 0,
    y: (json['y'] as num?)?.toDouble() ?? 0,
    w: (json['w'] as num?)?.toDouble() ?? 100,
    h: (json['h'] as num?)?.toDouble() ?? 100,
    url: json['url']?.toString() ?? '',
  );
}

typedef SpecElement = dynamic; // SpecText | SpecShape | SpecImage

class PageSpec {
  final String? background;
  final List<SpecElement> elements;

  const PageSpec({this.background, required this.elements});
}

// ── Parsing ───────────────────────────────────────────────────────

/// Parse raw LLM output into a validated PageSpec.
/// Extracts the first JSON object from the text (tolerates markdown fences).
ParseResult parseSlideSpec(String raw) {
  // Extract JSON object from raw text
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) {
    return ParseResult.error('No JSON object found in AI output');
  }

  Map<String, dynamic> root;
  try {
    root = jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
  } catch (e) {
    return ParseResult.error('Invalid JSON: $e');
  }

  final rawEls = root['elements'] as List<dynamic>? ?? [];
  if (rawEls.isEmpty) {
    return ParseResult.error('"elements" array is missing or empty');
  }

  final warnings = <String>[];
  final elements = <SpecElement>[];
  int images = 0;

  for (int i = 0; i < rawEls.length && elements.length < _maxElements; i++) {
    final rawEl = rawEls[i];
    if (rawEl is! Map<String, dynamic>) continue;

    final type = rawEl['type']?.toString() ?? '';
    final x = (rawEl['x'] as num?)?.toDouble() ?? 0;
    final y = (rawEl['y'] as num?)?.toDouble() ?? 0;
    final w = (rawEl['w'] as num?)?.toDouble() ?? 100;
    final h = (rawEl['h'] as num?)?.toDouble() ?? 100;

    // Clamp to canvas
    if (x >= specCanvasW || y >= specCanvasH || x + w <= 0 || y + h <= 0) {
      warnings.add('Element $i outside canvas, dropped');
      continue;
    }

    if (type == 'image') {
      images++;
      if (images > _maxImages) {
        warnings.add('Max $_maxImages images exceeded, dropped element $i');
        continue;
      }
      final url = rawEl['url']?.toString() ?? '';
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        warnings.add('Element $i: invalid image URL, dropped');
        continue;
      }
      elements.add(SpecImage.fromJson(rawEl));
    } else if (type == 'text') {
      elements.add(SpecText.fromJson(rawEl));
    } else if (type == 'shape') {
      final shape = rawEl['shape']?.toString() ?? 'rect';
      if (!_shapeKinds.contains(shape)) {
        warnings.add('Element $i: unknown shape "$shape", defaulting to rect');
        rawEl['shape'] = 'rect';
      }
      elements.add(SpecShape.fromJson(rawEl));
    } else {
      warnings.add('Element $i: unknown type "$type", skipped');
    }
  }

  if (elements.isEmpty) {
    return ParseResult.error('No valid elements (${warnings.join('; ')})');
  }

  final bg = root['background']?.toString();
  return ParseResult.ok(PageSpec(
    background: bg != null ? _normColor(bg) : null,
    elements: elements,
  ), warnings: warnings);
}

class ParseResult {
  final bool ok;
  final PageSpec? spec;
  final String? error;
  final List<String> warnings;

  const ParseResult._({required this.ok, this.spec, this.error, this.warnings = const []});

  factory ParseResult.ok(PageSpec spec, {List<String> warnings = const []}) =>
      ParseResult._(ok: true, spec: spec, warnings: warnings);

  factory ParseResult.error(String error) =>
      ParseResult._(ok: false, error: error);
}

// ── Post-parse Layout Clamp ──────────────────────────────────────

/// Clamp all elements to canvas bounds (1280×720).
/// Fixes AI output that places elements partially or fully off-canvas.
void clampSpecToCanvas(PageSpec spec) {
  for (final el in spec.elements) {
    if (el is SpecBase) {
      // Clamp x,y so element starts inside canvas
      if (el.x < 0) {
        (el as dynamic).x = 0.0;
      }
      if (el.y < 0) {
        (el as dynamic).y = 0.0;
      }
      // Clamp so element doesn't extend past right/bottom edge
      if (el.x + el.w > specCanvasW) {
        final newW = specCanvasW - el.x;
        if (newW > 10) {
          (el as dynamic).w = newW;
        } else {
          (el as dynamic).x = (specCanvasW - 10).toDouble();
        }
      }
      if (el.y + el.h > specCanvasH) {
        final newH = specCanvasH - el.y;
        if (newH > 10) {
          (el as dynamic).h = newH;
        } else {
          (el as dynamic).y = (specCanvasH - 10).toDouble();
        }
      }
    }
  }
}

// ── Spec → SlideElement Conversion ────────────────────────────────

/// Scale factor from spec canvas (1280×720) to model canvas (1920×1080).
const double specToModelScale = 1920 / 1280; // 1.5

/// Convert a PageSpec to SlideElements.
/// [scale] multiplies all coordinates/sizes — pass [specToModelScale] (1.5)
/// when targeting the 1920×1080 model canvas, or 1.0 for 1280×720 (PPTX).
List<SlideElement> specToSlideElements(PageSpec spec, {double scale = 1.0}) {
  final elements = <SlideElement>[];
  int zIdx = 0;

  for (final el in spec.elements) {
    if (el is SpecText) {
      _addTextElements(el, elements, zIdx, scale: scale);
      zIdx++;
    } else if (el is SpecShape) {
      _addShapeElements(el, elements, zIdx, scale: scale);
      zIdx++;
    } else if (el is SpecImage) {
      elements.add(SlideElement(
        id: _uuid.v7(),
        type: ElementType.image,
        x: el.x * scale,
        y: el.y * scale,
        width: el.w * scale,
        height: el.h * scale,
        content: el.url,
        zIndex: zIdx++,
      ));
    }
  }

  return elements;
}

void _addTextElements(SpecText spec, List<SlideElement> elements, int zIdx, {double scale = 1.0}) {
  if (spec.paragraphs.isEmpty) return;

  // Use first paragraph's dominant run for base styling
  final firstRun = spec.paragraphs.first.runs.isNotEmpty
      ? spec.paragraphs.first.runs.first
      : null;

  // GenOffice-style: preserve paragraph structure with newline separators
  // Each paragraph keeps its own alignment and spacing
  final buffer = StringBuffer();
  for (int pi = 0; pi < spec.paragraphs.length; pi++) {
    final p = spec.paragraphs[pi];
    for (final run in p.runs) {
      // Preserve bold/italic markers in content for downstream rendering
      String text = run.text;
      if (run.bold == true) text = '**$text**';
      if (run.italic == true) text = '_${text}_';
      buffer.write(text);
    }
    // Add paragraph break (not after last paragraph)
    if (pi < spec.paragraphs.length - 1) buffer.writeln();
  }
  final content = buffer.toString().trim();
  if (content.isEmpty) return;

  // GenOffice: preserve font family from first run
  final fontFamily = firstRun?.font;

  elements.add(SlideElement(
    id: _uuid.v7(),
    type: ElementType.text,
    x: spec.x * scale,
    y: spec.y * scale,
    width: spec.w * scale,
    height: spec.h * scale,
    content: content,
    zIndex: zIdx,
    textStyle: TextStyleData(
      fontSize: (firstRun?.sizePt ?? 24) * scale,
      colorValue: firstRun?.color != null ? _hexToInt(firstRun!.color!) : 0xFFFFFFFF,
      fontWeight: firstRun?.bold == true ? 'bold' : 'normal',
      fontFamily: fontFamily,
      textAlign: spec.paragraphs.first.align == 'center'
          ? 'center'
          : spec.paragraphs.first.align == 'right'
              ? 'right'
              : 'left',
    ),
  ));
}

void _addShapeElements(SpecShape spec, List<SlideElement> elements, int zIdx, {double scale = 1.0}) {
  // Shape background — apply scale factor
  elements.add(SlideElement(
    id: _uuid.v7(),
    type: ElementType.shape,
    x: spec.x * scale,
    y: spec.y * scale,
    width: spec.w * scale,
    height: spec.h * scale,
    zIndex: zIdx,
    shapeStyle: ShapeStyleData(
      shapeType: _mapShapeType(spec.shape),
      fillColorValue: spec.fill != null ? _hexToInt(spec.fill!) : 0xFF4F46E5,
      strokeColorValue: spec.stroke?['color'] != null ? _hexToInt(spec.stroke!['color'] as String) : null,
      strokeWidth: (spec.stroke?['widthPt'] as num?)?.toDouble() ?? 1,
    ),
  ));

  // GenOffice: zero inner padding — shape label text uses exact same position as shape
  if (spec.paragraphs != null && spec.paragraphs!.isNotEmpty) {
    final buffer = StringBuffer();
    for (final p in spec.paragraphs!) {
      for (final run in p.runs) {
        buffer.write(run.text);
      }
      buffer.writeln();
    }
    final label = buffer.toString().trim();
    if (label.isNotEmpty) {
      final firstRun = spec.paragraphs!.first.runs.firstOrNull;
      // GenOffice: zero padding — box top-left is exactly where first glyph starts
      elements.add(SlideElement(
        id: _uuid.v7(),
        type: ElementType.text,
        x: spec.x * scale,
        y: spec.y * scale,
        width: spec.w * scale,
        height: spec.h * scale,
        content: label,
        zIndex: zIdx + 1,
        textStyle: TextStyleData(
          fontSize: (firstRun?.sizePt ?? 16) * scale,
          colorValue: firstRun?.color != null ? _hexToInt(firstRun!.color!) : 0xFFFFFFFF,
          fontWeight: firstRun?.bold == true ? 'bold' : 'normal',
          fontFamily: firstRun?.font,
          textAlign: 'center',
        ),
      ));
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────

/// Convert hex color string (#RGB or #RRGGBB or #RRGGBBAA) to int (0xFFFFFFFF)
int _hexToInt(String hex) {
  hex = hex.trim().replaceFirst('#', '');
  if (hex.length == 3) {
    // #RGB → #RRGGBB
    hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
  }
  if (hex.length == 8) {
    // #RRGGBBAA → strip alpha, keep RGB as 0xFFRRGGBB
    hex = 'FF${hex.substring(0, 6)}';
  }
  if (hex.length == 6) hex = 'FF$hex'; // add full alpha
  return int.tryParse(hex, radix: 16) ?? 0xFFFFFFFF;
}

String _normColor(String c) {
  c = c.trim();
  if (c.length == 4 && c.startsWith('#')) {
    // #RGB → #RRGGBB
    return '#${c[1]}${c[1]}${c[2]}${c[2]}${c[3]}${c[3]}';
  }
  return c;
}

String _mapShapeType(String shape) {
  switch (shape) {
    case 'roundRect':
      return 'roundRect';
    case 'ellipse':
      return 'ellipse';
    case 'triangle':
      return 'triangle';
    case 'diamond':
      return 'diamond';
    case 'star5':
      return 'star';
    case 'heart':
      return 'heart';
    case 'cloud':
      return 'cloud';
    case 'hexagon':
      return 'hexagon';
    case 'pentagon':
      return 'pentagon';
    case 'line':
    case 'lineArrow':
      return 'line';
    case 'rightArrow':
    case 'leftArrow':
    case 'upArrow':
    case 'downArrow':
    case 'chevron':
      return 'arrow';
    default:
      return 'rect';
  }
}
