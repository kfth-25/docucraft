// DocuCraft — Main Editor Screen (Orchestrator)
// Mengganti slide_editor_screen.dart yang monolitik dengan komposisi widget modular

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/slide.dart';
import '../../services/pptx_export.dart';
import '../../services/web_download_selector.dart';
import '../../providers/slide_provider.dart';
import '../../services/pptx_import.dart';
import '../../services/file_reader.dart';
import '../../themes/app_theme.dart';
import '../../main.dart'; // CollabManager
import '../../widgets/search_panel.dart';
import '../../widgets/text_editor_bottom_sheet.dart';
import '../../widgets/grid_view.dart';
import '../../widgets/draw_canvas.dart';
import '../../widgets/presentation_mode.dart';
import '../../widgets/ai_chat_panel.dart';
import '../../widgets/comments_panel.dart';
import '../../widgets/element_comments.dart';
import '../../widgets/presence_overlay.dart';

// Import modular editor widgets
import 'editor_top_nav.dart';
import 'editor_canvas_area.dart';
import 'editor_context_toolbar.dart';
import 'editor_slide_actions.dart';
import 'editor_toolbar.dart';
import 'editor_thumbnail_strip.dart';

class SlideEditorScreen extends StatefulWidget {
  final bool autoOpenAi;
  final String? initialPrompt;

  const SlideEditorScreen({
    super.key,
    this.autoOpenAi = false,
    this.initialPrompt,
  });

  @override
  State<SlideEditorScreen> createState() => _SlideEditorScreenState();
}

