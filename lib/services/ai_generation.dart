// DocuCraft — AI Generation Service (SVG-based)
// Menghasilkan SVG dari prompt dan coretan, lalu di-parse menjadi SlideElements
// @see skills/workflows/ai-generation.md
// @see skills/SKILL.md

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import '../config/endpoints.dart';
import '../models/slide.dart';
import 'ai_errors.dart';
import 'skill_loader.dart';

/// Result of SVG generation from AI
class SvgGenerateResult {
  final bool success;
  final String? svg;
  final String? error;
  final String? question; // Pertanyaan dari AI jika prompt ambigu

  const SvgGenerateResult({required this.success, this.svg, this.error, this.question});
}

/// AI Provider configuration — mirrors Claude Code's multi-provider setup
class AiProvider {
  final String name;
  final String baseUrl;
  final String apiKey;
  final List<String> models;

  const AiProvider({
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.models,
  });
}

/// Configuration for the AI service
/// Mirrors Claude Code's tiered model system + GenOffice's generation model:
///   GenOffice uses `claude-opus-4-7` for generation, user model for chat
///   We use similar approach: generationModel for deck/page generation
class AiConfig {
  // GenOffice as primary AI backend (SRS: GenOffice = Brain, DocuCraft = Face)
  // Points to GenOffice HTTP server which proxies AI requests
  // Falls back to local AI proxy (127.0.0.1:20128/v1) if GenOffice unreachable
  // URL backend GenOffice terpusat di Endpoints (lib/config/endpoints.dart).
  static String get baseUrl => Endpoints.apiV1;

  /// Local AI proxy fallback — used when GenOffice server is unreachable
  static String get fallbackBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/proxy';
    }
    return 'http://127.0.0.1:20128/v1';
  }

  /// GenOffice HTTP server — provides higher-quality AI-generated outlines and SVG slides.
  static String get genOfficeBaseUrl => Endpoints.backend;

  /// API key untuk panggilan AI LANGSUNG (fallback 127.0.0.1:20128).
  /// Frontend TIDAK menyimpan key — isi saat build via:
  ///   flutter run --dart-define=AI_API_KEY=sk-...
  /// Request ke backend GenOffice (port 3001) tidak butuh key di sisi client;
  /// key + gammaApiKey disimpan di server (ai-settings.json GenOffice).
  static String get apiKey => const String.fromEnvironment(
    'AI_API_KEY',
    defaultValue: '',
  );

  // ── Model Tiers (synced with Claude Code config) ──
  /// Haiku tier — fast, cheap (routing, simple tasks)
  static const String fastModel = 'oc/mimo-v2.5-free';

  /// Sonnet tier — balanced quality (Claude Opus thinking via local proxy)
  static const String qualityModel = 'ag/claude-opus-4-6-thinking';

  /// Opus tier — powerful (DeepSeek Chat, flagship)
  static const String powerfulModel = 'deepseek-chat';

  /// Fable tier — reasoning (Ultra 550B, deepest thinking)
  static const String reasoningModel = 'kc/nvidia/nemotron-3-ultra-550b-a55b:free';

  /// Vision model
  static const String visionModel = 'gc/gemini-3-flash-preview';

  /// Claude tier — Anthropic via local proxy (127.0.0.1:20128)
  static const String claudeModel = 'ag/claude-opus-4-6-thinking';

  // ── GenOffice-style: Dedicated generation model ──
  /// Generation model — used for deck/page generation
  /// Uses Fable tier (Ultra 550B) for complex generation tasks
  static const String generationModel = 'kc/nvidia/nemotron-3-ultra-550b-a55b:free';

  /// Chat model — used for conversational AI (user-configurable)
  static String chatModel = qualityModel;

  // ── Aliases for backward compatibility ──
  static String get freeModel => fastModel;
  static String get longcatModel => reasoningModel;

  /// Fallback chain: fast → quality → powerful → reasoning → claude → vision
  static const List<String> fallbackModels = [
    fastModel,
    qualityModel,
    powerfulModel,
    reasoningModel,
    claudeModel,
    visionModel,
  ];

  /// Generation fallback chain (prioritizes quality for generation)
  static const List<String> generationFallbackModels = [
    generationModel,  // Fable Ultra 550B first for generation
    powerfulModel,    // DeepSeek V4 Pro as secondary
    qualityModel,
    fastModel,
  ];

  static const int maxTokens = 8192;
  static const int generationMaxTokens = 16384;  // Higher for generation tasks

  // ── Provider Registry (Claude Code-style multi-provider) ──
  static const localProxy = AiProvider(
    name: 'local-proxy',
    baseUrl: 'http://127.0.0.1:20128/v1',
    apiKey: '',  // Tidak ada key di kode — isi via --dart-define=AI_API_KEY
    models: [
      'oc/mimo-v2.5-free',
      'ag/claude-opus-4-6-thinking',
      'kc/nvidia/nemotron-3-ultra-550b-a55b:free',
      'kc/nvidia/nemotron-3-super-120b-a12b:free',
      'gc/gemini-3-flash-preview',
    ],
  );

  static const openrouter = AiProvider(
    name: 'openrouter',
    baseUrl: 'https://openrouter.ai/api/v1',
    apiKey: '',  // User must set via settings
    models: [
      'deepseek/deepseek-chat',
      'deepseek/deepseek-r1',
      'anthropic/claude-opus-4-6',
      'nvidia/nemotron-3-ultra-550b:free',
      'google/gemini-3-flash-preview',
    ],
  );

  static const deepseek = AiProvider(
    name: 'deepseek',
    baseUrl: 'https://api.deepseek.com',
    apiKey: '',  // User must set via settings
    models: [
      'deepseek-chat',
      'deepseek-reasoner',
    ],
  );

  static const anthropic = AiProvider(
    name: 'anthropic',
    baseUrl: 'https://api.anthropic.com',
    apiKey: '',  // User must set via settings
    models: [
      'claude-opus-4-6',
      'claude-sonnet-4-5',
      'claude-haiku-4-5-20251001',
    ],
  );

  /// All registered providers
  static const List<AiProvider> providers = [
    localProxy,
    openrouter,
    deepseek,
    anthropic,
  ];

  /// Resolve which provider to use for a given model ID.
  /// Returns the first provider whose `models` list contains the model,
  /// falling back to [localProxy].
  static AiProvider resolveProvider(String modelId) {
    for (final p in providers) {
      if (p.models.contains(modelId)) return p;
    }
    return localProxy;
  }
}

/// Rate limiter
class _RateLimiter {
  static const int _maxRequestsPerMinute = 10;
  static final List<DateTime> _requestTimes = [];

  Duration get waitTime {
    final now = DateTime.now();
    _requestTimes.removeWhere((t) => now.difference(t).inMinutes >= 1);
    if (_requestTimes.length >= _maxRequestsPerMinute) {
      final oldest = _requestTimes.first;
      return Duration(minutes: 1) - now.difference(oldest);
    }
    return Duration.zero;
  }

  void recordRequest() {
    _requestTimes.add(DateTime.now());
  }
}

final _rateLimiter = _RateLimiter();

/// AI Generation Service
class AiGenerationService {
  // ── Public API ──

  /// Generate SVG from sketch image (vision AI)
  static Future<SvgGenerateResult> sketchToDesignSvg(
    Uint8List sketchPng,
    String userPrompt, {
    Slide? currentSlide,
    String? model,
    int canvasWidth = 1920,
    int canvasHeight = 1080,
    Map<String, dynamic>? sketchBounds,
  }) async {
    final systemPrompt = _buildSketchToDesignVisionPrompt(canvasWidth: canvasWidth, canvasHeight: canvasHeight);
    final userMessage = _buildSketchUserMessage(sketchPng, userPrompt, currentSlide, canvasWidth, canvasHeight, sketchBounds: sketchBounds);
    final String? response = await _executeVisionWithFallbackSvg(
      systemPrompt: systemPrompt,
      userContent: userMessage,
      preferredModel: model,
      operationName: 'sketchToDesignSvg',
    );

    // Cek apakah response adalah SVG
    if (response != null && response.isNotEmpty) {
      if (response.trimLeft().startsWith('<svg')) {
        return SvgGenerateResult(success: true, svg: response);
      } else {
        // AI return pertanyaan (bukan SVG)
        return SvgGenerateResult(success: false, question: response);
      }
    }
    return const SvgGenerateResult(success: false, error: 'AI tidak menghasilkan SVG');
  }

