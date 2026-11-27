// DocuCraft Flutter — DocuCraftRunCoordinator (GenOffice-style)
//
// Menyambungkan AgentLoop ke state machine `AiRunProvider` ChatPanel yang
// sudah ada. Flow ala GenOffice:
//
//   1. **Style Skill**: panggilan LLM khusus menghasilkan panduan gaya visual
//   2. **Plan Outline**: model merencanakan struktur deck (core_hook + pages)
//   3. **Generate Pages**: generasi per-halaman via PageGenerator
//   4. **Land Pages**: PptxBuilder menghasilkan .pptx sungguhan dan menyimpannya ke disk
//   5. **QC Pass**: audit layout deterministik, auto-fix, revert jika lebih buruk
//
// Output adalah file .pptx SUNGGUHAN (bukan sekadar kode SVG atau elemen in-memory).
// Mencerminkan landGeneratedPages() + generasi PPTX main process di GenOffice.

import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import '../ai/run_state_machine.dart';
import '../models/slide.dart';
import '../services/pptx_builder.dart';
import '../services/skill_loader.dart';
import '../services/style_skill.dart';
import 'agent_core.dart';
import '../services/ai_generation.dart';

/// Adapter wrapping AiGenerationServicePageGenerator as SlidesSkill.PageGenerator
class _PageGeneratorAdapter implements PageGenerator {
  final AiGenerationServicePageGenerator _inner;
  _PageGeneratorAdapter(this._inner);

  @override
  Future<String> generateSvg({
    required String topic,
    required int pageIndex,
    required int totalPages,
    required String title,
    required String brief,
    String layout = '',
  }) => _inner.generateSvg(
        topic: topic,
        pageIndex: pageIndex,
        totalPages: totalPages,
        title: title,
        brief: brief,
        layout: layout,
      );
}

/// Adapter that maps SlidesSkill.DeckProgressEvent → OnProgress
void _mapDeckProgress(
  DeckProgressEvent event,
  OnProgress onProgress,
) {
  if (event is StyleProgressEvent) {
    onProgress(
      stage: 'style',
      label: event.label,
      done: 0,
      total: 1,
      status: event.status,
      summary: event.summary,
    );
  } else if (event is PlanProgressEvent) {
    onProgress(
      stage: 'plan',
      label: event.label,
      done: event.done,
      total: event.total,
      status: event.status,
      summary: event.summary,
    );
  } else if (event is ImagesProgressEvent) {
    onProgress(
      stage: 'images',
      label: event.label,
      done: event.done,
      total: event.total,
      status: event.status,
      summary: event.summary,
    );
  } else if (event is PagesProgressEvent) {
    final pages = event.pages?.map((p) => PageProgressItem(
          title: p.title,
          status: PageProgressStatus.values.byName(p.status.name),
          error: p.error,
        )).toList();
    onProgress(
      stage: 'pages',
      label: event.label,
      done: event.done,
      total: event.total,
      status: event.status,
      summary: event.summary,
      pages: pages,
    );
  } else if (event is DoneProgressEvent) {
    onProgress(
      stage: 'done',
      label: '',
      done: event.total,
      total: event.total,
      status: 'done',
      summary: event.summary,
    );
  }
}

/// Callback invoked after the model emits a `plan_deck_outline` tool call.
/// Returns the pages the user (or default) confirmed — `null` means the
/// review was cancelled (e.g. user pressed "Skip" or "New Chat").
/// Also receives [planSummary] from AI's "Briefly explain your reasoning" text.
typedef OnOutlineReady = Future<List<OutlinePage>?> Function(
    String topic, List<OutlinePage> initial, {String? planSummary});

/// Callback when a slide lands — updates in-memory state
typedef OnSlideLanded = void Function(Slide snapshot, {required bool replaceAll});

/// Callback when all pages are generated — saves real .pptx file (GenOffice-style)
typedef OnDeckSaved = Future<LandResult> Function({
  required List<Slide> slides,
  required String? deckName,
  required bool replaceAll,
});

/// Granular progress callback with stage, label, done/total counts
/// Mirrors GenOffice's DeckProgressEvent stages: style → plan → images → pages → done
typedef OnProgress = void Function({
  required String stage,  // 'style' | 'plan' | 'images' | 'pages' | 'done'
  required String label,
  required int done,
  required int total,
  required String status, // 'running' | 'done' | 'error'
  String? summary,
  List<PageProgressItem>? pages, // Per-page progress for 'pages' stage
});

typedef RunProvider = dynamic;

