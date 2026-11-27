// DocuCraft — Slide Canvas Widget V3
// Sistem edit teks tunggal: Inline editor + Floating Toolbar
//
// Flow:
//   1. Tap text element → masuk mode editing inline (TextField)
//   2. Toolbar floating muncul di atas keyboard → rich text controls
//   3. Tap outside atau tekan Done → simpan + kembali ke mode view
//   4. Gak perlu bottom sheet, gak perlu double-tap

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/slide.dart';
import '../services/svg_path.dart';
import '../services/template_widget_registry.dart';
import '../themes/app_theme.dart';
import 'chart_editor_panel.dart';
import 'table_editor_panel.dart';

class SlideCanvas extends StatelessWidget {
  final Slide slide;
  final String? selectedElementId;
  final String? editingElementId;
  final bool isSlideSelected;  // ← NEW: slide-level selection
  final Function(String) onElementTap;
  final Function(String, double, double) onElementDragEnd;
  final Function(String, double, double)? onElementResizeEnd;
  final Function(String)? onElementLongPress;
  final Function(String, String)? onContentChange;
  final Function(String, Map<String, dynamic>)? onStyleChange;
  final VoidCallback? onEditingDone;
  final Function(String)? onElementDoubleTap;
  final Function()? onSlideTap;  // ← NEW: slide-level tap handler
  /// Design-to-slide scale (rendered slide width ÷ 1920). Maps the 1920×1080
  /// design space into the slide's actual pixel size so elements always fit
  /// inside the slide (no clipping). The user's zoom is applied OUTSIDE this
  /// widget by EditorCanvasArea's outer `Transform.scale`.
  final double fitScale;
  /// Called when text layout metrics (contentHeight, overflowXPx) are computed.
  /// Allows parent to update the model for accurate QC.
  final void Function(String elementId, {double? contentHeight, double? overflowXPx})? onRenderMetrics;

  const SlideCanvas({
    super.key,
    required this.slide,
    this.selectedElementId,
    this.editingElementId,
    this.isSlideSelected = false,  // ← NEW
    this.fitScale = 1.0,
    required this.onElementTap,
    required this.onElementDragEnd,
    this.onElementResizeEnd,
    this.onElementLongPress,
    this.onContentChange,
    this.onStyleChange,
    this.onEditingDone,
    this.onElementDoubleTap,
    this.onSlideTap,  // ← NEW
    this.onRenderMetrics,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = AppTheme.gradientFor(slide.backgroundGradient);
    final scale = fitScale.clamp(0.01, 8.0);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTap: onSlideTap,  // ← NEW: Handle slide-level tap
        child: Container(
          decoration: BoxDecoration(
            color: gradient[0],
            gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: gradient[0].withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
            border: isSlideSelected
                ? Border.all(color: AppTheme.primary, width: 2)  // ← Visual indicator for selected slide
                : null,
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Template widget — render via TemplateWidgetRegistry (model Presenton):
            // layoutId → widget builder, templateData → content
            // Template di-render sebagai background, elemen tetap di-render di atasnya
            if (TemplateWidgetRegistry.has(slide.layoutId))
              Positioned.fill(
                child: TemplateWidgetRegistry.build(
                  slide.layoutId,
                  slide.templateData,
                )!,
              ),

            // Title + subtitle (only when no template AND no elements)
            if (!TemplateWidgetRegistry.has(slide.layoutId) && slide.elements.isEmpty)
              Positioned(
                top: 16 * scale, left: 20 * scale,
                right: 20 * scale,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(slide.title, style: TextStyle(fontSize: (16 * scale).clamp(8.0, 48.0), fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 4 * scale),
                  Text(slide.subtitle, style: TextStyle(fontSize: (10 * scale).clamp(6.0, 32.0), color: Colors.white.withValues(alpha: 0.7))),
                ]),
              ),

            // Elements — positioned in 1920x1080 design space, scaled
            // SELALU render elemen (meskipun ada template) — elemen AI harus tampil di atas template
            ..._sortedElements.map((el) => _DraggableElement(
              element: el,
              isSelected: el.id == selectedElementId,
              isEditing: el.id == editingElementId,
              scale: scale,
              onTap: () => onElementTap(el.id),
              onLongPress: onElementLongPress != null ? () => onElementLongPress!(el.id) : null,
              onDoubleTap: onElementDoubleTap != null ? () => onElementDoubleTap!(el.id) : null,
              onContentChange: onContentChange,
              onStyleChange: onStyleChange,
              onEditingDone: onEditingDone,
              onDragEnd: (String id, double dx, double dy) {
                final newX = dx.clamp(0.0, 1920 - el.width);
                final newY = dy.clamp(0.0, 1080 - el.height);
                onElementDragEnd(el.id, newX, newY);
              },
              onResizeEnd: onElementResizeEnd != null
                  ? (String id, double w, double h) => onElementResizeEnd!(id, w.clamp(40, 1920), h.clamp(30, 1080))
                  : null,
              onRenderMetrics: onRenderMetrics,
            )),

            // Page indicator
            Positioned(
              bottom: 8 * scale, right: 12 * scale,
              child: Text('#${slide.id.length > 6 ? slide.id.substring(0, 6) : slide.id}',
                style: TextStyle(fontSize: (8 * scale).clamp(5.0, 24.0), color: Colors.white.withValues(alpha: 0.4))),
            ),
          ],
        ),
      ),
    ),
  );
  }

  List<SlideElement> get _sortedElements {
    final elem = List<SlideElement>.from(slide.elements);
    elem.sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return elem;
  }
}

