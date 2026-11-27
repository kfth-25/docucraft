// DocuCraft — Slide Model V2
// Di-refactor untuk kolaborasi CRDT, AI generation, dan editing PPT asli
//
// Perubahan dari V1:
//   - ID UUID v7 (terurut waktu, bisa di-sort, aman untuk multi-user)
//   - Posisi berbasis piksel (design space 1920×1080)
//   - Objek style terstruktur (TextStyleData, ShapeStyleData, dll.)
//   - Metadata CRDT (version, lastModifiedBy, lastModifiedAt)
//   - zIndex untuk urutan tumpukan elemen
//   - templateSlotId untuk template engine (Phase 2)
//   - Enum ElementType menggantikan String mentah
//   - Migrasi JSON backward-compatible dari format V1

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
const double _baseCanvasWidth = 1920;
const double _baseCanvasHeight = 1080;

/// Coerce a dynamic JSON value to [double] with a fallback. Returns
/// [fallback] when the value is `null`, not a number, or a non-parsable
/// string. Used by [SlideElement.fromJson] to absorb legacy / hand-edited
/// documents that surface numeric fields as strings.
double _toDouble(dynamic v, double fallback) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

// ──────────────────────────────────────────────
// Enums
// ──────────────────────────────────────────────

@HiveType(typeId: 0)
enum ElementType {
  @HiveField(0)
  text,
  @HiveField(1)
  image,
  @HiveField(2)
  shape,
  @HiveField(3)
  chart,
  @HiveField(4)
  table,
  @HiveField(5)
  icon,
  @HiveField(6)
  video,
  @HiveField(7)
  audio,
  @HiveField(8)
  draw,
}

// ──────────────────────────────────────────────
// Style Data Classes
// ──────────────────────────────────────────────

@HiveType(typeId: 0)
class TextStyleData {
  @HiveField(0)
  double fontSize;
  @HiveField(1)
  int colorValue;
  @HiveField(2)
  String fontWeight;
  @HiveField(3)
  String fontStyle;
  @HiveField(4)
  String textAlign;
  @HiveField(5)
  String? fontFamily;
  @HiveField(6)
  double? letterSpacing;
  @HiveField(7)
  double? lineHeight;
  @HiveField(8)
  double? wordSpacing;
  @HiveField(9)
  String textDecoration; // 'none', 'underline', 'line-through'
  @HiveField(10)
  double? contentHeight; // Actual laid-out content height (px), computed after layout
  @HiveField(11)
  double? overflowXPx; // Actual width overflow (px) — widest line exceeds box inner width
  @HiveField(12)
  bool isVertical; // True if text uses vertical layout (vert/vert270/eaVert/wordArtVert)
  @HiveField(13)
  double insetL; // Text-box left inset (px) — wrap width = box.w − insetL − insetR
  @HiveField(14)
  double insetT; // Text-box top inset (px)
  @HiveField(15)
  double insetR; // Text-box right inset (px)
  @HiveField(16)
  double insetB; // Text-box bottom inset (px)
  @HiveField(17)
  String anchor; // Vertical anchor: 'top' | 'middle' | 'bottom'

  TextStyleData({
    this.fontSize = 14,
    this.colorValue = 0xFFFFFFFF,
    this.fontWeight = 'normal',
    this.fontStyle = 'normal',
    this.textAlign = 'left',
    this.fontFamily,
    this.letterSpacing,
    this.lineHeight,
    this.wordSpacing,
    this.textDecoration = 'none',
    this.contentHeight,
    this.overflowXPx,
    this.isVertical = false,
    this.insetL = 4.0,
    this.insetT = 4.0,
    this.insetR = 4.0,
    this.insetB = 4.0,
    this.anchor = 'top',
  });

  int get fontWeightValue {
    switch (fontWeight) {
      case 'thin': return 100;
      case 'light': return 300;
      case 'normal': return 400;
      case 'medium': return 500;
      case 'semibold': return 600;
      case 'bold': return 700;
      case 'extrabold': return 800;
      case 'black': return 900;
      default: return 400;
    }
  }

