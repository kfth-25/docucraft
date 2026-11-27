// DocuCraft — Sheet chart rendering
// Chart CustomPainter buatan sendiri untuk layar AI Excel. Sidecar GenOffice
// sudah mem-parse tiap `xl/charts/chartN.xml` ke JSON (title, type, series dengan
// categories/values/colors); file ini menggambarnya — tanpa paket charting.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/genoffice_sheets.dart';
import '../themes/app_theme.dart';

/// Green-first series color cycle, consistent with the AI Excel theme.
const List<Color> _kDefaultPalette = [
  Color(0xFF16A34A), // green
  Color(0xFFF59E0B), // amber
  Color(0xFF3F51B5), // indigo
  Color(0xFF06B6D4), // cyan
  Color(0xFFF43F5E), // rose
  Color(0xFF8B5CF6), // violet
  Color(0xFFF97316), // orange
];

Color? _parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var h = hex.replaceFirst('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final value = int.tryParse(h, radix: 16);
  return value == null ? null : Color(value);
}

String _truncate(String s, int max) => s.length <= max ? s : '${s.substring(0, max)}…';

List<Color> _seriesColors(SheetChart chart) {
  return [
    for (var i = 0; i < chart.series.length; i++)
      _parseHexColor(chart.series[i].color) ??
          _kDefaultPalette[i % _kDefaultPalette.length],
  ];
}

/// A floating chart object overlaid on the grid at its anchor position, like
/// how Excel/Univer float a chart above the cells it was inserted over. Fills
/// the `Positioned` box the screen computes from the anchor + column widths.
class SheetChartOverlay extends StatelessWidget {
  final SheetChart chart;

  const SheetChartOverlay({super.key, required this.chart});