// ── Draggable + Editable Element Widget ──
class _DraggableElement extends StatefulWidget {
  final SlideElement element;
  final bool isSelected;
  final bool isEditing;
  final double scale; // design-to-screen scale factor
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final Function(String, double, double) onDragEnd;
  final Function(String, double, double)? onResizeEnd;
  final Function(String, String)? onContentChange;
  final Function(String, Map<String, dynamic>)? onStyleChange;
  final VoidCallback? onEditingDone;
  final void Function(String elementId, {double? contentHeight, double? overflowXPx})? onRenderMetrics;

  const _DraggableElement({
    required this.element,
    required this.isSelected,
    this.isEditing = false,
    this.scale = 1.0,
    required this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    required this.onDragEnd,
    this.onResizeEnd,
    this.onContentChange,
    this.onStyleChange,
    this.onEditingDone,
    this.onRenderMetrics,
  });

  @override
  State<_DraggableElement> createState() => _DraggableElementState();
}

class _DraggableElementState extends State<_DraggableElement> {
  double _dx = 0, _dy = 0;
  bool _isDragging = false;

  // Resize state
  int? _resizingHandle; // 0-7: tl, tr, bl, br, t, b, l, r
  double _resizeStartW = 0, _resizeStartH = 0, _resizeStartX = 0, _resizeStartY = 0;
  double _resizeDeltaX = 0, _resizeDeltaY = 0;