  Map<String, dynamic> toJson() => {
    'fontSize': fontSize,
    'colorValue': colorValue,
    'fontWeight': fontWeight,
    'fontStyle': fontStyle,
    'textAlign': textAlign,
    'fontFamily': fontFamily,
    'letterSpacing': letterSpacing,
    'lineHeight': lineHeight,
    'wordSpacing': wordSpacing,
    'textDecoration': textDecoration,
    'contentHeight': contentHeight,
    'overflowXPx': overflowXPx,
    'isVertical': isVertical,
    'insetL': insetL,
    'insetT': insetT,
    'insetR': insetR,
    'insetB': insetB,
    'anchor': anchor,
  };

  factory TextStyleData.fromJson(Map<String, dynamic> json) => TextStyleData(
    fontSize: (json['fontSize'] is String)
        ? double.tryParse(json['fontSize']) ?? 14
        : (json['fontSize'] as num?)?.toDouble() ?? 14,
    colorValue: (json['colorValue'] is String)
        ? (int.tryParse(json['colorValue'], radix: 16) ?? 0xFFFFFFFF)
        : (json['colorValue'] as int?) ?? 0xFFFFFFFF,
    fontWeight: json['fontWeight']?.toString() ?? 'normal',
    fontStyle: json['fontStyle']?.toString() ?? 'normal',
    textAlign: json['textAlign']?.toString() ?? 'left',
    fontFamily: json['fontFamily']?.toString(),
    letterSpacing: (json['letterSpacing'] as num?)?.toDouble(),
    lineHeight: (json['lineHeight'] as num?)?.toDouble(),
    wordSpacing: (json['wordSpacing'] as num?)?.toDouble(),
    textDecoration: json['textDecoration']?.toString() ?? 'none',
    contentHeight: (json['contentHeight'] as num?)?.toDouble(),
    overflowXPx: (json['overflowXPx'] as num?)?.toDouble(),
    isVertical: json['isVertical'] == true,
    insetL: (json['insetL'] as num?)?.toDouble() ?? 4.0,
    insetT: (json['insetT'] as num?)?.toDouble() ?? 4.0,
    insetR: (json['insetR'] as num?)?.toDouble() ?? 4.0,
    insetB: (json['insetB'] as num?)?.toDouble() ?? 4.0,
    anchor: json['anchor']?.toString() ?? 'top',
  );

  TextStyleData copyWith({
    double? fontSize,
    int? colorValue,
    String? fontWeight,
    String? fontStyle,
    String? textAlign,
    String? fontFamily,
    double? letterSpacing,
    double? lineHeight,
    double? wordSpacing,
    String? textDecoration,
    double? contentHeight,
    double? overflowXPx,
    bool? isVertical,
    double? insetL,
    double? insetT,
    double? insetR,
    double? insetB,
    String? anchor,
  }) => TextStyleData(
    fontSize: fontSize ?? this.fontSize,
    colorValue: colorValue ?? this.colorValue,
    fontWeight: fontWeight ?? this.fontWeight,
    fontStyle: fontStyle ?? this.fontStyle,
    textAlign: textAlign ?? this.textAlign,
    fontFamily: fontFamily ?? this.fontFamily,
    letterSpacing: letterSpacing ?? this.letterSpacing,
    lineHeight: lineHeight ?? this.lineHeight,
    wordSpacing: wordSpacing ?? this.wordSpacing,
    textDecoration: textDecoration ?? this.textDecoration,
    contentHeight: contentHeight ?? this.contentHeight,
    overflowXPx: overflowXPx ?? this.overflowXPx,
    isVertical: isVertical ?? this.isVertical,
    insetL: insetL ?? this.insetL,
    insetT: insetT ?? this.insetT,
    insetR: insetR ?? this.insetR,
    insetB: insetB ?? this.insetB,
    anchor: anchor ?? this.anchor,
  );
}

