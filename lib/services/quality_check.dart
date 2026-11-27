// DocuCraft — Quality Check Service
// Validasi desain SVG setelah AI generate + auto-fix

import '../models/slide.dart';

class QualityCheckResult {
  final bool passed;
  final List<String> issues;
  final List<String> fixes;

  QualityCheckResult({required this.passed, required this.issues, required this.fixes});
}

/// Layout audit result (GenOffice-style).
class LayoutAuditResult {
  final int score;
  final List<String> issues;
  final List<String> autoFixable;
  final bool shouldRevert;

  const LayoutAuditResult({
    required this.score,
    required this.issues,
    required this.autoFixable,
    required this.shouldRevert,
  });
}

class QualityChecker {
  static const double canvasWidth = 1280;
  static const double canvasHeight = 720;
  static const double minFontSize = 12;
  static const int minElements = 3;
  static const int maxElements = 20;

  /// Comprehensive layout audit (GenOffice-style).
  /// Checks for common issues and returns audit score.
  /// Higher score = better layout quality.
  static LayoutAuditResult auditLayout(List<SlideElement> elements) {
    int score = 100;
    final issues = <String>[];
    final autoFixable = <String>[];

    // 1. Canvas boundary check (-10 per violation)
    for (final el in elements) {
      if (el.x + el.width > canvasWidth) {
        score -= 10;
        issues.add('Element overflow right: x=${el.x.toInt()}, w=${el.width.toInt()}');
        autoFixable.add('clamp_${el.id}');
      }
      if (el.y + el.height > canvasHeight) {
        score -= 10;
        issues.add('Element overflow bottom: y=${el.y.toInt()}, h=${el.height.toInt()}');
        autoFixable.add('clamp_${el.id}');
      }
    }

    // 2. Text readability (-5 per violation)
    for (final el in elements.where((e) => e.type == ElementType.text)) {
      if (el.textStyle != null && el.textStyle!.fontSize < minFontSize) {
        score -= 5;
        issues.add('Text too small: ${el.textStyle!.fontSize}px');
        autoFixable.add('fontsize_${el.id}');
      }
    }

    // 3. Overlap detection (-15 per overlap)
    final textEls = elements.where((e) => e.type == ElementType.text).toList();
    for (int i = 0; i < textEls.length; i++) {
      for (int j = i + 1; j < textEls.length; j++) {
        final a = textEls[i];
        final b = textEls[j];
        if (_rectsOverlap(a.x, a.y, a.width, a.height, b.x, b.y, b.width, b.height)) {
          score -= 15;
          issues.add('Text overlap detected');
        }
      }
    }

    // 4. Content distribution (-10 if crammed in top half)
    if (elements.isNotEmpty) {
      final avgY = elements.map((e) => e.y + e.height / 2).reduce((a, b) => a + b) / elements.length;
      if (avgY < canvasHeight * 0.35) {
        score -= 10;
        issues.add('Content crammed in top half (avg Y: ${avgY.toInt()})');
      }
    }

    // 5. Element count check
    if (elements.length < minElements) {
      score -= 5;
      issues.add('Too few elements: ${elements.length}');
    }

    // 6. Color variety check (anti-rainbow) - strip alpha for comparison
    final colors = <String>{};
    for (final el in elements) {
      if (el.shapeStyle != null) {
        // Strip alpha byte, compare only RGB
        final rgb = (el.shapeStyle!.fillColorValue & 0x00FFFFFF).toRadixString(16).padLeft(6, '0');
        colors.add(rgb);
      }
    }
    if (colors.length > 5) {
      score -= 10;
      issues.add('Too many colors: ${colors.length} (anti-rainbow rule)');
    }

    return LayoutAuditResult(
      score: score.clamp(0, 100),
      issues: issues,
      autoFixable: autoFixable,
      shouldRevert: score < 50,
    );
  }