  late TextEditingController _textCtrl;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.element.content ?? '');
  }

  @override
  void didUpdateWidget(covariant _DraggableElement old) {
    super.didUpdateWidget(old);
    if (!widget.isEditing && old.isEditing != widget.isEditing) {
      // Exited inline-edit mode (via Done button OR tap-outside). Commit any
      // pending text once so edits survive either exit path. Deferred to a
      // post-frame callback because mutating the model here would run during
      // the build phase.
      final text = _textCtrl.text;
      if (text != (widget.element.content ?? '')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onContentChange?.call(widget.element.id, text);
        });
      }
    }
    if (old.element.content != widget.element.content && !widget.isEditing) {
      _textCtrl.text = widget.element.content ?? '';
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTap() {
    if (widget.isEditing) return; // Already editing
    widget.onTap();
  }

  void _onDoubleTap() {
    final el = widget.element;
    // For chart/table, open the inline editor panel directly
    if (el.type == ElementType.chart) {
      ChartEditorPanel.show(context, el);
    } else if (el.type == ElementType.table) {
      TableEditorPanel.show(context, el);
    } else {
      // Fallback to parent handler (text/icon editing)
      widget.onDoubleTap?.call();
    }
  }

  void _finishEditing() {
    final text = _textCtrl.text;
    if (text != (widget.element.content ?? '')) {
      widget.onContentChange?.call(widget.element.id, text);
    }
    widget.onEditingDone?.call();
  }

  void _applyStyle(Map<String, dynamic> updates) {
    widget.onStyleChange?.call(widget.element.id, updates);
  }

  void _toggleBold() {
    final ts = widget.element.textStyle ?? TextStyleData();
    _applyStyle({'fontWeight': ts.fontWeight == 'bold' ? 'normal' : 'bold'});
  }

  void _toggleItalic() {
    final ts = widget.element.textStyle ?? TextStyleData();
    _applyStyle({'fontStyle': ts.fontStyle == 'italic' ? 'normal' : 'italic'});
  }

  void _setFontSize(double size) {
    _applyStyle({'fontSize': size.clamp(8, 72)});
  }

  void _setColor(int c) {
    _applyStyle({'colorValue': c});
  }

  @override
  Widget build(BuildContext context) {
    final el = widget.element;
    final isSelected = widget.isSelected;
    final isEditing = widget.isEditing;
    final scale = widget.scale;

    // Guard: skip elemen dengan dimensi invalid (0/negative) — bisa muncul
    // dari template JSON layout dengan elemen zero-size (spacer, decoration)
    final elW = el.width.isFinite && el.width > 0 ? el.width : 0;
    final elH = el.height.isFinite && el.height > 0 ? el.height : 0;
    if (elW <= 0 || elH <= 0) return const SizedBox.shrink();

    return Positioned(
      left: (el.x + _dx) * scale,
      top: (el.y + _dy) * scale,
      width: max(elW * scale, 40),
      height: max(elH * scale, 30),
      child: GestureDetector(
        onTap: _onTap,
        onDoubleTap: _onDoubleTap,
        onPanStart: isEditing ? null : (_) { setState(() { _isDragging = true; _dx = 0; _dy = 0; }); },
        onPanUpdate: isEditing ? null : (d) {
          final s = widget.scale;
          setState(() { _dx += d.delta.dx / s; _dy += d.delta.dy / s; });
        },
        onPanEnd: isEditing ? null : (_) {
          final nx = (el.x + _dx).clamp(0.0, 1920 - el.width);
          final ny = (el.y + _dy).clamp(0.0, 1080 - el.height);
          widget.onDragEnd(widget.element.id, nx, ny);
          setState(() { _isDragging = false; _dx = 0; _dy = 0; });
        },
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topLeft,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 0,
            maxWidth: double.infinity,
            minHeight: 0,
            maxHeight: double.infinity,
            child: Container(
              width: max(el.width, 40),
              height: max(el.height, 30),
              decoration: BoxDecoration(
                border: isSelected && !isEditing ? Border.all(color: Colors.white, width: 2) : null,
                borderRadius: BorderRadius.circular(4),
                color: _isDragging ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
              ),
              child: Stack(
              // Text is allowed to overflow its box vertically (GenOffice renders
              // it visible — the AI layout leaves slack below). Default Clip.hardEdge
              // would cut the last line(s) off at the box edge ("content terpotong").
              // The slide-level Stack still clips everything to the slide bounds.
              clipBehavior: Clip.none,
              children: [
                if (isEditing && (el.type == ElementType.text || el.type == ElementType.icon))
                  _inlineEditor(el)
                else
                  _staticContent(el),

                // Resize handles (when selected, not editing)
                if (isSelected && !isEditing) ..._resizeHandles(el),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  Widget _inlineEditor(SlideElement el) {
    final ts = el.textStyle ?? TextStyleData();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Floating toolbar (appears above text when editing)
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
            boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 8)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _toolBtn('B', ts.fontWeight == 'bold', _toggleBold),
              _toolBtn('I', ts.fontStyle == 'italic', _toggleItalic),
              _toolSep(),
              _toolBtn('-', false, () => _setFontSize((ts.fontSize - 2).clamp(8, 72))),
              Text('${ts.fontSize.round()}', style: const TextStyle(color: Colors.white, fontSize: 10)),
              _toolBtn('+', false, () => _setFontSize((ts.fontSize + 2).clamp(8, 72))),
              _toolSep(),
              _colorDot(0xFFFFFFFF),
              _colorDot(0xFF6366F1),
              _colorDot(0xFF10B981),
              _colorDot(0xFFEF4444),
              _toolSep(),
              GestureDetector(
                onTap: _finishEditing,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(4)),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        // Text field
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.primary, width: 2),
            ),
            child: TextField(
              controller: _textCtrl,
              focusNode: _focusNode,
              autofocus: true,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(
                color: Color(ts.colorValue),
                fontSize: ts.fontSize,
                fontWeight: ts.fontWeightValue >= 700 ? FontWeight.bold : FontWeight.normal,
                fontStyle: ts.fontStyle == 'italic' ? FontStyle.italic : FontStyle.normal,
                fontFamily: ts.fontFamily,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _toolBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(child: Text(label, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.bold,
          color: active ? Colors.white : AppTheme.textSecondary,
        ))),
      ),
    );
  }

  Widget _toolSep() => Container(width: 1, height: 16, margin: const EdgeInsets.symmetric(horizontal: 2), color: Colors.white.withValues(alpha: 0.15));

  Widget _colorDot(int color) {
    return GestureDetector(
      onTap: () => _setColor(color),
      child: Container(
        width: 16, height: 16,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(color: Color(color), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
      ),
    );
  }

  Widget _staticContent(SlideElement el) {
    switch (el.type) {
      case ElementType.text:
        if (el.verticalRuns != null && el.verticalRuns!.isNotEmpty) {
          return _renderVerticalRuns(el);
        }
        return _renderText(el);
      case ElementType.icon: return _renderIcon(el);
      case ElementType.chart: return _chartWidget(el);
      case ElementType.shape: return _shapeWidget(el);
      case ElementType.image: return _imageWidget(el);
      case ElementType.table: return _tableWidget(el);
      case ElementType.video: return _iconBox(el.content ?? '🎬', 'Video');
      case ElementType.audio: return _iconBox(el.content ?? '🎵', 'Audio');
      case ElementType.draw: return _drawWidget(el);
    }
  }

  Widget _renderIcon(SlideElement el) {
    final content = el.content ?? '⭐';
    final hasColor = el.textStyle?.colorValue != null && el.textStyle!.colorValue != 0xFFFFFFFF;
    final iconColor = hasColor ? Color(el.textStyle!.colorValue) : Colors.white;

    if (content.startsWith('icon:')) {
      // Extract code point: icon:12345
      final parts = content.split(',');
      final codeStr = parts[0].replaceFirst('icon:', '');
      final codePoint = int.tryParse(codeStr);
      if (codePoint != null) {
        // Use string-based unicode to avoid tree-shaking issues on web
        return Center(
          child: Text(
            String.fromCharCode(codePoint),
            style: TextStyle(
              fontSize: el.textStyle?.fontSize ?? 24,
              color: iconColor,
              fontFamily: 'MaterialIcons',
            ),
          ),
        );
      }
    }
    return Center(child: Text(content, style: TextStyle(fontSize: el.textStyle?.fontSize ?? 24, color: iconColor)));
  }

  Widget _renderText(SlideElement el) {
    final ts = el.textStyle ?? TextStyleData();
    final content = el.content ?? 'Tap to edit';
    final richRuns = el.richRuns;
    final hasRich = richRuns != null && richRuns.isNotEmpty;

    // Shared base style: line height / spacing / decoration apply to every span.
    // Per-run color/size/weight live on child spans so mixed runs (stat cards with a
    // huge accent number beside small grey sub-labels) render at their own size
    // instead of being flattened to the first run's.
    final baseStyle = TextStyle(
      letterSpacing: ts.letterSpacing,
      height: ts.lineHeight,
      decoration: ts.textDecoration == 'underline'
          ? TextDecoration.underline
          : ts.textDecoration == 'line-through'
              ? TextDecoration.lineThrough
              : TextDecoration.none,
    );

    // Build the Flutter TextStyle from our TextStyleData (plain-text fallback)
    final textStyle = baseStyle.copyWith(
      color: Color(ts.colorValue),
      fontSize: ts.fontSize,
      fontWeight: ts.fontWeightValue >= 700 ? FontWeight.bold : ts.fontWeightValue >= 500 ? FontWeight.w500 : FontWeight.normal,
      fontStyle: ts.fontStyle == 'italic' ? FontStyle.italic : FontStyle.normal,
      fontFamily: ts.fontFamily,
    );

    // The span used for BOTH measurement and painting — a rich span when the box has
    // mixed styles, otherwise a single-styled span.
    final InlineSpan span = hasRich
        ? TextSpan(
            style: baseStyle,
            children: [
              for (final r in richRuns)
                TextSpan(
                  text: r.text,
                  style: TextStyle(
                    color: Color(r.colorValue),
                    fontSize: r.fontSize,
                    fontWeight: r.fontWeight == 'bold' ? FontWeight.bold : FontWeight.normal,
                    fontStyle: r.fontStyle == 'italic' ? FontStyle.italic : FontStyle.normal,
                    fontFamily: r.fontFamily,
                  ),
                ),
            ],
          )
        : TextSpan(text: content, style: textStyle);

    // Use TextPainter to measure actual laid-out dimensions.
    // This mirrors GenOffice's layout-audit.ts approach: using real contentHeight
    // and overflowXPx instead of heuristic estimates.
    //
    // We perform TWO layout passes:
    // 1. Constrained layout (wrap within the box width) → measures contentHeight
    // 2. Unconstrained layout (maxWidth = double.infinity) → measures natural width for overflowXPx
    return LayoutBuilder(
      builder: (context, constraints) {
        // Text-box insets (from GenOffice) replace the old fixed 4px padding, so
        // text wraps at exactly (box.w − insets.l − insets.r) — matching GenOffice's
        // layout and preventing the re-flowed text from overflowing the box.
        final insetL = ts.insetL;
        final insetT = ts.insetT;
        final insetR = ts.insetR;
        final insetB = ts.insetB;
        final textWidth = max(0.0, constraints.maxWidth - insetL - insetR);

        // Pass 1: Constrained — wraps text at the actual available width
        final tp = TextPainter(
          text: span,
          textDirection: TextDirection.ltr,
          textAlign: _align(ts.textAlign),
          maxLines: null,
        )..layout(maxWidth: textWidth);

        // Pass 2: Unconstrained — measures the widest line without wrapping
        // This tells us if any single line would overflow the box width
        final tp2 = TextPainter(
          text: span,
          textDirection: TextDirection.ltr,
          textAlign: _align(ts.textAlign),
          maxLines: null,
        )..layout(maxWidth: double.infinity);

        // Report actual layout metrics to parent (via callback).
        // contentHeight = the actual laid-out text height (wraps within box width).
        // overflowXPx = the widest single line width minus the box inner width (0 if no overflow).
        // For vertical text, only height matters — overflowXPx stays 0 (handled by genoffice audit).
        final contentHeight = tp.height;
        final overflowXPx = ts.isVertical ? 0.0 : max(0.0, tp2.width - textWidth);

        // Notify parent of layout metrics (use microtask to avoid layout cycle)
        if (widget.onRenderMetrics != null) {
          // Only notify if metrics changed (avoid spamming)
          final needsNotify = ts.contentHeight != contentHeight ||
              ts.overflowXPx != (overflowXPx > 0 ? overflowXPx : null);
          if (needsNotify) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onRenderMetrics!(el.id,
                contentHeight: contentHeight,
                overflowXPx: overflowXPx > 0 ? overflowXPx : null,
              );
            });
          }
        }

        // The Text would otherwise be height-clamped to the box by the Stack's
        // loose constraints and clip its own last line(s). OverflowBox gives it an
        // unbounded height (full natural text height) so text overflows visibly
        // (GenOffice behaviour) instead of being cut off. Its `alignment` maps the
        // bodyPr vertical anchor (top/middle/bottom); the SizedBox(width: textWidth)
        // forces the Text to fill the box width so `textAlign` actually centers /
        // right-aligns lines within the box (a narrow Text would ignore textAlign).
        return Padding(
          padding: EdgeInsets.fromLTRB(insetL, insetT, insetR, insetB),
          child: OverflowBox(
            alignment: _anchorAlignment(ts.anchor),
            minWidth: 0,
            maxWidth: double.infinity,
            minHeight: 0,
            maxHeight: double.infinity,
            child: SizedBox(
              width: max(1.0, textWidth),
              child: Text.rich(span, textAlign: _align(ts.textAlign)),
            ),
          ),
        );
      },
    );
  }

  /// Vertical text (bodyPr vert) — the laid-out glyph runs carry their own
  /// box-relative position + rotation, so we draw them verbatim instead of trying
  /// to re-flow the paragraph (eaVert rotates Latin words per column; vert rotates
  /// the whole block). Rotating the runs here mirrors GenOffice's `glyphToDraw`
  /// (rotation 90° clockwise / -90° counterclockwise around the glyph top-left).
  Widget _renderVerticalRuns(SlideElement el) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final run in el.verticalRuns!)
          Positioned(
            left: run.x,
            top: run.y,
            child: Transform.rotate(
              angle: run.rotate * pi / 180,
              child: Text(
                run.text,
                style: TextStyle(
                  color: Color(run.colorValue),
                  fontSize: run.fontSize,
                  fontWeight: run.fontWeight == 'bold' ? FontWeight.bold : FontWeight.normal,
                  fontStyle: run.fontStyle == 'italic' ? FontStyle.italic : FontStyle.normal,
                  fontFamily: run.fontFamily,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _chartWidget(SlideElement el) {
    final cd = el.chartData;
    if (cd == null) return _placeholder('Chart');
    switch (cd.chartType) {
      case 'pie':
      case 'donut':
        return _pieChart(cd);
      case 'line':
        return _lineChart(cd);
      default:
        return _barChart(cd);
    }
  }

  Widget _barChart(ChartData cd) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.end,
      children: cd.labels.map((l) {
        final idx = cd.labels.indexOf(l);
        return Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 24, child: Stack(alignment: Alignment.bottomCenter, children: [
            for (var d = 0; d < cd.dataSets.length; d++)
              if (cd.dataSets[d].values.length > idx)
                Padding(padding: EdgeInsets.only(bottom: d * 10.0), child: Container(
                  width: 10, height: cd.dataSets[d].values[idx] * 2,
                  decoration: BoxDecoration(color: Color(cd.dataSets[d].colorValue), borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                )),
          ])),
          const SizedBox(height: 4),
          Text(l, style: const TextStyle(color: Colors.white70, fontSize: 7),
            overflow: TextOverflow.ellipsis, maxLines: 2, textAlign: TextAlign.center),
        ]);
      }).toList(),
    );
  }

  Widget _pieChart(ChartData cd) {
    // Take values from first data set for pie
    final ds = cd.dataSets.isNotEmpty ? cd.dataSets.first : ChartDataSet(values: [], label: '');
    final total = ds.values.fold(0.0, (a, b) => a + b);
    if (total == 0 || ds.values.isEmpty) return _placeholder('Pie');

    return LayoutBuilder(builder: (ctx, constraints) {
      final size = constraints.maxWidth < constraints.maxHeight ? constraints.maxWidth : constraints.maxHeight;
      final radius = (size - 10) / 2;
      final center = Offset(size / 2, size / 2);

      return CustomPaint(
        size: Size(size, size),
        painter: _PieChartPainter(
          values: ds.values,
          colors: List.generate(ds.values.length, (i) => Color(cd.dataSets.length > 0 && i < cd.labels.length
              ? cd.dataSets[0].colorValue : 0xFF6366F1)),
          labels: cd.labels,
          isDonut: cd.chartType == 'donut',
          center: center,
          radius: radius,
        ),
      );
    });
  }

  Widget _lineChart(ChartData cd) {
    if (cd.dataSets.isEmpty || cd.labels.isEmpty) return _placeholder('Line');

    return LayoutBuilder(builder: (ctx, constraints) {
      return CustomPaint(
        size: Size(constraints.maxWidth, constraints.maxHeight),
        painter: _LineChartPainter(data: cd),
      );
    });
  }

  Widget _shapeWidget(SlideElement el) {
    final ss = el.shapeStyle ?? ShapeStyleData();
    final borderRadius = ss.shapeType == 'circle' ? BorderRadius.circular(9999) : BorderRadius.circular(ss.borderRadius);
    // Compose the fill's own alpha (8-digit hex, e.g. #2E7DFF14 → a faint glow)
    // with the shape opacity MULTIPLICATIVELY. withValues(alpha: opacity) would
    // REPLACE the alpha and blow the subtle glow up to a fully-opaque blob.
    final baseColor = Color(ss.fillColorValue);
    final color = baseColor.withValues(alpha: (baseColor.a * ss.opacity).clamp(0.0, 1.0));

    // Ellipse/circle — render a true oval via ClipOval, not a rounded stadium.
    if (ss.shapeType == 'circle') {
      return ClipOval(
        child: Container(width: double.infinity, height: double.infinity, color: color),
      );
    }

    // Closed-polygon preset (hexagon/diamond/pentagon/star/arrow…) — clip to the
    // exact point list GenOffice serialized instead of flattening to a plain box.
    if (ss.shapeType == 'polygon' && ss.polygonPoints != null && ss.polygonPoints!.length >= 6) {
      return ClipPath(
        clipper: _PolygonClipper(ss.polygonPoints!),
        child: Container(width: double.infinity, height: double.infinity, color: color),
      );
    }

    // Curved preset (donut/ring/heart/cloud…) — parse the SVG path and clip to it;
    // the outer + reverse-wound inner subpaths punch the hole via nonzero fill.
    if (ss.shapeType == 'path' && ss.pathData != null && ss.pathData!.isNotEmpty) {
      return ClipPath(
        clipper: _SvgPathClipper(ss.pathData!),
        child: Container(width: double.infinity, height: double.infinity, color: color),
      );
    }

    // Diamond = rotated square
    if (ss.shapeType == 'diamond') {
      return Transform.rotate(
        angle: 3.14159 / 4,
        child: Container(width: double.infinity, height: double.infinity,
          decoration: BoxDecoration(
            color: color, borderRadius: borderRadius,
            border: ss.strokeColorValue != null
                ? Border.all(color: Color(ss.strokeColorValue!), width: ss.strokeWidth)
                : null,
          ),
        ),
      );
    }

    // Triangle = CSS-style border hack using ClipPath
    if (ss.shapeType == 'triangle') {
      return ClipPath(
        clipper: _TriangleClipper(),
        child: Container(width: double.infinity, height: double.infinity,
          decoration: BoxDecoration(color: color),
        ),
      );
    }

    // Default rect / hexagon / arrow — all use standard rounded container
    return Container(width: double.infinity, height: double.infinity,
      decoration: BoxDecoration(
        color: color, borderRadius: borderRadius,
        border: ss.strokeColorValue != null
            ? Border.all(color: Color(ss.strokeColorValue!), width: ss.strokeWidth)
            : null,
      ),
    );
  }

  Widget _imageWidget(SlideElement el) {
    final img = el.imageStyle ?? ImageStyleData();
    final src = img.src;
    if (src == null || src.isEmpty) return _iconBox(img.placeholderLabel ?? '🖼', 'Image');
    if (src.startsWith('http')) {
      return ClipRRect(borderRadius: BorderRadius.circular(img.borderRadius),
        child: Image.network(src, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _iconBox(img.placeholderLabel ?? '🖼', 'Image')));
    }
    // Base64 data URI (e.g. "data:image/png;base64,...") — used by workspace/prompt flow
    if (src.startsWith('data:')) {
      try {
        final b64 = src.contains(',') ? src.split(',').last : src;
        final bytes = base64Decode(b64);
        return ClipRRect(borderRadius: BorderRadius.circular(img.borderRadius),
          child: Image.memory(Uint8List.fromList(bytes), fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _iconBox(img.placeholderLabel ?? '🖼', 'Image')));
      } catch (_) {
        return _iconBox(img.placeholderLabel ?? '🖼', 'Image');
      }
    }
    if (kIsWeb) {
      return _iconBox('🌐', 'Image (local)');
    }
    try {
      return ClipRRect(borderRadius: BorderRadius.circular(img.borderRadius),
        child: Image.asset(src, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _iconBox(img.placeholderLabel ?? '🖼', 'Image')));
    } catch (_) {
      return _iconBox(img.placeholderLabel ?? '🖼', 'Image');
    }
  }

  Widget _tableWidget(SlideElement el) {
    final td = el.tableData;
    if (td == null) return _placeholder('Table');
    return Padding(padding: const EdgeInsets.all(2),
      child: Column(children: List.generate(td.rows, (r) => Expanded(
        child: Row(children: List.generate(td.cols, (c) => Expanded(
          child: Container(
            margin: const EdgeInsets.all(1),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            decoration: BoxDecoration(
              color: r == 0 && td.hasHeader
                  ? const Color(0xFF6366F1).withAlpha(180)
                  : r % 2 == 0 ? Colors.white.withAlpha(10) : Colors.white.withAlpha(5),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: Colors.white.withAlpha(15), width: 0.5),
            ),
            child: Center(child: Text(
              r < td.cells.length && c < td.cells[r].length ? td.cells[r][c] : '',
              style: TextStyle(
                fontSize: 10, color: r == 0 && td.hasHeader ? Colors.white : Colors.white70,
                fontWeight: r == 0 && td.hasHeader ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 2)),
          ),
        ))),
      ))),
    );
  }

  Widget _drawWidget(SlideElement el) {
    final dd = el.drawData;
    if (dd == null || dd.strokes.isEmpty) return _placeholder('Draw');
    return GestureDetector(
      onTap: () {
        // Select this element via callback
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: CustomPaint(
          painter: _DrawPainter(strokes: dd.strokes, designWidth: el.width, designHeight: el.height),
          size: Size.infinite,
        ),
      ),
    );
  }

  Widget _placeholder(String label) => Center(child: Container(
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
    child: Center(child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)))));

  Widget _iconBox(String icon, String label) => Container(
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(icon, style: const TextStyle(fontSize: 24)),
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
    ])),
  );

  // ── Resize Handles ──
  List<Widget> _resizeHandles(SlideElement el) {
    const handleSize = 8.0;
    final half = handleSize / 2;
    // Guard: clamp width/height supaya gak ada Positioned dengan koordinat invalid
    final w = el.width.isFinite && el.width > 0 ? el.width : 40.0;
    final h = el.height.isFinite && el.height > 0 ? el.height : 30.0;

    // Build a resize handle GestureDetector
    Widget _handle(int id, double left, double top, String cursor) {
      return Positioned(
        left: left - half,
        top: top - half,
        child: GestureDetector(
          onPanStart: (_) {
            setState(() {
              _resizingHandle = id;
              _resizeStartW = w;
              _resizeStartH = h;
              _resizeStartX = el.x;
              _resizeStartY = el.y;
              _resizeDeltaX = 0;
              _resizeDeltaY = 0;
            });
          },
          onPanUpdate: (d) {
            final s = widget.scale;
            setState(() {
              _resizeDeltaX += d.delta.dx / s;
              _resizeDeltaY += d.delta.dy / s;
            });
          },
          onPanEnd: (_) {
            final handle = _resizingHandle;
            if (handle == null) return;
            double newW = w, newH = h, newX = el.x, newY = el.y;
            final dx = _resizeDeltaX;
            final dy = _resizeDeltaY;

            // Corner handles
            if (handle == 0) { newW -= dx; newH -= dy; newX += dx; newY += dy; } // top-left
            if (handle == 1) { newW += dx; newH -= dy; newY += dy; }             // top-right
            if (handle == 2) { newW -= dx; newH += dy; newX += dx; }             // bottom-left
            if (handle == 3) { newW += dx; newH += dy; }                         // bottom-right
            // Edge handles
            if (handle == 4) { newH -= dy; newY += dy; } // top
            if (handle == 5) { newH += dy; }              // bottom
            if (handle == 6) { newW -= dx; newX += dx; }  // left
            if (handle == 7) { newW += dx; }              // right

            widget.onResizeEnd?.call(el.id, newW.clamp(40, 1920), newH.clamp(30, 1080));
            setState(() {
              _resizingHandle = null;
              _resizeDeltaX = 0;
              _resizeDeltaY = 0;
            });
          },
          child: Container(
            width: handleSize,
            height: handleSize,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppTheme.primary, width: 1.5),
              borderRadius: BorderRadius.circular(1),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 2)],
            ),
          ),
        ),
      );
    }

    return [
      _handle(0, 0, 0, 'nwse'),          // top-left
      _handle(1, w, 0, 'nesw'),           // top-right
      _handle(2, 0, h, 'nesw'),           // bottom-left
      _handle(3, w, h, 'nwse'),           // bottom-right
      _handle(4, w / 2, 0, 'ns'),         // top
      _handle(5, w / 2, h, 'ns'),         // bottom
      _handle(6, 0, h / 2, 'ew'),         // left
      _handle(7, w, h / 2, 'ew'),         // right
    ];
  }

  /// Maps the bodyPr vertical anchor to an OverflowBox alignment (horizontal is
  /// fixed to left — the Text's `textAlign` handles horizontal alignment).
  Alignment _anchorAlignment(String? anchor) {
    switch (anchor) {
      case 'middle':
        return Alignment.centerLeft;
      case 'bottom':
        return Alignment.bottomLeft;
      default:
        return Alignment.topLeft;
    }
  }

  TextAlign _align(String a) {
    switch (a) {
      case 'left': return TextAlign.left;
      case 'center': return TextAlign.center;
      case 'right': return TextAlign.right;
      case 'justify': return TextAlign.justify;
      default: return TextAlign.left;
    }
  }
}