class _SlideEditorScreenState extends State<SlideEditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  double _zoomLevel = 1.0;
  bool _drawActive = false;
  final GlobalKey<DrawCanvasState> _drawCanvasKey =
      GlobalKey<DrawCanvasState>();

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SlideProvider>();
      if (provider.slides.isEmpty) {
        provider.initFromStorage();
      }
      provider.startAutoSave();
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
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC):
                const CopyIntent(),
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV):
                const PasteIntent(),
            LogicalKeySet(LogicalKeyboardKey.delete): const DeleteIntent(),
            LogicalKeySet(LogicalKeyboardKey.backspace): const DeleteIntent(),
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
                const UndoIntent(),
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyY):
                const RedoIntent(),
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter):
                const AddSlideIntent(),
          },
          child: Actions(
            actions: {
              CopyIntent: CallbackAction<CopyIntent>(
                onInvoke: (_) => _copyElement(),
              ),
              PasteIntent: CallbackAction<PasteIntent>(
                onInvoke: (_) => _pasteElement(),
              ),
              DeleteIntent: CallbackAction<DeleteIntent>(
                onInvoke: (_) => _deleteSelected(),
              ),
              UndoIntent: CallbackAction<UndoIntent>(
                onInvoke: (_) => context.read<SlideProvider>().undo(),
              ),
              RedoIntent: CallbackAction<RedoIntent>(
                onInvoke: (_) => context.read<SlideProvider>().redo(),
              ),
              AddSlideIntent: CallbackAction<AddSlideIntent>(
                onInvoke: (_) => context.read<SlideProvider>().addSlide(),
              ),
            },
            child: Consumer<SlideProvider>(
              builder: (ctx, provider, _) {
                final slide = provider.currentSlide;
                if (slide == null) {
                  return const Center(
                    child: Text(
                      'Tidak ada slide',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
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
                              if (el != null &&
                                  (el.type == ElementType.text ||
                                      el.type == ElementType.icon)) {
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
                              onDrawStrokesChanged: () =>
                                  _saveDrawStrokes(provider),
                              onElementTap: (id) => provider.selectElement(id),
                              onElementDragEnd: (id, x, y) =>
                                  provider.updateElementPosition(id, x, y),
                              onElementResizeEnd: (id, w, h) =>
                                  provider.updateElementSize(id, w, h),
                              onContentChange: (id, c) {
                                provider.updateElementContent(id, c);
                                provider.selectElement(null);
                              },
                              onStyleChange: (id, s) =>
                                  provider.updateElementStyle(id, s),
                              onEditingDone: () {
                                setState(() => _editingElementId = null);
                                provider.selectElement(null);
                              },
                              onElementDoubleTap: (id) {
                                final s = provider.currentSlide;
                                if (s == null) return;
                                final el = s.elements
                                    .where((e) => e.id == id)
                                    .firstOrNull;
                                if (el != null &&
                                    (el.type == ElementType.text ||
                                        el.type == ElementType.icon)) {
                                  TextEditorSheet.show(context, el);
                                }
                              },
                              onElementLongPress: (id) {
                                setState(() {
                                  _commentingElementId = id;
                                  _elementCommentCtrl.clear();
                                });
                              },
                              onSlideTap: () => provider.selectSlide(slide.id),
                              onRenderMetrics: (id, {double? contentHeight, double? overflowXPx}) {
                                provider.updateTextLayoutMetrics(id,
                                  contentHeight: contentHeight,
                                  overflowXPx: overflowXPx,
                                );
                              },
                              onCommentSubmit: _submitElementComment,
                              onCommentCancel: () =>
                                  setState(() => _commentingElementId = null),
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
                            onSlideChanged: (index) =>
                                _lastNotesSlideIndex = index,
                            onAddSlide: () => provider.addSlide(),
                            onDuplicateSlide: () => provider.duplicateSlide(),
                            onDeleteSlide: () => provider.deleteSlide(null),
                            onToggleHideSlide: () => provider.toggleHideSlide(),
                            onPresent: () => _showPresentDialog(provider),
                          ),
                          // Draw Toolbar
                          if (_drawActive &&
                              _drawCanvasKey.currentState != null)
                            DrawToolbar(
                              drawState: _drawCanvasKey.currentState!,
                              onClose: () {
                                setState(() {
                                  _drawActive = false;
                                  _drawCanvasKey.currentState?.setActive(false);
                                });
                              },
                            ),
                          // Editor Toolbar
                          EditorToolbar(
                            provider: provider,
                            drawActive: _drawActive,
                            onDrawToggle: () {
                              setState(() => _drawActive = !_drawActive);
                              if (_drawActive) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  _drawCanvasKey.currentState?.setActive(true);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '✏️ Mode coret aktif — coret di canvas',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              } else {
                                _drawCanvasKey.currentState?.setActive(false);
                              }
                            },
                            onSketchToDesign: () =>
                                _showSketchToDesignDialog(provider),
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
                                CircularProgressIndicator(
                                  color: AppTheme.primary,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Mengexport .pptx...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Tunggu sebentar ya',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
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
                                CircularProgressIndicator(
                                  color: AppTheme.primary,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Mengimport .pptx...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Membaca file...',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
          const SnackBar(
            content: Text('📋 Element disalin'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
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
        const SnackBar(
          content: Text('📋 Element ditempel'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
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
  void _saveDrawStrokes(SlideProvider provider) {
    final state = _drawCanvasKey.currentState;
    if (state == null || provider.currentSlide == null) return;

    final drawData = state.toDrawData();
    if (drawData == null) return;

    final slide = provider.currentSlide!;
    final existing = slide.elements
        .where((e) => e.type == ElementType.draw)
        .firstOrNull;

    if (existing != null) {
      existing.drawData = drawData;
      existing.bumpVersion();
      provider.notify();
    } else {
      provider.addElement(
        SlideElement(
          type: ElementType.draw,
          drawData: drawData,
          x: 0,
          y: 0,
          width: 1920,
          height: 1080,
        ),
      );
    }
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
    PresentationScreen.start(
      context,
      initialSlideIndex: provider.currentSlideIndex,
    );
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
            Text(
              '🎨 AI dari Coretan',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Coretan Anda akan dianalisis & dijadikan desain profesional.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: promptCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Prompt desain',
                hintText:
                    'Contoh: "Buat slide pitch deck clean, warna biru profesional"',
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
            child: Text(
              'Batal',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (promptCtrl.text.trim().isNotEmpty) {
                provider.generateFromSketch(promptCtrl.text.trim());
              }
            },
            child: Text('✨ Generate Desain'),
          ),
        ],
      ),
    );
  }

  // ── Share Dialog ──
  void _showShareDialog(SlideProvider provider) {
    final docId = provider.slides.isNotEmpty
        ? provider.slides.first.id
        : 'unknown';
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
      final title = _titleController.text.isNotEmpty
          ? _titleController.text
          : 'presentasi';
      final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '') + '.pptx';
      final exporter = PptxExporter(slides: provider.slides, title: title);
      await Future.delayed(const Duration(milliseconds: 50));

      if (kIsWeb) {
        final bytes = exporter.exportAsBytes();
        downloadBytes(safeTitle, bytes);
      } else {
        final bytes = exporter.exportAsBytes();
        final xfile = XFile.fromData(
          Uint8List.fromList(bytes),
          name: safeTitle,
          mimeType:
              'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        );
        await Share.shareXFiles([xfile], text: safeTitle);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '"$safeTitle" siap dibagikan (${provider.slides.length} slide)',
              ),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
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

      if (result != null &&
          (result.files.single.bytes != null ||
              result.files.single.path != null)) {
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
                content: Text(
                  '⚠️ ${importResult.warnings.length} catatan: ${importResult.warnings.first}',
                ),
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
                content: Text(
                  '📥 Berhasil import ${importResult.slides.length} slide dari .pptx',
                ),
                backgroundColor: AppTheme.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '⚠️ Gagal parse .pptx: file mungkin corrupt atau tidak didukung',
                ),
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

// ── Keyboard Shortcuts Intents ──
class CopyIntent extends Intent {
  const CopyIntent();
}

class PasteIntent extends Intent {
  const PasteIntent();
}

class DeleteIntent extends Intent {
  const DeleteIntent();
}

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

class AddSlideIntent extends Intent {
  const AddSlideIntent();
}