  /// Auto-fix layout issues where possible.
  /// Returns a NEW list with cloned elements (does not mutate input).
  static List<SlideElement> autoFixLayout(List<SlideElement> elements) {
    final fixed = elements.map((el) => SlideElement(
      id: el.id,
      type: el.type,
      x: el.x,
      y: el.y,
      width: el.width,
      height: el.height,
      content: el.content,
      zIndex: el.zIndex,
      textStyle: el.textStyle,
      shapeStyle: el.shapeStyle,
      imageStyle: el.imageStyle,
      chartData: el.chartData,
      tableData: el.tableData,
      drawData: el.drawData,
    )).toList();

    for (final el in fixed) {
      // Clamp to canvas
      if (el.x + el.width > canvasWidth) el.width = canvasWidth - el.x;
      if (el.y + el.height > canvasHeight) el.height = canvasHeight - el.y;
      if (el.x < 0) el.x = 0;
      if (el.y < 0) el.y = 0;

      // Ensure minimum size
      if (el.width < 10) el.width = 10;
      if (el.height < 10) el.height = 10;
    }
    return fixed;
  }

  static QualityCheckResult check(List<SlideElement> elements) {
    final issues = <String>[];
    final fixes = <String>[];

    // 1. Canvas boundary check
    for (final el in elements) {
      if (el.x + el.width > canvasWidth) {
        issues.add('Element keluar kanan canvas: x=${el.x.toInt()}, width=${el.width.toInt()}');
        fixes.add('reposition_${el.id}');
      }
      if (el.y + el.height > canvasHeight) {
        issues.add('Element keluar bawah canvas: y=${el.y.toInt()}, height=${el.height.toInt()}');
        fixes.add('reposition_${el.id}');
      }
      if (el.x < 0) {
        issues.add('Element negatif x: ${el.x.toInt()}');
        fixes.add('reposition_${el.id}');
      }
      if (el.y < 0) {
        issues.add('Element negatif y: ${el.y.toInt()}');
        fixes.add('reposition_${el.id}');
      }
    }

    // 2. Text readability check
    for (final el in elements.where((e) => e.type == ElementType.text)) {
      if (el.textStyle != null && el.textStyle!.fontSize < minFontSize) {
        issues.add('Teks terlalu kecil: ${el.textStyle!.fontSize}px (min ${minFontSize}px)');
        fixes.add('fontsize_${el.id}');
      }
    }

    // 3. Element count check
    if (elements.length < minElements) {
      issues.add('Terlalu sedikit elemen: ${elements.length} (min $minElements)');
      fixes.add('add_decorative');
    }
    if (elements.length > maxElements) {
      issues.add('Terlalu banyak elemen: ${elements.length} (max $maxElements)');
      fixes.add('simplify');
    }

    // 4. Overlap detection (text elements only)
    final textEls = elements.where((e) => e.type == ElementType.text).toList();
    for (int i = 0; i < textEls.length; i++) {
      for (int j = i + 1; j < textEls.length; j++) {
        final a = textEls[i];
        final b = textEls[j];
        if (_rectsOverlap(a.x, a.y, a.width, a.height, b.x, b.y, b.width, b.height)) {
          final labelA = (a.content ?? '').length > 20 ? '${(a.content ?? '').substring(0, 20)}...' : (a.content ?? '');
          final labelB = (b.content ?? '').length > 20 ? '${(b.content ?? '').substring(0, 20)}...' : (b.content ?? '');
          issues.add('Teks overlap: "$labelA" dan "$labelB"');
          fixes.add('overlap_${a.id}_${b.id}');
        }
      }
    }

    // 5. Text overflow check — uses actual laid-out values (contentHeight & overflowXPx)
    //    Falls back to heuristic only when contentHeight is not available.
    //    Skips width overflow check for vertical text (axes are mixed in vertical layout).
    for (final el in elements.where((e) => e.type == ElementType.text)) {
      if (el.textStyle == null) continue;
      final ts = el.textStyle!;
      final content = el.content ?? '';

      // Skip width overflow for vertical text (the renderer's contentHeight still measures
      // the correct vertical axis, but run.x/widthPx mix axes in vertical layout).
      if (ts.isVertical) {
        // Only check height overflow for vertical text
        if (ts.contentHeight != null && ts.contentHeight! - el.height > 0) {
          final label = content.length > 20 ? '${content.substring(0, 20)}...' : content;
          issues.add('Teks vertikal melebihi tinggi kotak: "$label" melebihi ${el.height.toInt()}px');
          fixes.add('textheight_${el.id}');
        }
        continue;
      }

      // Width overflow check — uses real laid-out overflowXPx if available
      if (ts.overflowXPx != null && ts.overflowXPx! > 0) {
        final label = content.length > 20 ? '${content.substring(0, 20)}...' : content;
        final overflow = ts.overflowXPx!.toInt();
        issues.add('Teks melebihi lebar kotak: "$label" overflow ${overflow}px');
        fixes.add('textoverflow_${el.id}');
      } else if (ts.contentHeight == null && content.length > 3 && el.width > 0) {
        // Fallback heuristic when contentHeight not computed (e.g. programmatic elements)
        final charWidth = ts.fontSize;
        if (content.length * charWidth * 0.6 > el.width * 1.5) {
          final label = content.length > 20 ? '${content.substring(0, 20)}...' : content;
          issues.add('Teks mungkin terpotong: "$label" melebihi lebar');
          fixes.add('textoverflow_${el.id}');
        }
      }
    }

    return QualityCheckResult(
      passed: issues.isEmpty,
      issues: issues,
      fixes: fixes,
    );
  }

