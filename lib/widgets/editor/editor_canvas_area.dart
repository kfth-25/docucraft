// DocuCraft — Editor Canvas Area
// Diekstrak dari slide_editor_screen.dart demi modularitas

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../models/slide.dart';
import '../../providers/slide_provider.dart';
import '../../widgets/slide_canvas.dart';
import '../../widgets/draw_canvas.dart';
import '../../widgets/grid_view.dart';
import '../../widgets/element_comments.dart';
import '../../themes/app_theme.dart';
import '../../main.dart'; // CollabManager

typedef OnElementTap = void Function(String id);
typedef OnElementDragEnd = void Function(String id, double x, double y);
typedef OnElementResizeEnd = void Function(String id, double w, double h);
typedef OnContentChange = void Function(String id, String content);
typedef OnStyleChange = void Function(String id, Map<String, dynamic> style);
typedef OnEditingDone = void Function();
typedef OnElementDoubleTap = void Function(String id);
typedef OnElementLongPress = void Function(String id);
typedef OnSlideTap = void Function();

class EditorCanvasArea extends StatefulWidget {
  final Slide slide;
  final SlideProvider provider;
  final double zoomLevel;
  final String? selectedElementId;
  final String? editingElementId;
  final String? commentingElementId;
  final TextEditingController elementCommentCtrl;
  final bool drawActive;
  final GlobalKey<DrawCanvasState> drawCanvasKey;
  final VoidCallback onDrawStrokesChanged;
  final OnElementTap onElementTap;
  final OnElementDragEnd onElementDragEnd;
  final OnElementResizeEnd onElementResizeEnd;
  final OnContentChange onContentChange;
  final OnStyleChange onStyleChange;
  final OnEditingDone onEditingDone;
  final OnElementDoubleTap onElementDoubleTap;
  final OnElementLongPress onElementLongPress;
  final OnSlideTap onSlideTap;
  /// Called when text layout metrics (contentHeight, overflowXPx) are computed
  /// during rendering. Allows the parent to update the model for accurate QC.
  final void Function(String elementId, {double? contentHeight, double? overflowXPx})? onRenderMetrics;
  final VoidCallback onCommentSubmit;
  final VoidCallback onCommentCancel;
  final VoidCallback? onElementAISketch;
  final VoidCallback onGridViewTap;
  final Function(double) onZoomChanged;

  const EditorCanvasArea({
    super.key,
    required this.slide,
    required this.provider,
    required this.zoomLevel,
    required this.selectedElementId,
    required this.editingElementId,
    required this.commentingElementId,
    required this.elementCommentCtrl,
    required this.drawActive,
    required this.drawCanvasKey,
    required this.onDrawStrokesChanged,
    required this.onElementTap,
    required this.onElementDragEnd,
    required this.onElementResizeEnd,
    required this.onContentChange,
    required this.onStyleChange,
    required this.onEditingDone,
    required this.onElementDoubleTap,
    required this.onElementLongPress,
    required this.onSlideTap,
    this.onRenderMetrics,
    required this.onCommentSubmit,
    required this.onCommentCancel,
    this.onElementAISketch,
    required this.onGridViewTap,
    required this.onZoomChanged,
  });

  @override
  State<EditorCanvasArea> createState() => _EditorCanvasAreaState();
}

class _EditorCanvasAreaState extends State<EditorCanvasArea> {
  String? _currentSlideId;
  // Auto-fit flag: fits the 1920×1080 design space to the viewport once, on first
  // build and whenever the slide changes (e.g. a fresh AI deck is applied). Mirrors
  // GenOffice's needsFitRef → fitZoom = min(availW/widthPx, availH/heightPx).
  bool _needsFit = true;

  static const double _zoomStep = 0.1;
  static const double _minZoom = 0.1;
  static const double _maxZoom = 3.0;

  @override
  void initState() {
    super.initState();
    _currentSlideId = widget.slide.id;
  }

  void _changeZoom(double newZoom) {
    widget.onZoomChanged(newZoom.clamp(_minZoom, _maxZoom));
  }

  void _zoomIn() => _changeZoom(widget.zoomLevel + _zoomStep);
  void _zoomOut() => _changeZoom(widget.zoomLevel - _zoomStep);
  void _zoomReset() => _changeZoom(1.0);
  // "Fit" re-runs the viewport fit (computed in the LayoutBuilder below), matching
  // GenOffice's fit-to-screen rather than a hardcoded 100%.
  void _zoomFit() => setState(() => _needsFit = true);

