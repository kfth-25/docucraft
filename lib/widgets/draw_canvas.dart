// DocuCraft — Draw Mode Canvas V2
// Diperbarui untuk model V2: DrawStroke dengan koordinat double, terintegrasi dengan SlideElement
// Dioptimasi memori: batas stroke, penyederhanaan titik, optimasi performa

import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import '../models/slide.dart';
import '../themes/app_theme.dart';

/// Maximum number of strokes to keep in memory
const int _maxStrokes = 200;

/// Maximum points per stroke before simplification kicks in
const int _maxPointsPerStroke = 500;

/// Simplification tolerance (Douglas-Peucker epsilon)
const double _simplificationTolerance = 2.0;

/// Minimum distance between points to add new point (pixels)
const double _minPointDistance = 3.0;

class DrawCanvas extends StatefulWidget {
  final Size canvasSize;
  final VoidCallback? onStrokeChanged;
  final bool isActive;

  const DrawCanvas({
    super.key,
    required this.canvasSize,
    this.onStrokeChanged,
    this.isActive = false,
  });

  @override
  State<DrawCanvas> createState() => DrawCanvasState();
}

class DrawCanvasState extends State<DrawCanvas> {
  // Key for RepaintBoundary — used to capture canvas as PNG for AI sketch-to-design
  final GlobalKey _repaintKey = GlobalKey();

  bool _drawModeActive = false;
  String _drawMode = 'free';
  double _penSize = 3;
  Color _penColor = const Color(0xFFFFFFFF);
  bool _eraserMode = false;
  final List<DrawStroke> _strokes = [];
  final List<DrawStroke> _undoneStrokes = [];
  DrawStroke? _currentStroke;
  Offset? _currentOffset;