// ── Draw Painter ──
class _DrawPainter extends CustomPainter {
  final List<DrawStroke> strokes;
  final double designWidth, designHeight;
  _DrawPainter({required this.strokes, required this.designWidth, required this.designHeight});
  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      if (s.points.length < 2) continue;
      final path = Path()..moveTo(s.points[0][0], s.points[0][1]);
      for (int i = 1; i < s.points.length; i++) path.lineTo(s.points[i][0], s.points[i][1]);
      canvas.drawPath(path, Paint()
        ..color = Color(s.colorValue)
        ..strokeWidth = s.size
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke);
    }
  }
  @override
  bool shouldRepaint(_DrawPainter old) =>
    old.strokes.length != strokes.length ||
    old.designWidth != designWidth ||
    old.designHeight != designHeight;
}

// ── Pie Chart Painter ──
class _PieChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final List<String> labels;
  final bool isDonut;
  final Offset center;
  final double radius;

  _PieChartPainter({
    required this.values,
    required this.colors,
    required this.labels,
    required this.isDonut,
    required this.center,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (a, b) => a + b);
    if (total == 0) return;

    double startAngle = -3.14159 / 2; // Start from top
    for (var i = 0; i < values.length; i++) {
      final sweepAngle = (values[i] / total) * 2 * 3.14159;
      // Safe color access: use colors[i] if available, else use first color with opacity variation
      final color = i < colors.length ? colors[i] : (colors.isNotEmpty ? colors.first.withValues(alpha: 0.85 - i * 0.08) : Colors.white24);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }

    // Donut: cut out center
    if (isDonut) {
      final holePaint = Paint()
        ..color = const Color(0xFF13131A) // AppTheme.surface2
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius * 0.5, holePaint);
    }

    // Labels around the pie
    startAngle = -3.14159 / 2;
    for (var i = 0; i < values.length; i++) {
      final sweepAngle = (values[i] / total) * 2 * 3.14159;
      final midAngle = startAngle + sweepAngle / 2;
      final labelRadius = radius + 12;
      final labelPos = Offset(
        center.dx + labelRadius * cos(midAngle),
        center.dy + labelRadius * sin(midAngle),
      );

      final tp = TextPainter(
        text: TextSpan(
          text: i < labels.length ? labels[i] : '',
          style: TextStyle(color: Colors.white70, fontSize: 7),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, labelPos - Offset(tp.width / 2, tp.height / 2));

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_PieChartPainter old) => false;
}

