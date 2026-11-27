// DocuCraft — Universal Template Layout Data Model
// Intermediate format hasil konversi dari React .tsx templates.
// Menyimpan struktur layout + styling yang dirender oleh TemplateRenderer.

import 'dart:ui';

// ── Canvas / Background ──
class TemplateCanvas {
  final double width, height;
  final String? backgroundColor;
  final List<String>? gradientColors; // [start, end]
  final String? backgroundImage;
  final String? fontFamily;

  const TemplateCanvas({
    this.width = 1280,
    this.height = 720,
    this.backgroundColor,
    this.gradientColors,
    this.backgroundImage,
    this.fontFamily,
  });

  factory TemplateCanvas.fromJson(Map<String, dynamic> j) => TemplateCanvas(
    width: (j['width'] ?? 1280).toDouble(),
    height: (j['height'] ?? 720).toDouble(),
    backgroundColor: j['backgroundColor'] as String?,
    gradientColors: (j['gradientColors'] as List?)?.cast<String>(),
    backgroundImage: j['backgroundImage'] as String?,
    fontFamily: j['fontFamily'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'width': width, 'height': height,
    'backgroundColor': backgroundColor,
    'gradientColors': gradientColors,
    'backgroundImage': backgroundImage,
    'fontFamily': fontFamily,
  };
}

// ── Position (absolute, relatif ke canvas) ──
class TemplatePosition {
  final double x, y, width, height;

  const TemplatePosition({this.x = 0, this.y = 0, this.width = 0, this.height = 0});

  factory TemplatePosition.fromJson(Map<String, dynamic> j) => TemplatePosition(
    x: (j['x'] ?? 0).toDouble(),
    y: (j['y'] ?? 0).toDouble(),
    width: (j['width'] ?? 0).toDouble(),
    height: (j['height'] ?? 0).toDouble(),
  );

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'width': width, 'height': height};
}

// ── Style (shared untuk text & shape) ──
class TemplateStyle {
  final String? fontFamily;
  final double? fontSize;
  final String? fontWeight; // normal, medium, semibold, bold
  final String? color; // hex string
  final String? textAlign; // left, center, right
  final double? letterSpacing;
  final double? lineHeight;
  final String? backgroundColor;
  final String? borderColor;
  final double? borderRadius;
  final double? borderWidth;
  final bool? italic;

  const TemplateStyle({
    this.fontFamily, this.fontSize, this.fontWeight, this.color,
    this.textAlign, this.letterSpacing, this.lineHeight,
    this.backgroundColor, this.borderColor, this.borderRadius,
    this.borderWidth, this.italic,
  });

  factory TemplateStyle.fromJson(Map<String, dynamic> j) => TemplateStyle(
    fontFamily: j['fontFamily'] as String?,
    fontSize: (j['fontSize'] as num?)?.toDouble(),
    fontWeight: j['fontWeight'] as String?,
    color: j['color'] as String?,
    textAlign: j['textAlign'] as String?,
    letterSpacing: (j['letterSpacing'] as num?)?.toDouble(),
    lineHeight: (j['lineHeight'] as num?)?.toDouble(),
    backgroundColor: j['backgroundColor'] as String?,
    borderColor: j['borderColor'] as String?,
    borderRadius: (j['borderRadius'] as num?)?.toDouble(),
    borderWidth: (j['borderWidth'] as num?)?.toDouble(),
    italic: j['italic'] as bool?,
  );

  Map<String, dynamic> toJson() => {
    'fontFamily': fontFamily, 'fontSize': fontSize, 'fontWeight': fontWeight,
    'color': color, 'textAlign': textAlign, 'letterSpacing': letterSpacing,
    'lineHeight': lineHeight, 'backgroundColor': backgroundColor,
    'borderColor': borderColor, 'borderRadius': borderRadius,
    'borderWidth': borderWidth, 'italic': italic,
  };
}

// ── Element Types ──
enum TemplateElementType {
  text, image, shape, decoration, card, listItem, icon, spacer,
}

// ── Element ──
class TemplateElement {
  final String id;
  final TemplateElementType type;
  final TemplatePosition position;

  // Content: langsung nilai default (bukan schema) — diisi parser dari Zod defaults
  final dynamic content; // String, List, atau Map

  // Style
  final TemplateStyle style;

  // Khusus shape/decoration
  final String? shape; // 'rect', 'circle', 'diamond', 'line'
  final String? rotation;

  // Khusus list/items (mis. metrics, bullets)
  final List<Map<String, dynamic>>? items;

  const TemplateElement({
    required this.id,
    required this.type,
    required this.position,
    this.content,
    this.style = const TemplateStyle(),
    this.shape,
    this.rotation,
    this.items,
  });

  factory TemplateElement.fromJson(Map<String, dynamic> j) => TemplateElement(
    id: j['id'] as String,
    type: TemplateElementType.values.firstWhere(
      (t) => t.name == j['type'], orElse: () => TemplateElementType.text),
    position: TemplatePosition.fromJson(j['position'] as Map<String, dynamic>? ?? {}),
    content: j['content'],
    style: TemplateStyle.fromJson(j['style'] as Map<String, dynamic>? ?? {}),
    shape: j['shape'] as String?,
    rotation: j['rotation'] as String?,
    items: (j['items'] as List?)?.cast<Map<String, dynamic>>(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'type': type.name, 'position': position.toJson(),
    'content': content, 'style': style.toJson(),
    'shape': shape, 'rotation': rotation, 'items': items,
  };
}

// ── Template Layout Data (root) ──
class TemplateLayoutData {
  final String layoutId;
  final String name;
  final String description;
  final TemplateCanvas canvas;
  final List<TemplateElement> elements;

  const TemplateLayoutData({
    required this.layoutId,
    required this.name,
    required this.description,
    required this.canvas,
    required this.elements,
  });

  factory TemplateLayoutData.fromJson(Map<String, dynamic> j) => TemplateLayoutData(
    layoutId: j['layoutId'] as String,
    name: j['name'] as String,
    description: j['description'] as String? ?? '',
    canvas: TemplateCanvas.fromJson(j['canvas'] as Map<String, dynamic>? ?? {}),
    elements: (j['elements'] as List? ?? [])
        .map((e) => TemplateElement.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'layoutId': layoutId, 'name': name, 'description': description,
    'canvas': canvas.toJson(),
    'elements': elements.map((e) => e.toJson()).toList(),
  };

  // ── Color helpers ──
  static Color? parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var h = hex.replaceFirst('#', '');
    if (h.length == 3) {
      h = h.split('').map((c) => '$c$c').join();
    }
    if (h.length == 6) {
      h = 'FF$h';
    }
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Color(v);
  }

  static FontWeight parseFontWeight(String? w) {
    switch (w) {
      case 'thin': return FontWeight.w100;
      case 'light': return FontWeight.w300;
      case 'medium': return FontWeight.w500;
      case 'semibold': return FontWeight.w600;
      case 'bold': return FontWeight.w700;
      default: return FontWeight.w400;
    }
  }
}