/// A simple skill for capturing outline JSON as a private class.
class _JsonOutlineSkill extends AgentSkill {
  final String _systemPrompt;

  _JsonOutlineSkill(this._systemPrompt);

  @override
  String get id => 'json_outline';

  @override
  String get systemPrompt => _systemPrompt;

  @override
  List<AgentToolDef> get tools => [
        AgentToolDef(
          name: 'plan_deck_outline',
          description: 'Create a presentation outline. The outlineJson must be a valid JSON string containing an object with "pages" array, each page having "title" and "brief" fields.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'outlineJson': {
                'type': 'string',
                'description': 'A JSON string containing the outline. Format: {"pages":[{"title":"Slide Title","brief":"Content brief"}]}',
              }
            },
            'required': ['outlineJson'],
          },
        ),
      ];

  @override
  Future<ToolExecution> executeTool(AgentToolCall call, {AbortSignal? signal}) async {
    if (call.name == 'plan_deck_outline') {
      final outlineJson = call.input['outlineJson'] as String?;
      if (outlineJson != null && outlineJson.isNotEmpty) {
        return ToolExecution(output: outlineJson, isError: false, summary: 'Outline generated');
      }
    }
    return ToolExecution(output: 'Unknown tool', isError: true, summary: 'Tool execution failed');
  }
}

class DocuCraftRunCoordinator {
  final AgentTransport transport;
  final String systemPrompt;
  final OnOutlineReady onOutlineReady;
  final OnSlideLanded onSlideLanded;
  final OnProgress onProgress;
  final OnDeckSaved? onDeckSaved;
  final String? defaultModel;

  DocuCraftRunCoordinator({
    required this.transport,
    required this.systemPrompt,
    required this.onOutlineReady,
    required this.onSlideLanded,
    required this.onProgress,
    this.onDeckSaved,
    this.defaultModel,
  });

  /// Stage 0: Generate Style Skill (GenOffice-style).
  /// Dedicated LLM call for visual style guide — ensures consistent design
  /// across all pages. Returns the style skill string for downstream use.
  Future<String?> generateStyleSkill({
    required String topic,
    required RunProvider runProvider,
    String? styleHint,
  }) async {
    debugPrint('🎨 [Coordinator] Generating Style Skill for: $topic');

    onProgress(
      stage: 'style',
      label: 'Generating style guide...',
      done: 0,
      total: 1,
      status: 'running',
    );

    try {
      final result = await StyleSkillGenerator.generate(
        topic: topic,
        styleHint: styleHint,
      );

      if (result.ok && result.skill != null) {
        final styleString = result.skill!.toPromptString();
        debugPrint('✅ [Coordinator] Style Skill generated');
        onProgress(
          stage: 'style',
          label: 'Style guide ready',
          done: 1,
          total: 1,
          status: 'done',
          summary: 'Style guide generated with ${result.skill!.layoutVariants.length} layout types',
        );
        return styleString;
      } else {
        debugPrint('⚠️ [Coordinator] Style Skill failed: ${result.error}');
        onProgress(
          stage: 'style',
          label: 'Style guide failed',
          done: 1,
          total: 1,
          status: 'error',
          summary: result.error,
        );
        return null;
      }
    } catch (e) {
      debugPrint('❌ [Coordinator] Style Skill error: $e');
      onProgress(
        stage: 'style',
        label: 'Style guide error',
        done: 1,
        total: 1,
        status: 'error',
        summary: e.toString(),
      );
      return null;
    }
  }

