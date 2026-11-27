// DocuCraft — SVG Export Service
// Mengonversi JSON SlideElements → SVG string (format antara untuk ekspor PPTX)
//
// Flow: JSON Elements → SVG → DrawingML → PPTX

import 'dart:convert';
import '../models/slide.dart';

class SvgExportService {
  /// Convert a slide to SVG string (1920×1080 design space)
  static String slideToSvg(Slide slide) {
    final buffer = StringBuffer();

    // SVG header
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<svg width="1920" height="1080" viewBox="0 0 1920 1080" xmlns="http://www.w3.org/2000/svg">');

    // Background
    final bgColor = _gradientToColor(slide.backgroundGradient);
    buffer.writeln('  <rect width="1920" height="1080" fill="$bgColor"/>');

    // Title + subtitle (if no template elements)
    if (slide.elements.isEmpty) {
      buffer.writeln('  <text x="96" y="80" font-size="16" fill="#9CA3AF">${_escapeXml(slide.title)}</text>');
      buffer.writeln('  <text x="96" y="120" font-size="48" fill="#FFFFFF" font-weight="bold">${_escapeXml(slide.title)}</text>');
      buffer.writeln('  <text x="96" y="180" font-size="24" fill="#9CA3AF">${_escapeXml(slide.subtitle)}</text>');
    }

    // Elements
    for (final el in slide.elements) {
      buffer.writeln(_elementToSvg(el, '  '));
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  /// Convert single element to SVG
  static String _elementToSvg(SlideElement el, String indent) {
    switch (el.type) {
      case ElementType.text:
        return _textToSvg(el, indent);
      case ElementType.shape:
        return _shapeToSvg(el, indent);
      case ElementType.image:
        return _imageToSvg(el, indent);
      case ElementType.chart:
        return _chartToSvg(el, indent);
      case ElementType.table:
        return _tableToSvg(el, indent);
      case ElementType.icon:
        return _iconToSvg(el, indent);
      default:
        return '$indent<!-- unsupported type: ${el.type.name} -->';
    }
  }

  static String _textToSvg(SlideElement el, String indent) {
    final ts = el.textStyle ?? TextStyleData();
    final color = _colorToHex(ts.colorValue);
    final fontSize = ts.fontSize;
    final weight = ts.fontWeight == 'bold' || ts.fontWeight == 'extrabold' ? 'bold' : 'normal';
    final align = _alignToSvg(ts.textAlign);
    final text = _escapeXml(el.content ?? '');

    return '''$indent<text x="${el.x}" y="${el.y + fontSize * 1.2}"
$indent  font-size="$fontSize" fill="$color" font-weight="$weight"
$indent  text-anchor="$align" font-family="Inter, sans-serif">$text</text>''';
  }

  static String _shapeToSvg(SlideElement el, String indent) {
    final ss = el.shapeStyle ?? ShapeStyleData();
    final fill = _colorToHex(ss.fillColorValue);
    final opacity = ss.opacity;
    final shapeType = ss.shapeType;

    switch (shapeType) {
      case 'circle':
        final cx = el.x + el.width / 2;
        final cy = el.y + el.height / 2;
        final r = (el.width < el.height ? el.width : el.height) / 2;
        return '$indent<ellipse cx="$cx" cy="$cy" rx="$r" ry="$r" fill="$fill" opacity="$opacity"/>';
      case 'diamond':
        final cx = el.x + el.width / 2;
        final cy = el.y + el.height / 2;
        final points = '${cx},${cy - el.height / 2} ${cx + el.width / 2},${cy} ${cx},${cy + el.height / 2} ${cx - el.width / 2},${cy}';
        return '$indent<polygon points="$points" fill="$fill" opacity="$opacity"/>';
      case 'triangle':
        final cx = el.x + el.width / 2;
        final points = '$cx,${el.y} ${el.x + el.width},${el.y + el.height} ${el.x},${el.y + el.height}';
        return '$indent<polygon points="$points" fill="$fill" opacity="$opacity"/>';
      default: // rect
        final rx = ss.borderRadius;
        return '$indent<rect x="${el.x}" y="${el.y}" width="${el.width}" height="${el.height}" rx="$rx" fill="$fill" opacity="$opacity"/>';
    }
  }

  static String _imageToSvg(SlideElement el, String indent) {
    final src = el.imageStyle?.src ?? '';
    final placeholder = el.imageStyle?.placeholderLabel ?? '🖼 Image';

    if (src.isEmpty) {
      return '''$indent<g>
$indent  <rect x="${el.x}" y="${el.y}" width="${el.width}" height="${el.height}" fill="#374151" rx="8"/>
$indent  <text x="${el.x + el.width / 2}" y="${el.y + el.height / 2}" text-anchor="middle" fill="#9CA3AF" font-size="14">$placeholder</text>
$indent</g>''';
    }

    return '$indent<image x="${el.x}" y="${el.y}" width="${el.width}" height="${el.height}" href="$src" preserveAspectRatio="xMidYMid slice"/>';
  }

  static String _chartToSvg(SlideElement el, String indent) {
    final cd = el.chartData ?? ChartData();
    final chartType = cd.chartType;

    // SVG placeholder with data-pptx-replace attribute for converter
    final dataJson = jsonEncode({
      'chartType': chartType,
      'dataSets': cd.dataSets.map((ds) => {'values': ds.values, 'label': ds.label, 'color': ds.colorValue}).toList(),
      'labels': cd.labels,
    });

    return '''$indent<g data-pptx-replace="chart" data-pptx-chart='${_escapeXml(dataJson)}'>
$indent  <rect x="${el.x}" y="${el.y}" width="${el.width}" height="${el.height}" fill="#F3F4F6" rx="8"/>
$indent  <text x="${el.x + el.width / 2}" y="${el.y + el.height / 2}" text-anchor="middle" fill="#6B7280" font-size="16">📊 ${chartType.toUpperCase()} CHART</text>
$indent</g>''';
  }

  static String _tableToSvg(SlideElement el, String indent) {
    final td = el.tableData ?? TableData();
    final rows = td.rows;
    final cols = td.cols;
    final cellW = el.width / cols;
    final cellH = el.height / rows;

    final buffer = StringBuffer();
    buffer.writeln('$indent<g data-pptx-replace="table">');

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final x = el.x + c * cellW;
        final y = el.y + r * cellH;
        final isHeader = r == 0 && td.hasHeader;
        final fill = isHeader ? '#6366F1' : (r % 2 == 0 ? '#FFFFFF' : '#F9FAFB');
        final textColor = isHeader ? '#FFFFFF' : '#1F2937';
        final cellText = r < td.cells.length && c < td.cells[r].length ? _escapeXml(td.cells[r][c]) : '';

        buffer.writeln('$indent  <rect x="$x" y="$y" width="$cellW" height="$cellH" fill="$fill" stroke="#E5E7EB" stroke-width="0.5"/>');
        buffer.writeln('$indent  <text x="${x + 4}" y="${y + cellH / 2 + 4}" font-size="10" fill="$textColor">$cellText</text>');
      }
    }

    buffer.writeln('$indent</g>');
    return buffer.toString();
  }

