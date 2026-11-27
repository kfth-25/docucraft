// DocuCraft — Shared Template Converter
// Mengonversi TemplateLayoutData (JSON dari presenton-templates) → (SlideElements, backgroundGradient)
// Dipakai oleh: TemplatesStorageScreen, TemplatePanel, TemplateBrowser

import '../models/slide.dart';
import '../models/template_layout.dart';

class TemplateConverter {
  /// Convert TemplateLayoutData → (elements, backgroundGradient)
  /// Scale: 1280×720 (JSON canvas) → 1920×1080 (editor canvas)
  static ({List<SlideElement> elements, String backgroundGradient}) fromLayoutData(
    TemplateLayoutData data,
  ) {
    final canvasW = data.canvas.width;
    final canvasH = data.canvas.height;
    const targetW = 1920.0;
    const targetH = 1080.0;
    final scaleX = targetW / canvasW;
    final scaleY = targetH / canvasH;

    final elements = <SlideElement>[];

    for (final el in data.elements) {
      // Guard: clamp dimensi — elemen zero-size/negative dari JSON template
      // (spacer, decoration, dsb) akan di-skip supaya tidak crash RenderStack
      final x = el.position.x * scaleX;
      final y = el.position.y * scaleY;
      final w = el.position.width * scaleX;
      final h = el.position.height * scaleY;
      if (!w.isFinite || !h.isFinite || w <= 0 || h <= 0) continue;

      switch (el.type) {
        case TemplateElementType.text:
          elements.add(_convertText(el, x, y, w, h));
          break;
        case TemplateElementType.image:
          elements.add(_convertImage(el, x, y, w, h));
          break;
        case TemplateElementType.shape:
        case TemplateElementType.decoration:
          elements.add(_convertShape(el, x, y, w, h));
          break;
        case TemplateElementType.card:
          elements.add(_convertCard(el, x, y, w, h));
          break;
        default:
          break;
      }
    }

    // Background gradient
    final bgHex = data.canvas.backgroundColor ?? '#FFFFFF';
    final hex = bgHex.replaceFirst('#', '');
    final backgroundGradient = 'custom_$hex,$hex';

    return (elements: elements, backgroundGradient: backgroundGradient);
  }

  static SlideElement _convertText(
    TemplateElement el,
    double x, double y, double w, double h,
  ) {
    final scale = 1920.0 / 1280.0;
    final colorInt = _hexToInt(el.style.color) ?? 0xFF111827;
    return SlideElement(
      type: ElementType.text,
      content: '${el.content ?? ''}',
      x: x,
      y: y,
      width: w,
      height: h,
      textStyle: TextStyleData(
        fontSize: (el.style.fontSize ?? 16) * scale,
        colorValue: colorInt,
        fontWeight: _mapFontWeight(el.style.fontWeight),
        fontStyle: 'normal',
        textAlign: _mapAlign(el.style.textAlign),
      ),
    );
  }

  static SlideElement _convertImage(
    TemplateElement el,
    double x, double y, double w, double h,
  ) {
    return SlideElement(
      type: ElementType.image,
      content: el.content ?? '',
      x: x,
      y: y,
      width: w,
      height: h,
    );
  }

  static SlideElement _convertShape(
    TemplateElement el,
    double x, double y, double w, double h,
  ) {
    final scale = 1920.0 / 1280.0;
    return SlideElement(
      type: ElementType.shape,
      x: x,
      y: y,
      width: w,
      height: h,
      shapeStyle: ShapeStyleData(
        fillColorValue: _hexToInt(el.style.color) ?? 0xFF111827,
        borderRadius: (el.style.borderRadius ?? 0) * scale,
      ),
    );
  }

  static SlideElement _convertCard(
    TemplateElement el,
    double x, double y, double w, double h,
  ) {
    final scale = 1920.0 / 1280.0;
    return SlideElement(
      type: ElementType.shape,
      x: x,
      y: y,
      width: w,
      height: h,
      shapeStyle: ShapeStyleData(
        fillColorValue: _hexToInt(el.style.backgroundColor) ?? 0xFFF3F4F6,
        borderRadius: (el.style.borderRadius ?? 12) * scale,
      ),
    );
  }

  // ── Helpers ──

  static int? _hexToInt(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return int.tryParse(h, radix: 16);
  }

  static String _mapFontWeight(String? w) {
    switch (w) {
      case 'bold': return 'bold';
      case 'semibold': return 'w600';
      case 'medium': return 'w500';
      default: return 'normal';
    }
  }

  static String _mapAlign(String? a) {
    switch (a) {
      case 'center': return 'center';
      case 'right': return 'right';
      default: return 'left';
    }
  }
}