  /// Stage 1: ask the model for an outline with Core Hook and Layout Variants.
  /// Returns the outline the user ultimately approves.
  /// Shows AI's reasoning output immediately without hardcoded UI text.
  Future<List<OutlinePage>> planOutline({
    required String topic,
    required RunProvider runProvider,
    String? styleSkill,
  }) async {
    final completer = Completer<String>();

    final loop = AgentLoop(AgentLoopOptions(
      transport: transport,
      skill: _JsonOutlineSkill(systemPrompt),
      events: AgentLoopEvents(
        onText: (t) {
          // Stream AI text directly to chat bubble — no hardcoded labels
          runProvider.onText(t);
        },
        onToolExecuted: (c, e) {
          // Capture the outline JSON from the tool's input.
          if (c.name == 'plan_deck_outline' && !completer.isCompleted) {
            final rawInput = c.input['outlineJson'] as String?;
            if (rawInput != null && rawInput.isNotEmpty) completer.complete(rawInput);
          }
        },
      ),
    ));

    // Build planning prompt with Core Hook and Layout Variants (GenOffice-style)
    final styleBlock = styleSkill != null && styleSkill.isNotEmpty
        ? '\nStyle Skill:\n$styleSkill'
        : '';

    String raw;
    try {
      loop.run(
        'You are a professional deck planner. Given the topic$styleBlock, plan the content page by page.\n'
        '\n'
        'Output one JSON object with:\n'
        '- core_hook: The deck\'s narrative anchor — one sentence, with tension, containing a number or counter-intuitive contrast, at most 20 characters.\n'
        '- pages: Array of pages, each with title, type (cover/content/data/closing), brief (detailed content description with real data), layout (choose from the Style Skill\'s layout variants), and image_queries (keywords for real photos).\n'
        '\n'
        'Layout selection criteria:\n'
        '- 3 parallel points → three_column_cards\n'
        '- A key number → hero_big_number\n'
        '- Comparison/categories → two_column_comparison or two_by_two_grid\n'
        '- Sequence → timeline_horizontal\n'
        '- Image+text → left_text_right_image or full_image_text_overlay\n'
        '- Metrics → kpi_cards_row\n'
        '\n'
        'IMPORTANT: Content pages within one deck must NOT repeat the same layout variant. Each content page should use a different layout for visual variety.\n'
        '\n'
        'Call plan_deck_outline with JSON: {"core_hook":"...","pages":[{"title":"...","type":"content","brief":"...","layout":"...","image_queries":["keyword1","keyword2"]}]}'
        '\nAim for 4-8 slides. Use real data/facts in briefs, no placeholders.',
      );
      raw = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw TimeoutException('The AI took too long to respond.'),
      );
      loop.cancel();
    } catch (e) {
      debugPrint('⚠️ planOutline: error: $e');
      runProvider.onError(e.toString());
      loop.cancel();
      return const <OutlinePage>[];
    }

    final obj = parseOutlineJson(raw);
    final pages = extractOutlinePages(obj, defaultCount: 4);

    // Extract core_hook if present
    if (obj != null && obj.containsKey('core_hook')) {
      final coreHook = obj['core_hook']?.toString() ?? '';
      debugPrint('🎯 [Coordinator] Core Hook: $coreHook');
      // Store core_hook for use in page generation
      _lastCoreHook = coreHook;
    }