  @override
  void didUpdateWidget(EditorCanvasArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.slide.id != _currentSlideId) {
      if (oldWidget.slide.id == _currentSlideId) {
        widget.drawCanvasKey.currentState?.saveStrokesToMap(oldWidget.slide.drawStrokes);
      }
      widget.drawCanvasKey.currentState?.loadStrokesFromMap(widget.slide.drawStrokes);
      _currentSlideId = widget.slide.id;
      // New slide (fresh AI deck applied via replaceAll) → re-fit to viewport.
      _needsFit = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zoom control bar
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _zoomFit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: widget.zoomLevel <= 0.55 ? AppTheme.primary.withAlpha(40) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Fit', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove, size: 16, color: AppTheme.textSecondary),
                  onPressed: _zoomOut,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
                Text('${(widget.zoomLevel * 100).round()}%',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                Expanded(
                  child: Slider(
                    value: widget.zoomLevel,
                    min: 0.1,
                    max: 2.0,
                    divisions: 19,
                    activeColor: AppTheme.primary,
                    inactiveColor: AppTheme.surface3,
                    onChanged: (v) => _changeZoom(v),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 16, color: AppTheme.textSecondary),
                  onPressed: _zoomIn,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
                GestureDetector(
                  onTap: _zoomReset,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: (widget.zoomLevel >= 0.95 && widget.zoomLevel <= 1.05) ? AppTheme.primary.withAlpha(40) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('100%', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                  ),
                ),
              ],
            ),
          ),
          // Canvas — responsive
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final slideW = constraints.maxWidth;
                final slideH = slideW * 9 / 16;
                final maxH = constraints.maxHeight;
                final finalW = slideH > maxH ? maxH * 16 / 9 : slideW;
                final finalH = slideH > maxH ? maxH : slideH;

                // Auto-fit: SlideCanvas maps the 1920×1080 design space into the
                // rendered slide size internally (fitScale = finalW/1920), and this
                // outer Transform.scale(zoomLevel) is the ONLY zoom. So 1.0 = fit-to-screen.
                final fitZoom = 1.0;
                if (_needsFit) {
                  _needsFit = false;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) widget.onZoomChanged(fitZoom);
                  });
                }

                // Hitung ukuran tampilan berdasarkan zoom
                final displayW = finalW * widget.zoomLevel;
                final displayH = finalH * widget.zoomLevel;

                return Center(
                  child: ClipRect(
                    child: SizedBox(
                      width: finalW,
                      height: finalH,
                      child: Transform.scale(
                        scale: widget.zoomLevel,
                        alignment: Alignment.topCenter,
                        child: RepaintBoundary(
                          child: SizedBox(
                            width: finalW,
                            height: finalH,
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                SlideCanvas(
                                  slide: widget.slide,
                                  fitScale: finalW / 1920,
                                  selectedElementId: widget.selectedElementId,
                                  editingElementId: widget.editingElementId,
                                  isSlideSelected: widget.provider.selectedSlideId == widget.slide.id,
                                  onElementTap: widget.onElementTap,
                                  onElementDragEnd: widget.onElementDragEnd,
                                  onElementResizeEnd: widget.onElementResizeEnd,
                                  onContentChange: widget.onContentChange,
                                  onStyleChange: widget.onStyleChange,
                                  onEditingDone: widget.onEditingDone,
                                  onElementDoubleTap: widget.onElementDoubleTap,
                                  onElementLongPress: widget.onElementLongPress,
                                  onSlideTap: widget.onSlideTap,
                                  onRenderMetrics: widget.onRenderMetrics,
                                ),
                                // Always render DrawCanvas so setActive() works immediately
                                // Visibility controlled by IgnorePointer inside DrawCanvas
                                Positioned.fill(
                                  child: IgnorePointer(
                                    ignoring: !widget.drawActive,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: widget.drawActive ? Colors.white.withValues(alpha: 0.02) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: widget.drawActive ? Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 1) : null,
                                      ),
                                      child: DrawCanvas(
                                        key: widget.drawCanvasKey,
                                        canvasSize: Size(finalW, finalH),
                                        onStrokeChanged: widget.onDrawStrokesChanged,
                                        isActive: widget.drawActive,
                                      ),
                                    ),
                                  ),
                                ),
                                if (widget.slide.hidden)
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      child: const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.visibility_off, color: Colors.white54, size: 32),
                                            SizedBox(height: 8),
                                            Text('Slide tersembunyi', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                            Text('Tap "Tampil" untuk menampilkan', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: 8 * widget.zoomLevel,
                                  left: 8 * widget.zoomLevel,
                                  child: GestureDetector(
                                    onTap: widget.onGridViewTap,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: AppTheme.surface3,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.grid_view_rounded, size: 14, color: AppTheme.textSecondary),
                                    ),
                                  ),
                                ),
                                if (widget.commentingElementId != null)
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    right: 8,
                                    child: FloatingCommentInput(
                                      elementId: widget.commentingElementId!,
                                      controller: widget.elementCommentCtrl,
                                      onSend: widget.onCommentSubmit,
                                      onCancel: widget.onCommentCancel,
                                      onAISketch: widget.onElementAISketch,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