  /// Analyze sketch and return description (for interactive flow)
  static Future<SvgGenerateResult> analyzeSketch(
    Uint8List sketchPng, {
    Slide? currentSlide,
    String? model,
    int canvasWidth = 380,
    int canvasHeight = 214,
    Map<String, dynamic>? basicAnalysis,
  }) async {
    final systemPrompt = _buildSketchAnalysisPrompt(canvasWidth: canvasWidth, canvasHeight: canvasHeight);
    final userMessage = _buildAnalysisUserMessage(sketchPng, currentSlide, canvasWidth, canvasHeight, basicAnalysis: basicAnalysis);

    // Use vision model with fallback chain
    final waitTime = _rateLimiter.waitTime;
    if (waitTime > Duration.zero) {
      await Future.delayed(waitTime);
    }

    String? responseText;
    Object? lastError;

    for (final modelName in _visionFallbackChain(model)) {
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          debugPrint('🔄 Analyze: mencoba model $modelName (attempt ${attempt + 1})');
          final resp = await _callVision(modelName, systemPrompt, userMessage);
          if (resp != null && resp.isNotEmpty) {
            responseText = resp;
            debugPrint('✅ Analyze: model $modelName berhasil (${responseText!.length} chars)');
            debugPrint('🔍 [AI] Analisis: ${responseText!.substring(0, responseText!.length > 200 ? 200 : responseText!.length)}');
            break;
          }
        } catch (e) {
          lastError = e;
          debugPrint('❌ Analyze: model $modelName gagal (attempt ${attempt + 1}) → $e');
          if (e.toString().contains('Failed to fetch') || e.toString().contains('CORS')) {
            break;
          }
          if (attempt < 2) {
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }
      if (responseText != null) break;
    }

    if (responseText != null && responseText.isNotEmpty) {
      return SvgGenerateResult(success: true, svg: responseText);
    }
    return SvgGenerateResult(success: false, error: 'AI tidak dapat menganalisis coretan: ${lastError ?? "unknown"}');
  }

  /// Generate SVG from sketch stroke data (fallback for non-vision)
  static Future<SvgGenerateResult> generateFromSketchSvg(
    Map<String, dynamic> sketchData,
    String prompt, {
    Slide? currentSlide,
    String? model,
    int canvasWidth = 1920,
    int canvasHeight = 1080,
  }) async {
    final systemPrompt = _buildSketchToDesignVisionPrompt(canvasWidth: canvasWidth, canvasHeight: canvasHeight);
    final regions = sketchData['regions'] as List? ?? [];
    final shapeDescriptions = <String>[];
    for (final region in regions) {
      final type = region['type'] as String? ?? 'unknown';
      final bounds = region['bounds'] as Map<String, dynamic>? ?? {};
      final width = (bounds['width'] as num?)?.toDouble() ?? 0;
      final height = (bounds['height'] as num?)?.toDouble() ?? 0;
      final x = (bounds['x'] as num?)?.toDouble() ?? 0;
      final y = (bounds['y'] as num?)?.toDouble() ?? 0;
      final aspect = width > 0 ? height / width : 0;
      String shapeName = type;
      if (aspect > 0.8 && aspect < 1.2) {
        shapeName = (width > 100 && height > 100) ? 'kotak/bulatan besar' : 'kotak kecil';
      } else if (aspect < 0.2) {
        shapeName = 'garis horizontal (divider)';
      } else if (aspect > 5) {
        shapeName = 'garis vertikal';
      } else if (width > 300 && height > 100) {
        shapeName = 'content box';
      }
      shapeDescriptions.add('$shapeName di posisi (${x.toInt()}, ${y.toInt()}) ukuran ${width.toInt()}x${height.toInt()}');
    }

    final String shapeContext = shapeDescriptions.isNotEmpty
        ? 'BENTUK FISIK CORETAAN:\n${shapeDescriptions.map((d) => '• $d').join('\n')}\n\n'
        : '';

    final userPrompt = 'User menggambar coretan di canvas ${canvasWidth}×${canvasHeight}. ${shapeContext}User instruksi: "$prompt"\n\nBuat SVG yang MIRIP bentuk fisik coretan.\nPosisi dan ukuran elemen harus sesuai dengan posisi coretan di canvas (${canvasWidth}x${canvasHeight}).\nOutput HANYA SVG valid, tidak ada teks lain!';

    final svgText = await _executeWithFallbackSvg(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      preferredModel: model,
      operationName: 'generateFromSketchSvg',
    );

    if (svgText != null && svgText.isNotEmpty) {
      return SvgGenerateResult(success: true, svg: svgText);
    }
    return const SvgGenerateResult(success: false, error: 'AI tidak menghasilkan SVG');
  }

  /// Build a Gamma `inputText` from the sketch's structured JSON (local
  /// geometric analysis) + the user's design intent. Gamma is text-only, so we
  /// serialize the sketch's shapes/positions/size into a natural-language
  /// layout description that Gamma can turn into a deck.
  static String buildGammaPromptFromSketch({
    required Map<String, dynamic> analysis,
    required String userPrompt,
    int canvasWidth = 1920,
    int canvasHeight = 1080,
  }) {
    final shapes = (analysis['shapes'] as String?) ?? 'bentuk bebas';
    final width = (analysis['width'] as num?)?.toInt() ?? 0;
    final height = (analysis['height'] as num?)?.toInt() ?? 0;
    final centerX = (analysis['centerX'] as num?)?.toInt() ?? 0;
    final centerY = (analysis['centerY'] as num?)?.toInt() ?? 0;
    final strokeCount = analysis['strokeCount'] ?? 0;

    final sb = StringBuffer();
    sb.writeln('Buat desain presentasi yang mengikuti layout sketsa user berikut:');
    sb.writeln('- Bentuk terdeteksi: $shapes');
    sb.writeln('- Ukuran area sketsa: ${width}x${height} px (pada canvas ${canvasWidth}x${canvasHeight} px)');
    sb.writeln('- Posisi pusat sketsa: ($centerX, $centerY)');
    sb.writeln('- Jumlah coretan: $strokeCount');
    if (userPrompt.trim().isNotEmpty) {
      sb.writeln();
      sb.writeln('Instruksi user: "$userPrompt"');
    }
    sb.writeln();
    sb.writeln('Pertahankan struktur/posisi elemen sesuai sketsa, lalu isi dengan konten nyata dan warna/style sesuai instruksi user.');
    return sb.toString().trim();
  }

