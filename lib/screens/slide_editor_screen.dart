// DocuCraft — Slide Editor Screen (Editor PPT Utama)
// Memakai widget modular dari lib/widgets/editor/

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import '../models/slide.dart';
import '../services/pptx_export.dart';
import '../services/web_download_selector.dart';
import '../services/ai_generation.dart';
import '../services/svg_to_slide_elements.dart';
import '../providers/slide_provider.dart';
import '../services/pptx_import.dart';
import '../services/file_reader.dart';
import '../themes/app_theme.dart';
import '../main.dart'; // CollabManager
import '../src/ffi/collab_factory.dart';
import '../src/ffi/slide_provider_crdt.dart';
import '../widgets/ai_chat_panel.dart';
import '../widgets/sketch_ai_panel.dart';
import '../widgets/search_panel.dart';
import '../widgets/text_editor_bottom_sheet.dart';
import '../widgets/grid_view.dart';
import '../widgets/presentation_mode.dart';
import '../widgets/draw_canvas.dart';
import '../widgets/share_dialog.dart';
import '../slide_editor_intents.dart';

// Import modular editor widgets
import '../widgets/editor/editor_top_nav.dart';
import '../screens/presentation_viewer_screen.dart';
import '../widgets/editor/editor_canvas_area.dart';
import '../widgets/editor/editor_context_toolbar.dart';
import '../widgets/editor/editor_slide_actions.dart';
import '../widgets/editor/editor_toolbar.dart';
import '../widgets/editor/editor_thumbnail_strip.dart';

class SlideEditorScreen extends StatefulWidget {
  final bool autoOpenAi;
  final String? initialPrompt;

  const SlideEditorScreen({super.key, this.autoOpenAi = false, this.initialPrompt});

  @override
  State<SlideEditorScreen> createState() => _SlideEditorScreenState();
}