  static List<SlideElement> autoFix(List<SlideElement> elements, QualityCheckResult check) {
    final fixed = <SlideElement>[];

    for (final el in elements) {
      final newEl = SlideElement.fromJson(el.toJson());

      // Fix canvas boundary
      if (check.fixes.contains('reposition_${newEl.id}')) {
        if (newEl.x + newEl.width > canvasWidth) {
          newEl.x = canvasWidth - newEl.width - 20;
        }
        if (newEl.y + newEl.height > canvasHeight) {
          newEl.y = canvasHeight - newEl.height - 20;
        }
        if (newEl.x < 0) newEl.x = 10;
        if (newEl.y < 0) newEl.y = 10;
      }

      // Fix font size
      if (check.fixes.contains('fontsize_${newEl.id}')) {
        if (newEl.type == ElementType.text && newEl.textStyle != null) {
          if (newEl.textStyle!.fontSize < minFontSize) {
            newEl.textStyle!.fontSize = minFontSize;
          }
        }
      }

      // Fix text overflow — widen the element or reduce font size
      if (check.fixes.contains('textoverflow_${newEl.id}')) {
        if (newEl.type == ElementType.text && newEl.textStyle != null) {
          // Strategy: reduce font size by 20% to fit (simpler than widening boxes)
          newEl.textStyle!.fontSize = (newEl.textStyle!.fontSize * 0.8).clamp(8.0, 72.0);
        }
      }

      // Fix text height overflow — reduce font size to fit height
      if (check.fixes.contains('textheight_${newEl.id}')) {
        if (newEl.type == ElementType.text && newEl.textStyle != null) {
          newEl.textStyle!.fontSize = (newEl.textStyle!.fontSize * 0.85).clamp(8.0, 72.0);
        }
      }

      fixed.add(newEl);
    }

    return fixed;
  }

  /// Check if two axis-aligned rectangles overlap (with 10% margin tolerance)
  static bool _rectsOverlap(
    double x1, double y1, double w1, double h1,
    double x2, double y2, double w2, double h2,
  ) {
    const margin = 0.1; // 10% tolerance
    final mx1 = x1 - w1 * margin;
    final my1 = y1 - h1 * margin;
    final mx2 = x2 - w2 * margin;
    final my2 = y2 - h2 * margin;
    final mw1 = w1 * (1 + 2 * margin);
    final mh1 = h1 * (1 + 2 * margin);
    final mw2 = w2 * (1 + 2 * margin);
    final mh2 = h2 * (1 + 2 * margin);
    return mx1 < mx2 + mw2 && mx1 + mw1 > mx2 && my1 < my2 + mh2 && my1 + mh1 > my2;
  }
}