@HiveType(typeId: 1)
class ShapeStyleData {
  @HiveField(0)
  int fillColorValue;
  @HiveField(1)
  int? strokeColorValue;
  @HiveField(2)
  double strokeWidth;
  @HiveField(3)
  double borderRadius;
  @HiveField(4)
  double opacity;
  @HiveField(5)
  String shapeType; // rect, circle, diamond, triangle, arrow, hexagon, polygon, path
  @HiveField(6)
  List<double>? polygonPoints; // flat [x0,y0,x1,y1,…] in design px, box-local
  @HiveField(7)
  String? pathData; // SVG path d-string (box-local design px)

  ShapeStyleData({
    this.fillColorValue = 0xFF6366F1,
    this.strokeColorValue,
    this.strokeWidth = 1,
    this.borderRadius = 8,
    this.opacity = 1,
    this.shapeType = 'rect',
    this.polygonPoints,
    this.pathData,
  });

  Map<String, dynamic> toJson() => {
    'fillColorValue': fillColorValue,
    'strokeColorValue': strokeColorValue,
    'strokeWidth': strokeWidth,
    'borderRadius': borderRadius,
    'opacity': opacity,
    'shapeType': shapeType,
    'polygonPoints': polygonPoints,
    'pathData': pathData,
  };

  factory ShapeStyleData.fromJson(Map<String, dynamic> json) => ShapeStyleData(
    fillColorValue: json['fillColorValue'] ?? 0xFF6366F1,
    strokeColorValue: json['strokeColorValue'],
    strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 1,
    borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 8,
    opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
    shapeType: json['shapeType']?.toString() ?? 'rect',
    polygonPoints: (json['polygonPoints'] as List?)
        ?.map((e) => (e as num).toDouble())
        .toList(),
    pathData: json['pathData']?.toString(),
  );
}

@HiveType(typeId: 2)
class ImageStyleData {
  @HiveField(0)
  String? src;
  @HiveField(1)
  String? placeholderLabel;
  @HiveField(2)
  double opacity;
  @HiveField(3)
  double borderRadius;

  ImageStyleData({
    this.src,
    this.placeholderLabel = '🖼 Image',
    this.opacity = 1,
    this.borderRadius = 8,
  });

  Map<String, dynamic> toJson() => {
    'src': src,
    'placeholderLabel': placeholderLabel,
    'opacity': opacity,
    'borderRadius': borderRadius,
  };

  factory ImageStyleData.fromJson(Map<String, dynamic> json) => ImageStyleData(
    src: json['src'],
    placeholderLabel: json['placeholderLabel'] ?? '🖼 Image',
    opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
    borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 8,
  );
}

class ChartData {
  String chartType; // bar, line, pie, donut
  List<ChartDataSet> dataSets;
  List<String> labels;

  ChartData({
    this.chartType = 'bar',
    List<ChartDataSet>? dataSets,
    List<String>? labels,
  }) : dataSets = dataSets ?? [
         ChartDataSet(values: [60, 80, 45, 90, 70], label: 'Series 1'),
       ],
       labels = labels ?? ['Jan', 'Feb', 'Mar', 'Apr', 'May'];

  Map<String, dynamic> toJson() => {
    'chartType': chartType,
    'dataSets': dataSets.map((ds) => ds.toJson()).toList(),
    'labels': labels,
  };

  factory ChartData.fromJson(Map<String, dynamic> json) => ChartData(
    chartType: json['chartType'] ?? 'bar',
    dataSets: (json['dataSets'] as List?)
        ?.map((ds) => ChartDataSet.fromJson(ds))
        .toList(),
    labels: (json['labels'] as List?)?.cast<String>(),
  );
}

class ChartDataSet {
  List<double> values;
  String label;
  int colorValue;

  ChartDataSet({
    required this.values,
    this.label = '',
    this.colorValue = 0xFF6366F1,
  });

  Map<String, dynamic> toJson() => {
    'values': values,
    'label': label,
    'colorValue': colorValue,
  };