// ── Line Chart Painter ──
class _LineChartPainter extends CustomPainter {
  final ChartData data;

  _LineChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final padding = 12.0;
    final chartW = size.width - padding * 2;
    final chartH = size.height - padding * 2;

    final allValues = data.dataSets.expand((ds) => ds.values).toList();
    if (allValues.isEmpty) return;
    final maxVal = allValues.reduce((a, b) => a > b ? a : b);
    if (maxVal <= 0) return;

    // Grid lines
    for (var i = 0; i < 4; i++) {
      final y = padding + chartH * (1 - (i + 1) / 4);
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        Paint()..color = Colors.white.withAlpha(20)..strokeWidth = 0.5,
      );
    }

    // Draw lines per data set
    for (var dsIdx = 0; dsIdx < data.dataSets.length; dsIdx++) {
      final ds = data.dataSets[dsIdx];
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

        // Data point dot
        canvas.drawCircle(Offset(x, y), 3,
          Paint()..color = Color(ds.colorValue)..style = PaintingStyle.fill);
      }

      canvas.drawPath(path, paint);

      // Fill area under line
      final fillPath = Path.from(path)
        ..lineTo(padding + chartW, padding + chartH)
        ..lineTo(padding, padding + chartH)
        ..close();
      canvas.drawPath(fillPath, fillPaint);
    }

    // X-axis labels
    for (var i = 0; i < data.labels.length; i++) {
      final x = padding + (chartW / max(1, data.labels.length - 1)) * i;
      final tp = TextPainter(
        text: TextSpan(text: data.labels[i], style: TextStyle(color: Colors.white54, fontSize: 8)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - padding + 2));
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) => false;
}