  static String _iconToSvg(SlideElement el, String indent) {
    final content = el.content ?? '⭐';
    final fontSize = el.textStyle?.fontSize ?? 24;
    final color = _colorToHex(el.textStyle?.colorValue ?? 0xFFFFFFFF);

    return '$indent<text x="${el.x}" y="${el.y + fontSize}" font-size="$fontSize" fill="$color">$content</text>';
  }

  // ── Helpers ──

  static String _gradientToColor(String gradient) {
    const map = {
      'indigo': '#6366F1',
      'purple': '#A855F7',
      'blue': '#3B82F6',
      'emerald': '#10B981',
      'amber': '#F59E0B',
      'rose': '#F43F5E',
      'teal': '#14B8A6',
      'orange': '#F97316',
      'pink': '#E11D48',
      'cyan': '#06B6D4',
      'lime': '#65A30D',
      'violet': '#8B5CF6',
      'slate': '#475569',
      'warm': '#D97706',
      'frost': '#2DD4BF',
      'midnight': '#1E1B4B',
    };
    return map[gradient] ?? '#6366F1';
  }

  static String _colorToHex(int colorValue) {
    return '#${colorValue.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  static String _alignToSvg(String align) {
    switch (align) {
      case 'center': return 'middle';
      case 'right': return 'end';
      default: return 'start';
    }
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