  /// Get system prompt for SVG generation
  /// Combines routing context + generation instructions in one prompt
  static Future<String> _getSkillSystemPrompt() async {
    try {
      final strategist = await SkillLoader.load('references/strategist.md');
      final executor = await SkillLoader.load('references/executor.md');

      return '''
You are an expert presentation designer AI. Create attractive and COMPLEX presentation designs based on user instructions.

## AVAILABLE WORKFLOWS (detect from user intent):
- **generate-pptx**: Create new presentation from topic/text (DEFAULT for most requests)
- **create-template**: Create reusable Brand/Style/Layout/Deck template
- **fill-pptx**: Fill existing PPTX template with new content
- **enhance-pptx**: Add notes, audio, transitions to existing PPTX
- **quick-generate**: Fast generation without interaction gates
- **sketch-to-design**: Convert hand-drawn sketch to professional design

For most "buat presentasi/ppt" requests, use generate-pptx workflow.

## KEY RULES
- Canvas size: 1920x1080
- Font size: 40-48 for titles, 16-24 for body text
- Use requested colors or defaults (indigo #6366F1, pink #EC4899, white #FFFFFF)
- Output ONLY valid SVG, no other text or markdown!
- SVG width="1920" height="1080"
- Do NOT create background rect (first element should not be full canvas rect)
- Text MUST contain REAL content about the requested topic, NOT placeholders!
- Minimum 6-8 elements per design

## FOR AMBIGUOUS PROMPTS
If the user gives an unclear prompt (e.g., "make design", "improve", "fix"), ASK the user first about topic, colors, style, slide count. Do NOT generate SVG.

## FOR CLEAR PROMPTS
If the user gives a detailed prompt (e.g., "create 5 slides about marketing strategy, blue professional, modern style"), generate SVG immediately.

## REQUIRED ELEMENTS
- Large attractive title text (font-size 48-64)
- Subtitle/body text (font-size 20-32)
- Bullet points or lists
- Decorative shapes (rect, ellipse, polygon) as accents
- Varied element positions (top, center, bottom, left, right)
- Harmonious color variety

## SVG ELEMENTS TO USE
- <text x=".." y=".." font-size=".." fill=".." font-weight="bold">Title</text>
- <rect x=".." y=".." width=".." height=".." fill=".." rx="12"/>
- <ellipse cx=".." cy=".." rx=".." ry=".." fill=".."/>
- <polygon points="x1,y1 x2,y2 x3,y3" fill=".."/>

## MANDATORY
1. Use colors as requested by user
2. Minimum 6-8 elements per design
3. Text MUST contain REAL content about the topic
4. Create elements as requested
5. No background rect (except for full gradient background)
6. ONLY SVG — no markdown, explanation, or other text

---
Reference: Strategist Role
$strategist

---
Reference: Executor Role
$executor
''';
    } catch (e) {
      debugPrint('⚠️ Failed to load skill system prompt: $e');
      return '''
You are an expert presentation designer AI. Create attractive and COMPLEX presentation designs based on user instructions.

KEY RULES:
- Canvas size: 1920x1080
- Font size: 40-48 for titles, 16-24 for body text
- Use requested colors or defaults (indigo #6366F1, pink #EC4899, white #FFFFFF)
- Output ONLY valid SVG, no other text or markdown!
- SVG width="1920" height="1080"
- Do NOT create background rect (first element should not be full canvas rect)
- Text MUST contain REAL content about the requested topic, NOT placeholders!
- Minimum 6-8 elements per design

FOR AMBIGUOUS PROMPTS:
If the user gives an unclear prompt (e.g., "make design", "improve", "fix"), ASK the user first about topic, colors, style, slide count. Do NOT generate SVG.

FOR CLEAR PROMPTS:
If the user gives a detailed prompt (e.g., "create 5 slides about marketing strategy, blue professional, modern style"), generate SVG immediately.

REQUIRED ELEMENTS:
- Large attractive title text (font-size 48-64)
- Subtitle/body text (font-size 20-32)
- Bullet points or lists
- Decorative shapes (rect, ellipse, polygon) as accents
- Varied element positions (top, center, bottom, left, right)
- Harmonious color variety

SVG ELEMENTS TO USE:
- <text x=".." y=".." font-size=".." fill=".." font-weight="bold">Title</text>
- <rect x=".." y=".." width=".." height=".." fill=".." rx="12"/>
- <ellipse cx=".." cy=".." rx=".." ry=".." fill=".."/>
- <polygon points="x1,y1 x2,y2 x3,y3" fill=".."/>

MANDATORY:
1. Use colors as requested by user
2. Minimum 6-8 elements per design
3. Text MUST contain REAL content about the topic
4. Create elements as requested
5. No background rect (except for full gradient background)
6. ONLY SVG — no markdown, explanation, or other text
''';
    }
  }