    final confirmed = await onOutlineReady(topic, pages);
    if (confirmed == null || confirmed.isEmpty) {
      debugPrint('⚠️ [Coordinator] Outline cancelled or empty');
      return const <OutlinePage>[];
    }
    return confirmed;
  }

  /// Last generated core hook (for use in page generation).
  String _lastCoreHook = '';
  String get lastCoreHook => _lastCoreHook;

  /// Stage 2: user-approved outline → SlidesSkill generate_deck → real slides.
  /// Uses GenOffice-style self-driven pipeline via SlidesSkill.
  Future<DeckGenerationResult> generateDeck({
    required String topic,
    required List<OutlinePage> pages,
    required String? styleSkill,
    required RunProvider runProvider,
    String? coreHook,
  }) async {
    try {
      // Create SlidesSkill with the approved outline
      final pageGenerator = AiGenerationServicePageGenerator(
        model: AiConfig.generationModel,
        style: 'modern',
        colorScheme: 'indigo',
        styleSkill: styleSkill,
        coreHook: coreHook,
      );

      final collectedSlides = <Slide>[];
      bool firstLand = true;

      // Use Flutter-specific system prompt (tool-based generation)
      // instead of desktop GenOffice workflow prompt
      final flutterPrompt = await SkillLoader.buildSystemPrompt(route: 'generate-pptx-flutter');

      final skill = SlidesSkill(
        systemPrompt: flutterPrompt,
        generator: _PageGeneratorAdapter(pageGenerator),
        sink: (slide, {required replaceAll}) {
          collectedSlides.add(slide);
          onSlideLanded(slide, replaceAll: firstLand);
          firstLand = false;
        },
        topic: topic,
        pages: pages,
        styleSkill: styleSkill,
        onProgress: (event) => _mapDeckProgress(event, onProgress),
        slideFixer: (slideIndex, slide) async {
          // Re-land a QC-fixed slide at its position
          onSlideLanded(slide, replaceAll: false);
          return const LandResult(ok: true);
        },
        canvasW: 1280,
        canvasH: 720,
      );

      // Emit initial progress
      onProgress(
        stage: 'pages',
        label: '',
        done: 0,
        total: pages.length,
        status: 'running',
      );

      // ── AgentLoop Turn-Based Architecture (GenOffice-style) ──
      // Instead of single tool call, let AI drive turn-by-turn tool sequence:
      // - Can call plan_deck → user reviews outline → generate_deck
      // - Can make post-generation edits via element-level tools
      // - Enables true multi-turn refinement matching GenOffice

      final agentLoop = AgentLoop(AgentLoopOptions(
        transport: transport,
        skill: skill,
        events: AgentLoopEvents(
          onText: (text) {
            // Stream assistant text to chat bubble
            runProvider.onText(text);
          },
          onToolStart: (call) {
            debugPrint('🔧 [AgentLoop] Tool start: ${call.name}');
            // Tool execution started - could show live indicator if needed
          },
          onToolExecuted: (call, exec) {
            debugPrint('✅ [AgentLoop] Tool executed: ${call.name}, ok=${!exec.isError}');
            if (!exec.isError) {
              // Successful tool execution - could update UI if needed
              // Note: Slide landings are handled via the sink callback in SlidesSkill
            } else {
              debugPrint('❌ [AgentLoop] Tool failed: ${call.name} - ${exec.output}');
            }
          },
          onTurnEnd: () {
            debugPrint('🔄 [AgentLoop] Turn ended');
          },
          onDone: (result) {
            debugPrint('🏁 [AgentLoop] Run completed: success=${!result.isError}, text=${result.text.length} chars');
            if (result.isError) {
              runProvider.onError(result.text.isNotEmpty ? result.text : 'AgentLoop failed');
            }
          },
          onError: (error) {
            debugPrint('💥 [AgentLoop] Error: $error');
          },
        ),
        maxTurns: 20, // Reasonable limit for deck generation
        maxHistory: 50,
        compaction: CompactionOptions(
          maxBytes: 256 * 1024, // 256KB
          keepRecentBytes: 96 * 1024, // 96KB
          disableLlmSummary: false,
        ),
        systemSuffix: () {
          // Append any turn-specific context if needed
          return '';
        },
        formatUserMessage: (instruction, context) {
          // Format the user message with context (system prompt handles <deck meta>)
          if (context.isNotEmpty) {
            return '$instruction\n\n$context';
          }
          return instruction;
        },
      ));

      // Start the AgentLoop with generation instruction
      final agentResult = await agentLoop.run(
        'Buatkan presentasi tentang topik "$topic" dengan outline yang sudah disetujui.',
      );

      // QC pass already runs inside _executeGenerateDeck via SlidesSkill
      // (QualityChecker.check → autoFix → slideFixer → re-land).
      // No duplicate QC here to avoid double-fix conflicts.

      // Save the deck as .pptx
      final deckName = topic.replaceAll(' ', '_');
      final landResult = await onDeckSaved?.call(
        slides: collectedSlides,
        deckName: deckName,
        replaceAll: true,
      ) ?? const LandResult(ok: false, error: 'No deck saver configured');

      final isSuccess = !agentResult.isError && !agentResult.cancelled && !agentResult.turnLimit && landResult.ok;
      onProgress(
        stage: 'done',
        label: '',
        done: 1,
        total: 1,
        status: isSuccess ? 'done' : 'error',
        summary: agentResult.isError ? agentResult.text : (agentResult.cancelled ? 'Dibatalkan oleh user' : (agentResult.turnLimit ? 'Turn limit tercapai' : 'Berhasil')),
      );

      return DeckGenerationResult(
        success: isSuccess,
        slides: collectedSlides,
        pptxPath: landResult.ok ? '$deckName.pptx' : null,
        error: isSuccess ? null : (agentResult.isError ? agentResult.text : (agentResult.cancelled ? 'Dibatalkan oleh user' : (agentResult.turnLimit ? 'Turn limit tercapai' : 'Unknown error'))),
      );
    } catch (e) {
      debugPrint('⚠️ generateDeck: error: $e');
      onProgress(
        stage: 'done',
        label: '',
        done: 1,
        total: 1,
        status: 'error',
        summary: e.toString(),
      );
      return DeckGenerationResult(
        success: false,
        slides: [],
        pptxPath: null,
        error: e.toString(),
      );
    }
  }
}

/// Result from deck generation
class DeckGenerationResult {
  final bool success;
  final List<Slide> slides;
  final String? pptxPath;
  final String? error;

  DeckGenerationResult({
    required this.success,
    required this.slides,
    this.pptxPath,
    this.error,
  });
}