class _SlideEditorScreenState extends State<SlideEditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  double _zoomLevel = 1.0;
  bool _drawActive = false;
  final GlobalKey<DrawCanvasState> _drawCanvasKey = GlobalKey<DrawCanvasState>();

  // Element comments state
  final TextEditingController _elementCommentCtrl = TextEditingController();
  String? _commentingElementId;

  // Inline text editing state
  String? _editingElementId;
  final TextEditingController _inlineTextCtrl = TextEditingController();

  // Presenter notes persistent controller
  final TextEditingController _notesCtrl = TextEditingController();
  int _lastNotesSlideIndex = -1;

  // Export/Import loading state
  bool _isExporting = false;
  bool _isImporting = false;

  // Clipboard (copy/paste)
  SlideElement? _clipboard;

  // Keyboard listener
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<SlideProvider>();
      final collabManager = CollabManager();

      // Check if CRDT mode is active
      if (collabManager.mode == CollabMode.crdt && collabManager.crdtProvider != null) {
        final crdtProvider = collabManager.crdtProvider!;
        if (crdtProvider.slides.isEmpty) {
          // Try to load from local storage
          await provider.initFromStorage();
          // Migrate legacy to CRDT if needed
          if (provider.slides.isNotEmpty) {
            final snapshot = await CollabMigration.exportLegacyToCrdt(provider, 'doc_${provider.currentProjectId}');
            if (snapshot.isNotEmpty) {
              await crdtProvider.initCollab(
                documentId: 'doc_${provider.currentProjectId}',
                userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
                userName: 'User',
                snapshot: snapshot,
              );
            }
          }
        }
        // Connect WebSocket for sync
        await collabManager.connectWebSocket(
          documentId: 'doc_${provider.currentProjectId}',
          userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
          userName: 'User',
        );
      } else {
        // Legacy mode
        if (provider.slides.isEmpty) {
          provider.initFromStorage();
        }
        provider.startAutoSave();
      }
    });
    _focusNode.addListener(_onKeyEvent);

    // Auto-open AI Chat + send prompt
    if (widget.autoOpenAi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final provider = context.read<SlideProvider>();
          AiChatPanel.show(
            context,
            initialPrompt: widget.initialPrompt,
            currentSlideIndex: provider.currentSlideIndex,
            drawCanvasKey: _drawCanvasKey,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _elementCommentCtrl.dispose();
    _inlineTextCtrl.dispose();
    _notesCtrl.dispose();
    _focusNode.removeListener(_onKeyEvent);
    _focusNode.dispose();
    // Note: CollabManager.dispose() is called app-wide, not per screen
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Shortcuts(
          shortcuts: {
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC): const CopyIntent(),
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV): const PasteIntent(),
            LogicalKeySet(LogicalKeyboardKey.delete): const DeleteIntent(),
            LogicalKeySet(LogicalKeyboardKey.backspace): const DeleteIntent(),
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ): const UndoIntent(),
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyY): const RedoIntent(),
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter): const AddSlideIntent(),
          },
          child: Actions(
            actions: {
              CopyIntent: CallbackAction<CopyIntent>(onInvoke: (_) => _copyElement()),
              PasteIntent: CallbackAction<PasteIntent>(onInvoke: (_) => _pasteElement()),
              DeleteIntent: CallbackAction<DeleteIntent>(onInvoke: (_) => _deleteSelected()),
              UndoIntent: CallbackAction<UndoIntent>(onInvoke: (_) => context.read<SlideProvider>().undo()),
              RedoIntent: CallbackAction<RedoIntent>(onInvoke: (_) => context.read<SlideProvider>().redo()),
              AddSlideIntent: CallbackAction<AddSlideIntent>(onInvoke: (_) => context.read<SlideProvider>().addSlide()),
            },
            child: Consumer<SlideProvider>(
              builder: (ctx, provider, _) {
                final slide = provider.currentSlide;
                if (slide == null) {
                  return const Center(
                    child: Text('Tidak ada slide', style: TextStyle(color: AppTheme.textSecondary)),
                  );
                }

                return Stack(
                  children: [
                    Positioned.fill(
                      child: Column(
                        children: [
                          // Top Navigation
                          EditorTopNav(
                            slide: slide,
                            provider: provider,
                            titleController: _titleController,
                            selectedElementId: provider.selectedElementId,
                            onBackPressed: () => Navigator.pop(context),
                            onSharePressed: () => _showShareDialog(provider),
                            onExportPressed: () => _exportPPT(provider),
                            onSearchPressed: () => SearchPanel.show(context),
                            onEditTextPressed: () async {
                              final el = _findElement(provider);
                              if (el != null && (el.type == ElementType.text || el.type == ElementType.icon)) {
                                TextEditorSheet.show(context, el);
                              }
                            },
                          ),
                          // Canvas Area
                          Expanded(
                            child: EditorCanvasArea(
                              slide: slide,
                              provider: provider,
                              zoomLevel: _zoomLevel,
                              selectedElementId: provider.selectedElementId,
                              editingElementId: _editingElementId,
                              commentingElementId: _commentingElementId,
                              elementCommentCtrl: _elementCommentCtrl,
                              drawActive: _drawActive,
                              drawCanvasKey: _drawCanvasKey,
                              onDrawStrokesChanged: () => _saveDrawStrokes(provider),
                              onElementTap: (id) {
                                if (id.isEmpty) {
                                  provider.selectElement(null);
                                  return;
                                }
                                final s = provider.currentSlide;
                                final el = s?.elements.where((e) => e.id == id).firstOrNull;
                                if (el != null && (el.type == ElementType.text || el.type == ElementType.icon)) {
                                  // GenOffice-style: tap text → inline edit (cursor + keyboard)
                                  setState(() => _editingElementId = id);
                                  provider.selectElement(id);
                                } else {
                                  // Non-text element: exit any active edit, then select
                                  if (_editingElementId != null) setState(() => _editingElementId = null);
                                  provider.selectElement(id);
                                }
                              },
                              onElementDragEnd: (id, x, y) => provider.updateElementPosition(id, x, y),
                              onElementResizeEnd: (id, w, h) => provider.updateElementSize(id, w, h),
                              onContentChange: (id, c) => provider.updateElementContent(id, c),
                              onStyleChange: (id, s) => provider.updateElementStyle(id, s),
                              onEditingDone: () => setState(() => _editingElementId = null),
                              onElementDoubleTap: (id) {
                                // GenOffice double-clicks to edit text inline (TextEditOverlay).
                                // Mirror that here: double-tap → same inline editor as single-tap.
                                final s = provider.currentSlide;
                                if (s == null) return;
                                final el = s.elements.where((e) => e.id == id).firstOrNull;
                                if (el != null && (el.type == ElementType.text || el.type == ElementType.icon)) {
                                  setState(() => _editingElementId = id);
                                  provider.selectElement(id);
                                }
                              },
                              onElementLongPress: (id) { setState(() { _commentingElementId = id; _elementCommentCtrl.clear(); }); },
                              onSlideTap: () {
                                if (_editingElementId != null) setState(() => _editingElementId = null);
                                provider.selectSlide(slide.id);
                              },
                              onRenderMetrics: (id, {double? contentHeight, double? overflowXPx}) {
                                provider.updateTextLayoutMetrics(id,
                                  contentHeight: contentHeight,
                                  overflowXPx: overflowXPx,
                                );
                              },
                              onCommentSubmit: _submitElementComment,
                              onCommentCancel: () => setState(() => _commentingElementId = null),
                              onElementAISketch: _triggerAISketchFromComment,
                              onGridViewTap: () => SlideGridView.show(context),
                              onZoomChanged: (v) => setState(() => _zoomLevel = v),
                            ),
                          ),
                          // Context Toolbar
                          EditorContextToolbar(
                            provider: provider,
                            slide: slide,
                            parentContext: context,
                          ),
                          // Slide Actions
                          EditorSlideActions(
                            provider: provider,
                            notesCtrl: _notesCtrl,
                            lastNotesSlideIndex: _lastNotesSlideIndex,
                            onSlideChanged: (index) => _lastNotesSlideIndex = index,
                            onAddSlide: () => provider.addSlide(),
                            onDuplicateSlide: () => provider.duplicateSlide(),
                            onDeleteSlide: () => provider.deleteSlide(null),
                            onToggleHideSlide: () => provider.toggleHideSlide(),
                            onPresent: () => _showPresentDialog(provider),
                          ),
                          // Draw Toolbar + AI button di sampingnya
                          if (_drawActive && _drawCanvasKey.currentState != null)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  DrawToolbar(
                                    drawState: _drawCanvasKey.currentState!,
                                    onClose: () {
                                      setState(() {
                                        _drawActive = false;
                                        _drawCanvasKey.currentState?.setActive(false);
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  // AI Coret button — panel khusus sketch-to-design
                                  FloatingActionButton.small(
                                    onPressed: () => SketchAiPanel.show(
                                      context,
                                      drawCanvasKey: _drawCanvasKey,
                                    ),
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    heroTag: 'ai_sketch_btn',
                                    child: const Icon(Icons.draw, size: 18),
                                  ),
                              ],
                            ),
                          ),
                          // Editor Toolbar
                          EditorToolbar(
                            provider: provider,
                            drawActive: _drawActive,
                            onDrawToggle: () {
                              setState(() => _drawActive = !_drawActive);
                              if (_drawActive) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  _drawCanvasKey.currentState?.setActive(true);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('✏️ Mode coret aktif — coret di canvas'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 1)),
                                );
                              } else {
                                _drawCanvasKey.currentState?.setActive(false);
                              }
                            },
                            onSketchToDesign: () => _showSketchToDesignDialog(provider),
                            onImportPPT: () => _importPPT(provider),
                          ),
                          // Thumbnail Strip
                          EditorThumbnailStrip(provider: provider),
                        ],
                      ),
                    ),
                    // Export loading overlay
                    if (_isExporting)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black54,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: AppTheme.primary),
                                SizedBox(height: 16),
                                Text('Mengexport .pptx...', style: TextStyle(color: Colors.white, fontSize: 14)),
                                SizedBox(height: 4),
                                Text('Tunggu sebentar ya', style: TextStyle(color: Colors.white60, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // Import loading overlay
                    if (_isImporting)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black54,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: AppTheme.primary),
                                SizedBox(height: 16),
                                Text('Mengimport .pptx...', style: TextStyle(color: Colors.white, fontSize: 14)),
                                SizedBox(height: 4),
                                Text('Membaca file...', style: TextStyle(color: Colors.white60, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // Floating AI Design button (always visible)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // View PPT button — buka presentation viewer langsung
                          if (provider.slides.isNotEmpty)
                            FloatingActionButton(
                              heroTag: 'view_ppt_btn',
                              onPressed: () {
                                PresentationViewerScreen.openFromSlides(
                                  context,
                                  provider.slides,
                                  title: _titleController.text.isNotEmpty
                                      ? _titleController.text
                                      : 'Presentasi',
                                );
                              },
                              backgroundColor: AppTheme.surface3,
                              foregroundColor: AppTheme.textSecondary,
                              mini: true,
                              child: const Icon(Icons.visibility, size: 20),
                            ),
                          const SizedBox(width: 10),
                          FloatingActionButton(
                            heroTag: 'ai_design_btn',
                            onPressed: () => _showSketchToDesignDialog(provider),
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            child: const Icon(Icons.auto_awesome),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Clipboard ──
  void _copyElement() {
    final provider = context.read<SlideProvider>();
    final id = provider.selectedElementId;
    if (id == null || provider.currentSlide == null) return;
    try {
      final el = provider.currentSlide!.elements.firstWhere((e) => e.id == id);
      _clipboard = SlideElement.fromJson(el.toJson());
      _clipboard!.id = '';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📋 Element disalin'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 1)),
        );
      }
    } catch (_) {}
  }

  void _pasteElement() {
    if (_clipboard == null) return;
    final provider = context.read<SlideProvider>();
    final clone = SlideElement.fromJson(_clipboard!.toJson());
    clone.x += 20;
    clone.y += 20;
    provider.addElement(clone);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📋 Element ditempel'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 1)),
      );
    }
  }

  void _deleteSelected() {
    final provider = context.read<SlideProvider>();
    final id = provider.selectedElementId;
    if (id != null) provider.deleteElement(id);
  }

  void _onKeyEvent() {
    // Handled via Shortcuts widget
  }

  /// Save drawing strokes to slide model when drawing changes
  /// NOTE: Draw strokes are NOT saved as slide elements to avoid double rendering.
  /// The DrawCanvas overlay handles display, and stroke data is sent directly to AI.
  void _saveDrawStrokes(SlideProvider provider) {
    // Intentionally empty - draw strokes should NOT be saved as slide elements.
    // They are rendered by DrawCanvas overlay only, preventing double display.
    // The stroke data is captured directly from DrawCanvas when needed for AI.
  }

  // ── Find Element Helper ──
  SlideElement? _findElement(SlideProvider provider) {
    final id = provider.selectedElementId;
    if (id == null || provider.currentSlide == null) return null;
    try {
      return provider.currentSlide!.elements.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Present Mode ──
  void _showPresentDialog(SlideProvider provider) {
    PresentationScreen.start(context, initialSlideIndex: provider.currentSlideIndex);
  }

  // ── Element Comment ──
  void _submitElementComment() {
    final text = _elementCommentCtrl.text.trim();
    final elementId = _commentingElementId;
    if (text.isEmpty || elementId == null) return;

    setState(() {
      _commentingElementId = null;
      _elementCommentCtrl.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('💬 Komentar terpin di elemen $elementId'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Trigger Sketch-to-Design AI from the element comment overlay.
  /// Opens AiChatPanel with the draw canvas key, pre-filled prompt.
  void _triggerAISketchFromComment() {
    AiChatPanel.show(
      context,
      initialPrompt: 'Convert coretan di canvas ke design profesional untuk elemen yang sedang dipilih.',
      drawCanvasKey: _drawCanvasKey,
    );
  }

  // ── AI dari Coretan (Sketch to Design) ──
  void _showSketchToDesignDialog(SlideProvider provider) {
    final TextEditingController promptCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface2,
        title: Row(
          children: [
            Icon(Icons.auto_awesome, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text('🎨 AI dari Coretan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Coretan Anda akan dianalisis & dijadikan desain profesional.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: promptCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Prompt desain',
                hintText: 'Contoh: "Buat slide pitch deck clean, warna biru profesional"',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                hintStyle: TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.surface3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withAlpha(30)),
                ),
              ),
              maxLines: 3,
              minLines: 1,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final prompt = promptCtrl.text.trim();
              if (prompt.isNotEmpty) {
                _runSketchToDesign(prompt);
              }
            },
            child: const Text('✨ Generate Desain'),
          ),
        ],
      ),
    );
  }

  /// Sketch-to-Design: capture canvas → kirim ke vision AI → apply ke slide
  Future<void> _runSketchToDesign(String prompt) async {
    final state = _drawCanvasKey.currentState;
    if (state == null || state.strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Tidak ada coretan. Gambar dulu di canvas!')),
      );
      return;
    }

    // Canvas size for DrawCanvas is 380x214
    const canvasWidth = 380;
    const canvasHeight = 214;

    // Capture canvas to PNG
    final pngBytes = await state.captureToImage();
    if (pngBytes == null || pngBytes.isEmpty) {
      // Fallback: kirim data stroke sebagai JSON (tanpa vision)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Capture gambar gagal, mencoba dengan data stroke...')),
      );
      final sketchData = state.getStrokesAsJson();
      final fallbackResult = await AiGenerationService.generateFromSketchSvg(
        sketchData,
        prompt,
        currentSlide: context.read<SlideProvider>().currentSlide,
        canvasWidth: canvasWidth,
        canvasHeight: canvasHeight,
      );
      if (context.mounted && fallbackResult.success) {
        // Parse SVG → SlideElements and add to slide
        final elements = SvgToSlideElements.parse(
          fallbackResult.svg ?? '',
          sourceCanvasWidth: canvasWidth,
          sourceCanvasHeight: canvasHeight,
        );
        if (elements.isNotEmpty) {
          final currentSlide = context.read<SlideProvider>().currentSlide;
          currentSlide?.elements.addAll(elements);
          context.read<SlideProvider>().notify();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ AI generate ${elements.length} elemen dari SVG (fallback)!'), backgroundColor: AppTheme.success),
          );
        }
      }
      return;
    }

    if (!context.mounted) return;

    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('🤖 AI sedang membuat desain dari coretan...'),
        ]),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      // Kirim ke vision AI
      final currentSlide = context.read<SlideProvider>().currentSlide;
      final result = await AiGenerationService.sketchToDesignSvg(
        pngBytes,
        prompt,
        currentSlide: currentSlide,
        canvasWidth: canvasWidth,
        canvasHeight: canvasHeight,
      );

      if (!context.mounted) return;

      if (result.success && result.svg != null && result.svg!.isNotEmpty) {
        // Parse SVG → SlideElements (scale from 380x214 to 1920x1080)
        final elements = SvgToSlideElements.parse(
          result.svg!,
          sourceCanvasWidth: canvasWidth,
          sourceCanvasHeight: canvasHeight,
        );
        if (elements.isNotEmpty) {
          final provider = context.read<SlideProvider>();
          final currentSlide = provider.currentSlide;
          if (currentSlide != null) {
            currentSlide.elements.addAll(elements);
            provider.notify();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ AI berhasil membuat ${elements.length} elemen dari coretan!'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ AI gagal: ${result.error ?? "tidak ada hasil"}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Error: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  // ── Share Dialog ──
  void _showShareDialog(SlideProvider provider) {
    final docId = provider.slides.isNotEmpty ? provider.slides.first.id : 'unknown';
    showDialog(
      context: context,
      builder: (_) => ShareDialog(documentId: docId),
    );
  }

  // ── Export .pptx ──
  void _exportPPT(SlideProvider provider) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final title = _titleController.text.isNotEmpty ? _titleController.text : 'presentasi';
      final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '') + '.pptx';
      final exporter = PptxExporter(slides: provider.slides, title: title);
      await Future.delayed(const Duration(milliseconds: 50));

      if (kIsWeb) {
        final bytes = exporter.exportAsBytes();
        downloadBytes(safeTitle, bytes);
      } else {
        final bytes = exporter.exportAsBytes();
        final xfile = XFile.fromData(Uint8List.fromList(bytes), name: safeTitle, mimeType: 'application/vnd.openxmlformats-officedocument.presentationml.presentation');
        await Share.shareXFiles([xfile], text: safeTitle);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$safeTitle" siap dibagikan (${provider.slides.length} slide)'),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── Import .pptx ──
  void _importPPT(SlideProvider provider) async {
    if (_isImporting) return;
    setState(() => _isImporting = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📂 Memilih file .pptx...'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pptx'],
      );

      if (result != null && (result.files.single.bytes != null || result.files.single.path != null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏳ Mengimport .pptx...'),
            behavior: SnackBarBehavior.floating,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 50));

        final fileBytes = result.files.single.bytes;
        final filePath = result.files.single.path;
        ImportResult? importResult;
        if (fileBytes != null && fileBytes.isNotEmpty) {
          importResult = PptxImporter.fromBytes(fileBytes);
        } else if (!kIsWeb && filePath != null && filePath.isNotEmpty) {
          final fileData = await readBytesFromPath(filePath);
          if (fileData != null) {
            importResult = PptxImporter.fromBytes(fileData);
          }
        }
        if (importResult != null && importResult.slides.isNotEmpty) {
          if (importResult.warnings.isNotEmpty && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ ${importResult.warnings.length} catatan: ${importResult.warnings.first}'),
                backgroundColor: AppTheme.warning,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
          }

          provider.applyAiResult(importResult.slides, replaceAll: false);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📥 Berhasil import ${importResult.slides.length} slide dari .pptx'),
                backgroundColor: AppTheme.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Gagal parse .pptx: file mungkin corrupt atau tidak didukung'),
                backgroundColor: AppTheme.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }
}