  @override
  void didUpdateWidget(covariant DrawCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      setState(() => _drawModeActive = widget.isActive);
    }
  }

  // Performance tracking
  int _totalPointsAdded = 0;
  int _totalPointsSimplified = 0;

  bool get drawModeActive => _drawModeActive;
  List<DrawStroke> get strokes => _strokes;

  /// Save current strokes to a list (for per-slide storage)
  void saveStrokesToMap(List<Map<String, dynamic>> target) {
    target.clear();
    for (final stroke in _strokes) {
      target.add(stroke.toJson());
    }
  }

  /// Load strokes from a list (for per-slide restore)
  void loadStrokesFromMap(List<Map<String, dynamic>> source) {
    _strokes.clear();
    for (final json in source) {
      _strokes.add(DrawStroke.fromJson(json));
    }
    setState(() {});
  }

  /// Get strokes as JSON map for AI processing (fallback if capture fails)
  Map<String, dynamic> getStrokesAsJson() => {
    'canvasSize': {'width': widget.canvasSize.width, 'height': widget.canvasSize.height},
    'strokeCount': _strokes.length,
    'strokes': _strokes.map((s) => {
      'color': s.colorValue,
      'size': s.size,
      'pointCount': s.points.length,
      'points': s.points,
      'bounds': s.points.isEmpty ? null : {
        'minX': s.points.map((p) => p[0]).reduce((a, b) => a < b ? a : b),
        'minY': s.points.map((p) => p[1]).reduce((a, b) => a < b ? a : b),
        'maxX': s.points.map((p) => p[0]).reduce((a, b) => a > b ? a : b),
        'maxY': s.points.map((p) => p[1]).reduce((a, b) => a > b ? a : b),
      },
    }).toList(),
  };

  /// Get memory usage stats for debugging
  Map<String, int> get memoryStats => {
    'strokeCount': _strokes.length,
    'totalPoints': _strokes.fold(0, (sum, s) => sum + s.points.length),
    'totalPointsAdded': _totalPointsAdded,
    'totalPointsSimplified': _totalPointsSimplified,
    'maxStrokes': _maxStrokes,
    'maxPointsPerStroke': _maxPointsPerStroke,
  };

  void setActive(bool active) {
    setState(() => _drawModeActive = active);
  }

  void setDrawMode(String mode) {
    setState(() {
      _drawMode = mode;
      _eraserMode = false;
    });
  }

  void setPenSize(double size) {
    setState(() => _penSize = size);
  }

  void setPenColor(Color color) {
    setState(() {
      _penColor = color;
      _eraserMode = false;
    });
  }

  void toggleEraser() {
    setState(() => _eraserMode = !_eraserMode);
  }

  /// Capture the current canvas stroke rendering as a PNG (Uint8List).
  /// Used for Sketch-to-Design: user sketch → AI vision prompt.
  Future<Uint8List?> captureToImage({double pixelRatio = 1.0}) async {
    try {
      final context = _repaintKey.currentContext;
      if (context == null) return null;
      final boundary = context.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('captureToImage error: $e');
      return null;
    }
  }

  void undoStroke() {
    if (_strokes.isEmpty) return;
    setState(() {
      _undoneStrokes.add(_strokes.removeLast());
    });
    widget.onStrokeChanged?.call();
  }

  void clearAll() {
    setState(() {
      _strokes.clear();
      _undoneStrokes.clear();
    });
    widget.onStrokeChanged?.call();
  }

  void deleteStrokeAtPoint(Offset localPoint) {
    final hit = _strokes.lastIndexWhere(
      (s) => s.points.any((p) =>
        (Offset(p[0], p[1]) - localPoint).distance < _penSize * 3),
    );
    if (hit >= 0) {
      setState(() => _strokes.removeAt(hit));
      widget.onStrokeChanged?.call();
    }
  }

  void setStrokeLabel(int index, String label) {
    if (index >= 0 && index < _strokes.length) {
      setState(() {
        _drawMode = 'free';
        _strokes[index].label = label;
      });
      widget.onStrokeChanged?.call();
    }
  }

  /// Convert strokes to SlideElement DrawData for persistence
  DrawData? toDrawData() {
    if (_strokes.isEmpty) return null;
    return DrawData(strokes: List.from(_strokes));
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !_drawModeActive,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: RepaintBoundary(
          key: _repaintKey,
          child: CustomPaint(
            size: widget.canvasSize, // Explicit size for proper hit testing
            painter: _DrawPainter(
              strokes: _strokes,
              currentOffset: _currentOffset,
              currentColor: _eraserMode ? null : _penColor,
              currentSize: _penSize,
              eraserMode: _eraserMode,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              onTapUp: _onTapUp,
            ),
          ),
        ),
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    if (!_drawModeActive) return;
    if (_eraserMode) {
      deleteStrokeAtPoint(details.localPosition);
      return;
    }
    _currentStroke = DrawStroke(
      colorValue: _penColor.toARGB32(),
      size: _penSize,
      points: [[details.localPosition.dx, details.localPosition.dy]],
    );
    _currentOffset = details.localPosition;
    _totalPointsAdded++;
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_drawModeActive || _currentStroke == null || _eraserMode) {
      if (_eraserMode) {
        deleteStrokeAtPoint(details.localPosition);
      }
      return;
    }

    // Distance-based point filtering to reduce noise and memory
    final lastPoint = _currentStroke!.points.last;
    final dx = details.localPosition.dx - lastPoint[0];
    final dy = details.localPosition.dy - lastPoint[1];
    final distanceSquared = dx * dx + dy * dy;
    final minDistanceSquared = _minPointDistance * _minPointDistance;

    if (distanceSquared >= minDistanceSquared) {
      _currentStroke!.points.add([details.localPosition.dx, details.localPosition.dy]);
      _totalPointsAdded++;

      // Simplify stroke if it exceeds max points
      if (_currentStroke!.points.length > _maxPointsPerStroke) {
        _simplifyCurrentStroke();
      }
    }

    _currentOffset = details.localPosition;
    setState(() {});
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentStroke != null && _currentStroke!.points.length > 1) {
      // Simplify final stroke before saving
      if (_currentStroke!.points.length > _maxPointsPerStroke) {
        _simplifyCurrentStroke();
      }

      setState(() {
        // Enforce max strokes limit
        if (_strokes.length >= _maxStrokes) {
          _strokes.removeAt(0); // Remove oldest stroke
        }
        _strokes.add(_currentStroke!);
        _undoneStrokes.clear();
      });
      widget.onStrokeChanged?.call();
    }
    _currentStroke = null;
    _currentOffset = null;
  }

  void _onTapUp(TapUpDetails details) {
    if (!_drawModeActive) return;
    if (_eraserMode) {
      deleteStrokeAtPoint(details.localPosition);
    }
  }
  /// Simplify current stroke using Douglas-Peucker algorithm
  void _simplifyCurrentStroke() {
    if (_currentStroke == null || _currentStroke!.points.length <= _maxPointsPerStroke) return;

    final simplified = _douglasPeucker(_currentStroke!.points, _simplificationTolerance);
    _totalPointsSimplified += _currentStroke!.points.length - simplified.length;
    _currentStroke = DrawStroke(
      colorValue: _currentStroke!.colorValue,
      size: _currentStroke!.size,
      points: simplified,
    );
  }

  /// Douglas-Peucker line simplification algorithm
  /// Returns a simplified list of points within the given tolerance
  List<List<double>> _douglasPeucker(List<List<double>> points, double epsilon) {
    if (points.length <= 2) return List.from(points);

    // Find the point with the maximum distance from the line between start and end
    double maxDist = 0;
    int index = 0;
    final start = points.first;
    final end = points.last;

    for (int i = 1; i < points.length - 1; i++) {
      final dist = _pointToLineDistance(points[i], start, end);
      if (dist > maxDist) {
        maxDist = dist;
        index = i;
      }
    }

    // If max distance is greater than epsilon, recursively simplify
    if (maxDist > epsilon) {
      final left = _douglasPeucker(points.sublist(0, index + 1), epsilon);
      final right = _douglasPeucker(points.sublist(index), epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [points.first, points.last];
    }
  }

  /// Calculate perpendicular distance from point to line segment
  double _pointToLineDistance(List<double> point, List<double> lineStart, List<double> lineEnd) {
    final x = point[0];
    final y = point[1];
    final x1 = lineStart[0];
    final y1 = lineStart[1];
    final x2 = lineEnd[0];
    final y2 = lineEnd[1];

    final A = x - x1;
    final B = y - y1;
    final C = x2 - x1;
    final D = y2 - y1;

    final dot = A * C + B * D;
    final lenSq = C * C + D * D;

    if (lenSq == 0) return math.sqrt(A * A + B * B);

    final param = dot / lenSq;

    double xx, yy;
    if (param < 0) {
      xx = x1;
      yy = y1;
    } else if (param > 1) {
      xx = x2;
      yy = y2;
    } else {
      xx = x1 + param * C;
      yy = y1 + param * D;
    }

    final dx = x - xx;
    final dy = y - yy;
    return math.sqrt(dx * dx + dy * dy);
  }
}