// ── Triangle Clipper ──
class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_TriangleClipper oldClipper) => false;
}

// ── Polygon Clipper ──
/// Clips to a closed polygon from GenOffice's flat `[x0,y0,x1,y1,…]` point list
/// (box-local design px). The element box is `el.width × el.height`, so the points
/// map 1:1 into the clip size.
class _PolygonClipper extends CustomClipper<Path> {
  final List<double> points;
  _PolygonClipper(this.points);

  @override
  Path getClip(Size size) {
    final path = Path();
    if (points.length < 6) return path;
    path.moveTo(points[0], points[1]);
    for (int i = 2; i + 1 < points.length; i += 2) {
      path.lineTo(points[i], points[i + 1]);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_PolygonClipper oldClipper) => !listEquals(oldClipper.points, points);
}

// ── SVG Path Clipper ──
/// Clips to a GenOffice SVG path (donut/ring/heart/cloud…). GenOffice's `PathB`
/// only ever emits `M`/`L`/`Q`/`C`/`Z` (arcs are pre-split into cubics), so the
/// parser handles exactly those commands — no `A` arcs, no relative coords.
class _SvgPathClipper extends CustomClipper<Path> {
  final String d;
  _SvgPathClipper(this.d);

  @override
  Path getClip(Size size) => parseSvgPath(d);

  @override
  bool shouldReclip(_SvgPathClipper oldClipper) => oldClipper.d != d;
}