  factory ChartDataSet.fromJson(Map<String, dynamic> json) => ChartDataSet(
    values: (json['values'] as List?)?.map((v) => (v as num).toDouble()).toList() ?? [],
    label: json['label'] ?? '',
    colorValue: json['colorValue'] ?? 0xFF6366F1,
  );
}

class TableData {
  int rows;
  int cols;
  List<List<String>> cells;
  bool hasHeader;

  TableData({
    this.rows = 3,
    this.cols = 3,
    List<List<String>>? cells,
    this.hasHeader = true,
  }) : cells = cells ?? List.generate(3, (r) =>
         List.generate(3, (c) => r == 0 ? 'Header ${c + 1}' : 'Cell ${r + 1}.${c + 1}'));

  Map<String, dynamic> toJson() => {
    'rows': rows,
    'cols': cols,
    'cells': cells,
    'hasHeader': hasHeader,
  };

  factory TableData.fromJson(Map<String, dynamic> json) => TableData(
    rows: json['rows'] ?? 3,
    cols: json['cols'] ?? 3,
    cells: (json['cells'] as List?)?.map((row) =>
      (row as List).cast<String>().toList()
    ).toList(),
    hasHeader: json['hasHeader'] ?? true,
  );
}

class DrawData {
  List<DrawStroke> strokes;

  DrawData({List<DrawStroke>? strokes}) : strokes = strokes ?? [];

  Map<String, dynamic> toJson() => {
    'strokes': strokes.map((s) => s.toJson()).toList(),
  };

  factory DrawData.fromJson(Map<String, dynamic> json) => DrawData(
    strokes: (json['strokes'] as List?)
        ?.map((s) => DrawStroke.fromJson(s))
        .toList(),
  );
}

class DrawStroke {
  int colorValue;
  double size;
  List<List<double>> points; // [[x, y], ...]
  String? label;

  DrawStroke({
    this.colorValue = 0xFF1E293B,
    this.size = 3,
    List<List<double>>? points,
    this.label,
  }) : points = points ?? [];

  Map<String, dynamic> toJson() => {
    'colorValue': colorValue,
    'size': size,
    'points': points,
    'label': label,
  };

  factory DrawStroke.fromJson(Map<String, dynamic> json) => DrawStroke(
    colorValue: json['colorValue'] as int? ?? 0xFF1E293B,
    size: (json['size'] as num?)?.toDouble() ?? 3.0,
    points: (json['points'] as List?)
        ?.map((p) => (p as List).map((e) => (e as num).toDouble()).toList())
        .toList(),
    label: json['label'] as String?,
  );
}

// ──────────────────────────────────────────────
// Vertical text run
// ──────────────────────────────────────────────

/// A laid-out glyph run of a vertical text body (bodyPr vert). GenOffice resolves
/// the per-run position + rotation (box-relative) so DocuCraft draws it verbatim
/// as a rotated [Text] — re-flowing eaVert/vert columns in Flutter would drift from
/// the PowerPoint layout.
class VerticalRun {
  final String text;
  /// Glyph left x (design px, relative to the text box top-left).
  final double x;
  /// Glyph top y (baseline − ascent, design px, relative to the text box top-left).
  final double y;
  /// Rotation in degrees: 90 (clockwise), -90 (counterclockwise), or 0.
  final double rotate;
  final double fontSize;
  final int colorValue;
  final String fontWeight;
  final String fontStyle;
  final String? fontFamily;