// ── Painter ──
class _DrawPainter extends CustomPainter {
  final List<DrawStroke> strokes;
  final Offset? currentOffset;
  final Color? currentColor;
  final double currentSize;
  final bool eraserMode;

  _DrawPainter({
    required this.strokes,
    this.currentOffset,
    this.currentColor,
    required this.currentSize,
    required this.eraserMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed strokes
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = Color(stroke.colorValue)
        ..strokeWidth = stroke.size
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path();
      path.moveTo(stroke.points[0][0], stroke.points[0][1]);
      if (stroke.points.length > 2) {
        // Use quadratic bezier curves for smooth lines
        for (int i = 1; i < stroke.points.length - 1; i++) {
          final xc = (stroke.points[i][0] + stroke.points[i + 1][0]) / 2;
          final yc = (stroke.points[i][1] + stroke.points[i + 1][1]) / 2;
          path.quadraticBezierTo(
            stroke.points[i][0], stroke.points[i][1],
            xc, yc,
          );
        }
        final last = stroke.points.length - 1;
        path.lineTo(stroke.points[last][0], stroke.points[last][1]);
      } else {
        path.lineTo(stroke.points[1][0], stroke.points[1][1]);
      }
      canvas.drawPath(path, paint);
    }

    // Draw current stroke (while dragging)
    if (currentOffset != null && currentColor != null && !eraserMode) {
      final paint = Paint()
        ..color = currentColor!
        ..strokeWidth = currentSize
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentOffset!, currentSize / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_DrawPainter oldDelegate) =>
    oldDelegate.strokes.length != strokes.length ||
    oldDelegate.currentOffset != currentOffset ||
    oldDelegate.eraserMode != eraserMode;
}

// ── Draw Toolbar Widget ──
class DrawToolbar extends StatelessWidget {
  final DrawCanvasState drawState;
  final VoidCallback onClose;

