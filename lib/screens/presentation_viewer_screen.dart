// DocuCraft — Presentation Viewer Screen
// Membuka file .pptx/.ppt dan menampilkannya layaknya presentation mode (full-screen)
//
// Flow:
//   1. Menerima bytes dari file picker / share / export
//   2. Parse dengan PptxImporter dari bytes
//   3. Render slide-by-slide
//   4. Navigasi left/right, gesture swipe, progress bar, back button
//
// Juga dapat menerima list Slide langsung (e.g. preview AI generate)

import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../models/slide.dart';
import '../services/api_client.dart';
import '../services/pptx_export.dart';
import '../services/pptx_import.dart';
import '../services/svg_to_slide_elements.dart';
import '../themes/app_theme.dart';
import '../widgets/presentation_mode.dart';

/// PresentationViewerScreen — full-screen slide viewer
///
/// Menerima [slides] langsung, [pptxBytes] untuk di-parse, ATAU
/// [pngBase64Slides] (list of base64-encoded PNG strings) yang di-render
/// langsung sebagai gambar — ini dipakai oleh workspace/prompt flow
/// dimana slide data dikirim via WebSocket sebagai PNG base64.
/// Juga mendukung [title] untuk app bar.
class PresentationViewerScreen extends StatefulWidget {
  final List<Slide>? slides;
  final Uint8List? pptxBytes;
  final List<String>? pngBase64Slides;
  final String? title;
  final bool showChrome; // false = pure fullscreen

  const PresentationViewerScreen({
    super.key,
    this.slides,
    this.pptxBytes,
    this.pngBase64Slides,
    this.title,
    this.showChrome = true,
  });

  /// Static helper: buka viewer dari file picker (.pptx)
  static Future<void> openFromFile(BuildContext context, {String? title}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pptx', 'ppt', 'pptm'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final fileBytes = result.files.first.bytes;
      if (fileBytes == null || fileBytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Tidak dapat membaca file'), backgroundColor: AppTheme.error),
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PresentationViewerScreen(
            pptxBytes: Uint8List.fromList(fileBytes),
            title: title,
          ),
          fullscreenDialog: true,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ File picker error: $e');
    }
  }