  VerticalRun({
    required this.text,
    required this.x,
    required this.y,
    this.rotate = 0,
    required this.fontSize,
    required this.colorValue,
    this.fontWeight = 'normal',
    this.fontStyle = 'normal',
    this.fontFamily,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'x': x,
    'y': y,
    'rotate': rotate,
    'fontSize': fontSize,
    'colorValue': colorValue,
    'fontWeight': fontWeight,
    'fontStyle': fontStyle,
    'fontFamily': fontFamily,
  };

  factory VerticalRun.fromJson(Map<String, dynamic> json) => VerticalRun(
    text: json['text']?.toString() ?? '',
    x: _toDouble(json['x'], 0),
    y: _toDouble(json['y'], 0),
    rotate: _toDouble(json['rotate'], 0),
    fontSize: _toDouble(json['fontSize'], 14),
    colorValue: (json['colorValue'] is String)
        ? (int.tryParse(json['colorValue'], radix: 16) ?? 0xFFFFFFFF)
        : (json['colorValue'] as int?) ?? 0xFFFFFFFF,
    fontWeight: json['fontWeight']?.toString() ?? 'normal',
    fontStyle: json['fontStyle']?.toString() ?? 'normal',
    fontFamily: json['fontFamily']?.toString(),
  );
}

// ──────────────────────────────────────────────
// Rich text run (mixed-style horizontal text)
// ──────────────────────────────────────────────

/// A formatted run of horizontal text. GenOffice emits these when a single text box
/// mixes styles (a stat card's huge accent number beside small grey sub-labels), so
/// DocuCraft re-flows the paragraph with each run at its own size/color instead of
/// flattening everything to the first run's style.
class RichRun {
  final String text;
  final double fontSize;
  final int colorValue;
  final String fontWeight;
  final String fontStyle;
  final String? fontFamily;

  RichRun({
    required this.text,
    required this.fontSize,
    required this.colorValue,
    this.fontWeight = 'normal',
    this.fontStyle = 'normal',
    this.fontFamily,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'fontSize': fontSize,
    'colorValue': colorValue,
    'fontWeight': fontWeight,
    'fontStyle': fontStyle,
    'fontFamily': fontFamily,
  };

  factory RichRun.fromJson(Map<String, dynamic> json) => RichRun(
    text: json['text']?.toString() ?? '',
    fontSize: _toDouble(json['fontSize'], 14),
    colorValue: (json['colorValue'] is String)
        ? (int.tryParse(json['colorValue'], radix: 16) ?? 0xFFFFFFFF)
        : (json['colorValue'] as int?) ?? 0xFFFFFFFF,
    fontWeight: json['fontWeight']?.toString() ?? 'normal',
    fontStyle: json['fontStyle']?.toString() ?? 'normal',
    fontFamily: json['fontFamily']?.toString(),
  );
}

// ──────────────────────────────────────────────
// Slide
// ──────────────────────────────────────────────

class Slide {
  String id;
  String title;
  String subtitle;
  String backgroundGradient;
  bool hidden;
  List<SlideElement> elements;
  Map<String, dynamic>? extra;

  // CRDT metadata
  int version;
  String? lastModifiedBy;
  DateTime? lastModifiedAt;

  // Draw strokes (coretan) — stored per-slide
  List<Map<String, dynamic>> drawStrokes = [];

  // Template linkage
  String? templateId;

  // Template content data (Presenton model):
  // slide.layoutId + slide.templateData — template widget yang render data
  String? layoutId;
  Map<String, dynamic>? templateData;

  Slide({
    String? id,
    this.title = 'Slide Baru',
    this.subtitle = 'Subtitle',
    this.backgroundGradient = 'indigo',
    this.hidden = false,
    List<SlideElement>? elements,
    this.extra,
    this.version = 1,
    this.lastModifiedBy,
    this.lastModifiedAt,
    this.templateId,
    this.layoutId,
    this.templateData,
  }) : id = id ?? _uuid.v7(),
       elements = elements ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'backgroundGradient': backgroundGradient,
    'hidden': hidden,
    'elements': elements.map((e) => e.toJson()).toList(),
    'extra': extra,
    'version': version,
    'lastModifiedBy': lastModifiedBy,
    'lastModifiedAt': lastModifiedAt?.toIso8601String(),
    'templateId': templateId,
    'layoutId': layoutId,
    'templateData': templateData,
  };

