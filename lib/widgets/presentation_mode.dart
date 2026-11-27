// DocuCraft — Presentation Mode (Fullscreen Presenter)
// Terinspirasi PresentationMode.tsx milik Presenton (fullscreen, keyboard nav, speaker notes, auto-hide chrome)
//
// Fitur:
//   - Overlay fullscreen dengan semua elemen dirender (teks, chart, gambar, shape, dll.)
//   - Navigasi touch/swipe (kiri/kanan)
//   - Navigasi keyboard (panah, Home, End, Esc)
//   - Overlay speaker notes (toggle dengan "N" atau tap)
//   - Auto-hide kontrol chrome setelah 5 detik
//   - Progress bar slide + indikator jumlah
// @see skills/workflows/export-pptx.md
// @see skills/SKILL.md
//   - Background gradient per slide

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/slide.dart';
import '../providers/slide_provider.dart';
import '../themes/app_theme.dart';

/// Fullscreen presentation mode — stand-alone screen
class PresentationScreen extends StatefulWidget {
  final int initialSlideIndex;

  const PresentationScreen({
    super.key,
    this.initialSlideIndex = 0,
  });

  /// Push to navigator and start presentation
  static void start(BuildContext context, {int initialSlideIndex = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PresentationScreen(initialSlideIndex: initialSlideIndex),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<PresentationScreen> createState() => _PresentationScreenState();
}

class _PresentationScreenState extends State<PresentationScreen>
    with SingleTickerProviderStateMixin {
  late int _currentSlide;
  bool _chromeVisible = true;
  bool _speakerNotesVisible = false;
  Timer? _chromeTimer;
  Timer? _doubleTapTimer;
  int _tapCount = 0;
  int _lastTapTime = 0;

  // Animation for slide transitions
  late AnimationController _slideAnimController;
  late Animation<double> _slideAnim;
  // Per-slide transition effect (from slide.extra['transition'])
  String _lastSlideTransition = 'fade';
  int _lastTransitionSlideIndex = -1;

  // Drag/swipe detection
  double _dragStartX = 0;
  bool _isDragging = false;

  static const _chromeHideDelay = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _currentSlide = widget.initialSlideIndex;
    _slideAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = CurvedAnimation(
      parent: _slideAnimController,
      curve: Curves.easeInOut,
    );
    _startChromeTimer();

    // Lock to landscape if on mobile
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Hide system UI for true fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _chromeTimer?.cancel();
    _doubleTapTimer?.cancel();
    _slideAnimController.dispose();
    // Restore portrait orientation
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startChromeTimer() {
    _chromeTimer?.cancel();
    _chromeTimer = Timer(_chromeHideDelay, () {
      if (mounted) {
        setState(() {
          _chromeVisible = false;
          _speakerNotesVisible = false;
        });
      }
    });
  }

  void _bumpChrome() {
    setState(() {
      _chromeVisible = true;
    });
    _startChromeTimer();
  }

  void _goToSlide(int index, SlideProvider provider) {
    if (index < 0 || index >= provider.slides.length) return;
    // Read transition from slide extra (set by TransitionPanel)
    final nextSlide = provider.slides[index];
    final transition = nextSlide.extra?['transition'] as String? ?? 'fade';
    if (transition != _lastSlideTransition || _lastTransitionSlideIndex != index) {
      _lastSlideTransition = transition;
      _lastTransitionSlideIndex = index;
    }
    setState(() {
      _currentSlide = index;
    });
    _slideAnimController.forward(from: 0);
  }

  void _nextSlide(SlideProvider provider) {
    if (_currentSlide < provider.slides.length - 1) {
      _goToSlide(_currentSlide + 1, provider);
    }
  }

  void _prevSlide(SlideProvider provider) {
    if (_currentSlide > 0) {
      _goToSlide(_currentSlide - 1, provider);
    }
  }

  void _toggleSpeakerNotes() {
    setState(() {
      _speakerNotesVisible = !_speakerNotesVisible;
    });
    if (_speakerNotesVisible) {
      _chromeVisible = true;
      _chromeTimer?.cancel(); // keep chrome visible while notes are shown
    } else {
      _startChromeTimer();
    }
  }

  void _exitPresentation() {
    Navigator.of(context).pop();
  }

  // ── Keyboard handler ──
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final provider = context.read<SlideProvider>();

    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.pageDown ||
        event.logicalKey == LogicalKeyboardKey.space) {
      _nextSlide(provider);
      _bumpChrome();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.pageUp) {
      _prevSlide(provider);
      _bumpChrome();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.home) {
      _goToSlide(0, provider);
      _bumpChrome();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.end) {
      _goToSlide(provider.slides.length - 1, provider);
      _bumpChrome();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _exitPresentation();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyF &&
        event is KeyDownEvent) {
      // Toggle fullscreen (already immersive, just bump chrome)
      _bumpChrome();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyN &&
        event is KeyDownEvent) {
      _toggleSpeakerNotes();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SlideProvider>(
      builder: (ctx, provider, _) {
        if (provider.slides.isEmpty) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text('No slides', style: TextStyle(color: Colors.white54, fontSize: 18)),
            ),
          );
        }

        final currentSlide = provider.slides[_currentSlide.clamp(0, provider.slides.length - 1)];
        final totalSlides = provider.slides.length;
        final progress = (_currentSlide + 1) / totalSlides;
        final notes = currentSlide.extra?['notes'] as String? ?? '';

        return Scaffold(
          backgroundColor: Colors.black,
          body: Focus(
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: GestureDetector(
              onTap: () {
                _bumpChrome();
                // Double-tap → toggle speaker notes
                final now = DateTime.now().millisecondsSinceEpoch;
                if (now - _lastTapTime < 300) {
                  _toggleSpeakerNotes();
                  _tapCount = 0;
                } else {
                  _tapCount = 1;
                  _lastTapTime = now;
                }
              },
              onHorizontalDragStart: (details) {
                _dragStartX = details.globalPosition.dx;
                _isDragging = true;
              },
              onHorizontalDragUpdate: (details) {
                // Visual feedback could go here
              },
              onHorizontalDragEnd: (details) {
                if (!_isDragging) return;
                _isDragging = false;
                final dx = details.globalPosition.dx - _dragStartX;
                if (dx.abs() < 50) return; // threshold
                if (dx > 0) {
                  _prevSlide(provider);
                } else {
                  _nextSlide(provider);
                }
                _bumpChrome();
              },
              child: Stack(
                children: [
                  // ── Slide Content ──
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _slideAnim,
                      builder: (ctx, child) {
                        final t = _lastSlideTransition;
                        final animVal = _slideAnim.value;

                        // Apply transition effect based on selection
                        Widget slideContent = child!;

                        if (t == 'fade' || t == 'dissolve') {
                          slideContent = Opacity(
                            opacity: max(0.0, 1.0 - animVal * 0.15),
                            child: child,
                          );
                        } else if (t == 'slide' || t == 'slide-left') {
                          slideContent = Transform.translate(
                            offset: Offset(animVal * 200, 0),
                            child: Opacity(
                              opacity: max(0.0, 1.0 - animVal * 0.2),
                              child: child,
                            ),
                          );
                        } else if (t == 'slide-right') {
                          slideContent = Transform.translate(
                            offset: Offset(-animVal * 200, 0),
                            child: Opacity(
                              opacity: max(0.0, 1.0 - animVal * 0.2),
                              child: child,
                            ),
                          );
                        } else if (t == 'scale') {
                          // Scale IN: starts small → grows to full size
                          final scaleVal = max(0.75, 1.0 - (1.0 - animVal) * 0.25);
                          slideContent = Transform.scale(
                            scale: scaleVal,
                            child: Opacity(
                              opacity: max(0.0, animVal),
                              child: child,
                            ),
                          );
                        } else if (t == 'zoom') {
                          // Zoom IN: starts large → shrinks to normal size
                          final scaleVal = 1.0 + (1.0 - animVal) * 0.25;
                          slideContent = Transform.scale(
                            scale: scaleVal,
                            child: Opacity(
                              opacity: max(0.0, animVal),
                              child: child,
                            ),
                          );
                        } else if (t == 'push') {
                          slideContent = Transform.translate(
                            offset: Offset(animVal * 300, 0),
                            child: child,
                          );
                        } else {
                          // Default: simple fade
                          slideContent = Opacity(
                            opacity: max(0.0, 1.0 - animVal * 0.1),
                            child: child,
                          );
                        }

                        return slideContent;
                      },
                      child: FullScreenSlide(slide: currentSlide),
                    ),
                  ),

                  // ── Left/Right tap zones (for single-tap navigation) ──
                  if (_chromeVisible)
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _prevSlide(provider);
                              _bumpChrome();
                            },
                            behavior: HitTestBehavior.opaque,
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _nextSlide(provider);
                              _bumpChrome();
                            },
                            behavior: HitTestBehavior.opaque,
                          ),
                        ),
                      ],
                    ),

                  // ── Speaker Notes (overlay from bottom) ──
                  if (_speakerNotesVisible && notes.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.95),
                              Colors.black.withValues(alpha: 0.85),
                              Colors.black.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.record_voice_over, size: 16, color: Colors.white.withValues(alpha: 0.6)),
                                const SizedBox(width: 8),
                                Text(
                                  'SPEAKER NOTES',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              notes,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── Chrome Controls (auto-hide) ──
                  AnimatedOpacity(
                    opacity: _chromeVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: _buildChromeBar(currentSlide, totalSlides, progress, notes, provider),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChromeBar(
    Slide currentSlide, int totalSlides, double progress, String notes, SlideProvider provider,
  ) {
    return Column(
      children: [
        // ── Top chrome (transparent) ──
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Container(),
        ),

        // ── Bottom chrome bar ──
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress bar
              Container(
                height: 3,
                color: Colors.white.withValues(alpha: 0.15),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, Color(0xFFA855F7)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Control bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
                child: Row(
                  children: [
                    // Slide count
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Text(
                        '${_currentSlide + 1} / $totalSlides',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Speaker notes toggle
                    if (notes.isNotEmpty)
                      GestureDetector(
                        onTap: _toggleSpeakerNotes,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _speakerNotesVisible
                                ? AppTheme.primary.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _speakerNotesVisible
                                  ? AppTheme.primary.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.record_voice_over,
                                size: 14,
                                color: _speakerNotesVisible ? AppTheme.primary : Colors.white.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Notes',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _speakerNotesVisible ? AppTheme.primary : Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const Spacer(),

                    // Navigation buttons
                    GestureDetector(
                      onTap: () => _prevSlide(provider),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Exit button
                    GestureDetector(
                      onTap: _exitPresentation,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),

                    const SizedBox(width: 12),

                    GestureDetector(
                      onTap: () => _nextSlide(provider),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Full-screen slide renderer ──
// Renders the slide using the same element rendering logic as SlideCanvas
// but full-screen sized, no drag handles, no selection borders.
class FullScreenSlide extends StatelessWidget {
  final Slide slide;

  const FullScreenSlide({required this.slide});

  @override
  Widget build(BuildContext context) {
    final gradient = AppTheme.gradientFor(slide.backgroundGradient);

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaleX = constraints.maxWidth / 1920;
        final scaleY = constraints.maxHeight / 1080;
        final scale = min(scaleX, scaleY);
        final offsetX = (constraints.maxWidth - 1920 * scale) / 2;
        final offsetY = (constraints.maxHeight - 1080 * scale) / 2;

        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // ── Default Title (centered if no elements) ──
              if (slide.elements.where((e) => e.type == ElementType.text).isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 60 * scale),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: min(48, 48 * scale * 1.5),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        if (slide.subtitle.isNotEmpty) ...[
                          SizedBox(height: 16 * scale),
                          Text(
                            slide.subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: min(22, 22 * scale * 1.5),
                              color: Colors.white.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // ── All elements positioned absolutely ──
              ..._buildElements(scale, offsetX, offsetY),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildElements(double scale, double offsetX, double offsetY) {
    final sorted = List<SlideElement>.from(slide.elements);
    sorted.sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return sorted.map((el) {
      return Positioned(
        left: offsetX + el.x * scale,
        top: offsetY + el.y * scale,
        width: el.width * scale,
        height: el.height * scale,
        child: _renderElement(el, scale),
      );
    }).toList();
  }

  Widget _renderElement(SlideElement el, double scale) {
    switch (el.type) {
      case ElementType.text:
        return _renderText(el, scale);
      case ElementType.icon:
        return _renderIcon(el, scale);
      case ElementType.shape:
        return _renderShape(el, scale);
      case ElementType.image:
        return _renderImage(el, scale);
      case ElementType.chart:
        return _renderChart(el, scale);
      case ElementType.table:
        return _renderTable(el, scale);
      case ElementType.video:
      case ElementType.audio:
        return _placeholder(el.content ?? '🎬', scale);
      case ElementType.draw:
        return _renderDraw(el, scale);
    }
  }

  Widget _renderText(SlideElement el, double scale) {
    final ts = el.textStyle ?? TextStyleData();
    final align = _parseAlign(ts.textAlign);
    return Padding(
      padding: EdgeInsets.all(4 * scale),
      child: Text(
        el.content ?? '',
        style: TextStyle(
          color: Color(ts.colorValue),
          fontSize: max(10, ts.fontSize * scale * 1.2),
          fontWeight: _fontWeight(ts.fontWeightValue),
          fontStyle: ts.fontStyle == 'italic' ? FontStyle.italic : FontStyle.normal,
          fontFamily: ts.fontFamily,
          letterSpacing: ts.letterSpacing,
          height: ts.lineHeight,
          decoration: ts.textDecoration == 'underline'
              ? TextDecoration.underline
              : ts.textDecoration == 'line-through'
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
        ),
        textAlign: align,
        overflow: TextOverflow.clip,
      ),
    );
  }

  Widget _renderIcon(SlideElement el, double scale) {
    final content = el.content ?? '⭐';
    final hasColor = el.textStyle?.colorValue != null && el.textStyle!.colorValue != 0xFFFFFFFF;
    final iconColor = hasColor ? Color(el.textStyle!.colorValue) : Colors.white;

    if (content.startsWith('icon:')) {
      final parts = content.split(',');
      final codeStr = parts[0].replaceFirst('icon:', '');
      final codePoint = int.tryParse(codeStr);
      if (codePoint != null) {
        return Center(
          child: Text(
            String.fromCharCode(codePoint),
            style: TextStyle(
              fontSize: max(16, (el.textStyle?.fontSize ?? 36) * scale * 1.2),
              color: iconColor,
              fontFamily: 'MaterialIcons',
            ),
          ),
        );
      }
    }
    return Center(
      child: Text(
        content,
        style: TextStyle(
          fontSize: max(16, (el.textStyle?.fontSize ?? 36) * scale * 1.2),
          color: iconColor,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _renderShape(SlideElement el, double scale) {
    final ss = el.shapeStyle ?? ShapeStyleData();
    return Container(
      decoration: BoxDecoration(
        color: Color(ss.fillColorValue).withValues(alpha: ss.opacity),
        borderRadius: BorderRadius.circular(ss.borderRadius * scale),
        border: ss.strokeColorValue != null
            ? Border.all(
                color: Color(ss.strokeColorValue!),
                width: max(0.5, ss.strokeWidth * scale),
              )
            : null,
      ),
    );
  }

  Widget _renderImage(SlideElement el, double scale) {
    final img = el.imageStyle ?? ImageStyleData();
    final borderRadius = img.borderRadius * scale;

    Widget imageWidget;
    if (img.src != null && img.src!.isNotEmpty) {
      if (img.src!.startsWith('http')) {
        imageWidget = Image.network(
          img.src!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholderIcon(img.placeholderLabel ?? '🖼', scale),
        );
      } else if (img.src!.startsWith('assets/')) {
        imageWidget = Image.asset(
          img.src!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholderIcon(img.placeholderLabel ?? '🖼', scale),
        );
      } else {
        imageWidget = _placeholderIcon(img.placeholderLabel ?? '🖼', scale);
      }
    } else {
      imageWidget = _placeholderIcon(img.placeholderLabel ?? '🖼', scale);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Opacity(
        opacity: img.opacity,
        child: imageWidget,
      ),
    );
  }

  Widget _renderChart(SlideElement el, double scale) {
    final cd = el.chartData;
    if (cd == null) return _placeholder('Chart', scale);

    switch (cd.chartType) {
      case 'bar':
        return _renderBarChart(cd, scale);
      case 'line':
        return _renderLineChart(cd, scale);
      case 'pie':
      case 'donut':
        return _renderPieChart(cd, scale);
      default:
        return _renderBarChart(cd, scale);
    }
  }

  Widget _renderBarChart(ChartData cd, double scale) {
    return Padding(
      padding: EdgeInsets.all(8 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Chart title
          Text(
            cd.dataSets.map((ds) => ds.label).join(' · '),
            style: TextStyle(
              fontSize: max(10, 14 * scale),
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 8 * scale),
          // Bars
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < cd.labels.length; i++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Stacked bar groups
                        SizedBox(
                          height: 120 * scale,
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              for (var dsIdx = 0; dsIdx < cd.dataSets.length; dsIdx++)
                                if (i < cd.dataSets[dsIdx].values.length)
                                  Padding(
                                    padding: EdgeInsets.only(bottom: dsIdx * 18 * scale),
                                    child: Container(
                                      width: 16 * scale,
                                      height: (cd.dataSets[dsIdx].values[i] / 100) * 100 * scale,
                                      decoration: BoxDecoration(
                                        color: Color(cd.dataSets[dsIdx].colorValue),
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(3 * scale),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color(cd.dataSets[dsIdx].colorValue).withValues(alpha: 0.4),
                                            blurRadius: 4 * scale,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                        SizedBox(height: 4 * scale),
                        Text(
                          cd.labels[i],
                          style: TextStyle(
                            fontSize: max(8, 10 * scale),
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderPieChart(ChartData cd, double scale) {
    final ds = cd.dataSets.isNotEmpty ? cd.dataSets.first : ChartDataSet(values: [], label: '');
    final total = ds.values.fold(0.0, (a, b) => a + b);
    if (total == 0 || ds.values.isEmpty) return _placeholder('Pie', scale);
    final isDonut = cd.chartType == 'donut';
    return Padding(
      padding: EdgeInsets.all(8 * scale),
      child: CustomPaint(
        size: Size.infinite,
        painter: _FullScreenPiePainter(
          data: cd, total: total, isDonut: isDonut, scale: scale,
        ),
      ),
    );
  }

  Widget _renderLineChart(ChartData cd, double scale) {
    return Padding(
      padding: EdgeInsets.all(8 * scale),
      child: CustomPaint(
        painter: _FullScreenLineChartPainter(
          cd,
          scale: scale,
        ),
        size: Size.infinite,
      ),
    );
  }

  Widget _renderTable(SlideElement el, double scale) {
    final td = el.tableData;
    if (td == null) return _placeholder('Table', scale);
    return Padding(
      padding: EdgeInsets.all(2 * scale),
      child: Column(
        children: [
          for (var r = 0; r < td.rows; r++)
            Expanded(
              child: Row(
                children: [
                  for (var c = 0; c < td.cols; c++)
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.all(1 * scale),
                        padding: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 2 * scale),
                        decoration: BoxDecoration(
                          color: r == 0 && td.hasHeader
                              ? const Color(0xFF6366F1).withAlpha(180)
                              : r % 2 == 0 ? Colors.white.withAlpha(10) : Colors.white.withAlpha(5),
                          borderRadius: BorderRadius.circular(2 * scale),
                          border: Border.all(color: Colors.white.withAlpha(15), width: 0.5),
                        ),
                        child: Center(
                          child: Text(
                            r < td.cells.length && c < td.cells[r].length
                                ? td.cells[r][c]
                                : '',
                            style: TextStyle(
                              fontSize: max(8, 11 * scale),
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: r == 0 && td.hasHeader ? FontWeight.bold : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _renderDraw(SlideElement el, double scale) {
    final dd = el.drawData;
    if (dd == null || dd.strokes.isEmpty) return _placeholder('Draw', scale);
    return CustomPaint(
      painter: _FullScreenDrawPainter(
        strokes: dd.strokes,
        scale: scale,
        designWidth: el.width,
        designHeight: el.height,
      ),
      size: Size.infinite,
    );
  }

  Widget _placeholder(String label, double scale) {
    return Center(
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: max(10, 14 * scale),
        ),
      ),
    );
  }

  Widget _placeholderIcon(String icon, double scale) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: Text(
          icon,
          style: TextStyle(fontSize: max(16, 28 * scale)),
        ),
      ),
    );
  }

  TextAlign _parseAlign(String align) {
    switch (align) {
      case 'left': return TextAlign.left;
      case 'center': return TextAlign.center;
      case 'right': return TextAlign.right;
      case 'justify': return TextAlign.justify;
      default: return TextAlign.left;
    }
  }

  FontWeight _fontWeight(int weight) {
    switch (weight) {
      case 100: return FontWeight.w100;
      case 200: return FontWeight.w200;
      case 300: return FontWeight.w300;
      case 400: return FontWeight.w400;
      case 500: return FontWeight.w500;
      case 600: return FontWeight.w600;
      case 700: return FontWeight.w700;
      case 800: return FontWeight.w800;
      case 900: return FontWeight.w900;
      default: return FontWeight.w400;
    }
  }
}

// ── Line Chart Painter ──
class _FullScreenLineChartPainter extends CustomPainter {
  final ChartData data;
  final double scale;

  _FullScreenLineChartPainter(this.data, {required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final allValues = data.dataSets.expand((ds) => ds.values).toList();
    if (allValues.isEmpty) return;
    final maxVal = allValues.reduce((a, b) => a > b ? a : b);
    if (maxVal <= 0) return;

    const padding = 20.0;
    final chartW = size.width - padding * 2;
    final chartH = size.height - padding * 2;

    // Draw grid lines
    for (var i = 0; i < 4; i++) {
      final y = padding + chartH * (1 - (i + 1) / 4);
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.08)
          ..strokeWidth = 0.5,
      );
    }

    for (var dsIdx = 0; dsIdx < data.dataSets.length; dsIdx++) {
      final ds = data.dataSets[dsIdx];
      if (ds.values.length < 2) continue;

      final paint = Paint()
        ..color = Color(ds.colorValue)
        ..strokeWidth = 2.5 * scale
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final fillPaint = Paint()
        ..color = Color(ds.colorValue).withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;

      final path = Path();
      final stepX = chartW / (ds.values.length - 1);

      for (var i = 0; i < ds.values.length; i++) {
        final x = padding + i * stepX;
        final y = padding + chartH * (1 - ds.values[i] / maxVal);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }

        // Draw data point dot
        canvas.drawCircle(
          Offset(x, y),
          3 * scale,
          Paint()
            ..color = Color(ds.colorValue)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          Offset(x, y),
        4 * scale,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }

      canvas.drawPath(path, paint);

      // Fill area under line
      final fillPath = Path.from(path);
      fillPath.lineTo(padding + chartW, padding + chartH);
      fillPath.lineTo(padding, padding + chartH);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
    }

    // Draw X-axis labels
    for (var i = 0; i < data.labels.length; i++) {
      final x = padding + (chartW / max(1, data.labels.length - 1)) * i;
      final tp = TextPainter(
        text: TextSpan(
          text: data.labels[i],
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9 * scale),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - padding + 4));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ── Draw Painter ──
class _FullScreenDrawPainter extends CustomPainter {
  final List<DrawStroke> strokes;
  final double scale;
  final double designWidth;
  final double designHeight;

  _FullScreenDrawPainter({
    required this.strokes,
    required this.scale,
    required this.designWidth,
    required this.designHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sX = size.width / designWidth;
    final sY = size.height / designHeight;

    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = Color(stroke.colorValue)
        ..strokeWidth = max(1.0, stroke.size * scale * 1.5)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path();
      path.moveTo(stroke.points[0][0] * sX, stroke.points[0][1] * sY);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i][0] * sX, stroke.points[i][1] * sY);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FullScreenDrawPainter oldDelegate) => true;
}

// ── Full-Screen Pie Chart Painter ──
class _FullScreenPiePainter extends CustomPainter {
  final ChartData data;
  final double total;
  final bool isDonut;
  final double scale;

  _FullScreenPiePainter({
    required this.data,
    required this.total,
    required this.isDonut,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0 || data.dataSets.isEmpty) return;

    final ds = data.dataSets.first;
    final centerX = size.width / 2;
    final centerY = size.height * 0.45;
    final radius = min(size.width, size.height) * 0.38;

    double startAngle = -pi / 2;
    for (var i = 0; i < ds.values.length; i++) {
      if (ds.values[i] <= 0) continue;
      final sweepAngle = (ds.values[i] / total) * 2 * pi;
      // Safe color: use ds.colorValue with opacity variation, not data.labels/dataSets index
      final color = Color(ds.colorValue).withValues(alpha: max(0.2, 0.85 - i * 0.08));

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Label
      final midAngle = startAngle + sweepAngle / 2;
      final labelR = radius * 0.65;
      final lx = centerX + labelR * cos(midAngle);
      final ly = centerY + labelR * sin(midAngle);
      final pct = ((ds.values[i] / total) * 100).round();
      final tp = TextPainter(
        text: TextSpan(
          text: pct > 5 ? '$pct%' : '',
          style: TextStyle(
            color: Colors.white,
            fontSize: max(10, 12 * scale),
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));

      startAngle += sweepAngle;
    }

    // Donut hole
    if (isDonut) {
      canvas.drawCircle(
        Offset(centerX, centerY),
        radius * 0.48,
        Paint()..color = const Color(0xFF13131A),
      );
    }

    // Legend
    final legendY = size.height * 0.82;
    final legendX = size.width * 0.1;
    for (var i = 0; i < min(ds.values.length, 6); i++) {
      final lx = legendX + (i % 3) * (size.width * 0.3);
      final ly = legendY + (i >= 3 ? 18.0 : 0.0);
      final color = Color(ds.colorValue).withValues(alpha: 0.85);
      canvas.drawRect(
        Rect.fromLTWH(lx, ly, 10 * scale, 10 * scale),
        Paint()..color = color,
      );
      final label = i < data.labels.length ? data.labels[i] : '';
      final ltp = TextPainter(
        text: TextSpan(text: ' $label', style: TextStyle(
          color: Colors.white70, fontSize: max(9, 11 * scale))),
        textDirection: TextDirection.ltr,
      )..layout();
      ltp.paint(canvas, Offset(lx + 14 * scale, ly));
    }
  }

  @override
  bool shouldRepaint(_FullScreenPiePainter old) => false;
}