  const DrawToolbar({
    super.key,
    required this.drawState,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        border: Border(top: BorderSide(color: Colors.white.withAlpha(12))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.draw, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            _modeBtn('Bebas', 'free', drawState._drawMode == 'free'),
            const SizedBox(width: 4),
            _modeBtn('Sketch', 'sketch', drawState._drawMode == 'sketch'),
            const SizedBox(width: 8),
            _divider(),
            const SizedBox(width: 4),
            _sizeDot(4, drawState._penSize == 4),
            const SizedBox(width: 4),
            _sizeDot(8, drawState._penSize == 8),
            const SizedBox(width: 4),
            _sizeDot(12, drawState._penSize == 12),
            const SizedBox(width: 8),
            _divider(),
            const SizedBox(width: 4),
            // Warna dasar
            _colorCircle(const Color(0xFF1E293B), 'Hitam'),
            const SizedBox(width: 4),
            _colorCircle(const Color(0xFFFFFFFF), 'Putih'),
            const SizedBox(width: 4),
            _colorCircle(const Color(0xFFEF4444), 'Merah'),
            const SizedBox(width: 4),
            _colorCircle(const Color(0xFF3B82F6), 'Biru'),
            const SizedBox(width: 4),
            _colorCircle(const Color(0xFF10B981), 'Hijau'),
            const SizedBox(width: 4),
            _colorCircle(const Color(0xFFF59E0B), 'Kuning'),
            const SizedBox(width: 4),
            _colorCircle(const Color(0xFFEC4899), 'Pink'),
            const SizedBox(width: 4),
            _colorCircle(const Color(0xFF94A3B8), 'Abu'),
            const SizedBox(width: 4),
            _colorCircle(const Color(0xFF6366F1), 'Indigo'),
            const SizedBox(width: 4),
            _colorCircle(const Color(0xFF14B8A6), 'Teal'),
            const SizedBox(width: 4),
            _colorCircle(const Color(0xFFF97316), 'Orange'),
            const SizedBox(width: 4),
            _colorCircle(const Color(0xFFA855F7), 'Ungu'),
            const SizedBox(width: 8),
            _divider(),
            const SizedBox(width: 4),
            _iconBtn(Icons.auto_fix_high, 'Eraser', drawState._eraserMode, drawState.toggleEraser),
            const SizedBox(width: 4),
            _iconBtn(Icons.undo_rounded, 'Undo', false, drawState.undoStroke),
            const SizedBox(width: 4),
            _iconBtn(Icons.delete_sweep, 'Clear', false, () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.surface2,
                  title: const Text('Hapus semua coretan?', style: TextStyle(color: Colors.white, fontSize: 14)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary))),
                    TextButton(onPressed: () { drawState.clearAll(); Navigator.pop(ctx); }, child: const Text('Hapus', style: TextStyle(color: AppTheme.error))),
                  ],
                ),
              );
            }),
            const SizedBox(width: 8),
            _divider(),
            const SizedBox(width: 4),
            _iconBtn(Icons.close, 'Tutup', false, onClose),
          ],
        ),
      ),
    );
  }

  Widget _modeBtn(String label, String value, bool active) {
    return GestureDetector(
      onTap: () => drawState.setDrawMode(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary.withAlpha(30) : Colors.transparent,
          border: Border.all(
            color: active ? AppTheme.primary.withAlpha(60) : Colors.white.withAlpha(15),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: active ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _sizeDot(double size, bool active) {
    return GestureDetector(
      onTap: () => drawState.setPenSize(size),
      child: Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          color: active ? AppTheme.primary.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: active ? Border.all(color: AppTheme.primary, width: 2) : null,
        ),
        child: Center(
          child: Container(
            width: size * 0.8, height: size * 0.8,
            decoration: BoxDecoration(
              color: active ? AppTheme.primary : AppTheme.textMuted,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _colorCircle(Color color, String tooltip) {
    final isActive = drawState._penColor == color && !drawState._eraserMode;
    return GestureDetector(
      onTap: () => drawState.setPenColor(color),
      child: Container(
        width: 22, height: 22,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? Colors.white : color == const Color(0xFF1E293B) ? AppTheme.textMuted : Colors.transparent,
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)] : null,
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, String tooltip, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: active ? AppTheme.error.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: active ? AppTheme.error : AppTheme.textSecondary),
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 20, color: Colors.white.withAlpha(20));
  }
}