  factory Slide.fromJson(Map<String, dynamic> json) {
    // V1 backward compat: if no 'version', it's old format
    final isV1 = json['version'] == null;

    // V1 used microsecond timestamps as IDs — convert to UUID v7
    final id = json['id']?.toString() ?? _uuid.v7();
    final isTimestampId = RegExp(r'^\d{10,}$').hasMatch(id);

    return Slide(
      id: isTimestampId ? _uuid.v7() : id,
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      backgroundGradient: json['backgroundGradient'] ?? 'indigo',
      hidden: json['hidden'] ?? false,
      elements: (json['elements'] as List?)
          ?.map((e) => SlideElement.fromJson(e, isV1: isV1))
          .toList() ?? [],
      extra: json['extra'] as Map<String, dynamic>?,
      version: json['version'] ?? 1,
      lastModifiedBy: json['lastModifiedBy'],
      lastModifiedAt: json['lastModifiedAt'] != null
          ? DateTime.tryParse(json['lastModifiedAt'])
          : null,
      templateId: json['templateId'],
      layoutId: json['layoutId'],
      templateData: json['templateData'] as Map<String, dynamic>?,
    );
  }

  Slide copyWith({
    String? title,
    String? subtitle,
    String? backgroundGradient,
    bool? hidden,
    List<SlideElement>? elements,
    int? version,
    String? templateId,
    String? layoutId,
    Map<String, dynamic>? templateData,
  }) => Slide(
    id: id,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    backgroundGradient: backgroundGradient ?? this.backgroundGradient,
    hidden: hidden ?? this.hidden,
    elements: elements ?? this.elements,
    version: version ?? this.version + 1,
    lastModifiedBy: lastModifiedBy,
    lastModifiedAt: DateTime.now(),
    templateId: templateId ?? this.templateId,
    extra: extra,
  );

  void bumpVersion() {
    version++;
    lastModifiedAt = DateTime.now();
  }
}

// ──────────────────────────────────────────────
// SlideElement
// ──────────────────────────────────────────────

class SlideElement {
  String id;
  ElementType type;
  double x, y, width, height;
  double rotation;
  int zIndex;
  String? content;

  // Structured style data (type-specific)
  TextStyleData? textStyle;
  ShapeStyleData? shapeStyle;
  ImageStyleData? imageStyle;
  ChartData? chartData;
  TableData? tableData;
  DrawData? drawData;

  // Vertical text runs (bodyPr vert) — laid-out glyphs drawn verbatim. Present on
  // text elements whose GenOffice body had vert set; takes precedence over `content`.
  List<VerticalRun>? verticalRuns;

  // Mixed-style horizontal runs — drawn as a rich TextSpan when present (stat cards,
  // accent words). Cleared whenever `content` is edited so the edit shows as plain text.
  List<RichRun>? richRuns;

  // Legacy support — kept for backward compat
  Map<String, dynamic>? extra;

  // CRDT metadata
  int version;
  String? lastModifiedBy;
  DateTime? lastModifiedAt;

  // Template linkage
  String? templateSlotId;

  SlideElement({
    String? id,
    this.type = ElementType.text,
    this.x = 0,
    this.y = 0,
    this.width = 400,
    this.height = 80,
    this.rotation = 0,
    this.zIndex = 0,
    this.content,
    this.textStyle,
    this.shapeStyle,
    this.imageStyle,
    this.chartData,
    this.tableData,
    this.drawData,
    this.verticalRuns,
    this.richRuns,
    this.extra,
    this.version = 1,
    this.lastModifiedBy,
    this.lastModifiedAt,
    this.templateSlotId,
  }) : id = id ?? _uuid.v7();

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'x': x, 'y': y, 'width': width, 'height': height,
    'rotation': rotation,
    'zIndex': zIndex,
    'content': content,
    'textStyle': textStyle?.toJson(),
    'shapeStyle': shapeStyle?.toJson(),
    'imageStyle': imageStyle?.toJson(),
    'chartData': chartData?.toJson(),
    'tableData': tableData?.toJson(),
    'drawData': drawData?.toJson(),
    'verticalRuns': verticalRuns?.map((r) => r.toJson()).toList(),
    'richRuns': richRuns?.map((r) => r.toJson()).toList(),
    'extra': extra,
    'version': version,
    'lastModifiedBy': lastModifiedBy,
    'lastModifiedAt': lastModifiedAt?.toIso8601String(),
    'templateSlotId': templateSlotId,
  };

