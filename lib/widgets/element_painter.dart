// DocuCraft — Shared Element Painter
// Single source of truth untuk rendering SlideElements di Canvas DAN export ke SVG
//
// Pemakaian:
//   // Untuk Canvas (berbasis widget)
//   ElementPainter.paintWidget(canvas, element, bounds);
//
//   // Untuk export SVG (berbasis PictureRecorder)
//   final picture = ElementPainter.recordToPicture(element, bounds);
//   final svg = pictureToSvg(picture);

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/slide.dart';
import '../themes/app_theme.dart';

/// Rect bounds in design space (1920x1080)
class ElementBounds {
  final double x, y, width, height;
  const ElementBounds({required this.x, required this.y, required this.width, required this.height});

  Rect get rect => Rect.fromLTWH(x, y, width, height);
  Size get size => Size(width, height);
}

/// Shared painting logic for all element types
class ElementPainter {
  // =========================================================================
  // PUBLIC API: Canvas Rendering (Widget-based for SlideCanvas)
  // =========================================================================

  /// Paint element to Flutter Canvas (used by SlideCanvas via CustomPainter)
  static void paintWidget(Canvas canvas, SlideElement element, ElementBounds bounds) {
    // Save canvas state
    canvas.save();
    canvas.translate(bounds.x, bounds.y);

    switch (element.type) {
      case ElementType.text:
        _paintText(canvas, element, bounds.size);
        break;
      case ElementType.icon:
        _paintIcon(canvas, element, bounds.size);
        break;
      case ElementType.chart:
        _paintChart(canvas, element, bounds.size);
        break;
      case ElementType.shape:
        _paintShape(canvas, element, bounds.size);
        break;
      case ElementType.image:
        _paintImage(canvas, element, bounds.size);
        break;
      case ElementType.table:
        _paintTable(canvas, element, bounds.size);
        break;
      case ElementType.video:
      case ElementType.audio:
        _paintMediaPlaceholder(canvas, element, bounds.size);
        break;
      case ElementType.draw:
        _paintDraw(canvas, element, bounds.size);
        break;
    }

    canvas.restore();
  }

  // =========================================================================
  // PUBLIC API: SVG Export (PictureRecorder-based)
  // =========================================================================

