// DocuCraft — Universal Template Renderer
// Render TemplateLayoutData (hasil konversi React .tsx) ke Flutter widget.
// Canvas 1280×720 dikonversi ke widget yang bisa diskalakan.

import 'package:flutter/material.dart';
import '../models/template_layout.dart';

class TemplateRenderer extends StatelessWidget {
  final TemplateLayoutData layout;
  final double width; // lebar tampilan dalam px
  const TemplateRenderer({super.key, required this.layout, this.width = 1280});

  // Scale factor: canvas 1280×720 → widget 1080×720 default
  double get _scale => width / layout.canvas.width;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      // Calculate scale to fit within parent bounds
      final scaleX = constraints.maxWidth / layout.canvas.width;
      final scaleY = constraints.maxHeight / layout.canvas.height;
      final scale = (scaleX < scaleY) ? scaleX : scaleY;
      final w = layout.canvas.width * scale;
      final h = layout.canvas.height * scale;

      return ClipRect(
        child: Container(
          width: w,
          height: h,
          decoration: _buildBackground(),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (final el in layout.elements)
                Positioned(
                  left: el.position.x * scale,
                  top: el.position.y * scale,
                  width: el.position.width * scale,
                  height: el.position.height * scale,
                  child: _buildElement(el),
                ),
            ],
          ),
        ),
      );
    });
  }

  // ── Background ──
  BoxDecoration _buildBackground() {
    final canvas = layout.canvas;

    // Gradient
    if (canvas.gradientColors != null && canvas.gradientColors!.length >= 2) {
      final c1 = TemplateLayoutData.parseColor(canvas.gradientColors![0]) ?? const Color(0xFFFFFFFF);
      final c2 = TemplateLayoutData.parseColor(canvas.gradientColors![1]) ?? const Color(0xFF000000);
      return BoxDecoration(
        gradient: LinearGradient(
          colors: [c1, c2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );
    }

    // Background image (dari network) — dibungkus decoration
    final bgColor = TemplateLayoutData.parseColor(canvas.backgroundColor) ?? const Color(0xFFFFFFFF);
    if (canvas.backgroundImage != null) {
      return BoxDecoration(color: bgColor);
    }

    return BoxDecoration(color: bgColor);
  }

  // ── Element dispatcher ──
  Widget _buildElement(TemplateElement el) {
    switch (el.type) {
      case TemplateElementType.text:
        return _buildText(el);
      case TemplateElementType.image:
        return _buildImage(el);
      case TemplateElementType.shape:
      case TemplateElementType.decoration:
        return _buildShape(el);
      case TemplateElementType.card:
        return _buildCard(el);
      case TemplateElementType.spacer:
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Text ──
  Widget _buildText(TemplateElement el) {
    final s = el.style;
    final color = TemplateLayoutData.parseColor(s.color) ?? const Color(0xFF111827);
    final bg = TemplateLayoutData.parseColor(s.backgroundColor);

    return Container(
      alignment: _textAlign(s.textAlign),
      padding: el.content == null ? null : const EdgeInsets.all(0),
      decoration: bg != null ? BoxDecoration(color: bg) : null,
      child: Text(
        '${el.content ?? ''}',
        style: TextStyle(
          fontSize: (s.fontSize ?? 16) * _scale,
          color: color,
          fontWeight: TemplateLayoutData.parseFontWeight(s.fontWeight),
          fontStyle: s.italic == true ? FontStyle.italic : FontStyle.normal,
          letterSpacing: s.letterSpacing,
          height: s.lineHeight,
          fontFamily: s.fontFamily,
        ),
        overflow: TextOverflow.clip,
        maxLines: el.position.height > 0 ? null : 1,
      ),
    );
  }

  Alignment? _textAlign(String? align) {
    switch (align) {
      case 'center': return Alignment.center;
      case 'right': return Alignment.centerRight;
      default: return Alignment.centerLeft;
    }
  }

  // ── Image ──
  Widget _buildImage(TemplateElement el) {
    final src = (el.content is String) ? el.content as String : null;
    if (src == null || src.isEmpty) return const SizedBox.shrink();
    if (src.startsWith('http')) {
      return Image.network(src, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink());
    }
    return Image.asset(src, fit: BoxFit.cover);
  }

  // ── Shape / Decoration ──
  Widget _buildShape(TemplateElement el) {
    final s = el.style;
    final color = TemplateLayoutData.parseColor(s.color ?? s.backgroundColor) ?? const Color(0xFF111827);
    final radius = (s.borderRadius ?? 0) * _scale;

    switch (el.shape ?? 'rect') {
      case 'circle':
        return Container(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle,
            border: s.borderColor != null ? Border.all(color: TemplateLayoutData.parseColor(s.borderColor)!, width: (s.borderWidth ?? 1) * _scale) : null),
        );
      case 'diamond':
        return Transform.rotate(
          angle: 3.14159 / 4,
          child: Container(decoration: BoxDecoration(color: color)),
        );
      case 'line':
        return Container(
          color: color,
          height: (s.borderWidth ?? 2) * _scale,
        );
      default: // rect
        return Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
            border: s.borderColor != null ? Border.all(color: TemplateLayoutData.parseColor(s.borderColor)!, width: (s.borderWidth ?? 1) * _scale) : null,
          ),
        );
    }
  }

  // ── Card (rounded container dengan content children) ──
  Widget _buildCard(TemplateElement el) {
    final s = el.style;
    final bg = TemplateLayoutData.parseColor(s.backgroundColor ?? s.color) ?? const Color(0xFFF3F4F6);
    final borderC = TemplateLayoutData.parseColor(s.borderColor);
    final radius = (s.borderRadius ?? 12) * _scale;

    // content bisa berupa list map → render baris sederhana
    Widget child = const SizedBox.shrink();
    if (el.items != null && el.items!.isNotEmpty) {
      child = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: el.items!.map((item) {
          final value = '${item['value'] ?? ''}';
          final line1 = '${item['line1'] ?? ''}';
          final line2 = '${item['line2'] ?? ''}';
          final desc = '${item['description'] ?? ''}';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              (value.isNotEmpty ? '$value ' : '') + line1 + (line2.isNotEmpty ? ' $line2' : '') + (desc.isNotEmpty ? ' — $desc' : ''),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: (s.fontSize ?? 14) * _scale,
                color: TemplateLayoutData.parseColor(s.color) ?? const Color(0xFF111827),
              ),
            ),
          );
        }).toList(),
      );
    }

    return Container(
      padding: EdgeInsets.all((s.borderRadius ?? 0) > 0 ? 8 * _scale : 0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: borderC != null ? Border.all(color: borderC, width: (s.borderWidth ?? 1) * _scale) : null,
      ),
      child: child,
    );
  }
}