  factory SlideElement.fromJson(Map<String, dynamic> json, {bool isV1 = false}) {
    final typeStr = json['type'] ?? 'text';
    final type = ElementType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => ElementType.text,
    );

    // V1 backward compat: convert percentage positions to pixels.
    // `_toDouble` is null-safe AND string-tolerant: JSON may surface numeric
    // fields as strings (or as a non-numeric value the caller never
    // sanitised) — both fall back to the default rather than throwing.
    double x = _toDouble(json['x'], 0);
    double y = _toDouble(json['y'], 0);
    double w = _toDouble(json['width'], 400);
    double h = _toDouble(json['height'], 80);

    if (isV1) {
      // V1 used 0-100% → convert to 1920×1080 pixels
      x = x * _baseCanvasWidth / 100;
      y = y * _baseCanvasHeight / 100;
      w = w * _baseCanvasWidth / 100;
      h = h * _baseCanvasHeight / 100;
    }

    // V1 backward compat: convert loose fields to structured styles
    TextStyleData? textStyle;
    if (type == ElementType.text || type == ElementType.icon) {
      textStyle = json['textStyle'] != null
          ? TextStyleData.fromJson(json['textStyle'])
          : TextStyleData(
              fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14,
              colorValue: _parseColorValue(json['color']),
              fontWeight: (json['bold'] == true) ? 'bold' : 'normal',
              fontStyle: (json['italic'] == true) ? 'italic' : 'normal',
              textAlign: json['extra']?['align'] ?? 'left',
            );
    }

    // V1 backward compat: chart was just {content: 'bar'} → real ChartData
    ChartData? chartData;
    if (type == ElementType.chart) {
      chartData = json['chartData'] != null
          ? ChartData.fromJson(json['chartData'])
          : ChartData(chartType: json['content'] ?? 'bar');
    }

    // V1 backward compat: image was just text placeholder
    ImageStyleData? imageStyle;
    if (type == ElementType.image) {
      imageStyle = json['imageStyle'] != null
          ? ImageStyleData.fromJson(json['imageStyle'])
          : ImageStyleData(placeholderLabel: json['content'] ?? '🖼 Image');
    }

    // V1 backward compat: draw type
    DrawData? drawData;
    if (type == ElementType.draw) {
      drawData = json['drawData'] != null
          ? DrawData.fromJson(json['drawData'])
          : null;
    }