  /// Static helper: buka viewer langsung dari bytes (e.g. download dari GenOffice)
  static Future<void> openFromBytes(
    BuildContext context,
    List<int> bytes, {
    String? title,
  }) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PresentationViewerScreen(
          pptxBytes: Uint8List.fromList(bytes),
          title: title,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  /// Static helper: buka viewer langsung dari list of Slide
  static Future<void> openFromSlides(
    BuildContext context,
    List<Slide> slides, {
    String? title,
    bool showChrome = true,
  }) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PresentationViewerScreen(
          slides: slides,
          title: title,
          showChrome: showChrome,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  /// Static helper: buka viewer dari list PNG base64 strings (workspace/prompt flow)
  /// Slides diterima langsung via WebSocket deck-ready event sebagai base64-encoded PNGs.
  static Future<void> openFromPngBase64(
    BuildContext context,
    List<String> pngBase64Slides, {
    String? title,
    bool showChrome = true,
  }) async {
    if (pngBase64Slides.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada slide untuk ditampilkan'), backgroundColor: AppTheme.error),
      );
      return;
    }
    debugPrint('🖼️ [PresentationViewer] Opening ${pngBase64Slides.length} PNG slides from WebSocket');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PresentationViewerScreen(
          pngBase64Slides: pngBase64Slides,
          title: title ?? 'Presentation',
          showChrome: showChrome,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  /// Static helper: buka viewer dari GenOffice workspace (fetch JSON SVG presentation)
  static Future<void> openFromWorkspace(
    BuildContext context,
    String workspaceId,
    GenOfficeClient apiClient, {
    String? title,
    bool showChrome = true,
  }) async {
    try {
      final result = await apiClient.getWorkspacePresentation(workspaceId: workspaceId);

      if (result['ok'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Workspace error: ${result['error'] ?? 'Unknown'}'), backgroundColor: AppTheme.error),
        );
        return;
      }

      final slidesData = result['slides'] as List<dynamic>?;
      if (slidesData == null || slidesData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada slide yang dipilih di workspace ini'), backgroundColor: AppTheme.error),
        );
        return;
      }

      // Parse SVG → Slide model
      final slides = <Slide>[];
      int parsedCount = 0;
      int erroredCount = 0;
      for (final sd in slidesData) {
        try {
          final slideMap = sd as Map<String, dynamic>;
          final svg = slideMap['svg'] as String? ?? '';
          final elements = svg.isNotEmpty
              ? SvgToSlideElements.parse(svg)
              : <SlideElement>[];
          slides.add(Slide(
            title: slideMap['title'] as String? ?? 'Slide',
            subtitle: '',
            backgroundGradient: slideMap['style'] as String? ?? 'indigo',
            elements: elements,
          ));
          parsedCount++;
        } catch (parseErr) {
            erroredCount++;
            debugPrint('⚠️ Slide parse error: $parseErr');
        }
      }

      if (slides.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal parse $erroredCount / ${slidesData.length} slide'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }

      // Warn if ada slide yang gagal parse
      if (erroredCount > 0 && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berhasil tampil $parsedCount / ${slidesData.length} slide ($erroredCount gagal)'), backgroundColor: AppTheme.surface3),
        );
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PresentationViewerScreen(
            slides: slides,
            title: title ?? (result['topic'] as String? ?? 'Presentation'),
            showChrome: showChrome,
          ),
          fullscreenDialog: true,
        ),
      );
    } on SocketException catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat terhubung ke server (port 3001)'), backgroundColor: AppTheme.error),
      );
    } on TimeoutException catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request timeout — pastikan server berjalan'), backgroundColor: AppTheme.error),
      );
    } catch (e) {
      debugPrint('⚠️ Workspace presentation fetch error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka presentasi:\n${e.toString()}', maxLines: 3),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  /// Static helper: upload current slides as PPTX to GenOffice workspace
  static Future<void> uploadToWorkspace(
    BuildContext context,
    List<Slide> slides,
    GenOfficeClient apiClient, {
    required String workspaceId,
  }) async {
    debugPrint('📤 [uploadToWorkspace] Starting PPTX export: ${slides.length} slides');
    try {
      // Export slides to PPTX
      final exporter = PptxExporter(slides: slides);
      final pptxBytes = exporter.exportAsBytes();
      debugPrint('📤 [uploadToWorkspace] PPTX export complete: ${pptxBytes.length} bytes');
      if (pptxBytes.isEmpty) {
        debugPrint('⚠️ [uploadToWorkspace] PPTX export produced empty bytes');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export PPTX gagal — tidak ada data'), backgroundColor: AppTheme.error),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mengunggah ${slides.length} slide...'), backgroundColor: AppTheme.surface3),
      );

      debugPrint('📤 [uploadToWorkspace] Calling importPptx API for workspace: $workspaceId');
      final result = await apiClient.importPptx(
        workspaceId: workspaceId,
        pptxBytes: pptxBytes,
      );
      debugPrint('📤 [uploadToWorkspace] API response: $result');

      if (result['ok'] == true) {
        debugPrint('✅ [uploadToWorkspace] PPTX uploaded successfully');

        // Auto-open viewer with the uploaded slides
        await openFromSlides(context, slides, title: '${slides.length} Slide');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '✅ ${slides.length} slide terunggah'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload gagal: ${result['error'] ?? 'Unknown'}'), backgroundColor: AppTheme.error),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Upload to workspace error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal upload: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  State<PresentationViewerScreen> createState() => _PresentationViewerScreenState();
}

class _PresentationViewerScreenState extends State<PresentationViewerScreen>
    with TickerProviderStateMixin {
  late List<Slide> _slides;
  List<Uint8List>? _pngSlideImages; // PNG base64 → decoded bytes
  int _currentSlideIndex = 0;
  bool _chromeVisible = true;
  bool _isParsing = false;
  String? _parseError;

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  /// Whether we're in PNG-image mode (workspace/prompt flow)
  bool get _isPngMode => _pngSlideImages != null && _pngSlideImages!.isNotEmpty;
  int get _slideCount => _isPngMode ? _pngSlideImages!.length : _slides.length;

  @override
  void initState() {
    super.initState();
    _slides = [];
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);

    // Priority: pngBase64Slides → pptxBytes → slides
    if (widget.pngBase64Slides != null && widget.pngBase64Slides!.isNotEmpty) {
      _decodePngSlides(widget.pngBase64Slides!);
    } else if (widget.pptxBytes != null) {
      _parsePptx(widget.pptxBytes!);
    } else if (widget.slides != null) {
      setState(() {
        _slides = widget.slides!;
      });
    } else {
      // No data — show error
      setState(() {
        _parseError = 'No presentation data provided';
      });
    }

    // Fullscreen mode
    if (widget.showChrome) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  Future<void> _parsePptx(Uint8List bytes) async {
    setState(() {
      _isParsing = true;
      _parseError = null;
    });

    try {
      final result = await compute(_parsePptxIsolate, bytes);
      if (result == null) {
        setState(() {
          _parseError = 'Failed to parse PPTX — file may be corrupt or unsupported format';
        });
      } else if (result.slides.isEmpty) {
        setState(() {
          _parseError = 'PPTX contains no slides';
        });
      } else {
        setState(() {
          _slides = result.slides;
          _parseError = null;
        });
      }
    } catch (e) {
      setState(() {
        _parseError = 'Parse error: $e';
      });
    } finally {
      setState(() {
        _isParsing = false;
      });
    }
  }

  /// Decode PNG base64 strings to Uint8List bytes for rendering
  void _decodePngSlides(List<String> pngBase64List) {
    final images = <Uint8List>[];
    for (final b64 in pngBase64List) {
      try {
        // Strip data URI prefix if present (e.g. "data:image/png;base64,")
        final raw = b64.contains(',') ? b64.split(',').last : b64;
        images.add(base64Decode(raw));
      } catch (e) {
        debugPrint('⚠️ Failed to decode PNG slide: $e');
      }
    }
    setState(() {
      _pngSlideImages = images;
    });
    debugPrint('🖼️ [PresentationViewer] Decoded ${images.length} / ${pngBase64List.length} PNG slides');
  }

  void _goToSlide(int index) {
    if (index < 0 || index >= _slideCount) return;
    setState(() {
      _currentSlideIndex = index;
    });
    _fadeController.forward(from: 0);
  }

  void _nextSlide() {
    if (_currentSlideIndex < _slideCount - 1) {
      _goToSlide(_currentSlideIndex + 1);
    }
  }

  void _prevSlide() {
    if (_currentSlideIndex > 0) {
      _goToSlide(_currentSlideIndex - 1);
    }
  }

  void _toggleChrome() {
    setState(() {
      _chromeVisible = !_chromeVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? 'Presentation';

    if (_isParsing) {
      return Scaffold(
        backgroundColor: AppTheme.surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primary),
              const SizedBox(height: 16),
              Text(
                'Membuka presentasi...',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_parseError != null || (_slides.isEmpty && !_isPngMode)) {
      return Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: widget.showChrome ? AppBar(
          title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
          backgroundColor: AppTheme.surface2,
          iconTheme: const IconThemeData(color: AppTheme.textSecondary),
        ) : null,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, size: 48, color: AppTheme.error),
              const SizedBox(height: 16),
              Text(
                _parseError ?? 'Tidak ada slide untuk ditampilkan',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              if (widget.showChrome) ...[
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
                  label: const Text('Kembali', style: TextStyle(color: AppTheme.primary)),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen slide content
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _fadeAnim,
              builder: (ctx, child) {
                final opacity = 1.0 - _fadeAnim.value * 0.15;
                return Opacity(
                  opacity: opacity,
                  child: child,
                );
              },
              child: _isPngMode
                  ? Image.memory(
                      _pngSlideImages![_currentSlideIndex],
                      fit: BoxFit.contain,
                      gaplessPlayback: true, // prevent flicker on slide change
                    )
                  : FullScreenSlide(slide: _slides[_currentSlideIndex]),
            ),
          ),

          // Chrome — only when showChrome is true and chrome is visible
          if (widget.showChrome)
            ..._buildChrome(),

          // Fullscreen mode: top-left tap zone for back, bottom bar
          if (!widget.showChrome) ..._buildMinimalChrome(),
        ],
      ),
    );
  }

  /// Chrome widgets for the viewer (when showChrome == true)
  List<Widget> _buildChrome() {
    if (!_chromeVisible) return [];

    return [
      // Top app bar overlay
      Positioned(
        top: 0, left: 0, right: 0,
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(180),
                  Colors.black.withAlpha(80),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.title ?? 'Presentation',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  '${_currentSlideIndex + 1} / ${_slideCount}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(width: 12),
                // Copy slide button
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
                  tooltip: 'Copy slide to editor',
                  onPressed: _copyCurrentSlide,
                ),
              ],
            ),
          ),
        ),
      ),

      // Bottom navigation bar
      Positioned(
        bottom: 0, left: 0, right: 0,
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withAlpha(180),
                  Colors.black.withAlpha(80),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                // Progress bar
                Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(50),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (_currentSlideIndex + 1) / _slideCount,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFFA855F7)]),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Navigation buttons
                _navButton(Icons.chevron_left, _prevSlide, enabled: _currentSlideIndex > 0),
                const SizedBox(width: 8),
                _navButton(Icons.chevron_right, _nextSlide, enabled: _currentSlideIndex < _slideCount - 1),
                const SizedBox(width: 8),
                // Fullscreen toggle
                _navButton(Icons.fullscreen, _toggleFullscreen, enabled: true),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  /// Minimal chrome for fullscreen mode (no app bar, tap to show)
  List<Widget> _buildMinimalChrome() {
    if (!_chromeVisible) return [];

    return [
      // Top — slide counter + close
      Positioned(
        top: 0, left: 0, right: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentSlideIndex + 1} / ${_slideCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // Bottom — nav buttons
      Positioned(
        bottom: 0, left: 0, right: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _navButton(Icons.chevron_left, _prevSlide, enabled: _currentSlideIndex > 0, mini: true),
                const SizedBox(width: 16),
                _navButton(Icons.chevron_right, _nextSlide, enabled: _currentSlideIndex < _slideCount - 1, mini: true),
                const SizedBox(width: 16),
                _navButton(Icons.pause_presentation, _toggleChrome, enabled: true, mini: true, tooltip: 'Hide controls'),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _navButton(IconData icon, VoidCallback? onPressed, {bool enabled = true, bool mini = false, String? tooltip}) {
    final size = mini ? 28.0 : 36.0;
    return SizedBox(
      width: size, height: size,
      child: IconButton(
        icon: Icon(icon, size: mini ? 16 : 20, color: enabled ? Colors.white : Colors.white.withAlpha(80)),
        onPressed: enabled ? onPressed : null,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _copyCurrentSlide() {
    if (_slideCount == 0) return;
    // Push to clipboard or share
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Slide ${_currentSlideIndex + 1} content ready'),
        backgroundColor: AppTheme.surface3,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleFullscreen() {
    if (widget.showChrome) {
      // Switch to minimal fullscreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PresentationViewerScreen(
            slides: _isPngMode ? null : _slides,
            pngBase64Slides: _isPngMode ? widget.pngBase64Slides : null,
            title: widget.title,
            showChrome: false,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    // Restore UI mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }
}

/// Compute-isolate-friendly parse function
ImportResult? _parsePptxIsolate(List<int> bytes) {
  try {
    return PptxImporter.fromBytes(bytes);
  } catch (e) {
    debugPrint('⚠️ Isolate parse error: $e');
    return null;
  }
}