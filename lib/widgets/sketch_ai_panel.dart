// DocuCraft — Sketch AI Panel (AI Coret)
// Semua interaksi lewat chat bubble - tidak ada UI hardcoded
// AI yang memulai percakapan, user balas via text input
// @see skills/workflows/sketch-to-design.md
// @see skills/SKILL.md

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/slide.dart';
import '../providers/slide_provider.dart';
import '../services/ai_generation.dart';
import '../services/api_client.dart';
import '../services/pptx_import.dart';
import '../services/quality_check.dart';
import '../services/svg_to_slide_elements.dart';
import '../themes/app_theme.dart';
import '../widgets/draw_canvas.dart';

class SketchAiPanel extends StatefulWidget {
  static void show(BuildContext context, {GlobalKey<DrawCanvasState>? drawCanvasKey}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SketchAiPanel(drawCanvasKey: drawCanvasKey),
    );
  }

  final GlobalKey<DrawCanvasState>? drawCanvasKey;

  const SketchAiPanel({super.key, this.drawCanvasKey});

  @override
  State<SketchAiPanel> createState() => _SketchAiPanelState();
}

class _SketchAiPanelState extends State<SketchAiPanel> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isGenerating = false;
  String _selectedModel = AiConfig.visionModel;

  @override
  void initState() {
    super.initState();
    // Auto-analisis saat panel dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _autoAnalyze();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Auto-analisis coretan dan kirim pesan pertama dari AI
  Future<void> _autoAnalyze() async {
    final key = widget.drawCanvasKey;
    if (key == null) return;
    final state = key.currentState;
    if (state == null || state.strokes.isEmpty) {
      _addAiMessage('Canvas kosong. Gambar coretan dulu di canvas, lalu buka AI Coret lagi.');
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // Capture gambar coretan
      final pngBytes = await state.captureToImage();
      if (pngBytes == null || pngBytes.isEmpty) {
        _addAiMessage('Gagal capture gambar coretan. Coba lagi.');
        return;
      }

      // Analisis coretan
      final analysis = _analyzeStrokes(state.strokes);

      // Kirim ke AI untuk analisis
      final result = await AiGenerationService.analyzeSketch(
        pngBytes,
        currentSlide: context.read<SlideProvider>().currentSlide,
        model: _selectedModel,
        canvasWidth: 380,
        canvasHeight: 214,
        basicAnalysis: analysis,
      );

      if (result.success && result.svg != null && result.svg!.isNotEmpty) {
        // AI menganalisis - tampilkan sebagai pesan AI
        _addAiMessage(result.svg!);
      } else if (result.question != null && result.question!.isNotEmpty) {
        // AI memberikan pertanyaan - tampilkan pertanyaan AI
        _addAiMessage(result.question!);
      } else {
        // Fallback - hanya jika AI tidak memberikan pertanyaan
        _addAiMessage(
          'Saya melihat coretan Anda: ${analysis['shapes'] ?? 'bentuk bebas'} '
          'di area ${analysis['bounds'] ?? 'tidak diketahui'}.\n\n'
          'Mohon berikan detail:\n'
          '1. Warna apa yang Anda inginkan?\n'
          '2. Style desain? (modern/minimalis/corporate)\n'
          '3. Elemen tambahan?'
        );
      }
    } catch (e) {
      _addAiMessage('Error: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  /// Analisis strokes secara lokal
  Map<String, dynamic> _analyzeStrokes(List<dynamic> strokes) {
    double minX = double.infinity, minY = double.infinity;
    double maxX = 0, maxY = 0;
    for (final stroke in strokes) {
      for (final point in stroke.points) {
        if (point[0] < minX) minX = point[0];
        if (point[1] < minY) minY = point[1];
        if (point[0] > maxX) maxX = point[0];
        if (point[1] > maxY) maxY = point[1];
      }
    }
    if (minX == double.infinity) minX = 0;
    if (minY == double.infinity) minY = 0;

    final boundsW = maxX - minX;
    final boundsH = maxY - minY;
    final aspect = boundsW > 0 ? boundsH / boundsW : 1;

    final shapes = <String>[];
    if (aspect > 0.8 && aspect < 1.2) {
      shapes.add(boundsW > 100 ? 'kotak/bulatan besar' : 'kotak kecil');
    } else if (aspect < 0.3) {
      shapes.add('garis horizontal');
    } else if (aspect > 3) {
      shapes.add('garis vertikal');
    } else if (boundsW > 150 && boundsH > 100) {
      shapes.add('content box');
    } else {
      shapes.add('bentuk bebas');
    }

    return {
      'shapes': shapes.join(', '),
      'bounds': '${boundsW.toInt()}x${boundsH.toInt()} px',
      'minX': minX,
      'minY': minY,
      'maxX': maxX,
      'maxY': maxY,
      'width': boundsW,
      'height': boundsH,
      'centerX': (minX + maxX) / 2,
      'centerY': (minY + maxY) / 2,
      'strokeCount': strokes.length,
    };
  }

  /// Handle kirim pesan user
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isGenerating) return;

    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text));
      _isGenerating = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      await _generateDesign(text);
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  /// Generate desain berdasarkan percakapan
  Future<void> _generateDesign(String userPrompt) async {
    final key = widget.drawCanvasKey;
    final state = key?.currentState;
    final hasStrokes = state != null && state.strokes.isNotEmpty;

    try {
      Uint8List? pngBytes;
      Map<String, dynamic>? sketchBounds;

      if (hasStrokes) {
        pngBytes = await state.captureToImage();
        sketchBounds = _analyzeStrokes(state.strokes);
      }

      const canvasWidth = 380;
      const canvasHeight = 214;

      final result = await AiGenerationService.sketchToDesignSvg(
        pngBytes ?? Uint8List(0),
        userPrompt,
        currentSlide: context.read<SlideProvider>().currentSlide,
        model: _selectedModel,
        canvasWidth: canvasWidth,
        canvasHeight: canvasHeight,
        sketchBounds: sketchBounds,
      );

      // DEBUG: Log AI response
      debugPrint('🎨 [SketchAI] Success: ${result.success}, SVG length: ${result.svg?.length ?? 0}');
      if (result.svg != null && result.svg!.isNotEmpty) {
        debugPrint('🎨 [SketchAI] SVG preview: ${result.svg!.substring(0, result.svg!.length > 300 ? 300 : result.svg!.length)}');
      }
      if (result.question != null) {
        debugPrint('🎨 [SketchAI] Question: ${result.question}');
      }
      if (result.error != null) {
        debugPrint('🎨 [SketchAI] Error: ${result.error}');
      }

      // Cek apakah AI balas dengan pertanyaan
      if (!result.success && result.question != null && result.question!.isNotEmpty) {
        _addAiMessage(result.question!);
        return;
      }

      if (result.success && result.svg != null && result.svg!.isNotEmpty) {
        var elements = SvgToSlideElements.parse(
          result.svg!,
          sourceCanvasWidth: canvasWidth,
          sourceCanvasHeight: canvasHeight,
        );

        // Quality check + auto-fix
        final qc = QualityChecker.check(elements);
        if (!qc.passed) {
          elements = QualityChecker.autoFix(elements, qc);
        }

        if (elements.isNotEmpty) {
          final provider = context.read<SlideProvider>();
          final currentSlide = provider.currentSlide;
          if (currentSlide != null) {
            currentSlide.elements.addAll(elements);
            provider.notify();
          }
          state?.clearAll();
          _addAiMessage(
            '✅ **Berhasil!** ${elements.length} elemen visual ditambahkan ke slide.\n\n'
            'Detail:\n'
            '• ${elements.where((e) => e.type == ElementType.text).length} teks\n'
            '• ${elements.where((e) => e.type == ElementType.shape).length} bentuk\n'
            '• ${elements.where((e) => e.type == ElementType.image).length} gambar'
          );
        } else {
          _addAiMessage('SVG parsed tapi tidak ada elemen valid. Coba dengan instruksi berbeda.');
        }
      } else {
        _addAiMessage('⚠️ Gagal generate: ${result.error ?? "tidak ada hasil"}');
      }
    } catch (e) {
      _addAiMessage('⚠️ Error: $e');
    }
  }

  /// Kirim JSON hasil coretan ke Gamma (text-only) → Gamma generate deck.
  Future<void> _generateViaGamma(String text) async {
    if (_isGenerating) return;
    final state = widget.drawCanvasKey?.currentState;
    if (state == null || state.strokes.isEmpty) {
      _addAiMessage('Canvas kosong. Gambar coretan dulu, lalu kirim lagi.');
      return;
    }

    final provider = context.read<SlideProvider>();

    setState(() {
      if (text.trim().isNotEmpty) {
        _messages.add(_ChatMessage(role: 'user', text: text));
      }
      _isGenerating = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final analysis = _analyzeStrokes(state.strokes);
      final prompt = AiGenerationService.buildGammaPromptFromSketch(
        analysis: analysis,
        userPrompt: text,
        canvasWidth: 380,
        canvasHeight: 214,
      );

      _addAiMessage('Mengirim sketsa ke Keqo...');

      final res = await GenOfficeClient().gammaGenerate(inputText: prompt);
      final ok = res['ok'] == true;
      final result = res['result'] as Map<String, dynamic>?;

      if (ok && result != null) {
        // 1) Kalau ada PPTX bytes, import langsung ke canvas.
        final pptxBase64 = res['pptxBase64'] as String?;
        if (pptxBase64 != null && pptxBase64.isNotEmpty) {
          final imported = PptxImporter.fromBytes(base64Decode(pptxBase64));
          if (imported != null && imported.slides.isNotEmpty) {
            provider.applyAiResult(imported.slides, replaceAll: true);
            _addAiMessage('✅ Deck muncul di canvas! ${imported.slides.length} slide dimuat.');
            return;
          }
        }
        // 2) Fallback: tampilkan link.
        final gammaUrl = result['gammaUrl'] as String?;
        final exportUrl = result['exportUrl'] as String?;
        final sb = StringBuffer('✅ Deck Pro siap!\n\n');
        if (gammaUrl != null) sb.writeln('Lihat hasil: $gammaUrl');
        if (exportUrl != null) sb.writeln('Download PPTX: $exportUrl');
        if (gammaUrl == null && exportUrl == null) sb.writeln('(tidak ada URL hasil)');
        _addAiMessage(sb.toString().trim());
      } else {
        _addAiMessage('⚠️ Gamma gagal: ${res['error'] ?? 'unknown'}');
      }
    } catch (e) {
      _addAiMessage('⚠️ Error: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  void _addAiMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(role: 'ai', text: text));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              _header(),
              // Messages
              Expanded(child: _messagesList()),
              // Input
              _buildInputBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withAlpha(12))),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.draw, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI Coret', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              Text('Interaktif - chat dengan AI', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _showModelPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary.withAlpha(50)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_selectedModel.split('/').last, style: const TextStyle(fontSize: 10, color: AppTheme.primary)),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more, size: 12, color: AppTheme.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messagesList() {
    if (_messages.isEmpty) {
      return const Center(
        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length + (_isGenerating ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i >= _messages.length) {
          return _typingIndicator();
        }
        return _chatBubble(_messages[i]);
      },
    );
  }

  Widget _chatBubble(_ChatMessage msg) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, size: 12, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.primary.withAlpha(20) : AppTheme.surface3,
                borderRadius: BorderRadius.circular(12),
                border: isUser ? Border.all(color: AppTheme.primary.withAlpha(40)) : null,
              ),
              child: Text(msg.text, style: TextStyle(fontSize: 11, color: isUser ? AppTheme.primary : AppTheme.textSecondary)),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: AppTheme.surface3,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person, size: 12, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _typingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome, size: 12, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface3,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text(_isGenerating ? 'AI sedang berpikir...' : '...', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withAlpha(12))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Ketik pesan... (mis: "warna biru modern")',
                hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                filled: true,
                fillColor: AppTheme.surface3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
              onSubmitted: (text) => _sendMessage(text),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _generateViaGamma(_controller.text),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primary.withAlpha(60)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: AppTheme.primary),
                  SizedBox(width: 4),
                  Text('Pro', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendMessage(_controller.text),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.send, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showModelPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface2,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pilih Model AI', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            _modelOption(AiConfig.visionModel, '👁️ Gemini Vision (default)'),
            _modelOption('oc/laguna-s-2.1-free', '⚡ Laguna (vision)'),
            _modelOption('kc/meituan/longcat-2.0-free', '🐱 Longcat (teks)'),
            _modelOption('kc/nvidia/nemotron-3-ultra-550b-a55f:free', '⭐ Nemotron (quality)'),
            _modelOption('Open-Code', '⚡ Open-Code (fast)'),
          ],
        ),
      ),
    );
  }

  Widget _modelOption(String id, String desc) {
    return ListTile(
      leading: Icon(Icons.smart_toy, color: _selectedModel == id ? AppTheme.primary : AppTheme.textMuted),
      title: Text(id, style: TextStyle(fontSize: 12, color: _selectedModel == id ? AppTheme.primary : AppTheme.textPrimary)),
      subtitle: Text(desc, style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
      onTap: () {
        setState(() => _selectedModel = id);
        Navigator.pop(context);
      },
    );
  }
}

class _ChatMessage {
  final String role; // 'user' atau 'ai'
  final String text;

  _ChatMessage({required this.role, required this.text});
}