  /// Record element to Picture for SVG export
  /// Returns a Picture that can be serialized to SVG
  static ui.Picture recordToPicture(SlideElement element, ElementBounds bounds) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, bounds.rect);

    // Translate to element origin
    canvas.translate(bounds.x, bounds.y);

    switch (element.type) {
      case ElementType.text:
        _recordText(canvas, element, bounds.size);
        break;
      case ElementType.icon:
        _recordIcon(canvas, element, bounds.size);
        break;
      case ElementType.chart:
        _recordChart(canvas, element, bounds.size);
        break;
      case ElementType.shape:
        _recordShape(canvas, element, bounds.size);
        break;
      case ElementType.image:
        _recordImage(canvas, element, bounds.size);
        break;
      case ElementType.table:
        _recordTable(canvas, element, bounds.size);
        break;
      case ElementType.video:
      case ElementType.audio:
        _recordMediaPlaceholder(canvas, element, bounds.size);
        break;
      case ElementType.draw:
        _recordDraw(canvas, element, bounds.size);
        break;
    }

    return recorder.endRecording();
  }

  /// Record multiple elements to a single slide Picture
  static ui.Picture recordSlideToPicture(Slide slide, {Size slideSize = const Size(1280, 720)}) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, slideSize.width, slideSize.height));

    // Paint background
    _recordBackground(canvas, slide, slideSize);

    // Paint template widget if layoutId exists
    if (slide.layoutId != null && slide.layoutId!.isNotEmpty) {
      // Template slides render as full widget - handled separately via widget capture
      // For SVG export, we'd use the template's SVG template directly
    } else {
      // Paint individual elements
      final sorted = List<SlideElement>.from(slide.elements)
        ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

      for (final element in sorted) {
        if (element.width > 0 && element.height > 0) {
          final bounds = ElementBounds(
            x: element.x, y: element.y, width: element.width, height: element.height
          );
          _recordElement(canvas, element, bounds);
        }
      }
    }

    return recorder.endRecording();
  }

  static void _recordElement(Canvas canvas, SlideElement element, ElementBounds bounds) {
    canvas.save();
    canvas.translate(bounds.x, bounds.y);

    switch (element.type) {
      case ElementType.text: _recordText(canvas, element, bounds.size); break;
      case ElementType.icon: _recordIcon(canvas, element, bounds.size); break;
      case ElementType.chart: _recordChart(canvas, element, bounds.size); break;
      case ElementType.shape: _recordShape(canvas, element, bounds.size); break;
      case ElementType.image: _recordImage(canvas, element, bounds.size); break;
      case ElementType.table: _recordTable(canvas, element, bounds.size); break;
      case ElementType.video:
      case ElementType.audio: _recordMediaPlaceholder(canvas, element, bounds.size); break;
      case ElementType.draw: _recordDraw(canvas, element, bounds.size); break;
    }

    canvas.restore();
  }

  // =========================================================================
  // BACKGROUND
  // =========================================================================

  static void _recordBackground(Canvas canvas, Slide slide, Size slideSize) {
    final gradientColors = AppTheme.gradientFor(slide.backgroundGradient);
    final rect = Rect.fromLTWH(0, 0, slideSize.width, slideSize.height);

    if (gradientColors.length >= 2 && gradientColors[0] != gradientColors[1]) {
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft, rect.bottomRight,
          gradientColors,
        );
      canvas.drawRect(rect, paint);
    } else {
      final paint = Paint()..color = gradientColors.first;
      canvas.drawRect(rect, paint);
    }
  }

  // =========================================================================
  // TEXT ELEMENT
  // =========================================================================

  static void _paintText(Canvas canvas, SlideElement element, Size size) {
    final ts = element.textStyle ?? TextStyleData();
    final textStyle = _buildTextStyle(ts);

    final textSpan = TextSpan(text: element.content ?? '', style: textStyle);
    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: _textAlign(ts.textAlign),
      maxLines: null,
    )..layout(maxWidth: size.width);

    tp.paint(canvas, Offset(0, 0));
  }

  static void _recordText(Canvas canvas, SlideElement element, Size size) {
    // For SVG, we need to output actual <text> elements with proper attributes
    // This is a simplified version - full SVG text export happens in SvgExportService
    _paintText(canvas, element, size);
  }

  // =========================================================================
  // ICON ELEMENT
  // =========================================================================

  static void _paintIcon(Canvas canvas, SlideElement element, Size size) {
    final content = element.content ?? '⭐';
    final ts = element.textStyle ?? TextStyleData();
    final color = ts.colorValue != 0xFFFFFFFF ? Color(ts.colorValue) : Colors.white;

    if (content.startsWith('icon:')) {
      final codeStr = content.split(',')[0].replaceFirst('icon:', '');
      final codePoint = int.tryParse(codeStr);
      if (codePoint != null) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(codePoint),
            style: TextStyle(fontSize: ts.fontSize ?? 24, fontFamily: 'MaterialIcons', color: color),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2));
        return;
      }
    }

    // Emoji/text fallback
    final textPainter = TextPainter(
      text: TextSpan(text: content, style: TextStyle(fontSize: ts.fontSize ?? 24, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2));
  }

  static void _recordIcon(Canvas canvas, SlideElement element, Size size) {
    _paintIcon(canvas, element, size);
  }

  // =========================================================================
  // CHART ELEMENT
  // =========================================================================

  static void _paintChart(Canvas canvas, SlideElement element, Size size) {
    final cd = element.chartData;
    if (cd == null) return _paintPlaceholder(canvas, 'Chart', size);

    switch (cd.chartType) {
      case 'pie':
      case 'donut':
        _paintPieChart(canvas, cd, size);
        break;
      case 'line':
        _paintLineChart(canvas, cd, size);
        break;
      default:
        _paintBarChart(canvas, cd, size);
    }
  }

  static void _recordChart(Canvas canvas, SlideElement element, Size size) {
    _paintChart(canvas, element, size);
  }

  static void _paintBarChart(Canvas canvas, ChartData cd, Size size) {
    final barCount = cd.labels.length;
    if (barCount == 0) return;

    final barWidth = size.width / (barCount * 2);
    final spacing = barWidth;
    final maxVal = cd.dataSets.expand((ds) => ds.values).fold(0.0, (a, b) => a > b ? a : b);
    if (maxVal <= 0) return;

    for (var i = 0; i < barCount; i++) {
      final x = i * (barWidth + spacing) + spacing;
      for (var dsIdx = 0; dsIdx < cd.dataSets.length; dsIdx++) {
        final ds = cd.dataSets[dsIdx];
        if (ds.values.length > i) {
          final h = (ds.values[i] / maxVal) * (size.height * 0.8);
          final rect = Rect.fromLTWH(
            x + dsIdx * (barWidth / cd.dataSets.length.clamp(1, 10)),
            size.height - h,
            barWidth / cd.dataSets.length.clamp(1, 10),
            h,
          );
          final paint = Paint()..color = Color(ds.colorValue);
          canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), paint);
        }
      }
    }
  }

  static void _paintPieChart(Canvas canvas, ChartData cd, Size size) {
    final ds = cd.dataSets.isNotEmpty ? cd.dataSets.first : ChartDataSet(values: [], label: '');
    final total = ds.values.fold(0.0, (a, b) => a + b);
    if (total == 0 || ds.values.isEmpty) return;

    final radius = math.min(size.width, size.height) / 2 - 10;
    final center = Offset(size.width / 2, size.height / 2);
    double startAngle = -math.pi / 2;

    for (var i = 0; i < ds.values.length; i++) {
      final sweepAngle = (ds.values[i] / total) * 2 * math.pi;
      // Use ds.colorValue for all values, not cd.dataSets[i] which can throw RangeError
      // when ds.values.length > cd.dataSets.length
      final baseColor = Color(ds.colorValue);
      final color = i < cd.dataSets.length ? Color(cd.dataSets[i].colorValue) : baseColor.withValues(alpha: math.max(0.2, 0.85 - i * 0.08));

      final paint = Paint()..color = color..style = PaintingStyle.fill;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, true, paint);
      startAngle += sweepAngle;
    }

    if (cd.chartType == 'donut') {
      final holePaint = Paint()..color = const Color(0xFF13131A)..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius * 0.5, holePaint);
    }
  }

  static void _paintLineChart(Canvas canvas, ChartData cd, Size size) {
    if (cd.dataSets.isEmpty || cd.labels.isEmpty) return;

    final padding = 12.0;
    final chartW = size.width - padding * 2;
    final chartH = size.height - padding * 2;

    final allValues = cd.dataSets.expand((ds) => ds.values).toList();
    final maxVal = allValues.reduce((a, b) => a > b ? a : b);
    if (maxVal <= 0) return;

    // Grid
    for (var i = 0; i < 4; i++) {
      final y = padding + chartH * (1 - (i + 1) / 4);
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        Paint()..color = Colors.white.withAlpha(20)..strokeWidth = 0.5,
      );
    }

    for (var dsIdx = 0; dsIdx < cd.dataSets.length; dsIdx++) {
      final ds = cd.dataSets[dsIdx];
      if (ds.values.length < 2) continue;

      final paint = Paint()
        ..color = Color(ds.colorValue)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final fillPaint = Paint()
        ..color = Color(ds.colorValue).withAlpha(30)
        ..style = PaintingStyle.fill;

      final path = Path();
      final stepX = chartW / (ds.values.length - 1);

      for (var i = 0; i < ds.values.length; i++) {
        final x = padding + i * stepX;
        final y = padding + chartH * (1 - ds.values[i] / maxVal);
        if (i == 0) path.moveTo(x, y);
        else path.lineTo(x, y);

        canvas.drawCircle(Offset(x, y), 3, Paint()..color = Color(ds.colorValue));
      }

      canvas.drawPath(path, paint);

      final fillPath = Path.from(path)
        ..lineTo(padding + chartW, padding + chartH)
        ..lineTo(padding, padding + chartH)
        ..close();
      canvas.drawPath(fillPath, fillPaint);
    }
  }

  // =========================================================================
  // SHAPE ELEMENT
  // =========================================================================

  static void _paintShape(Canvas canvas, SlideElement element, Size size) {
    final ss = element.shapeStyle ?? ShapeStyleData();
    final color = Color(ss.fillColorValue).withValues(alpha: ss.opacity);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final borderRadius = ss.shapeType == 'circle'
      ? BorderRadius.circular(9999)
      : BorderRadius.circular(ss.borderRadius);

    if (ss.shapeType == 'diamond') {
      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(math.pi / 4);
      final paint = Paint()..color = color;
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: size.width, height: size.height), paint);
      canvas.restore();
      return;
    }

    if (ss.shapeType == 'triangle') {
      final path = Path()
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
      return;
    }

    // Rect, rounded rect, etc.
    final paint = Paint()..color = color;
    if (borderRadius.topLeft.x > 0) {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(borderRadius.topLeft.x)), paint);
    } else {
      canvas.drawRect(rect, paint);
    }

    // Stroke
    if (ss.strokeColorValue != null && ss.strokeWidth > 0) {
      final strokePaint = Paint()
        ..color = Color(ss.strokeColorValue!)
        ..strokeWidth = ss.strokeWidth
        ..style = PaintingStyle.stroke;
      if (borderRadius.topLeft.x > 0) {
        canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(borderRadius.topLeft.x)), strokePaint);
      } else {
        canvas.drawRect(rect, strokePaint);
      }
    }
  }

  static void _recordShape(Canvas canvas, SlideElement element, Size size) {
    _paintShape(canvas, element, size);
  }

  // =========================================================================
  // IMAGE ELEMENT
  // =========================================================================

  static void _paintImage(Canvas canvas, SlideElement element, Size size) {
    // Note: Actual image painting requires async image loading
    // For SVG export, we embed image as data URI or reference
    final img = element.imageStyle ?? ImageStyleData();
    final src = img.src;

    if (src == null || src.isEmpty) {
      _paintPlaceholder(canvas, img.placeholderLabel ?? '🖼', size);
      return;
    }

    // In canvas mode, we'd use Image widget - here just placeholder
    _paintPlaceholder(canvas, 'Image', size);
  }

  static void _recordImage(Canvas canvas, SlideElement element, Size size) {
    // For SVG export, image handling is done in SvgExportService with data-pptx-* attributes
    _paintPlaceholder(canvas, 'Image', size);
  }

  // =========================================================================
  // TABLE ELEMENT
  // =========================================================================

  static void _paintTable(Canvas canvas, SlideElement element, Size size) {
    final td = element.tableData;
    if (td == null) return _paintPlaceholder(canvas, 'Table', size);

    final rowH = size.height / td.rows;
    final colW = size.width / td.cols;

    for (var r = 0; r < td.rows; r++) {
      for (var c = 0; c < td.cols; c++) {
        final rect = Rect.fromLTWH(c * colW, r * rowH, colW, rowH);
        final isHeader = r == 0 && td.hasHeader;

        final bgPaint = Paint()
          ..color = isHeader
            ? const Color(0xFF6366F1).withAlpha(180)
            : (r % 2 == 0 ? Colors.white.withAlpha(10) : Colors.white.withAlpha(5));
        canvas.drawRect(rect, bgPaint);

        // Border
        canvas.drawRect(rect, Paint()
          ..color = Colors.white.withAlpha(15)
          ..strokeWidth = 0.5
          ..style = PaintingStyle.stroke);

        // Text
        if (r < td.cells.length && c < td.cells[r].length) {
          final text = td.cells[r][c];
          final tp = TextPainter(
            text: TextSpan(text: text, style: TextStyle(
              fontSize: 10,
              color: isHeader ? Colors.white : Colors.white70,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            )),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
          )..layout(maxWidth: colW - 4);

          tp.paint(canvas, Offset(
            c * colW + (colW - tp.width) / 2,
            r * rowH + (rowH - tp.height) / 2,
          ));
        }
      }
    }
  }

  static void _recordTable(Canvas canvas, SlideElement element, Size size) {
    _paintTable(canvas, element, size);
  }

  // =========================================================================
  // DRAW/INK ELEMENT
  // =========================================================================

  static void _paintDraw(Canvas canvas, SlideElement element, Size size) {
    final dd = element.drawData;
    if (dd == null || dd.strokes.isEmpty) return;

    for (final stroke in dd.strokes) {
      if (stroke.points.length < 2) continue;
      final path = Path()..moveTo(stroke.points[0][0].toDouble(), stroke.points[0][1].toDouble());
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i][0].toDouble(), stroke.points[i][1].toDouble());
      }
      canvas.drawPath(path, Paint()
        ..color = Color(stroke.colorValue)
        ..strokeWidth = stroke.size
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke);
    }
  }

  static void _recordDraw(Canvas canvas, SlideElement element, Size size) {
    _paintDraw(canvas, element, size);
  }

  // =========================================================================
  // MEDIA PLACEHOLDER (VIDEO/AUDIO)
  // =========================================================================

  static void _paintMediaPlaceholder(Canvas canvas, SlideElement element, Size size) {
    final isVideo = element.type == ElementType.video;
    final icon = isVideo ? '🎬' : '🎵';
    final label = isVideo ? 'Video' : 'Audio';

    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(8)),
      Paint()..color = const Color(0xFF1A1A2E),
    );

    // Border
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(8)),
      Paint()..color = const Color(0xFF6366F1)..strokeWidth = 2..style = PaintingStyle.stroke,
    );

    // Icon
    final tp = TextPainter(
      text: TextSpan(text: icon, style: const TextStyle(fontSize: 32)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height / 2 - tp.height - 10));

    // Label
    final tp2 = TextPainter(
      text: TextSpan(text: label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, Offset((size.width - tp2.width) / 2, size.height / 2 + 10));
  }

  static void _recordMediaPlaceholder(Canvas canvas, SlideElement element, Size size) {
    _paintMediaPlaceholder(canvas, element, size);
  }

  // =========================================================================
  // PLACEHOLDER
  // =========================================================================

  static void _paintPlaceholder(Canvas canvas, String label, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(6)),
      Paint()..color = Colors.white.withValues(alpha: 0.1),
    );
    final tp = TextPainter(
      text: TextSpan(text: label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
  }

  // =========================================================================
  // HELPERS
  // =========================================================================

  static TextStyle _buildTextStyle(TextStyleData ts) {
    return TextStyle(
      color: Color(ts.colorValue),
      fontSize: ts.fontSize,
      fontWeight: ts.fontWeightValue >= 700 ? FontWeight.bold : ts.fontWeightValue >= 500 ? FontWeight.w500 : FontWeight.normal,
      fontStyle: ts.fontStyle == 'italic' ? FontStyle.italic : FontStyle.normal,
      fontFamily: ts.fontFamily,
      letterSpacing: ts.letterSpacing,
      height: ts.lineHeight,
      decoration: ts.textDecoration == 'underline' ? TextDecoration.underline
          : ts.textDecoration == 'line-through' ? TextDecoration.lineThrough : TextDecoration.none,
    );
  }

  static TextAlign _textAlign(String a) {
    switch (a) {
      case 'center': return TextAlign.center;
      case 'right': return TextAlign.right;
      case 'justify': return TextAlign.justify;
      default: return TextAlign.left;
    }
  }
}