  @override
  Widget build(BuildContext context) {
    final colors = _seriesColors(chart);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD8DEE4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x14000000),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chart.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
              child: Text(
                chart.title,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
              ),
            ),
          Expanded(
            // CustomPaint has no child/size, so inside Expanded (tight height,
            // loose width) it collapses to zero width and every bar/label slams
            // into the left edge ("kecil mepet"). SizedBox.expand forces it to
            // fill the box so the painter lays out across the full plot area.
            child: SizedBox.expand(
              child: CustomPaint(
                painter: _SheetChartPainter(chart: chart, seriesColors: colors),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A chart card (title + plot + legend) rendered with a green-first palette.
class SheetChartCard extends StatelessWidget {
  final SheetChart chart;

  const SheetChartCard({super.key, required this.chart});

  bool get _isPie => chart.chartType == 'pieChart' || chart.chartType == 'doughnutChart';

  @override
  Widget build(BuildContext context) {
    final colors = _seriesColors(chart);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chart.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                chart.title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
            ),
          SizedBox(
            height: 200,
            width: double.infinity,
            child: CustomPaint(
              painter: _SheetChartPainter(chart: chart, seriesColors: colors),
            ),
          ),
          const SizedBox(height: 8),
          _legend(colors),
        ],
      ),
    );
  }

  Widget _legend(List<Color> colors) {
    if (_isPie) {
      final s = chart.series.isEmpty ? null : chart.series[0];
      if (s == null) return const SizedBox.shrink();
      return Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (var i = 0; i < s.values.length; i++)
            _legendItem(
              i < s.categories.length ? s.categories[i] : 'Item ${i + 1}',
              _kDefaultPalette[i % _kDefaultPalette.length],
            ),
        ],
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (var i = 0; i < chart.series.length; i++)
          _legendItem(
            chart.series[i].name.isEmpty ? 'Series ${i + 1}' : chart.series[i].name,
            colors[i % colors.length],
          ),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _SheetChartPainter extends CustomPainter {
  final SheetChart chart;
  final List<Color> seriesColors;

  _SheetChartPainter({required this.chart, required this.seriesColors});

  @override
  void paint(Canvas canvas, Size size) {
    switch (chart.chartType) {
      case 'pieChart':
      case 'doughnutChart':
        _paintPie(canvas, size, chart.chartType == 'doughnutChart');
        break;
      case 'lineChart':
        _paintLine(canvas, size, filled: false);
        break;
      case 'areaChart':
        _paintLine(canvas, size, filled: true);
        break;
      case 'barChart':
        _paintBar(canvas, size);
        break;
      case 'scatterChart':
      case 'radarChart':
        // No dedicated scatter/radar renderer yet — plot values as a line so the
        // chart still appears rather than vanishing.
        _paintLine(canvas, size, filled: false);
        break;
      default:
        _paintBar(canvas, size);
    }
  }

  @override
  bool shouldRepaint(covariant _SheetChartPainter old) => old.chart != chart;

  List<String> _categories() {
    for (final s in chart.series) {
      if (s.categories.isNotEmpty) return s.categories;
    }
    var n = 0;
    for (final s in chart.series) {
      n = math.max(n, s.values.length);
    }
    return [for (var i = 0; i < n; i++) '${i + 1}'];
  }

  List<List<double>> _values() => [for (final s in chart.series) s.values];

  double _maxValue(List<List<double>> values) {
    var maxVal = 0.0;
    for (final row in values) {
      for (final v in row) {
        if (v.isFinite && v > maxVal) maxVal = v;
      }
    }
    return maxVal;
  }

  static const double _leftPad = 8;
  static const double _rightPad = 8;
  static const double _topPad = 8;
  static const double _bottomPad = 20;

  void _paintBar(Canvas canvas, Size size) {
    final horizontal = chart.barDirection == 'bar';
    final cats = _categories();
    final values = _values();
    if (cats.isEmpty) return;
    final maxVal = _maxValue(values);
    if (maxVal <= 0) return;

    final seriesCount = math.max(1, values.length);
    final plot = Rect.fromLTRB(_leftPad, _topPad, size.width - _rightPad, size.height - _bottomPad);
    const barGap = 1.0;
    final n = cats.length;

    for (var i = 0; i < n; i++) {
      for (var s = 0; s < seriesCount; s++) {
        final v = s < values.length && i < values[s].length ? values[s][i] : 0.0;
        final color = seriesColors[s % seriesColors.length];
        if (horizontal) {
          final bandH = plot.height / n;
          final barH = math.max(1.0, bandH * 0.7 / seriesCount);
          final centerY = plot.top + bandH * i + bandH / 2;
          final barY = centerY - bandH * 0.35 + s * (barH + barGap);
          final w = (v / maxVal) * plot.width;
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(plot.left, barY, w, barH), const Radius.circular(2)),
            Paint()..color = color,
          );
        } else {
          final bandW = plot.width / n;
          final barW = math.max(1.0, bandW * 0.7 / seriesCount);
          final centerX = plot.left + bandW * i + bandW / 2;
          final barX = centerX - bandW * 0.35 + s * (barW + barGap);
          final h = (v / maxVal) * plot.height;
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(barX, plot.bottom - h, barW, h), const Radius.circular(2)),
            Paint()..color = color,
          );
        }
      }
    }
    if (!horizontal) _drawCategoryLabels(canvas, cats, plot.left, plot.right, plot.bottom + 4, size.width);
  }

  void _paintLine(Canvas canvas, Size size, {required bool filled}) {
    final cats = _categories();
    final values = _values();
    if (cats.isEmpty) return;
    final maxVal = _maxValue(values);
    if (maxVal <= 0) return;

    final plot = Rect.fromLTRB(_leftPad, _topPad, size.width - _rightPad, size.height - _bottomPad);
    final n = cats.length;
    double xFor(int i) => plot.left + plot.width * (n <= 1 ? 0.5 : i / (n - 1));
    double yFor(double v) => plot.bottom - (v / maxVal) * plot.height;

    for (var s = 0; s < values.length; s++) {
      final vals = values[s];
      if (vals.isEmpty) continue;
      final color = seriesColors[s % seriesColors.length];

      final path = Path();
      for (var i = 0; i < vals.length; i++) {
        final x = xFor(i);
        final y = yFor(vals[i]);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      if (filled) {
        final fill = Path.from(path)
          ..lineTo(xFor(vals.length - 1), plot.bottom)
          ..lineTo(xFor(0), plot.bottom)
          ..close();
        canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.15));
      }
      canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2);
      for (var i = 0; i < vals.length; i++) {
        canvas.drawCircle(Offset(xFor(i), yFor(vals[i])), 2.5, Paint()..color = color);
      }
    }
    _drawCategoryLabels(canvas, cats, plot.left, plot.right, plot.bottom + 4, size.width);
  }

  void _paintPie(Canvas canvas, Size size, bool doughnut) {
    final s = chart.series.isEmpty ? null : chart.series[0];
    if (s == null || s.values.isEmpty) return;
    final total = s.values.fold(0.0, (a, b) => a + (b < 0 ? 0 : b));
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final inner = doughnut ? radius * 0.55 : 0.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    var start = -math.pi / 2;
    for (var i = 0; i < s.values.length; i++) {
      final v = s.values[i] < 0 ? 0.0 : s.values[i];
      final sweep = (v / total) * 2 * math.pi;
      final color = _kDefaultPalette[i % _kDefaultPalette.length];
      canvas.drawArc(rect, start, sweep, true, Paint()..color = color);
      start += sweep;
    }
    if (doughnut) {
      canvas.drawCircle(center, inner, Paint()..color = AppTheme.surface2);
    }
  }

  void _drawCategoryLabels(Canvas canvas, List<String> cats, double left, double right, double y, double maxWidth) {
    if (cats.isEmpty || right <= left) return;
    final n = cats.length;
    final step = (right - left) / n;
    for (var i = 0; i < n; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: _truncate(cats[i], 10),
          style: const TextStyle(fontSize: 8.5, color: AppTheme.textMuted),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: step);
      if (tp.width > step) {
        // Too wide even after truncation — skip to avoid overlap.
        continue;
      }
      final x = left + step * i + (step - tp.width) / 2;
      tp.paint(canvas, Offset(x, y));
    }
  }
}