    // Vertical text runs (bodyPr vert) — laid-out glyphs drawn verbatim.
    List<VerticalRun>? verticalRuns;
    if (json['verticalRuns'] is List) {
      verticalRuns = (json['verticalRuns'] as List)
          .whereType<Map>()
          .map((r) => VerticalRun.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    }

    // Mixed-style horizontal runs.
    List<RichRun>? richRuns;
    if (json['richRuns'] is List) {
      richRuns = (json['richRuns'] as List)
          .whereType<Map>()
          .map((r) => RichRun.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    }

    // Parse zIndex
    int zIndex = json['zIndex'] ?? 0;
    if (isV1) {
      // V1 didn't have zIndex — assign based on order
      zIndex = 0;
    }

    final isTimestampId = json['id'] != null && RegExp(r'^\d{10,}$').hasMatch(json['id'].toString());

    return SlideElement(
      id: isTimestampId ? _uuid.v7() : (json['id']?.toString() ?? _uuid.v7()),
      type: type,
      x: x, y: y, width: w, height: h,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      zIndex: zIndex,
      content: json['content'],
      textStyle: textStyle,
      shapeStyle: json['shapeStyle'] != null ? ShapeStyleData.fromJson(json['shapeStyle']) : null,
      imageStyle: imageStyle,
      chartData: chartData,
      tableData: json['tableData'] != null ? TableData.fromJson(json['tableData']) : null,
      drawData: drawData,
      verticalRuns: verticalRuns,
      richRuns: richRuns,
      extra: json['extra'] as Map<String, dynamic>?,
      version: json['version'] ?? 1,
      lastModifiedBy: json['lastModifiedBy'],
      lastModifiedAt: json['lastModifiedAt'] != null
          ? DateTime.tryParse(json['lastModifiedAt'])
          : null,
      templateSlotId: json['templateSlotId'],
    );
  }

  void bumpVersion() {
    version++;
    lastModifiedAt = DateTime.now();
  }

  // ── Convenience getters for legacy compat ──
  bool get bold => textStyle?.fontWeight == 'bold' || textStyle?.fontWeight == 'extrabold';
  set bold(bool value) {
    textStyle ??= TextStyleData();
    textStyle!.fontWeight = value ? 'bold' : 'normal';
  }

  bool get italic => textStyle?.fontStyle == 'italic';
  set italic(bool value) {
    textStyle ??= TextStyleData();
    textStyle!.fontStyle = value ? 'italic' : 'normal';
  }

  double? get fontSize => textStyle?.fontSize;
  set fontSize(double? value) {
    textStyle ??= TextStyleData();
    textStyle!.fontSize = value ?? 14;
  }

  String? get color {
    if (textStyle != null) {
      return _colorIntToHex(textStyle!.colorValue);
    }
    return null;
  }
  set color(String? hexValue) {
    textStyle ??= TextStyleData();
    textStyle!.colorValue = _parseHexToColorInt(hexValue);
  }
}

// ──────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────

int _parseColorValue(String? color) {
  if (color == null) return 0xFFFFFFFF;
  return _parseHexToColorInt(color);
}

String _colorIntToHex(int value) {
  return '#${value.toRadixString(16).padLeft(8, '0').substring(2)}';
}

int _parseHexToColorInt(String? hex) {
  if (hex == null || hex.isEmpty) return 0xFFFFFFFF;
  hex = hex.replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return int.tryParse(hex, radix: 16) ?? 0xFFFFFFFF;
}

// ──────────────────────────────────────────────
// Demo slides helper
// ──────────────────────────────────────────────

List<Slide> createDemoSlides() => [
  Slide(
    title: 'Strategi Pemasaran Digital 2026',
    subtitle: '2026 · Q2 Report',
    backgroundGradient: 'indigo',
    elements: [
      SlideElement(
        type: ElementType.chart,
        x: 120, y: 300, width: 800, height: 480,
        chartData: ChartData(
          chartType: 'bar',
          dataSets: [
            ChartDataSet(values: [65, 85, 45, 95, 75], label: 'Revenue', colorValue: 0xFF6366F1),
            ChartDataSet(values: [40, 60, 35, 70, 55], label: 'Costs', colorValue: 0xFFEC4899),
          ],
          labels: ['Jan', 'Feb', 'Mar', 'Apr', 'Mei'],
        ),
      ),
    ],
  ),
  Slide(
    title: 'Analisis Data & Insight',
    subtitle: 'Customer Behavior',
    backgroundGradient: 'purple',
    elements: [
      SlideElement(
        type: ElementType.text,
        x: 100, y: 200, width: 600, height: 80,
        content: '🎯 Target audience: Millennials & Gen Z',
        textStyle: TextStyleData(fontSize: 24, colorValue: 0xFFFFFFFF, fontWeight: 'semibold'),
      ),
    ],
  ),
  Slide(
    title: 'Metrik Kunci Q2',
    subtitle: 'Revenue · Growth · Retention',
    backgroundGradient: 'blue',
  ),
  Slide(
    title: 'Timeline Implementasi',
    subtitle: 'Q3 Roadmap',
    backgroundGradient: 'emerald',
  ),
  Slide(
    title: 'Kesimpulan & Next Steps',
    subtitle: '—',
    backgroundGradient: 'amber',
  ),
];