  /// Generate SVG — single call with routing context included
  static Future<SvgGenerateResult> generateFromPrompt(
    String prompt, {
    Slide? currentSlide,
    String? model,
  }) async {
    // Try GenOffice server first for chat completions
    if (await genOfficeAvailable()) {
      debugPrint('🔄 generateFromPrompt: using GenOffice server (chat/completions)');
      try {
        final systemPrompt = await _getSkillSystemPrompt();
        final baseUrl = await _getAvailableBaseUrl(model: model);
        final uri = Uri.parse('$baseUrl/chat/completions');
        final response = await http.post(uri, headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AiConfig.resolveProvider(model ?? '').apiKey.isNotEmpty ? AiConfig.resolveProvider(model ?? '').apiKey : AiConfig.apiKey}',
        }, body: jsonEncode({
          'model': model ?? AiConfig.qualityModel,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': 'Instruksi user: "$prompt"\n\nCanvas size: 1920×1080.\nBuat desain PRESENTASI yang MENARIK dan KOMPLEKS sesuai instruksi user.\nOutput HANYA SVG valid, tidak ada teks lain!'},
          ],
          'max_tokens': AiConfig.generationMaxTokens,
          'temperature': 0.7,
          'stream': false,
        })).timeout(const Duration(minutes: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final message = choices[0]['message'] as Map<String, dynamic>?;
            if (message != null) {
              final content = message['content'] as String? ?? '';
              if (content.isNotEmpty) {
                // Check if response is SVG
                if (content.trimLeft().startsWith('<svg')) {
                  debugPrint('✅ GenOffice chat generated SVG (${content.length} chars)');
                  return SvgGenerateResult(success: true, svg: content);
                }
                // Try to extract SVG from response
                final svgMatch = RegExp(r'<svg[\s\S]*?</svg>', multiLine: true).firstMatch(content);
                if (svgMatch != null) {
                  debugPrint('✅ GenOffice chat extracted SVG (${svgMatch.group(0)!.length} chars)');
                  return SvgGenerateResult(success: true, svg: svgMatch.group(0));
                }
                // Not SVG - return as question/text
                debugPrint('⚠️ GenOffice chat returned non-SVG (${content.length} chars)');
                return SvgGenerateResult(success: false, question: content);
              }
            }
          }
        }
        debugPrint('⚠️ GenOffice chat/completions failed (${response.statusCode}), falling back to local AI');
      } catch (e) {
        debugPrint('⚠️ GenOffice chat error: $e, falling back to local AI');
      }
    }

    final systemPrompt = await _getSkillSystemPrompt();

    const canvasWidth = 1920;
    const canvasHeight = 1080;

    final textPart = StringBuffer();
    textPart.writeln('Instruksi user: "$prompt"');
    textPart.writeln('Canvas size: ${canvasWidth}×${canvasHeight}.');
    textPart.writeln('Buat desain PRESENTASI yang MENARIK dan KOMPLEKS sesuai instruksi user.');
    textPart.writeln('PASTIKAN teks berisi konten nyata tentang topik yang diminta, bukan placeholder!');

    final String? response = await _executeWithFallbackSvg(
      systemPrompt: systemPrompt,
      userPrompt: textPart.toString().trim(),
      preferredModel: model,
      operationName: 'generateFromPrompt',
      skipRateLimit: true, // Page generation should not be rate-limited
    );

    // Cek apakah response adalah SVG
    if (response != null && response.isNotEmpty) {
      debugPrint('🔍 [AI] Response type: ${response.trimLeft().startsWith('<svg') ? 'SVG' : 'NON-SVG (length: ${response.length})'}');
      debugPrint('🔍 [AI] Response preview: ${response.substring(0, response.length > 300 ? 300 : response.length)}');

      if (response.trimLeft().startsWith('<svg')) {
        return SvgGenerateResult(success: true, svg: response);
      } else {
        // Coba cari SVG di dalam response (kalau AI wrap di markdown code block)
        final svgMatch = RegExp(r'<svg[\s\S]*?</svg>', multiLine: true).firstMatch(response);
        if (svgMatch != null) {
          debugPrint('✅ [AI] Found SVG inside response (length: ${svgMatch.group(0)!.length})');
          return SvgGenerateResult(success: true, svg: svgMatch.group(0));
        }

        // AI return pertanyaan (bukan SVG)
        debugPrint('⚠️ [AI] Response is not SVG and no SVG found inside');
        return SvgGenerateResult(success: false, question: response);
      }
    }
    debugPrint('❌ [AI] No response from model');
    return const SvgGenerateResult(success: false, error: 'AI tidak menghasilkan SVG');
  }

  /// Generate image (stub - not yet implemented)
  static Future<String?> generateImage({required String prompt}) async {
    return null;
  }

  /// Search stock images (stub - not yet implemented)
  static Future<List<String>> searchStockImages({required String query, required String provider}) async {
    return [];
  }

  /// Generate outline for multi-slide presentation
  static Future<List<String>> generateOutline(String topic, {int slideCount = 5}) async {
    // Try GenOffice server first (higher quality AI)
    if (await genOfficeAvailable()) {
      debugPrint('🔄 generateOutline: using GenOffice server');
      final result = await callGenOfficeOutline(topic, slideCount: slideCount);
      if (result != null && result.length >= 2) {
        debugPrint('✅ GenOffice outline: ${result.length} slides');
        return result;
      }
      debugPrint('⚠️ GenOffice outline failed, falling back to local AI');
    }

    final systemPrompt = '''
You are a presentation strategist. Given a topic, generate a logical outline for a presentation.
Output EXACTLY one slide title per line. No numbers, no bullets, no extra text.
Example:
Introduction
Key Benefits
Market Analysis
Implementation Strategy
Conclusion
''';

    final userPrompt = 'Topic: "$topic"\nNumber of slides: $slideCount\nGenerate a clear, logical outline.';

    try {
      final response = await _executeWithFallbackSvg(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        preferredModel: AiConfig.freeModel,
        operationName: 'generateOutline',
      );

      if (response != null && response.isNotEmpty) {
        return response
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty && !line.startsWith('<'))
            .toList();
      }
    } catch (e) {
      debugPrint('⚠️ generateOutline failed: $e');
    }

    // Fallback: generate simple outline
    return [
      'Introduction to $topic',
      'Key Concepts',
      'Benefits & Advantages',
      'Practical Applications',
      'Case Studies',
      'Implementation',
      'Conclusion',
    ].take(slideCount).toList();
  }

  /// Generate multiple slides for a presentation
  static Future<List<SvgGenerateResult>> generateMultipleSlides(
    List<String> slideTitles, {
    String topic = '',
    String style = 'modern',
    String colorScheme = 'indigo',
    String? model,
  }) async {
    final results = <SvgGenerateResult>[];
    final useGenOffice = await genOfficeAvailable();

    for (int i = 0; i < slideTitles.length; i++) {
      final title = slideTitles[i];
      debugPrint('🔄 Generating slide ${i + 1}/${slideTitles.length}: $title');

      SvgGenerateResult result;

      if (useGenOffice) {
        // Use GenOffice with structured context (index, total, prev/next)
        final svg = await callGenOfficeSlide(
          topic: topic.isNotEmpty ? topic : title,
          title: title,
          style: style,
          color: colorScheme,
          index: i,
          total: slideTitles.length,
          previousTitle: i > 0 ? slideTitles[i - 1] : null,
          nextTitle: i < slideTitles.length - 1 ? slideTitles[i + 1] : null,
        );
        result = svg != null
            ? SvgGenerateResult(success: true, svg: svg)
            : const SvgGenerateResult(success: false, error: 'Gagal membuat slide');
      } else {
        // Fallback to local AI
        final prompt = '''
Slide ${i + 1} of ${slideTitles.length}
Topic: $topic
Slide Title: $title
Style: $style
Color: $colorScheme
Context: This is slide ${i + 1} in a ${slideTitles.length}-slide presentation about "$topic".
${i > 0 ? 'Previous slide: ${slideTitles[i - 1]}' : ''}
${i < slideTitles.length - 1 ? 'Next slide: ${slideTitles[i + 1]}' : ''}

Create a complete, visually appealing slide for "$title".
''';
        result = await generateFromPrompt(prompt, model: model);
      }

      results.add(result);

      // Small delay between slides to avoid rate limiting
      if (i < slideTitles.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    return results;
  }

  /// Generate single slide (stub - not yet implemented)
  static Future<SvgGenerateResult> generateSingleSlide(String topic) async {
    return const SvgGenerateResult(success: false, error: 'Not implemented');
  }

  // ── System Prompts ──

  static String _buildSketchToDesignVisionPrompt({int canvasWidth = 1920, int canvasHeight = 1080}) => '''
Anda adalah AI designer presentasi expert. User menggambar coretan di kanvas dan Anda harus membuat desain PRESENTASI yang MENARIK dan KOMPLEKS berdasarkan coretan.

TUGAS UTAMA:
1. Lihat gambar coretan user
2. Baca koordinat coretan yang diberikan (bounds: x, y, width, height)
3. Buat desain PRESENTASI yang MENARIK — bukan hanya bangun datar sederhana!

ATURAN PENTING:
- Canvas size: ${canvasWidth}×${canvasHeight}
- Font size: ${(canvasWidth / 1920 * 40).round()}-${(canvasWidth / 1920 * 48).round()} untuk judul, ${(canvasWidth / 1920 * 16).round()}-${(canvasWidth / 1920 * 24).round()} untuk body text
- Warna: gunakan warna sesuai permintaan user atau default (indigo #6366F1, pink #EC4899, putih #FFFFFF)
- Output HANYA SVG valid, tidak ada teks lain, tidak ada markdown!
- SVG width="$canvasWidth" height="$canvasHeight"
- JANGAN buat background rect (elemen pertama jangan rect full canvas)

BATASAN UKURAN KETAT:
- SEMUA elemen HARUS berada dalam canvas ${canvasWidth}×${canvasHeight}
- x + width TIDAK BOLEH lebih dari $canvasWidth
- y + height TIDAK BOLEH lebih dari $canvasHeight
- x dan y TIDAK BOLEH negatif
- Jika ingin buat elemen besar, pastikan muat dalam canvas
- Lebar teks = panjang karakter × font-size × 0.6
- Tinggi teks = font-size × 1.5
- Pastikan teks tidak keluar dari canvas!

YANG HARUS DIBUKAN:
- JANGAN hanya buat 1 bangun datar sederhana!
- Buat desain yang terdiri dari BANYAK ELEMEN:
  - Teks judul yang menarik
  - Teks body/subtitle
  - Shape dekoratif (rect, ellipse, polygon)
  - Elemen visual tambahan
- Posisi elemen harus bervariasi (tidak hanya di satu tempat)
- Gunakan warna yang bervariasi dan harmonis

UKURAN DAN LOKASI:
- Canvas: 1920×1080 (slide design space)
- Gunakan koordinat absolut yang proporsional
- JANGAN gunakan koordinat kecil (380×214) — itu ukuran canvas coretan, bukan slide!
- Contoh posisi yang baik:
  - Judul: di atas (y=100-200), tengah (x=100-500)
  - Konten: di tengah (y=300-700)
  - Shape dekoratif: di samping atau belakang teks
- Pastikan semua elemen muat dalam 1920×1080
- Elemen harus proporsional — jangan ada yang terlalu besar atau terlalu kecil

CONTOH DESAIN YANG BAIK:
<svg width="1920" height="1080" xmlns="http://www.w3.org/2000/svg">
  <rect x="100" y="100" width="800" height="100" fill="#6366F1" rx="12"/>
  <text x="150" y="165" font-size="64" fill="#FFFFFF" font-weight="bold">Judul Presentasi</text>
  <rect x="100" y="300" width="600" height="400" fill="#32353a" rx="16"/>
  <ellipse cx="1100" cy="500" rx="250" ry="250" fill="#EC4899"/>
  <text x="150" y="400" font-size="32" fill="#FFFFFF">Konten di sini</text>
  <text x="1000" y="520" font-size="28" fill="#FFFFFF">Shape Dekoratif</text>
</svg>

ATURAN BENTUK CORETAN:
- IKUTI bentuk asli coretan user, jangan terpaku pada kotak/lingkaran
- Analisis gambar coretan secara visual
- Deteksi bentuk: garis, lengkung, sudut, lingkaran, kotak, panah, teks tulisan tangan, hati/love, bintang, segitiga, gelombang, bentuk bebas, dll
- Jika user coret bentuk hati/love, buat elemen berbentuk hati
- Jika user coret bentuk bintang, buat elemen berbentuk bintang
- Jika user coret bentuk gelombang, buat elemen berbentuk gelombang
- Pahami MAKNA bentuk: hati = cinta/love, bintang = rating/kualitas, panah = arah/flow, dll

ELEMEN SVG:
- <text x=".." y=".." font-size=".." fill=".." font-weight="bold">Judul</text>
- <rect x=".." y=".." width=".." height=".." fill=".." rx="12"/>
- <ellipse cx=".." cy=".." rx=".." ry=".." fill=".."/>
- <polygon points="x1,y1 x2,y2 x3,y3" fill=".."/>
- <line x1=".." y1=".." x2=".." y2=".." stroke=".." stroke-width=".."/>
- <circle cx=".." cy=".." r=".." fill=".."/>

ATURAN KOORDINAT:
- x, y = posisi kiri-atas elemen (harus di dalam area coretan user)
- width, height = ukuran elemen (jangan melebihi area coretan)
- Untuk ellipse: cx, cy = pusat, rx, ry = radius
- Untuk text: y = baseline (bukan top)

ATURAN WAJIB:
1. Posisi elemen harus sesuai posisi coretan di canvas (koordinat yang diberikan)
2. Ukuran elemen harus proporsional dengan ukuran coretan
3. Warna — gunakan warna sesuai permintaan user atau default
4. MINIMAL 4-5 elemen dalam satu desain!
4. Jumlah elemen — sesuaikan dengan jumlah bentuk coretan
5. Teks — jika ada tulisan di coretan, baca dan masukkan ke elemen text
6. Shape — buat elemen shape yang sesuai bentuk coretan user
7. JANGAN buat background rect
8. HANYA SVG — tidak ada markdown, penjelasan, atau teks lain
9. JANGAN generate elemen di luar area coretan user!
''';

  static List<Map<String, dynamic>> _buildSketchUserMessage(
  Uint8List sketchPng,
  String userPrompt,
  Slide? currentSlide,
  int canvasWidth,
  int canvasHeight, {
  Map<String, dynamic>? sketchBounds,
}) {
    final b64 = base64Encode(sketchPng);
    final textPart = StringBuffer();
    textPart.writeln('Berikut adalah coretan pengguna (PNG). Canvas size: ${canvasWidth}×${canvasHeight}.');

    // Kirim koordinat coretan agar AI tahu posisi pasti
    if (sketchBounds != null) {
      textPart.writeln('');
      textPart.writeln('KOORDINAT CORETAN USER (HARUS DI-GUNAKAN):');
      textPart.writeln('- Area coretan: x=${sketchBounds['minX']?.toInt()} hingga ${sketchBounds['maxX']?.toInt()}, y=${sketchBounds['minY']?.toInt()} hingga ${sketchBounds['maxY']?.toInt()}');
      textPart.writeln('- Lebar coretan: ${sketchBounds['width']?.toInt()}px, Tinggi coretan: ${sketchBounds['height']?.toInt()}px');
      textPart.writeln('- Posisi pusat: cx=${sketchBounds['centerX']?.toInt()}, cy=${sketchBounds['centerY']?.toInt()}');
      textPart.writeln('- Jumlah stroke: ${sketchBounds['strokeCount']}');
      textPart.writeln('');
      textPart.writeln('BUAT ELEMEN SVG DI AREA INI! Jangan buat elemen di luar koordinat coretan!');
    }

    textPart.writeln('Instruksi pengguna: "$userPrompt"');
    if (currentSlide != null) {
      textPart.writeln('Current slide context: layout=${currentSlide.layoutId}, title="${currentSlide.title}"');
    }

    // Debug log
    debugPrint('🎨 [SketchAI] Kirim ke AI:');
    debugPrint('🎨 [SketchAI] - Gambar: ${sketchPng.length} bytes');
    debugPrint('🎨 [SketchAI] - Bounds: $sketchBounds');
    debugPrint('🎨 [SketchAI] - Prompt: $userPrompt');

    return [
      {'type': 'text', 'text': textPart.toString().trim()},
      {'type': 'image_url', 'image_url': {'url': 'data:image/png;base64,$b64'}},
    ];
  }

  /// Build system prompt for sketch analysis (interactive flow)
  static String _buildSketchAnalysisPrompt({int canvasWidth = 1920, int canvasHeight = 1080}) => '''
Anda adalah AI designer presentasi expert dengan kemampuan VISI untuk melihat gambar coretan user.

TUGAS:
1. LIHAT gambar coretan user dengan teliti
2. Identifikasi BENTUK coretan:
   - Garis (horizontal, vertikal, diagonal)
   - Lingkaran/bulatan
   - Kotak/persegi
   - Segitiga
   - Hati/love
   - Bintang
   - Panah
   - Gelombang
   - Bentuk bebas/lainnya
3. Identifikasi LETAK coretan di canvas:
   - Kiri, kanan, tengah
   - Atas, bawah
   - Posisi spesifik
4. Buat RENCANA DESAIN berdasarkan coretan

FORMAT JAWABAN (HANYA TEKS, TIDAK ADA SVG):
Bentuk: [jenis bentuk yang terlihat di gambar]
Letak: [posisi di canvas]
Rencana: [jelaskan apa yang akan Anda buat]

CONTOH:
Bentuk: Garis horizontal
Letak: Di tengah canvas
Rencana: Saya akan membuat desain dengan garis divider horizontal di tengah, ditambah teks judul di atas dan subtitle di bawah. Warna akan menggunakan indigo (#6366F1) dan putih (#FFFFFF).

PENTING:
- LIHAT gambar dengan teliti, jangan tebak!
- Jika coretan berbentuk hati, sebut "hati/love"
- Jika coretan berbentuk lingkaran, sebut "lingkaran/bulatan"
- Jika coretan berbentuk garis, sebut "garis (horizontal/vertikal/diagonal)"
''';

  /// Build user message for analysis
  static List<Map<String, dynamic>> _buildAnalysisUserMessage(
    Uint8List sketchPng,
    Slide? currentSlide,
    int canvasWidth,
    int canvasHeight, {
    Map<String, dynamic>? basicAnalysis,
  }) {
    final b64 = base64Encode(sketchPng);
    final textPart = StringBuffer();
    textPart.writeln('Analisis coretan pengguna berikut. Canvas size: ${canvasWidth}×${canvasHeight}.');
    textPart.writeln('');
    textPart.writeln('LIHAT GAMBAR DENGAN TELITI!');
    textPart.writeln('Identifikasi bentuk yang ada di gambar: garis, lingkaran, kotak, segitiga, hati, bintang, panah, gelombang, atau bentuk lain.');

    if (basicAnalysis != null) {
      textPart.writeln('');
      textPart.writeln('INFO DASAR (bisa berubah setelah melihat gambar):');
      textPart.writeln('- Bentuk terdeteksi: ${basicAnalysis['shapes']}');
      textPart.writeln('- Area: ${basicAnalysis['bounds']}');
      textPart.writeln('- Jumlah stroke: ${basicAnalysis['strokeCount']}');
    }

    textPart.writeln('');
    textPart.writeln('Berikan analisis dengan format:');
    textPart.writeln('Bentuk: [jenis bentuk]');
    textPart.writeln('Letak: [posisi di canvas]');
    textPart.writeln('Rencana: [jelaskan apa yang akan dibuat]');

    return [
      {'type': 'text', 'text': textPart.toString().trim()},
      {'type': 'image_url', 'image_url': {'url': 'data:image/png;base64,$b64'}},
    ];
  }

  // ── LLM Execution ──

  static Future<String?> _executeVisionWithFallbackSvg({
    required String systemPrompt,
    required List<Map<String, dynamic>> userContent,
    String? preferredModel,
    required String operationName,
  }) async {
    final waitTime = _rateLimiter.waitTime;
    if (waitTime > Duration.zero) {
      await Future.delayed(waitTime);
    }

    String? responseText;
    Object? lastError;

    for (final model in _visionFallbackChain(preferredModel)) {
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          debugPrint('🔄 Vision AI: mencoba model $model (attempt ${attempt + 1})');
          final resp = await _callVision(model, systemPrompt, userContent);
          if (resp != null && resp.isNotEmpty) {
            debugPrint('🔍 [AI] Raw response (first 1000): ${resp.substring(0, resp.length > 1000 ? 1000 : resp.length)}');
            final svgMatch = RegExp(r'<svg[\s\S]*?</svg>').firstMatch(resp);
            if (svgMatch != null) {
              responseText = svgMatch.group(0);
              debugPrint('✅ Vision AI: model $model berhasil (${responseText!.length} chars)');
              debugPrint('🔍 [AI] Extracted SVG (first 500): ${responseText!.substring(0, responseText!.length > 500 ? 500 : responseText!.length)}');
              break;
            } else {
              // Cek apakah AI membalas dengan pertanyaan
              if (resp.contains('PERTANYAAN:')) {
                debugPrint('⚠️ Vision AI: model $model return pertanyaan (prompt ambigu)');
                // Return pertanyaan sebagai field terpisah
                final question = resp.replaceAll('PERTANYAAN:', '').trim();
                return question;
              }
              debugPrint('⚠️ Vision AI: model $model return non-SVG, retry...');
            }
          }
        } catch (e) {
          lastError = e;
          debugPrint('❌ Vision AI: model $model gagal (attempt ${attempt + 1}) → $e');
          if (e.toString().contains('Failed to fetch') || e.toString().contains('CORS')) {
            break;
          }
          if (attempt < 2) {
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }
      if (responseText != null) break;
    }

    return responseText;
  }

  // ── GenOffice HTTP Server Helpers ──

  /// Check if GenOffice server is reachable (with short timeout).
  static Future<bool> genOfficeAvailable() async {
    try {
      final uri = Uri.parse('${AiConfig.genOfficeBaseUrl}/api/v1/health');
      final resp = await http.get(uri).timeout(const Duration(seconds: 2));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Call GenOffice /api/v1/generate-outline
  static Future<List<String>?> callGenOfficeOutline(String topic, {int slideCount = 5}) async {
    try {
      final uri = Uri.parse('${AiConfig.genOfficeBaseUrl}/api/v1/generate-outline');
      final resp = await http.post(uri, headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'topic': topic, 'slideCount': slideCount}),
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final outline = data['outline'] as List?;
      if (outline == null) return null;
      return outline.map((e) => (e['title'] ?? '').toString()).where((t) => t.isNotEmpty).toList();
    } catch (e) {
      debugPrint('⚠️ GenOffice outline failed: $e');
      return null;
    }
  }

  /// Call GenOffice /api/v1/generate-slide
  static Future<String?> callGenOfficeSlide({
    required String topic,
    required String title,
    String style = 'modern',
    String color = 'indigo',
    int index = 0,
    int total = 1,
    String? previousTitle,
    String? nextTitle,
  }) async {
    try {
      final uri = Uri.parse('${AiConfig.genOfficeBaseUrl}/api/v1/generate-slide');
      final body = <String, dynamic>{
        'topic': topic,
        'title': title,
        'style': style,
        'color': color,
        'index': index,
        'total': total,
      };
      if (previousTitle != null) body['previousTitle'] = previousTitle;
      if (nextTitle != null) body['nextTitle'] = nextTitle;

      // Single-slide generation takes ~2 min on the reasoning model
      // (ocg/mimo-v2.6-flash via 9Router) — 60s always timed out.
      final resp = await http.post(uri, headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 180));

      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final svg = data['svg'] as String?;
      if (svg != null && svg.contains('<svg')) return svg;
      return null;
    } catch (e) {
      debugPrint('⚠️ GenOffice slide failed: $e');
      return null;
    }
  }

  static Future<String?> _executeWithFallbackSvg({
    required String systemPrompt,
    required String userPrompt,
    String? preferredModel,
    required String operationName,
    bool skipRateLimit = false,
  }) async {
    String? responseText;
    Object? lastError;

    for (final model in _fallbackChain(preferredModel)) {
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          debugPrint('🔄 AI: mencoba model $model (attempt ${attempt + 1})');
          // Use streaming for page generation (faster time-to-first-SVG)
          final resp = skipRateLimit
              ? await _callLlmStream(system: systemPrompt, user: userPrompt, model: model, skipRateLimit: skipRateLimit)
              : await _callLlm(system: systemPrompt, user: userPrompt, model: model, skipRateLimit: skipRateLimit);
          if (resp != null && resp.isNotEmpty) {
            debugPrint('🔍 [AI] Raw response (first 500): ${resp.substring(0, resp.length > 500 ? 500 : resp.length)}');
            final svgMatch = RegExp(r'<svg[\s\S]*?</svg>').firstMatch(resp);
            if (svgMatch != null) {
              responseText = svgMatch.group(0);
              debugPrint('✅ AI: model $model berhasil (${responseText!.length} chars)');
              debugPrint('🔍 [AI] Extracted SVG (first 500): ${responseText!.substring(0, responseText!.length > 500 ? 500 : responseText!.length)}');
              break;
            } else {
              // Cek apakah AI membalas dengan pertanyaan
              if (resp.contains('PERTANYAAN:')) {
                debugPrint('⚠️ AI: model $model return pertanyaan (prompt ambigu)');
                final question = resp.replaceAll('PERTANYAAN:', '').trim();
                return question;
              }
              debugPrint('⚠️ AI: model $model return non-SVG, retry...');
            }
          }
        } catch (e) {
          lastError = e;
          debugPrint('❌ AI: model $model gagal (attempt ${attempt + 1}) → $e');
          if (e.toString().contains('Failed to fetch') || e.toString().contains('CORS')) {
            break;
          }
          if (attempt < 2) {
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }
      if (responseText != null) break;
    }

    return responseText;
  }

  // ── HTTP Calls ──

  static Future<String?> _callVision(String model, String system, List<Map<String, dynamic>> content) async {
    try {
      // Try GenOffice server first, fallback to local proxy
      final baseUrl = await _getAvailableBaseUrl();
      final uri = Uri.parse('$baseUrl/chat/completions');
      final response = await http.post(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AiConfig.resolveProvider(model ?? '').apiKey.isNotEmpty ? AiConfig.resolveProvider(model ?? '').apiKey : AiConfig.apiKey}',
      }, body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': content},
        ],
        'max_tokens': AiConfig.maxTokens,
        'temperature': 0.7,
        'stream': false,
      })).timeout(const Duration(minutes: 5));

      debugPrint('📡 Vision HTTP ${response.statusCode} untuk model $model (${response.body.length} bytes)');
      if (response.statusCode != 200) {
        debugPrint('❌ Vision HTTP error: ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
        return null;
      }

      final responseBody = response.body;
      if (responseBody.isEmpty) return null;

      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;

      final message = choices[0]['message'] as Map<String, dynamic>?;
      if (message == null) return null;

      final text = message['content'] as String?;
      if (text != null && text.isNotEmpty) return text;

      final reasoning = message['reasoning'] as String?;
      if (reasoning != null && reasoning.isNotEmpty) return reasoning;

      final reasoningContent = message['reasoning_content'] as String?;
      if (reasoningContent != null && reasoningContent.isNotEmpty) return reasoningContent;

      // LongCat / reasoning_details format: array of {type, text, index}
      final reasoningDetails = message['reasoning_details'] as List?;
      if (reasoningDetails != null && reasoningDetails.isNotEmpty) {
        final sb = StringBuffer();
        for (final detail in reasoningDetails) {
          if (detail is Map<String, dynamic>) {
            final t = detail['text'] as String?;
            if (t != null && t.isNotEmpty) sb.write(t);
          }
        }
        final combined = sb.toString().trim();
        if (combined.isNotEmpty) return combined;
      }

      return null;
    } catch (e) {
      debugPrint('Vision call error ($model): $e');
      return null;
    }
  }

  static Future<String?> _callLlm({
    required String system,
    required String user,
    String? model,
    bool skipRateLimit = false,
  }) async {
    try {
      if (!skipRateLimit) {
        final waitTime = _rateLimiter.waitTime;
        if (waitTime > Duration.zero) await Future.delayed(waitTime);
      }

      // Try GenOffice server first, fallback to local proxy
      final baseUrl = await _getAvailableBaseUrl();
      final uri = Uri.parse('$baseUrl/chat/completions');
      final response = await http.post(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AiConfig.resolveProvider(model ?? '').apiKey.isNotEmpty ? AiConfig.resolveProvider(model ?? '').apiKey : AiConfig.apiKey}',
      }, body: jsonEncode({
        'model': model ?? AiConfig.freeModel,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
        'max_tokens': AiConfig.maxTokens,
        'temperature': 0.7,
        'stream': false,
      })).timeout(const Duration(minutes: 5));

      if (response.statusCode != 200) {
        debugPrint('⚠️ AI API error: ${response.statusCode} ${response.body}');
        return null;
      }

      final responseBody = response.body;
      if (responseBody.isEmpty) return null;

      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;

      final message = choices[0]['message'] as Map<String, dynamic>?;
      if (message == null) return null;

      final content = message['content'] as String?;
      if (content != null && content.isNotEmpty) return content;

      final reasoning = message['reasoning'] as String?;
      if (reasoning != null && reasoning.isNotEmpty) return reasoning;

      final reasoningContent = message['reasoning_content'] as String?;
      if (reasoningContent != null && reasoningContent.isNotEmpty) return reasoningContent;

      // LongCat / reasoning_details format: array of {type, text, index}
      final reasoningDetails = message['reasoning_details'] as List?;
      if (reasoningDetails != null && reasoningDetails.isNotEmpty) {
        final sb = StringBuffer();
        for (final detail in reasoningDetails) {
          if (detail is Map<String, dynamic>) {
            final t = detail['text'] as String?;
            if (t != null && t.isNotEmpty) sb.write(t);
          }
        }
        final combined = sb.toString().trim();
        if (combined.isNotEmpty) return combined;
      }

      return null;
    } catch (e) {
      debugPrint('⚠️ AI call error: $e');
      return null;
    }
  }

  /// Streaming LLM call that returns as soon as closing </svg> is found.
  /// Faster than _callLlm for SVG generation because we don't wait for
  /// the full response — just the SVG portion.
  static Future<String?> _callLlmStream({
    required String system,
    required String user,
    String? model,
    bool skipRateLimit = false,
  }) async {
    try {
      if (!skipRateLimit) {
        final waitTime = _rateLimiter.waitTime;
        if (waitTime > Duration.zero) await Future.delayed(waitTime);
      }

      // Try GenOffice server first, fallback to local proxy
      final baseUrl = await _getAvailableBaseUrl();
      final uri = Uri.parse('$baseUrl/chat/completions');
      final request = http.Request('POST', uri);
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AiConfig.resolveProvider(model ?? '').apiKey.isNotEmpty ? AiConfig.resolveProvider(model ?? '').apiKey : AiConfig.apiKey}',
      });
      request.body = jsonEncode({
        'model': model ?? AiConfig.freeModel,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
        'max_tokens': AiConfig.maxTokens,
        'temperature': 0.7,
        'stream': true,
      });

      final streamedResponse = await http.Client().send(request).timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw TimeoutException('LLM stream timeout'),
      );

      final buffer = StringBuffer();
      String? reasoningBuffer;
      final Completer<String?> completer = Completer();

      streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (completer.isCompleted) return;
          if (!line.startsWith('data:')) return;
          final payload = line.substring(5).trim();
          if (payload.isEmpty || payload == '[DONE]') return;

          try {
            final json = jsonDecode(payload) as Map<String, dynamic>;
            final choice = (json['choices'] as List?)?.firstOrNull;
            if (choice is! Map) return;
            final delta = choice['delta'] as Map?;
            if (delta == null) return;

            // Content chunks
            final content = delta['content'];
            if (content is String && content.isNotEmpty) {
              buffer.write(content);
            }

            // Reasoning chunks (nemotron/o1/o3)
            final reasoning = delta['reasoning'];
            if (reasoning is String && reasoning.isNotEmpty) {
              reasoningBuffer ??= '';
              reasoningBuffer = reasoningBuffer! + reasoning;
            }

            // Check if we have a complete SVG
            final current = buffer.toString();
            if (current.contains('</svg>')) {
              // Extract just the SVG portion
              final svgMatch = RegExp(r'<svg[\s\S]*?</svg>').firstMatch(current);
              if (svgMatch != null && !completer.isCompleted) {
                completer.complete(svgMatch.group(0));
              }
            }
          } catch (_) {}
        },
        onDone: () {
          if (!completer.isCompleted) {
            // Fallback: try to extract SVG from accumulated buffer
            final current = buffer.toString();
            final svgMatch = RegExp(r'<svg[\s\S]*?</svg>').firstMatch(current);
            if (svgMatch != null) {
              completer.complete(svgMatch.group(0));
            } else {
              // Return reasoning if no SVG found
              completer.complete(reasoningBuffer);
            }
          }
        },
        onError: (e) {
          if (!completer.isCompleted) completer.complete(null);
        },
      );

      return await completer.future;
    } catch (e) {
      debugPrint('⚠️ AI stream error: $e');
      return null;
    }
  }

  // ── Helpers ──

  static List<String> _fallbackChain(String? preferred) {
    if (preferred != null) return [preferred, ...AiConfig.fallbackModels.where((m) => m != preferred)];
    return AiConfig.fallbackModels;
  }

  /// Vision-first fallback chain. Sketch-to-design operations MUST hit a
  /// vision-capable model so the AI actually sees the sketch image. Text-only
  /// models (e.g. longcat) ignore `image_url` content and would "succeed" by
  /// generating SVG from the coordinate text alone — never truly seeing the
  /// sketch. So vision models go first, then the remaining fallback models,
  /// and a non-vision `preferred` is appended last as a best-effort fallback.
  static List<String> _visionFallbackChain(String? preferred) {
    final visionCapable = <String>{AiConfig.visionModel, 'oc/laguna-s-2.1-free'};
    final chain = <String>[];
    if (preferred != null && visionCapable.contains(preferred)) chain.add(preferred);
    for (final m in visionCapable) {
      if (!chain.contains(m)) chain.add(m);
    }
    for (final m in AiConfig.fallbackModels) {
      if (!chain.contains(m)) chain.add(m);
    }
    if (preferred != null && !chain.contains(preferred)) chain.add(preferred);
    return chain;
  }

  /// Get available base URL — try GenOffice first, fallback to provider for model.
  /// On web, always route through a CORS-friendly endpoint (GenOffice or proxy),
  /// never directly to 127.0.0.1:20128 which triggers cross-origin blocks.
  static Future<String> _getAvailableBaseUrl({String? model}) async {
    if (await genOfficeAvailable()) {
      debugPrint('🔄 Using GenOffice server as AI backend');
      return AiConfig.baseUrl;
    }
    // On web, never use provider's direct baseUrl (127.0.0.1) — it triggers CORS.
    // Always fall back to the CORS proxy (localhost:3000/proxy).
    if (kIsWeb) {
      debugPrint('⚠️ GenOffice unreachable (web), using CORS proxy');
      return AiConfig.fallbackBaseUrl;
    }
    // On native, resolve provider for this model (direct connections are fine).
    if (model != null) {
      final provider = AiConfig.resolveProvider(model);
      debugPrint('📡 Using provider "${provider.name}" for model $model');
      return provider.baseUrl;
    }
    debugPrint('⚠️ GenOffice unreachable, falling back to local AI proxy');
    return AiConfig.fallbackBaseUrl;
  }

  // ── Classified LLM Execution (GenOffice-style error handling) ──

  /// Classify an HTTP response into an AiErrKind.
  static AiErrKind _classifyHttpStatus(int statusCode, String body) {
    if (statusCode == 408 || statusCode == 504) return AiErrKind.timeout;
    if (statusCode == 429) return AiErrKind.api; // Rate limit — can retry with different model
    if (statusCode >= 400 && statusCode < 500) return AiErrKind.api; // Client error
    if (statusCode >= 500) return AiErrKind.api; // Server error
    return AiErrKind.api;
  }

  /// Single LLM call with error classification.
  /// Returns AiLlmResult with errKind for retry decisions.
  static Future<AiLlmResult> _callLlmClassified({
    required String system,
    required String user,
    required String model,
    int maxTokens = 8192,
    bool stream = false,
  }) async {
    try {
      // Try GenOffice server first, fallback to local proxy
      final baseUrl = await _getAvailableBaseUrl();
      final uri = Uri.parse('$baseUrl/chat/completions');
      debugPrint('📡 [Classified] Calling $model (${user.length} chars prompt)...');
      final response = await http.post(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AiConfig.resolveProvider(model ?? '').apiKey.isNotEmpty ? AiConfig.resolveProvider(model ?? '').apiKey : AiConfig.apiKey}',
      }, body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
        'max_tokens': maxTokens,
        'temperature': 0.7,
        'stream': stream,
      })).timeout(const Duration(seconds: 90));

      debugPrint('📡 [Classified] HTTP ${response.statusCode} for model $model (${response.body.length} bytes)');

      if (response.statusCode != 200) {
        final errKind = _classifyHttpStatus(response.statusCode, response.body);
        final errorMsg = 'HTTP ${response.statusCode}: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}';
        debugPrint('❌ [Classified] Error: $errorMsg (errKind=$errKind)');
        return errKind == AiErrKind.timeout
            ? AiLlmResult.timeout(error: errorMsg)
            : AiLlmResult.apiError(errorMsg);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        return AiLlmResult.empty(error: 'No choices in response');
      }

      final message = choices[0]['message'] as Map<String, dynamic>?;
      if (message == null) {
        return AiLlmResult.empty(error: 'No message in response');
      }

      // Extract content (check multiple formats)
      final content = message['content'] as String?;
      if (content != null && content.isNotEmpty) {
        return AiLlmResult.success(content);
      }

      final reasoning = message['reasoning'] as String?;
      if (reasoning != null && reasoning.isNotEmpty) {
        return AiLlmResult.success(reasoning);
      }

      final reasoningContent = message['reasoning_content'] as String?;
      if (reasoningContent != null && reasoningContent.isNotEmpty) {
        return AiLlmResult.success(reasoningContent);
      }

      // LongCat / reasoning_details format
      final reasoningDetails = message['reasoning_details'] as List?;
      if (reasoningDetails != null && reasoningDetails.isNotEmpty) {
        final sb = StringBuffer();
        for (final detail in reasoningDetails) {
          if (detail is Map<String, dynamic>) {
            final t = detail['text'] as String?;
            if (t != null && t.isNotEmpty) sb.write(t);
          }
        }
        final combined = sb.toString().trim();
        if (combined.isNotEmpty) {
          return AiLlmResult.success(combined);
        }
      }

      return AiLlmResult.empty(error: 'Empty response from model');
    } on TimeoutException {
      return AiLlmResult.timeout();
    } catch (e) {
      final msg = e.toString();
      // Network errors — can retry with different model
      if (msg.contains('Failed to fetch') || msg.contains('CORS') || msg.contains('SocketException')) {
        return AiLlmResult.apiError('Network error: $msg');
      }
      // User abort
      if (msg.contains('abort') || msg.contains('cancel')) {
        return AiLlmResult.stopped();
      }
      return AiLlmResult.apiError('Request failed: $msg');
    }
  }

  /// Execute LLM with model fallback (GenOffice-style).
  ///
  /// Strategy:
  /// 1. Try primary model (generationModel or preferredModel)
  /// 2. On API error (not timeout/empty/stopped), fall back to user's chat model
  /// 3. On timeout/empty/stopped, don't retry with different model
  ///
  /// This mirrors GenOffice's `runLlmWithFallback` in AiPanel.tsx.
  static Future<AiLlmResult> _executeWithFallbackClassified({
    required String system,
    required String user,
    String? preferredModel,
    required String operationName,
    int maxTokens = 8192,
    bool skipRateLimit = false,
  }) async {
    final primaryModel = preferredModel ?? AiConfig.generationModel;
    final fallbackModel = AiConfig.chatModel;

    // Only try fallback if primary is different from fallback
    final canFallback = primaryModel != fallbackModel;

    debugPrint('🔄 [$operationName] Trying primary model: $primaryModel');

    final first = await _callLlmClassified(
      system: system,
      user: user,
      model: primaryModel,
      maxTokens: maxTokens,
    );

    // Success or shouldNotRetry → return immediately
    if (first.ok || !canFallback || first.shouldNotRetry) {
      if (!first.ok) {
        debugPrint('⚠️ [$operationName] Primary model failed (errKind=${first.errKind}): ${first.error}');
      }
      return first;
    }

    // API error → try fallback model
    debugPrint('🔄 [$operationName] Primary failed with API error, trying fallback: $fallbackModel');
    final second = await _callLlmClassified(
      system: system,
      user: user,
      model: fallbackModel,
      maxTokens: maxTokens,
    );

    if (second.ok) {
      debugPrint('✅ [$operationName] Fallback model succeeded');
    } else {
      debugPrint('❌ [$operationName] Fallback also failed: ${second.error}');
    }

    return second;
  }

  /// Generate with classified error handling and model fallback.
  /// Returns AiLlmResult instead of SvgGenerateResult for better error handling.
  ///
  /// If the prompt is for SVG generation (contains "Slide Title:"), tries
  /// GenOffice HTTP server first for higher-quality output.
  static Future<AiLlmResult> generateClassified({
    required String prompt,
    String? model,
  }) async {
    // ── Try GenOffice HTTP server first for SVG generation prompts ──
    // Only when prompt contains "Slide Title:" (SVG prompt, not JSON spec prompt)
    if (prompt.contains('Slide Title:') && prompt.contains('Topic:')) {
      try {
        if (await genOfficeAvailable()) {
          // Extract info from prompt
          final topicMatch = RegExp(r'Topic:\s*(.+)').firstMatch(prompt);
          final titleMatch = RegExp(r'Slide Title:\s*(.+)').firstMatch(prompt);
          final styleMatch = RegExp(r'Style:\s*(.+)').firstMatch(prompt);
          final colorMatch = RegExp(r'Color:\s*(.+)').firstMatch(prompt);
          final slideMatch = RegExp(r'Slide (\d+) of (\d+)').firstMatch(prompt);

          final topic = topicMatch?.group(1)?.trim() ?? 'presentation';
          final title = titleMatch?.group(1)?.trim() ?? 'Slide';
          final style = styleMatch?.group(1)?.trim() ?? 'modern';
          final color = colorMatch?.group(1)?.trim() ?? 'indigo';
          final index = slideMatch != null ? (int.tryParse(slideMatch.group(1) ?? '0') ?? 0) : 0;
          final total = slideMatch != null ? (int.tryParse(slideMatch.group(2) ?? '1') ?? 1) : 1;

          debugPrint('🌐 [GenOffice] Trying server for slide "$title" ($index/$total)...');
          final svg = await callGenOfficeSlide(
            topic: topic,
            title: title,
            style: style,
            color: color,
            index: index,
            total: total,
          );

          if (svg != null && svg.contains('<svg')) {
            debugPrint('✅ [GenOffice] Server returned SVG (${svg.length} chars)');
            return AiLlmResult.success(svg);
          }
          debugPrint('⚠️ [GenOffice] Server returned invalid SVG, falling back to local AI');
        }
      } catch (e) {
        debugPrint('⚠️ [GenOffice] Server error, falling back to local AI: $e');
      }
    }

    // ── Fallback: local LLM ──
    final systemPrompt = await _getSkillSystemPrompt();

    final textPart = StringBuffer();
    textPart.writeln('Instruksi user: "$prompt"');
    textPart.writeln('Canvas size: 1920×1080.');
    textPart.writeln('Buat desain PRESENTASI yang MENARIK dan KOMPLEKS sesuai instruksi user.');
    textPart.writeln('PASTIKAN teks berisi konten nyata tentang topik yang diminta, bukan placeholder!');

    return _executeWithFallbackClassified(
      system: systemPrompt,
      user: textPart.toString().trim(),
      preferredModel: model,
      operationName: 'generateClassified',
      maxTokens: AiConfig.generationMaxTokens,
    );
  }
}
