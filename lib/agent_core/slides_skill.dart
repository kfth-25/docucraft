// DocuCraft Flutter — SlidesSkill (GenOffice-style)
//
// Mencerminkan GenOffice `apps/slides/src/renderer/ai/slides-skill.ts` (toolset
// generasi lengkap). Alat:
//   - generateStyleSkill: Panggilan LLM khusus untuk panduan gaya visual
//   - planDeckOutline: Perencanaan rekursif ter-batch untuk deck besar
//   - searchImages: Pencarian gambar di dalam tool dengan dedup
//   - generatePageCloud: Generasi single-page cloud (Genspark)
//   - generatePageLocal: Generasi single-page lokal (LLM spec → pptx)
//   - regenerateSlide: Ulang satu halaman di tempat
//   - generate_deck: Pipeline mandiri (style → plan → images → pages → land)
//   - save_style_template / list_style_templates: Persistensi style
//
// Skill ini mengikuti pipeline GenOffice secara persis:
//   1. Style Skill (panggilan LLM independen)
//   2. Outline planning (rekursif ter-batch)
//   3. Pencarian gambar (dedup di seluruh deck)
//   4. Generasi halaman (cloud/lokal, dengan marker)
//   5. Landing (landGeneratedPages menggabungkan marker ke deck)
//   6. Pass QC (audit opsional pasca-generasi)
//
// Ala GenOffice: menyimpan file .pptx sungguhan via PptxBuilder.
// Semua model dapat ditukar via AiConfig (seperti config Claude Code).

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show debugPrint;
import '../ai/run_state_machine.dart';
import 'agent_core.dart';
import '../models/slide.dart';
import '../services/pptx_builder.dart';
import '../services/quality_check.dart'
    show QualityChecker, QualityCheckResult;
import '../services/slide_spec.dart';
import '../services/svg_to_slide_elements.dart';

/// Strategy for generating a single page's SVG. Real wiring uses
/// `AiGenerationService.generateFromPrompt`; tests inject a fake.
abstract class PageGenerator {
  Future<String> generateSvg({
    required String topic,
    required int pageIndex,
    required int totalPages,
    required String title,
    required String brief,
    String layout = '',
  });
}

/// Callback the host supplies so the skill can push slides into the live
/// document. Receives each fully-formed `Slide` as it lands.
typedef SlideSink = void Function(Slide slide, {required bool replaceAll});

/// Callback for QC results after generation (per-page issues + fixes)
typedef QcResultCallback = void Function(int pageIndex, QualityCheckResult result);

/// Callback to re-land a slide after QC auto-fix (replaces at position)
typedef SlideFixer = Future<LandResult> Function(int slideIndex, Slide slide);

/// Callback to save generated slides as real PPTX (GenOffice-style)
typedef SlideSaver = Future<LandResult> Function({
  required List<Slide> slides,
  required String? deckName,
  required bool replaceAll,
});

/// Callback for in-tool style generation (Step 0)
typedef StyleGenerator = Future<StyleGenerationResult> Function({
  required String topic,
  String? questionnaire,
  String? styleHint,
  AbortSignal? signal,
});

/// Callback for in-tool deck outline planning (Step 1)
typedef OutlinePlanner = Future<OutlinePlanningResult> Function({
  required String topic,
  required int count,
  required int startPage,
  String? context,
  String? styleSkill,
  String? continueFromCoreHook,
  AbortSignal? signal,
});

/// Callback for in-tool image search (Step 1.5)
typedef ImageSearcher = Future<List<String>> Function(String query, int maxResults);

/// Callback for cloud single-page generation
typedef CloudPageGenerator = Future<PageGenerationResult> Function({
  required int pageIndex,
  required int totalPages,
  required String coreHook,
  required String style,
  required String title,
  required String brief,
  required String layout,
  required List<String> images,
  String? context,
  String? topic,
  required int canvasW,
  required int canvasH,
  AbortSignal? signal,
});

/// Callback for local single-page generation
typedef LocalPageGenerator = Future<PageGenerationResult> Function({
  required int pageIndex,
  required int totalPages,
  required String coreHook,
  required String style,
  required String title,
  required String brief,
  required String layout,
  required List<String> images,
  String? context,
  String? topic,
  required int canvasW,
  required int canvasH,
  AbortSignal? signal,
});

/// Callback to land generated pages (markers → real PPTX)
typedef PageLander = Future<LandResult> Function(
  List<String> pageMarkers, {
  String mode, // 'replace' | 'append' | 'insert_at'
  String? deckName,
  int? insertAt,
});

/// Callback to redo one slide in place
typedef SlideRegenerator = Future<LandResult> Function({
  required int slideIndex,
  required String marker,
});

/// Callback for outline review (Sprint 8)
typedef OutlineReviewer = Future<OutlineReviewResult> Function(
  String topic,
  List<OutlinePage> pages,
);

/// Callback to check if cloud page generation is available
typedef CloudAvailabilityChecker = Future<bool> Function();

/// Callback to get unread text attachments
typedef UnreadTextAttachmentsGetter = List<String> Function();

/// Callback to get the current slides in the deck
typedef SlidesGetter = List<Slide> Function();

/// Callback to replace a slide at a specific index
typedef SlideReplacer = void Function(int index, Slide slide);

/// Result of style skill generation
class StyleGenerationResult {
  final bool ok;
  final String? styleSkill;
  final String? error;

  const StyleGenerationResult({
    required this.ok,
    this.styleSkill,
    this.error,
  });
}

/// Result of outline planning
class OutlinePlanningResult {
  final bool ok;
  final OutlinePlanningOutput? outline;
  final String? error;

  const OutlinePlanningResult({
    required this.ok,
    this.outline,
    this.error,
  });
}

class OutlinePlanningOutput {
  final String? coreHook;
  final List<OutlinePlanningPage>? pages;

  const OutlinePlanningOutput({this.coreHook, this.pages});
}

class OutlinePlanningPage {
  final String? title;
  final String? type; // cover|content|data|closing
  final String? brief;
  final String? layout;
  final List<String>? imageQueries;

  const OutlinePlanningPage({
    this.title,
    this.type,
    this.brief,
    this.layout,
    this.imageQueries,
  });
}

/// Result of single page generation (cloud or local)
class PageGenerationResult {
  final bool ok;
  final String? marker;
  final String? error;
  final List<String>? imageFailures;

  const PageGenerationResult({
    required this.ok,
    this.marker,
    this.error,
    this.imageFailures,
  });
}

/// Result of outline review
class OutlineReviewResult {
  final List<OutlinePage>? pages;
  final bool cancelled;

  const OutlineReviewResult({this.pages, this.cancelled = false});
}

/// Skill state for tracking generation progress
class SkillState {
  bool htmlGenerated = false;
  bool? webSearched;
  int? plannedPages;
  List<String>? plannedTitles;
  List<bool>? pageDone;
  String? lastStyleSkill;
  String? lastTopic;
  List<Map<String, dynamic>>? blueprints;

  void reset() {
    htmlGenerated = false;
    webSearched = null;
    plannedPages = null;
    plannedTitles = null;
    pageDone = null;
    lastStyleSkill = null;
    lastTopic = null;
    blueprints = null;
  }
}

class SlidesSkill implements AgentSkill {
  final String _systemPrompt;
  final PageGenerator _generator;
  final SlideSink _sink;
  final SlideSaver? _saver;
  final StyleGenerator? _styleGenerator;
  final OutlinePlanner? _outlinePlanner;
  final ImageSearcher? _imageSearcher;
  final CloudPageGenerator? _cloudPageGenerator;
  final LocalPageGenerator? _localPageGenerator;
  final PageLander? _pageLander;
  final SlideRegenerator? _slideRegenerator;
  final OutlineReviewer? _outlineReviewer;
  final CloudAvailabilityChecker? _cloudAvailabilityChecker;
  final UnreadTextAttachmentsGetter? _unreadTextAttachmentsGetter;
  final SlidesGetter? _slidesGetter;
  final SlideReplacer? _slideReplacer;
  final QcResultCallback? _onQcResult;
  final SlideFixer? _slideFixer;
  List<OutlinePage> _pages;
  final String _topic;
  final String? _styleSkill;
  final int _canvasW;
  final int _canvasH;
  final int _retryBackoffMs;
  final void Function(DeckProgressEvent)? _onProgress;
  DeckBlueprintMeta? lastResult;
  final SkillState _state = SkillState();

  SlidesSkill({
    required String systemPrompt,
    required PageGenerator generator,
    required SlideSink sink,
    required String topic,
    required List<OutlinePage> pages,
    String? styleSkill,
    SlideSaver? saver,
    StyleGenerator? styleGenerator,
    OutlinePlanner? outlinePlanner,
    ImageSearcher? imageSearcher,
    CloudPageGenerator? cloudPageGenerator,
    LocalPageGenerator? localPageGenerator,
    PageLander? pageLander,
    SlideRegenerator? slideRegenerator,
    OutlineReviewer? outlineReviewer,
    CloudAvailabilityChecker? cloudAvailabilityChecker,
    UnreadTextAttachmentsGetter? unreadTextAttachmentsGetter,
    SlidesGetter? slidesGetter,
    SlideReplacer? slideReplacer,
    QcResultCallback? onQcResult,
    SlideFixer? slideFixer,
    void Function(DeckProgressEvent)? onProgress,
    int canvasW = 1280,
    int canvasH = 720,
    int retryBackoffMs = 2000,
  })  : _systemPrompt = systemPrompt,
        _generator = generator,
        _sink = sink,
        _saver = saver,
        _styleGenerator = styleGenerator,
        _outlinePlanner = outlinePlanner,
        _imageSearcher = imageSearcher,
        _cloudPageGenerator = cloudPageGenerator,
        _localPageGenerator = localPageGenerator,
        _pageLander = pageLander,
        _slideRegenerator = slideRegenerator,
        _outlineReviewer = outlineReviewer,
        _cloudAvailabilityChecker = cloudAvailabilityChecker,
        _unreadTextAttachmentsGetter = unreadTextAttachmentsGetter,
        _slidesGetter = slidesGetter,
        _slideReplacer = slideReplacer,
        _onQcResult = onQcResult,
        _slideFixer = slideFixer,
        _onProgress = onProgress,
        _canvasW = canvasW,
        _canvasH = canvasH,
        _retryBackoffMs = retryBackoffMs,
        _topic = topic,
        _pages = pages,
        _styleSkill = styleSkill;

  @override
  String get id => 'slides';

  @override
  String get systemPrompt => _systemPrompt;

  @override
  String buildContext() {
    final buffer = StringBuffer();

    // Inject <deck meta> block for style carryover across turns (GenOffice-style)
    buffer.writeln('<deck meta>');
    buffer.writeln('mode: generate');
    buffer.writeln('pages: ${_pages.length}');
    if (_topic.isNotEmpty) buffer.writeln('topic: $_topic');
    if ((_styleSkill ?? '').isNotEmpty) buffer.writeln('style: $_styleSkill');
    if (_state.lastStyleSkill != null && _state.lastStyleSkill!.isNotEmpty) {
      buffer.writeln('activeStyle: ${_state.lastStyleSkill}');
    }
    buffer.writeln('</deck meta>');

    if (_pages.isNotEmpty) {
      final preview = _pages
          .map((p) => '${p.index}. ${p.title}: ${p.brief}')
          .join('\n');
      buffer.writeln('');
      buffer.writeln('## Approved outline for "$_topic"');
      buffer.writeln(preview);
    }

    return buffer.toString();
  }

  @override
  List<AgentToolDef> get tools => [
    // ── Generation tools ──────────────────────────────────────────────
    AgentToolDef(
      name: 'generate_deck',
      description:
          'Generate a full presentation deck. Self-driven pipeline: style → plan → images → pages → land. '
          'Pass topic + approx_pages for internal planning, or core_hook + style + pages directly.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'topic': {'type': 'string', 'description': 'Deck topic'},
          'approx_pages': {'type': 'integer', 'description': 'Expected page count for internal planning'},
          'context': {'type': 'string', 'description': 'Real material/data for planning'},
          'core_hook': {'type': 'string', 'description': 'Narrative anchor sentence'},
          'style': {'type': 'string', 'description': 'Visual style description'},
          'pages': {
            'type': 'array',
            'description': 'Direct page briefs (when not using internal planning)',
            'items': {
              'type': 'object',
              'properties': {
                'title': {'type': 'string'},
                'type': {'type': 'string', 'enum': ['cover', 'content', 'data', 'closing']},
                'brief': {'type': 'string'},
                'layout': {'type': 'string'},
                'image_queries': {'type': 'array', 'items': {'type': 'string'}},
              },
              'required': ['title', 'brief', 'layout'],
            },
          },
          'insert_mode': {'type': 'string', 'enum': ['replace', 'append']},
          'style_template': {'type': 'string', 'description': 'Saved style template name'},
          'dataSource': {'type': 'string', 'enum': ['user', 'document', 'search', 'sample']},
        },
      },
    ),
    AgentToolDef(
      name: 'regenerate_slide',
      description:
          'Redo/redesign an existing page in place. First read_slide to get content, '
          'then call this with a detailed brief and layout.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Page to redo (0-based)'},
          'brief': {'type': 'string', 'description': 'Content and layout brief'},
          'title': {'type': 'string'},
          'layout': {'type': 'string'},
          'image_urls': {'type': 'array', 'items': {'type': 'string'}},
          'dataSource': {'type': 'string', 'enum': ['user', 'document', 'search', 'sample']},
        },
        'required': ['slideIndex', 'brief'],
      },
    ),
    // ── Style template tools ─────────────────────────────────────────
    AgentToolDef(
      name: 'save_style_template',
      description: 'Save the current deck\'s style as a reusable template.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': 'Template name (e.g. "minimal-blue")'},
        },
        'required': ['name'],
      },
    ),
    AgentToolDef(
      name: 'list_style_templates',
      description: 'List all saved style templates.',
      inputSchema: {'type': 'object', 'properties': {}},
    ),
    // ── Context tools ──────────────────────────────────────────────
    AgentToolDef(
      name: 'get_deck_context',
      description: 'Get the current deck state: slide count, titles, current slide, selected elements. Use before editing to understand what exists.',
      inputSchema: {'type': 'object', 'properties': {}},
    ),
    AgentToolDef(
      name: 'read_slide',
      description: 'Read the full content of a specific slide: all elements with their text, position, size, colors. Use before editing to see what\'s on the slide.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index to read (0-based)'},
        },
        'required': ['slideIndex'],
      },
    ),
    // ── Slide operations ──────────────────────────────────────────────
    AgentToolDef(
      name: 'add_slide',
      description: 'Add a new slide at a specific position. Returns the new slide index.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'index': {'type': 'integer', 'description': 'Position to insert at (0-based). Omit to append.'},
          'title': {'type': 'string', 'description': 'Slide title'},
          'brief': {'type': 'string', 'description': 'Content brief for the slide'},
          'layout': {'type': 'string', 'description': 'Layout variant name'},
        },
        'required': ['title', 'brief'],
      },
    ),
    AgentToolDef(
      name: 'delete_slide',
      description: 'Delete a slide by index.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index to delete (0-based)'},
        },
        'required': ['slideIndex'],
      },
    ),
    AgentToolDef(
      name: 'set_slide_background',
      description: 'Set the background color of a slide.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'color': {'type': 'string', 'description': 'Background color as hex (e.g. "#1a1a2e")'},
        },
        'required': ['slideIndex', 'color'],
      },
    ),
    // ── Element editing ──────────────────────────────────────────────
    AgentToolDef(
      name: 'set_element_text',
      description: 'Update the text content of an element on a slide.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'elementIndex': {'type': 'integer', 'description': 'Element index within the slide (0-based)'},
          'text': {'type': 'string', 'description': 'New text content'},
        },
        'required': ['slideIndex', 'elementIndex', 'text'],
      },
    ),
    AgentToolDef(
      name: 'set_element_style',
      description: 'Update the style of an element (font size, color, bold, etc).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'elementIndex': {'type': 'integer', 'description': 'Element index within the slide (0-based)'},
          'fontSize': {'type': 'number', 'description': 'Font size in pt'},
          'color': {'type': 'string', 'description': 'Text color as hex'},
          'bold': {'type': 'boolean', 'description': 'Bold text'},
        },
        'required': ['slideIndex', 'elementIndex'],
      },
    ),
    AgentToolDef(
      name: 'set_element_fill',
      description: 'Update the fill color of a shape element.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'elementIndex': {'type': 'integer', 'description': 'Element index within the slide (0-based)'},
          'color': {'type': 'string', 'description': 'Fill color as hex (e.g. "#6366F1")'},
        },
        'required': ['slideIndex', 'elementIndex', 'color'],
      },
    ),
    // ── Transform & creation ──────────────────────────────────────────
    AgentToolDef(
      name: 'set_element_transform',
      description: 'Update position, size, or rotation of an element.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'elementIndex': {'type': 'integer', 'description': 'Element index (0-based)'},
          'x': {'type': 'number', 'description': 'X position in px'},
          'y': {'type': 'number', 'description': 'Y position in px'},
          'width': {'type': 'number', 'description': 'Width in px'},
          'height': {'type': 'number', 'description': 'Height in px'},
          'rotation': {'type': 'number', 'description': 'Rotation in degrees'},
        },
        'required': ['slideIndex', 'elementIndex'],
      },
    ),
    AgentToolDef(
      name: 'add_text_box',
      description: 'Add a text box element to a slide.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'x': {'type': 'number', 'description': 'X position in px'},
          'y': {'type': 'number', 'description': 'Y position in px'},
          'width': {'type': 'number', 'description': 'Width in px'},
          'height': {'type': 'number', 'description': 'Height in px'},
          'text': {'type': 'string', 'description': 'Text content'},
          'fontSize': {'type': 'number', 'description': 'Font size in pt'},
          'color': {'type': 'string', 'description': 'Text color as hex'},
          'bold': {'type': 'boolean', 'description': 'Bold text'},
        },
        'required': ['slideIndex', 'text'],
      },
    ),
    AgentToolDef(
      name: 'add_shape',
      description: 'Add a shape element to a slide.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'shapeType': {'type': 'string', 'description': 'Shape type: rect, circle, diamond, triangle, arrow, hexagon'},
          'x': {'type': 'number', 'description': 'X position in px'},
          'y': {'type': 'number', 'description': 'Y position in px'},
          'width': {'type': 'number', 'description': 'Width in px'},
          'height': {'type': 'number', 'description': 'Height in px'},
          'fillColor': {'type': 'string', 'description': 'Fill color as hex'},
        },
        'required': ['slideIndex', 'shapeType'],
      },
    ),
    AgentToolDef(
      name: 'delete_element',
      description: 'Delete an element from a slide.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'elementIndex': {'type': 'integer', 'description': 'Element index (0-based)'},
        },
        'required': ['slideIndex', 'elementIndex'],
      },
    ),
    AgentToolDef(
      name: 'set_speaker_notes',
      description: 'Set speaker notes for a slide.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'notes': {'type': 'string', 'description': 'Speaker notes text'},
        },
        'required': ['slideIndex', 'notes'],
      },
    ),
    // ── Tables ──────────────────────────────────────────────────────
    AgentToolDef(
      name: 'add_table',
      description: 'Add a table element to a slide.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'rows': {'type': 'integer', 'description': 'Number of rows'},
          'cols': {'type': 'integer', 'description': 'Number of columns'},
          'x': {'type': 'number', 'description': 'X position in px'},
          'y': {'type': 'number', 'description': 'Y position in px'},
          'width': {'type': 'number', 'description': 'Width in px'},
          'height': {'type': 'number', 'description': 'Height in px'},
          'cells': {
            'type': 'array',
            'description': 'Optional 2D array of cell values',
            'items': {'type': 'array', 'items': {'type': 'string'}},
          },
          'hasHeader': {'type': 'boolean', 'description': 'First row is header'},
        },
        'required': ['slideIndex', 'rows', 'cols'],
      },
    ),
    AgentToolDef(
      name: 'edit_table_cell',
      description: 'Edit a specific cell in a table.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'elementIndex': {'type': 'integer', 'description': 'Table element index (0-based)'},
          'row': {'type': 'integer', 'description': 'Row index (0-based)'},
          'col': {'type': 'integer', 'description': 'Column index (0-based)'},
          'value': {'type': 'string', 'description': 'New cell value'},
        },
        'required': ['slideIndex', 'elementIndex', 'row', 'col', 'value'],
      },
    ),
    AgentToolDef(
      name: 'edit_table_structure',
      description: 'Insert or delete rows/columns in a table.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'elementIndex': {'type': 'integer', 'description': 'Table element index (0-based)'},
          'action': {'type': 'string', 'enum': ['insertRow', 'deleteRow', 'insertCol', 'deleteCol'], 'description': 'Action to perform'},
          'index': {'type': 'integer', 'description': 'Row/col index to insert at or delete'},
        },
        'required': ['slideIndex', 'elementIndex', 'action', 'index'],
      },
    ),
    // ── Charts ──────────────────────────────────────────────────────
    AgentToolDef(
      name: 'add_chart',
      description: 'Add a chart element to a slide.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'chartType': {'type': 'string', 'enum': ['bar', 'line', 'pie', 'area', 'doughnut'], 'description': 'Chart type'},
          'x': {'type': 'number', 'description': 'X position in px'},
          'y': {'type': 'number', 'description': 'Y position in px'},
          'width': {'type': 'number', 'description': 'Width in px'},
          'height': {'type': 'number', 'description': 'Height in px'},
          'labels': {'type': 'array', 'description': 'Category labels', 'items': {'type': 'string'}},
          'values': {'type': 'array', 'description': 'Data values', 'items': {'type': 'number'}},
          'title': {'type': 'string', 'description': 'Chart title'},
        },
        'required': ['slideIndex', 'chartType', 'labels', 'values'],
      },
    ),
    AgentToolDef(
      name: 'edit_chart',
      description: 'Update chart data, type, or styling.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'elementIndex': {'type': 'integer', 'description': 'Chart element index (0-based)'},
          'chartType': {'type': 'string', 'enum': ['bar', 'line', 'pie', 'area', 'doughnut']},
          'labels': {'type': 'array', 'description': 'Category labels', 'items': {'type': 'string'}},
          'values': {'type': 'array', 'description': 'Data values', 'items': {'type': 'number'}},
          'title': {'type': 'string', 'description': 'Chart title'},
        },
        'required': ['slideIndex', 'elementIndex'],
      },
    ),
    // ── Images ──────────────────────────────────────────────────────
    AgentToolDef(
      name: 'insert_web_image',
      description: 'Insert an image from a URL into a slide.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'url': {'type': 'string', 'description': 'Image URL'},
          'x': {'type': 'number', 'description': 'X position in px'},
          'y': {'type': 'number', 'description': 'Y position in px'},
          'width': {'type': 'number', 'description': 'Width in px'},
          'height': {'type': 'number', 'description': 'Height in px'},
        },
        'required': ['slideIndex', 'url'],
      },
    ),
    AgentToolDef(
      name: 'crop_image',
      description: 'Crop an image element by setting source rectangle.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'elementIndex': {'type': 'integer', 'description': 'Image element index (0-based)'},
          'srcX': {'type': 'number', 'description': 'Source X offset'},
          'srcY': {'type': 'number', 'description': 'Source Y offset'},
          'srcWidth': {'type': 'number', 'description': 'Source width to crop'},
          'srcHeight': {'type': 'number', 'description': 'Source height to crop'},
        },
        'required': ['slideIndex', 'elementIndex', 'srcX', 'srcY', 'srcWidth', 'srcHeight'],
      },
    ),
    AgentToolDef(
      name: 'replace_image',
      description: 'Replace an image element with a new URL.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'elementIndex': {'type': 'integer', 'description': 'Image element index (0-based)'},
          'url': {'type': 'string', 'description': 'New image URL'},
        },
        'required': ['slideIndex', 'elementIndex', 'url'],
      },
    ),
    // ── Batch operations ──────────────────────────────────────────────
    AgentToolDef(
      name: 'execute_slide_script',
      description: 'Run a batch script to manipulate multiple elements at once. Script is a list of commands: setBox(idx,x,y,w,h), moveBy(idx,dx,dy), resizeBy(idx,dw,dh), setText(idx,text), setFill(idx,color), setStroke(idx,color,width). Use "els" to reference all elements.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'script': {'type': 'string', 'description': 'Script commands (one per line)'},
        },
        'required': ['slideIndex', 'script'],
      },
    ),
    AgentToolDef(
      name: 'apply_ops',
      description: 'Apply batch operations using canonical EMU-based coordinates. Each op: {op: "setBox"|"moveBy"|"resizeBy"|"setText"|"setFill", idx: int, ...}. Max 50 ops.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'ops': {
            'type': 'array',
            'description': 'List of operations',
            'items': {'type': 'object'},
          },
        },
        'required': ['slideIndex', 'ops'],
      },
    ),
    // ── SmartArt & groups ──────────────────────────────────────────────
    AgentToolDef(
      name: 'add_smartart',
      description: 'Add a SmartArt diagram to a slide.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'layout': {'type': 'string', 'enum': ['list', 'process', 'cycle', 'hierarchy', 'pyramid', 'matrix'], 'description': 'SmartArt layout type'},
          'items': {'type': 'array', 'description': 'Text items for the diagram', 'items': {'type': 'string'}},
          'x': {'type': 'number', 'description': 'X position in px'},
          'y': {'type': 'number', 'description': 'Y position in px'},
          'width': {'type': 'number', 'description': 'Width in px'},
          'height': {'type': 'number', 'description': 'Height in px'},
        },
        'required': ['slideIndex', 'layout', 'items'],
      },
    ),
    AgentToolDef(
      name: 'ungroup_element',
      description: 'Ungroup a group element into its children.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'elementIndex': {'type': 'integer', 'description': 'Group element index (0-based)'},
        },
        'required': ['slideIndex', 'elementIndex'],
      },
    ),
    // ── Blueprints ──────────────────────────────────────────────────
    AgentToolDef(
      name: 'save_blueprint',
      description: 'Save the current deck generation recipe (topic, style, outline) as a blueprint for reuse.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': 'Blueprint name'},
          'topic': {'type': 'string', 'description': 'Deck topic'},
        },
        'required': ['name'],
      },
    ),
    AgentToolDef(
      name: 'load_blueprint',
      description: 'Load a saved blueprint to regenerate a similar deck.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'blueprintId': {'type': 'string', 'description': 'Blueprint ID to load'},
        },
        'required': ['blueprintId'],
      },
    ),
    AgentToolDef(
      name: 'list_blueprints',
      description: 'List all saved blueprints.',
      inputSchema: {'type': 'object', 'properties': {}},
    ),
    // ── Stroke & opacity ──────────────────────────────────────────────
    AgentToolDef(
      name: 'set_element_stroke',
      description: 'Update the stroke/border of an element.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'elementIndex': {'type': 'integer', 'description': 'Element index (0-based)'},
          'color': {'type': 'string', 'description': 'Stroke color as hex'},
          'width': {'type': 'number', 'description': 'Stroke width in pt'},
        },
        'required': ['slideIndex', 'elementIndex'],
      },
    ),
    AgentToolDef(
      name: 'set_picture_opacity',
      description: 'Set the opacity of an image element.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'elementIndex': {'type': 'integer', 'description': 'Image element index (0-based)'},
          'opacity': {'type': 'number', 'description': 'Opacity 0.0-1.0'},
        },
        'required': ['slideIndex', 'elementIndex', 'opacity'],
      },
    ),
    AgentToolDef(
      name: 'edit_table_style',
      description: 'Apply a style preset to a table.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'slideIndex': {'type': 'integer', 'description': 'Slide index (0-based)'},
          'elementIndex': {'type': 'integer', 'description': 'Table element index (0-based)'},
          'style': {'type': 'string', 'enum': ['default', 'accent1', 'accent2', 'accent3', 'success', 'warning', 'danger'], 'description': 'Table style preset'},
        },
        'required': ['slideIndex', 'elementIndex', 'style'],
      },
    ),
    // ── Planning & clarification ──────────────────────────────────────
    AgentToolDef(
      name: 'plan_deck',
      description: 'Plan a deck outline without generating. Returns core_hook + pages for user review.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'topic': {'type': 'string', 'description': 'Deck topic'},
          'approxPages': {'type': 'integer', 'description': 'Approximate page count'},
          'context': {'type': 'string', 'description': 'Additional context or data'},
        },
        'required': ['topic'],
      },
    ),
    AgentToolDef(
      name: 'ask_clarification',
      description: 'Ask the user a question to clarify requirements before generating.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'question': {'type': 'string', 'description': 'Question to ask the user'},
          'options': {'type': 'array', 'description': 'Optional multiple choice options', 'items': {'type': 'string'}},
        },
        'required': ['question'],
      },
    ),
    // ── Image tools ──────────────────────────────────────────────────
    AgentToolDef(
      name: 'image_search',
      description: 'Search for images by keyword. Returns list of URLs.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': 'Search query'},
          'maxResults': {'type': 'integer', 'description': 'Max results to return'},
        },
        'required': ['query'],
      },
    ),
    AgentToolDef(
      name: 'generate_image',
      description: 'Generate an AI image from a text prompt.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'prompt': {'type': 'string', 'description': 'Image generation prompt'},
          'width': {'type': 'integer', 'description': 'Image width'},
          'height': {'type': 'integer', 'description': 'Image height'},
        },
        'required': ['prompt'],
      },
    ),
    AgentToolDef(
      name: 'analyze_media',
      description: 'Analyze an image and return a description.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'url': {'type': 'string', 'description': 'Image URL to analyze'},
        },
        'required': ['url'],
      },
    ),
    AgentToolDef(
      name: 'web_search',
      description: 'Search the web for information.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': 'Search query'},
        },
        'required': ['query'],
      },
    ),
  ];

  @override
  String? verifyResponse(String finalText, List<ExecutedToolCall> executed) {
    // Reject runs that end without a successful generate_deck.
    if (executed.any((e) => e.name == 'generate_deck' && e.ok)) return null;
    return 'You said the deck is ready but I do not see a successful generate_deck tool call. Please call generate_deck with the approved outline.';
  }

  @override
  Future<ToolExecution> executeTool(AgentToolCall call, {AbortSignal? signal}) async {
    switch (call.name) {
      case 'generate_deck':
        return _executeGenerateDeck(call.input, signal: signal);
      case 'regenerate_slide':
        return _executeRegenerateSlide(call.input, signal: signal);
      case 'save_style_template':
        return _executeSaveStyleTemplate(call.input);
      case 'list_style_templates':
        return _executeListStyleTemplates();
      case 'get_deck_context':
        return _executeGetDeckContext();
      case 'read_slide':
        return _executeReadSlide(call.input);
      case 'add_slide':
        return _executeAddSlide(call.input);
      case 'delete_slide':
        return _executeDeleteSlide(call.input);
      case 'set_slide_background':
        return _executeSetSlideBackground(call.input);
      case 'set_element_text':
        return _executeSetElementText(call.input);
      case 'set_element_style':
        return _executeSetElementStyle(call.input);
      case 'set_element_fill':
        return _executeSetElementFill(call.input);
      case 'set_element_transform':
        return _executeSetElementTransform(call.input);
      case 'add_text_box':
        return _executeAddTextBox(call.input);
      case 'add_shape':
        return _executeAddShape(call.input);
      case 'delete_element':
        return _executeDeleteElement(call.input);
      case 'set_speaker_notes':
        return _executeSetSpeakerNotes(call.input);
      case 'add_table':
        return _executeAddTable(call.input);
      case 'edit_table_cell':
        return _executeEditTableCell(call.input);
      case 'edit_table_structure':
        return _executeEditTableStructure(call.input);
      case 'add_chart':
        return _executeAddChart(call.input);
      case 'edit_chart':
        return _executeEditChart(call.input);
      case 'insert_web_image':
        return _executeInsertWebImage(call.input);
      case 'crop_image':
        return _executeCropImage(call.input);
      case 'replace_image':
        return _executeReplaceImage(call.input);
      case 'execute_slide_script':
        return _executeSlideScript(call.input);
      case 'apply_ops':
        return _executeApplyOps(call.input);
      case 'add_smartart':
        return _executeAddSmartArt(call.input);
      case 'ungroup_element':
        return _executeUngroupElement(call.input);
      case 'save_blueprint':
        return _executeSaveBlueprint(call.input);
      case 'load_blueprint':
        return _executeLoadBlueprint(call.input);
      case 'list_blueprints':
        return _executeListBlueprints();
      case 'set_element_stroke':
        return _executeSetElementStroke(call.input);
      case 'set_picture_opacity':
        return _executeSetPictureOpacity(call.input);
      case 'edit_table_style':
        return _executeEditTableStyle(call.input);
      case 'plan_deck':
        return _executePlanDeck(call.input);
      case 'ask_clarification':
        return _executeAskClarification(call.input);
      case 'image_search':
        return _executeImageSearch(call.input);
      case 'generate_image':
        return _executeGenerateImage(call.input);
      case 'analyze_media':
        return _executeAnalyzeMedia(call.input);
      case 'web_search':
        return _executeWebSearch(call.input);
      default:
        return ToolExecution(
          output: 'Unknown tool: ${call.name}',
          isError: true,
          summary: call.name,
        );
    }
  }

  Future<ToolExecution> _executeGenerateDeck(
    Map<String, dynamic> input, {
    AbortSignal? signal,
  }) async {
    // Check for unread text attachments
    final unread = _unreadTextAttachmentsGetter?.call() ?? [];
    if (unread.isNotEmpty) {
      return ToolExecution(
        output: 'Text attachment(s) not read yet: ${unread.join(', ')}. '
            'Read each one first, then call generate_deck again.',
        isError: true,
        summary: 'generate_deck blocked',
      );
    }

    // Check if generation pipeline is available
    final useCloud = _cloudPageGenerator != null &&
        await (_cloudAvailabilityChecker?.call() ?? Future.value(false));
    final hasGenerator = _generator != null || _localPageGenerator != null || useCloud;
    if (!hasGenerator) {
      return ToolExecution(
        output: 'No page generation pipeline is available in this environment',
        isError: true,
        summary: 'generate_deck failed',
      );
    }

    const planBatch = 12; // Per-batch planning cap
    const genBatch = 2; // Per-page generation concurrency
    const backoffMs = 2000; // Retry backoff base

    String coreHook = (input['core_hook'] as String?)?.trim() ?? '';
    final style = (input['style'] as String?)?.trim() ?? '';
    final pagesInput = input['pages'] as List<dynamic>? ?? [];
    final topic = (input['topic'] as String?)?.trim() ?? _topic;
    final context = (input['context'] as String?)?.trim();
    final insertMode = input['insert_mode'] == 'append' ? 'append' : 'replace';
    final styleTemplateName = (input['style_template'] as String?)?.trim();

    // Parse pages from input
    final pages = <Map<String, dynamic>>[];
    for (final p in pagesInput) {
      if (p is Map<String, dynamic>) {
        pages.add({
          'title': p['title'] ?? '',
          'type': p['type'] ?? 'content',
          'brief': p['brief'] ?? '',
          'layout': p['layout'] ?? '',
          'image_queries': (p['image_queries'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
        });
      }
    }

    // Fall back to constructor's _pages if no pages provided in input
    if (pages.isEmpty && _pages.isNotEmpty) {
      for (final p in _pages) {
        pages.add({
          'title': p.title,
          'type': 'content',
          'brief': p.brief,
          'layout': p.layout ?? '',
          'image_queries': <String>[],
        });
      }
    }

    // ── Figure-Provenance Gate ──────────────────────────────────────
    // Reject pages with unverified statistics (%, $, large numbers)
    // unless they declare dataSource: 'search' or 'document'.
    final statPattern = RegExp(r'\b\d[\d,]*\.?\d*\s*[%$MBKk]|\$\s*[\d,]+');
    for (int i = 0; i < pages.length; i++) {
      final brief = pages[i]['brief']?.toString() ?? '';
      final dataSource = pages[i]['dataSource']?.toString() ?? '';
      final hasSource = dataSource == 'search' || dataSource == 'document';
      if (!hasSource && statPattern.hasMatch(brief)) {
        // Strip unverified statistics from the brief to prevent invented data
        final cleaned = brief.replaceAllMapped(statPattern, (m) => '[unverified]');
        pages[i]['brief'] = cleaned;
        pages[i]['_provenanceWarning'] = 'Statistics in brief removed — no dataSource declared';
      }
    }

    // ── Step 0: Generate Style Skill ───────────────────────────────
    String styleSkill = '';
    if (_styleGenerator != null) {
      _emitProgress(StyleProgressEvent(
        label: 'Generating style...',
        status: 'running',
        summary: 'Creating visual style guide',
      ));

      final styleResult = await _styleGenerator!(
        topic: topic,
        styleHint: style.isNotEmpty ? style : null,
        questionnaire: context,
        signal: signal,
      );

      if (styleResult.ok && styleResult.styleSkill != null) {
        styleSkill = styleResult.styleSkill!;
      }

      _emitProgress(StyleProgressEvent(
        label: 'Generating style...',
        status: 'done',
        summary: 'Style generated',
      ));
    } else {
      styleSkill = style.isNotEmpty ? style : _styleSkill ?? '';
    }

    // ── Step 1: Plan Outline ──────────────────────────────────────
    int approxForProgress = pages.isEmpty
        ? (int.tryParse((input['approx_pages'] ?? '0').toString()) ?? 4)
        : pages.length;

    if (pages.isEmpty) {
      if (topic.isEmpty || approxForProgress == 0) {
        return ToolExecution(
          output: 'generate_deck requires topic + approx_pages or pages directly',
          isError: true,
          summary: 'generate_deck failed',
        );
      }

      if (_outlinePlanner == null) {
        return ToolExecution(
          output: 'No planning pipeline available; pass pages directly',
          isError: true,
          summary: 'generate_deck failed',
        );
      }

      _emitProgress(PlanProgressEvent(
        label: 'Planning outline...',
        done: 0,
        total: approxForProgress,
        status: 'running',
        summary: 'Planning deck structure',
      ));

      int planned = 0;
      while (planned < approxForProgress) {
        if (signal?.aborted == true) {
          return _cancelResult(0, approxForProgress);
        }
        final count = (approxForProgress - planned).clamp(1, planBatch);

        final planResult = await _outlinePlanner!(
          topic: topic,
          count: count,
          startPage: planned + 1,
          context: context,
          styleSkill: styleSkill.isNotEmpty ? styleSkill : null,
          continueFromCoreHook: planned > 0 ? coreHook : null,
          signal: signal,
        );

        if (!planResult.ok || planResult.outline == null || planResult.outline!.pages == null) {
          _emitProgress(PlanProgressEvent(
            label: 'Planning outline...',
            done: 0,
            total: approxForProgress,
            status: 'error',
            summary: 'Planning failed',
          ));
          return ToolExecution(
            output: 'Planning failed: ${planResult.error ?? "empty outline"}',
            isError: true,
            summary: 'generate_deck failed',
          );
        }

        if (planned == 0 && planResult.outline!.coreHook != null) {
          coreHook = planResult.outline!.coreHook!;
        }

        for (final p in planResult.outline!.pages!) {
          pages.add({
            'title': p.title ?? '',
            'type': p.type ?? 'content',
            'brief': p.brief ?? '',
            'layout': p.layout ?? '',
            'image_queries': p.imageQueries ?? [],
          });
        }
        planned += planResult.outline!.pages!.length;

        _emitProgress(PlanProgressEvent(
          label: 'Planning outline...',
          done: planned,
          total: approxForProgress,
          status: 'running',
          summary: 'Planned $planned of $approxForProgress pages',
        ));

        if (planResult.outline!.pages!.length < count) break;
      }

      _emitProgress(PlanProgressEvent(
        label: 'Planning outline...',
        done: pages.length,
        total: pages.length,
        status: 'done',
        summary: 'Planned ${pages.length} pages',
      ));
    }

    // ── Step 1.4: Outline Review ──────────────────────────────────
    if (_outlineReviewer != null && pages.isNotEmpty) {
      final reviewable = pages.asMap().entries.map((e) => OutlinePage(
        index: e.key + 1,
        title: e.value['title']?.toString() ?? '',
        brief: e.value['brief']?.toString() ?? '',
        layout: e.value['layout']?.toString(),
      )).toList();

      final reviewResult = await _outlineReviewer(topic, reviewable);
      if (reviewResult.cancelled) {
        _emitProgress(const DoneProgressEvent(total: 0, summary: 'Outline rejected'));
        return ToolExecution(
          output: 'User discarded the outline',
          isError: true,
          summary: 'generate_deck cancelled',
        );
      }
      if (reviewResult.pages != null && reviewResult.pages!.isNotEmpty) {
        for (int i = 0; i < pages.length && i < reviewResult.pages!.length; i++) {
          final e = reviewResult.pages![i];
          pages[i]['title'] = e.title;
          pages[i]['brief'] = e.brief;
        }
      }
    }

    // ── Step 1.5: Image Search ────────────────────────────────────
    if (_imageSearcher != null) {
      final isUrl = (String s) => s.startsWith('http://') || s.startsWith('https://');
      final normKw = (String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

      // Collect unique keywords
      final uniqueKeywords = <String>[];
      final seenKw = <String>{};
      for (final p in pages) {
        final queries = p['image_queries'] as List<String>? ?? [];
        for (final q in queries) {
          if (q.isEmpty || isUrl(q)) continue;
          final k = normKw(q);
          if (!seenKw.contains(k)) {
            seenKw.add(k);
            uniqueKeywords.add(q);
          }
        }
      }

      // Search each keyword once
      final candidatesByKw = <String, List<String>>{};
      if (uniqueKeywords.isNotEmpty) {
        _emitProgress(ImagesProgressEvent(
          label: 'Searching images...',
          done: 0,
          total: uniqueKeywords.length,
          status: 'running',
          summary: 'Searching ${uniqueKeywords.length} keywords',
        ));

        int imagesDone = 0;
        for (final kw in uniqueKeywords) {
          if (signal?.aborted == true) break;
          try {
            final urls = await _imageSearcher!(kw, 5);
            candidatesByKw[normKw(kw)] = urls;
          } catch (_) {}
          imagesDone++;
          _emitProgress(ImagesProgressEvent(
            label: 'Searching images...',
            done: imagesDone,
            total: uniqueKeywords.length,
            status: 'running',
            summary: 'Searched $imagesDone of ${uniqueKeywords.length}',
          ));
        }

        // Allocate images to pages (deduped)
        final usedUrls = <String>{};
        for (final p in pages) {
          final queries = p['image_queries'] as List<String>? ?? [];
          final resolved = <String>[];
          for (final q in queries) {
            if (q.isEmpty) continue;
            if (isUrl(q)) {
              resolved.add(q);
              usedUrls.add(q);
            } else {
              final candidates = candidatesByKw[normKw(q)] ?? [];
              final pick = candidates.firstWhere((u) => !usedUrls.contains(u), orElse: () => candidates.firstOrNull ?? '');
              if (pick.isNotEmpty) {
                resolved.add(pick);
                usedUrls.add(pick);
              }
            }
          }
          p['image_queries'] = resolved;
        }

        _emitProgress(ImagesProgressEvent(
          label: 'Searching images...',
          done: uniqueKeywords.length,
          total: uniqueKeywords.length,
          status: 'done',
          summary: 'Found ${uniqueKeywords.length} image sets',
        ));
      }
    }

    if (coreHook.isEmpty) coreHook = topic;
    if (styleSkill.isEmpty) {
      styleSkill = 'Clean modern style: white background, dark text, blue accent';
    }
    final total = pages.length;
    if (total == 0) {
      return ToolExecution(
        output: 'No pages to generate (the plan is empty)',
        isError: true,
        summary: 'generate_deck failed',
      );
    }

    // Update skill state
    _state.plannedPages = total;
    _state.plannedTitles = pages.map((p) => p['title']?.toString() ?? '').toList();
    _state.pageDone = List.filled(total, false);
    _state.lastStyleSkill = styleSkill;
    _state.lastTopic = topic;

    final deckName = pages.first['title']?.toString() ?? topic;

    // Track collected slides for QC pass after landing
    final collectedSlides = <int, Slide>{}; // pageIndex → Slide

    // Wrapped sink that captures slides for QC
    void captureSink(Slide slide, {required bool replaceAll}) {
      _sink(slide, replaceAll: replaceAll);
    }

    // ── Step 2: Generate Page by Page ─────────────────────────────
    final markerByIndex = List<String?>.filled(total, null);
    final doneFlags = List<bool>.filled(total, false);
    final genFailed = <int>[];
    final landFailed = <int>[];
    final pageErrors = List<String?>.filled(total, null);
    int landedPages = 0;
    bool firstDone = false;
    int baseOffset = 0;
    int nextToLand = 0;

    // Page progress items
    final pageProgressItems = pages.asMap().entries.map((e) {
      final p = e.value;
      return PageProgressItem(
        title: p['title']?.toString() ?? 'Page ${e.key + 1}',
        status: PageProgressStatus.pending,
      );
    }).toList();

    _emitProgress(PagesProgressEvent(
      label: 'Generating pages...',
      done: 0,
      total: total,
      status: 'running',
      summary: 'Starting generation',
      pages: pageProgressItems,
    ));

    // Generation function
    Future<String?> genOne(Map<String, dynamic> pageData, int pageIndex) async {
      // Update to running
      pageProgressItems[pageIndex - 1] = PageProgressItem(
        title: pageData['title']?.toString() ?? 'Page $pageIndex',
        status: PageProgressStatus.running,
      );
      _emitProgress(PagesProgressEvent(
        label: 'Generating pages...',
        done: landedPages,
        total: total,
        status: 'running',
        summary: 'Generating page $pageIndex of $total',
        pages: pageProgressItems,
      ));

      final images = (pageData['image_queries'] as List<String>? ?? [])
          .where((u) => u.startsWith('http'))
          .toList();

      // Use cloud or local generator
      if (useCloud && _cloudPageGenerator != null) {
        for (int attempt = 0; attempt < 2; attempt++) {
          if (signal?.aborted == true) return null;
          if (attempt > 0) await Future.delayed(Duration(milliseconds: backoffMs));

          final result = await _cloudPageGenerator!(
            pageIndex: pageIndex,
            totalPages: total,
            coreHook: coreHook,
            style: styleSkill,
            title: pageData['title']?.toString() ?? '',
            brief: pageData['brief']?.toString() ?? '',
            layout: pageData['layout']?.toString() ?? '',
            images: images,
            context: context,
            topic: topic,
            canvasW: _canvasW,
            canvasH: _canvasH,
            signal: signal,
          );

          if (result.ok && result.marker != null) {
            pageErrors[pageIndex - 1] = null;
            return result.marker;
          }
          pageErrors[pageIndex - 1] = result.error;
        }
      } else if (_localPageGenerator != null) {
        for (int attempt = 0; attempt < 2; attempt++) {
          if (signal?.aborted == true) return null;
          if (attempt > 0) await Future.delayed(Duration(milliseconds: backoffMs));

          final result = await _localPageGenerator!(
            pageIndex: pageIndex,
            totalPages: total,
            coreHook: coreHook,
            style: styleSkill,
            title: pageData['title']?.toString() ?? '',
            brief: pageData['brief']?.toString() ?? '',
            layout: pageData['layout']?.toString() ?? '',
            images: images,
            context: context,
            topic: topic,
            canvasW: _canvasW,
            canvasH: _canvasH,
            signal: signal,
          );

          if (result.ok && result.marker != null) {
            pageErrors[pageIndex - 1] = null;
            return result.marker;
          }
          pageErrors[pageIndex - 1] = result.error;
        }
      } else if (_generator != null) {
        // Fallback to SVG/JSON generator
        try {
          final svg = await _generator.generateSvg(
            topic: topic,
            pageIndex: pageIndex,
            totalPages: total,
            title: pageData['title']?.toString() ?? '',
            brief: pageData['brief']?.toString() ?? '',
            layout: pageData['layout']?.toString() ?? '',
          );
          pageErrors[pageIndex - 1] = null;
          return svg; // Return as marker (JSON spec or SVG)
        } catch (e) {
          // Parse error kind from classified exceptions: "[timeout] page 1: ..."
          final errStr = e.toString();
          final kindMatch = RegExp(r'^\[(\w+)\]\s*').firstMatch(errStr);
          final errKind = kindMatch?.group(1) ?? 'error';
          final cleanError = errStr.replaceFirst(RegExp(r'^\[\w+\]\s*'), '');
          pageErrors[pageIndex - 1] = '$errKind: $cleanError';
          debugPrint('❌ [SlidesSkill] Page $pageIndex error ($errKind): $cleanError');
        }
      }
      return null;
    }

    // Flush landed pages
    Future<void> flushLanded() async {
      while (nextToLand < total && markerByIndex[nextToLand] != null) {
        if (signal?.aborted == true) return;
        final marker = markerByIndex[nextToLand]!;
        if (marker.isNotEmpty) {
          if (_pageLander != null) {
            final mode = firstDone ? 'append' : insertMode;
            final result = await _pageLander!(
              [marker],
              mode: mode,
              deckName: deckName,
            );
            if (result.ok) {
              if (!firstDone) baseOffset = result.appendedFrom ?? 0;
              landedPages++;
              firstDone = true;
              doneFlags[nextToLand] = true;
              pageProgressItems[nextToLand] = PageProgressItem(
                title: pageProgressItems[nextToLand].title,
                status: PageProgressStatus.done,
              );
              _emitProgress(PagesProgressEvent(
                label: 'Generating pages...',
                done: landedPages,
                total: total,
                status: 'running',
                summary: landedPages < total
                    ? 'Generating page ${landedPages + 1} of $total'
                    : 'Finalizing...',
                pages: pageProgressItems,
              ));
            } else {
              landFailed.add(nextToLand);
              pageProgressItems[nextToLand] = PageProgressItem(
                title: pageProgressItems[nextToLand].title,
                status: PageProgressStatus.error,
                error: result.error,
              );
            }
          } else {
            // Fallback: parse marker into SlideElements
            // Detect JSON spec (starts with {) vs SVG (starts with <svg)
            List<SlideElement> elements;
            final trimmed = marker.trimLeft();
            debugPrint('🔍 [flushLanded] Marker type: ${trimmed.startsWith('{') ? 'JSON' : 'SVG'}, length: ${marker.length}');
            debugPrint('🔍 [flushLanded] Marker preview: ${marker.substring(0, marker.length > 200 ? 200 : marker.length)}');
            String? specBg;
            if (trimmed.startsWith('{')) {
              // JSON spec (GenOffice-style) — parse via slide_spec.dart
              final parsed = parseSlideSpec(marker);
              if (parsed.ok) {
                clampSpecToCanvas(parsed.spec!);
                elements = specToSlideElements(parsed.spec!, scale: specToModelScale);
                specBg = parsed.spec!.background;
                debugPrint('✅ [JSON Spec] Parsed ${elements.length} elements, bg: $specBg');
              } else {
                debugPrint('⚠️ [JSON Spec] Parse failed: ${parsed.error}, falling back to SVG');
                elements = SvgToSlideElements.parse(
                  marker,
                  sourceCanvasWidth: 1920,
                  sourceCanvasHeight: 1080,
                  targetCanvasWidth: _canvasW,
                  targetCanvasHeight: _canvasH,
                );
              }
            } else {
              // SVG — parse via SvgToSlideElements
              elements = SvgToSlideElements.parse(
                marker,
                sourceCanvasWidth: 1920,
                sourceCanvasHeight: 1080,
                targetCanvasWidth: _canvasW,
                targetCanvasHeight: _canvasH,
              );
            }
            if (elements.isEmpty) {
              debugPrint('⚠️ [flushLanded] No elements parsed from marker, adding fallback layout');
              final pageTitle = pages[nextToLand]['title']?.toString() ?? 'Slide ${nextToLand + 1}';
              final pageBrief = pages[nextToLand]['brief']?.toString() ?? '';
              elements = _buildFallbackElements(pageTitle, pageBrief);
            } else {
              debugPrint('✅ [flushLanded] Parsed ${elements.length} elements: ${elements.map((e) => e.type.name).join(', ')}');
            }
            final slide = Slide(
              id: 'gen_${DateTime.now().millisecondsSinceEpoch}_$nextToLand',
              title: pages[nextToLand]['title']?.toString() ?? '',
              layoutId: pages[nextToLand]['layout']?.toString() ?? 'blank',
              backgroundGradient: _specBgToGradient(specBg),
              elements: elements,
            );
            captureSink(slide, replaceAll: !firstDone);
            collectedSlides[nextToLand] = slide;
            landedPages++;
            firstDone = true;
            doneFlags[nextToLand] = true;
            pageProgressItems[nextToLand] = PageProgressItem(
              title: pageProgressItems[nextToLand].title,
              status: PageProgressStatus.done,
            );
            _emitProgress(PagesProgressEvent(
              label: 'Generating pages...',
              done: landedPages,
              total: total,
              status: 'running',
              summary: landedPages < total
                  ? 'Generating page ${landedPages + 1} of $total'
                  : 'Finalizing...',
              pages: pageProgressItems,
            ));
          }
        }
        nextToLand++;
      }
    }

    // Generate in batches
    for (int start = 0; start < total; start += genBatch) {
      if (signal?.aborted == true) break;
      final end = (start + genBatch).clamp(0, total);
      final batch = <int>[];
      for (int i = start; i < end; i++) batch.add(i);

      final results = await Future.wait(
        batch.map((idx) async => (idx: idx, marker: await genOne(pages[idx], idx + 1))),
      );

      for (final r in results) {
        if (r.marker != null && r.marker!.isNotEmpty) {
          markerByIndex[r.idx] = r.marker;
        } else {
          markerByIndex[r.idx] = '';
          genFailed.add(r.idx);
          pageProgressItems[r.idx] = PageProgressItem(
            title: pageProgressItems[r.idx].title,
            status: PageProgressStatus.error,
            error: pageErrors[r.idx],
          );
        }
      }

      await flushLanded();
    }
    if (!(signal?.aborted ?? false)) await flushLanded();

    // Retry failed pages
    if (!(signal?.aborted ?? false)) {
      final retryIdxs = {...genFailed, ...landFailed}.toList()..sort();
      for (final idx in retryIdxs) {
        if (signal?.aborted == true) break;
        String? marker = markerByIndex[idx];
        if (marker == null || marker.isEmpty) {
          marker = await genOne(pages[idx], idx + 1);
        }
        if (marker != null && marker.isNotEmpty) {
          markerByIndex[idx] = marker;
          final isFirstLand = !firstDone;
          if (_pageLander != null) {
            final result = await _pageLander!(
              [marker],
              mode: isFirstLand ? insertMode : 'insert_at',
              deckName: deckName,
              insertAt: isFirstLand ? null : baseOffset + doneFlags.sublist(0, idx).where((b) => b).length,
            );
            if (result.ok) {
              if (isFirstLand) baseOffset = result.appendedFrom ?? 0;
              landedPages++;
              firstDone = true;
              doneFlags[idx] = true;
              pageProgressItems[idx] = PageProgressItem(
                title: pageProgressItems[idx].title,
                status: PageProgressStatus.done,
              );
            }
          } else {
            // Fallback: parse marker into SlideElements
            // Detect JSON spec (starts with {) vs SVG (starts with <svg)
            List<SlideElement> elements;
            final trimmed = marker.trimLeft();
            debugPrint('🔍 [flushLanded] Marker type: ${trimmed.startsWith('{') ? 'JSON' : 'SVG'}, length: ${marker.length}');
            debugPrint('🔍 [flushLanded] Marker preview: ${marker.substring(0, marker.length > 200 ? 200 : marker.length)}');
            String? specBg2;
            if (trimmed.startsWith('{')) {
              // JSON spec (GenOffice-style) — parse via slide_spec.dart
              final parsed = parseSlideSpec(marker);
              if (parsed.ok) {
                clampSpecToCanvas(parsed.spec!);
                elements = specToSlideElements(parsed.spec!, scale: specToModelScale);
                specBg2 = parsed.spec!.background;
                debugPrint('✅ [JSON Spec] Parsed ${elements.length} elements, bg: $specBg2');
              } else {
                debugPrint('⚠️ [JSON Spec] Parse failed: ${parsed.error}, falling back to SVG');
                elements = SvgToSlideElements.parse(
                  marker,
                  sourceCanvasWidth: 1920,
                  sourceCanvasHeight: 1080,
                  targetCanvasWidth: _canvasW,
                  targetCanvasHeight: _canvasH,
                );
              }
            } else {
              // SVG — parse via SvgToSlideElements
              elements = SvgToSlideElements.parse(
                marker,
                sourceCanvasWidth: 1920,
                sourceCanvasHeight: 1080,
                targetCanvasWidth: _canvasW,
                targetCanvasHeight: _canvasH,
              );
            }
            if (elements.isEmpty) {
              debugPrint('⚠️ [flushLanded] No elements parsed from marker, adding fallback layout');
              final pageTitle = pages[idx]['title']?.toString() ?? 'Slide ${idx + 1}';
              final pageBrief = pages[idx]['brief']?.toString() ?? '';
              elements = _buildFallbackElements(pageTitle, pageBrief);
            } else {
              debugPrint('✅ [flushLanded] Parsed ${elements.length} elements: ${elements.map((e) => e.type.name).join(', ')}');
            }
            final slide = Slide(
              id: 'gen_${DateTime.now().millisecondsSinceEpoch}_$idx',
              title: pages[idx]['title']?.toString() ?? '',
              layoutId: pages[idx]['layout']?.toString() ?? 'blank',
              backgroundGradient: _specBgToGradient(specBg2),
              elements: elements,
            );
            captureSink(slide, replaceAll: isFirstLand);
            collectedSlides[idx] = slide;
            landedPages++;
            firstDone = true;
            doneFlags[idx] = true;
            pageProgressItems[idx] = PageProgressItem(
              title: pageProgressItems[idx].title,
              status: PageProgressStatus.done,
            );
          }
        }
      }
    }

    // Handle cancellation
    if (signal?.aborted == true) {
      _state.htmlGenerated = landedPages > 0 || _state.htmlGenerated;
      _emitProgress(DoneProgressEvent(
        total: landedPages,
        summary: 'Generation stopped; $landedPages pages kept',
      ));
      return ToolExecution(
        output: 'User stopped generation. $landedPages page(s) kept.',
        mutated: landedPages > 0,
        summary: 'generate_deck stopped',
      );
    }

    _state.htmlGenerated = true;

    // ── Step 3: QC Pass ──────────────────────────────────────────
    if (collectedSlides.isNotEmpty) {
      int qcFixed = 0;
      int qcFailed = 0;

      for (final entry in collectedSlides.entries) {
        final slideIdx = entry.key;
        final slide = entry.value;

        final qcResult = QualityChecker.check(slide.elements);
        _onQcResult?.call(slideIdx, qcResult);

        if (!qcResult.passed && _slideFixer != null) {
          try {
            final fixedElements = QualityChecker.autoFix(slide.elements, qcResult);
            final fixedSlide = Slide(
              id: slide.id,
              layoutId: slide.layoutId,
              elements: fixedElements,
            );

            final fixResult = await _slideFixer!(slideIdx, fixedSlide);
            if (fixResult.ok) {
              qcFixed++;
              // Update collected slide with fixed version
              collectedSlides[slideIdx] = fixedSlide;
            } else {
              qcFailed++;
            }
          } catch (e) {
            qcFailed++;
          }
        }
      }

      if (qcFixed > 0 || qcFailed > 0) {
        _emitProgress(DoneProgressEvent(
          total: landedPages,
          summary: 'QC: fixed $qcFixed issues, $qcFailed could not be fixed',
        ));
      }
    }

    if (landedPages == 0) {
      _emitProgress(DoneProgressEvent(total: 0, summary: 'All pages failed'));
      return ToolExecution(
        output: 'All $total pages failed to generate',
        isError: true,
        summary: 'generate_deck failed',
      );
    }

    _emitProgress(DoneProgressEvent(
      total: landedPages,
      summary: 'Generated $landedPages/$total pages',
    ));

    // Build output message
    final stillFailed = <int>[];
    for (int i = 0; i < total; i++) {
      if (!doneFlags[i]) stillFailed.add(i + 1);
    }

    String output = 'Generated $landedPages/$total pages';
    if (stillFailed.isNotEmpty) {
      output += '. Failed: page ${stillFailed.join(', page ')}';
    }

    return ToolExecution(
      output: output,
      mutated: true,
      summary: 'Generated $landedPages pages',
      display: ToolDisplayText('Generated $landedPages pages for "$deckName"'),
    );
  }

  Future<ToolExecution> _executeRegenerateSlide(
    Map<String, dynamic> input, {
    AbortSignal? signal,
  }) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final brief = (input['brief'] as String?)?.trim() ?? '';

    if (brief.isEmpty) {
      return ToolExecution(
        output: 'brief must not be empty',
        isError: true,
        summary: 'regenerate_slide failed',
      );
    }

    final useCloud = _cloudPageGenerator != null &&
        await (_cloudAvailabilityChecker?.call() ?? Future.value(false));

    if (_slideRegenerator == null ||
        (!useCloud && _localPageGenerator == null && _generator == null)) {
      return ToolExecution(
        output: 'No page generation pipeline is available',
        isError: true,
        summary: 'regenerate_slide failed',
      );
    }

    String? marker;
    final images = (input['image_urls'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .where((u) => u.startsWith('http'))
        .toList() ?? [];

    // Generate with retry
    for (int attempt = 0; attempt < 2; attempt++) {
      if (signal?.aborted == true) {
        return ToolExecution(
          output: 'Regeneration cancelled',
          isError: true,
          summary: 'regenerate_slide cancelled',
        );
      }
      if (attempt > 0) await Future.delayed(Duration(milliseconds: _retryBackoffMs));

      if (useCloud && _cloudPageGenerator != null) {
        final result = await _cloudPageGenerator!(
          pageIndex: slideIndex + 1,
          totalPages: 1,
          coreHook: '',
          style: _state.lastStyleSkill ?? '',
          title: input['title']?.toString() ?? '',
          brief: brief,
          layout: input['layout']?.toString() ?? '',
          images: images,
          canvasW: _canvasW,
          canvasH: _canvasH,
          signal: signal,
        );
        if (result.ok && result.marker != null) {
          marker = result.marker;
          break;
        }
      } else if (_localPageGenerator != null) {
        final result = await _localPageGenerator!(
          pageIndex: slideIndex + 1,
          totalPages: 1,
          coreHook: '',
          style: _state.lastStyleSkill ?? '',
          title: input['title']?.toString() ?? '',
          brief: brief,
          layout: input['layout']?.toString() ?? '',
          images: images,
          canvasW: _canvasW,
          canvasH: _canvasH,
          signal: signal,
        );
        if (result.ok && result.marker != null) {
          marker = result.marker;
          break;
        }
      } else if (_generator != null) {
        // Fallback
        try {
          marker = await _generator.generateSvg(
            topic: _topic,
            pageIndex: slideIndex + 1,
            totalPages: 1,
            title: input['title']?.toString() ?? '',
            brief: brief,
          );
          break;
        } catch (e) {
          marker = null;
        }
      }
    }

    if (marker == null || marker.isEmpty) {
      return ToolExecution(
        output: 'Page regeneration failed after 2 attempts',
        isError: true,
        summary: 'regenerate_slide failed',
      );
    }

    // Land the regenerated page
    final result = await _slideRegenerator!(slideIndex: slideIndex, marker: marker);
    if (!result.ok) {
      return ToolExecution(
        output: 'Landing failed: ${result.error ?? "unknown error"}',
        isError: true,
        summary: 'regenerate_slide failed',
      );
    }

    _state.htmlGenerated = true;
    return ToolExecution(
      output: 'Redid page ${slideIndex + 1} in place',
      mutated: true,
      summary: 'Regenerated page ${slideIndex + 1}',
    );
  }

  Future<ToolExecution> _executeSaveStyleTemplate(Map<String, dynamic> input) async {
    final name = (input['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) {
      return ToolExecution(
        output: 'name must not be empty',
        isError: true,
        summary: 'save_style_template failed',
      );
    }

    final styleSkillToSave = _state.lastStyleSkill ?? _styleSkill ?? '';
    if (styleSkillToSave.isEmpty) {
      return ToolExecution(
        output: 'No style to save (generate a deck first)',
        isError: true,
        summary: 'save_style_template failed',
      );
    }

    // This would be implemented via a callback to persist
    return ToolExecution(
      output: 'Saved style "$name" (template persistence not yet wired)',
      mutated: false,
      summary: 'Saved style template "$name"',
    );
  }

  Future<ToolExecution> _executeListStyleTemplates() async {
    // This would be implemented via a callback to list templates
    return ToolExecution(
      output: 'Style templates (list not yet wired)',
      mutated: false,
      summary: 'Listed style templates',
    );
  }

  Future<ToolExecution> _executeGetDeckContext() async {
    final slideCount = _state.plannedPages ?? _pages.length;
    final titles = _state.plannedTitles ?? _pages.map((p) => p.title).toList();
    final doneFlags = _state.pageDone ?? List.filled(slideCount, false);
    final doneCount = doneFlags.where((b) => b).length;

    final buffer = StringBuffer();
    buffer.writeln('Deck: "$_topic"');
    buffer.writeln('Slides: $slideCount ($doneCount generated)');
    buffer.writeln('Style: ${_state.lastStyleSkill ?? _styleSkill ?? "none"}');
    buffer.writeln();
    buffer.writeln('Outline:');
    for (int i = 0; i < titles.length && i < slideCount; i++) {
      final status = i < doneFlags.length && doneFlags[i] ? '✅' : '⏳';
      buffer.writeln('  ${i + 1}. $status ${titles[i]}');
    }

    return ToolExecution(
      output: buffer.toString(),
      mutated: false,
      summary: 'Deck context: $slideCount slides, $doneCount done',
    );
  }

  Future<ToolExecution> _executeReadSlide(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;

    if (slideIndex < 0 || slideIndex >= _pages.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex (deck has ${_pages.length} pages)',
        isError: true,
        summary: 'read_slide failed',
      );
    }

    final page = _pages[slideIndex];
    final buffer = StringBuffer();
    buffer.writeln('Slide ${slideIndex + 1}: "${page.title}"');
    buffer.writeln('Layout: ${page.layout ?? "auto"}');
    buffer.writeln('Brief: ${page.brief}');

    if (page.layout != null && page.layout!.isNotEmpty) {
      buffer.writeln('Layout variant: ${page.layout}');
    }

    return ToolExecution(
      output: buffer.toString(),
      mutated: false,
      summary: 'Read slide ${slideIndex + 1}',
    );
  }

  Future<ToolExecution> _executeAddSlide(Map<String, dynamic> input) async {
    final title = (input['title'] as String?)?.trim() ?? '';
    final brief = (input['brief'] as String?)?.trim() ?? '';
    final layout = (input['layout'] as String?)?.trim();
    final index = (input['index'] as int?) ?? _pages.length;

    if (title.isEmpty) {
      return ToolExecution(
        output: 'title must not be empty',
        isError: true,
        summary: 'add_slide failed',
      );
    }

    final insertAt = index.clamp(0, _pages.length);
    final newPage = OutlinePage(
      index: insertAt + 1,
      title: title,
      brief: brief,
      layout: layout,
    );

    _pages.insert(insertAt, newPage);
    _reindexPages();

    // Update state
    _state.plannedPages = _pages.length;
    _state.plannedTitles = _pages.map((p) => p.title).toList();
    _state.pageDone = List.filled(_pages.length, false);

    return ToolExecution(
      output: 'Added slide "${title}" at position ${insertAt + 1}. Deck now has ${_pages.length} slides.',
      mutated: true,
      summary: 'Added slide "${title}"',
    );
  }

  Future<ToolExecution> _executeDeleteSlide(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;

    if (slideIndex < 0 || slideIndex >= _pages.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex (deck has ${_pages.length} pages)',
        isError: true,
        summary: 'delete_slide failed',
      );
    }

    if (_pages.length <= 1) {
      return ToolExecution(
        output: 'Cannot delete the last slide',
        isError: true,
        summary: 'delete_slide failed',
      );
    }

    final removed = _pages.removeAt(slideIndex);
    _reindexPages();

    // Update state
    _state.plannedPages = _pages.length;
    _state.plannedTitles = _pages.map((p) => p.title).toList();
    _state.pageDone = List.filled(_pages.length, false);

    return ToolExecution(
      output: 'Deleted slide "${removed.title}" at position ${slideIndex + 1}. Deck now has ${_pages.length} slides.',
      mutated: true,
      summary: 'Deleted slide "${removed.title}"',
    );
  }

  Future<ToolExecution> _executeSetSlideBackground(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final color = (input['color'] as String?)?.trim() ?? '';

    if (slideIndex < 0 || slideIndex >= _pages.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex (deck has ${_pages.length} pages)',
        isError: true,
        summary: 'set_slide_background failed',
      );
    }

    if (color.isEmpty || !color.startsWith('#')) {
      return ToolExecution(
        output: 'Invalid color format. Use hex like "#1a1a2e"',
        isError: true,
        summary: 'set_slide_background failed',
      );
    }

    // Update the page's brief to include background info
    final page = _pages[slideIndex];

    // Update actual slide background if slides are accessible
    if (_slidesGetter != null && _slideReplacer != null) {
      final slides = _slidesGetter!();
      if (slideIndex < slides.length) {
        final slide = slides[slideIndex];
        slide.extra ??= {};
        slide.extra!['backgroundColor'] = color;
      }
    }

    // Also store in outline for persistence
    final newBrief = '${page.brief}\n[background: $color]';
    _pages[slideIndex] = page.copyWith(brief: newBrief);

    return ToolExecution(
      output: 'Set background of slide ${slideIndex + 1} ("${page.title}") to $color',
      mutated: true,
      summary: 'Set background to $color',
    );
  }

  void _reindexPages() {
    for (int i = 0; i < _pages.length; i++) {
      _pages[i] = _pages[i].copyWith(index: i + 1);
    }
  }

  /// Convert spec background hex (e.g. "#1a1a2e") to gradient string
  /// for AppTheme.gradientFor (format: "custom_HEX1,HEX2" for solid color).
  static String _specBgToGradient(String? bg) {
    if (bg == null || bg.isEmpty) return 'indigo'; // default
    final hex = bg.replaceFirst('#', '');
    if (hex.length != 6) return 'indigo';
    // Use same color for both ends → solid background
    return 'custom_$hex,$hex';
  }

  /// Build fallback elements when JSON/SVG parsing produces nothing.
  /// Creates a title + optional brief text layout in 1920×1080 design space.
  static List<SlideElement> _buildFallbackElements(String title, String brief) {
    final elements = <SlideElement>[];
    int z = 0;

    // Title — large centered text
    if (title.isNotEmpty) {
      elements.add(SlideElement(
        type: ElementType.text,
        x: 160,
        y: 340,
        width: 1600,
        height: 120,
        content: title,
        zIndex: z++,
        textStyle: TextStyleData(
          fontSize: 48,
          colorValue: 0xFFFFFFFF,
          fontWeight: 'bold',
          textAlign: 'center',
        ),
      ));
    }

    // Brief — smaller subtitle below
    if (brief.isNotEmpty) {
      final displayBrief = brief.length > 200 ? '${brief.substring(0, 200)}...' : brief;
      elements.add(SlideElement(
        type: ElementType.text,
        x: 240,
        y: 480,
        width: 1440,
        height: 200,
        content: displayBrief,
        zIndex: z++,
        textStyle: TextStyleData(
          fontSize: 24,
          colorValue: 0xCCFFFFFF, // white 80% opacity
          fontWeight: 'normal',
          textAlign: 'center',
        ),
      ));
    }

    // Decorative accent bar at top
    elements.add(SlideElement(
      type: ElementType.shape,
      x: 760,
      y: 300,
      width: 400,
      height: 6,
      zIndex: z++,
      shapeStyle: ShapeStyleData(
        shapeType: 'roundRect',
        fillColorValue: 0xFF6366F1, // indigo accent
      ),
    ));

    return elements;
  }

  /// Convert hex color string to int (e.g. "#6366F1" → 0xFF6366F1)
  static int _hexToInt(String hex) {
    hex = hex.trim().replaceFirst('#', '');
    if (hex.length == 3) {
      hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
    }
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length == 8) hex = 'FF${hex.substring(0, 6)}'; // strip alpha
    return int.tryParse(hex, radix: 16) ?? 0xFF000000;
  }

  Future<ToolExecution> _executeSetElementText(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final elementIndex = (input['elementIndex'] as int?) ?? 0;
    final text = (input['text'] as String?)?.trim() ?? '';

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Element editing not available (no slide access configured)',
        isError: true,
        summary: 'set_element_text failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex (deck has ${slides.length} slides)',
        isError: true,
        summary: 'set_element_text failed',
      );
    }

    final slide = slides[slideIndex];
    if (elementIndex < 0 || elementIndex >= slide.elements.length) {
      return ToolExecution(
        output: 'Invalid element index $elementIndex (slide has ${slide.elements.length} elements)',
        isError: true,
        summary: 'set_element_text failed',
      );
    }

    final element = slide.elements[elementIndex];
    if (element.type != ElementType.text) {
      return ToolExecution(
        output: 'Element at index $elementIndex is not a text element (it\'s ${element.type.name})',
        isError: true,
        summary: 'set_element_text failed',
      );
    }

    // Mutate element directly (SlideElement has mutable fields)
    element.content = text;
    element.richRuns = null;

    return ToolExecution(
      output: 'Updated text of element $elementIndex on slide ${slideIndex + 1}',
      mutated: true,
      summary: 'Updated element text',
    );
  }

  Future<ToolExecution> _executeSetElementStyle(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final elementIndex = (input['elementIndex'] as int?) ?? 0;
    final fontSize = (input['fontSize'] as num?)?.toDouble();
    final color = (input['color'] as String?)?.trim();
    final bold = input['bold'] as bool?;

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Element editing not available (no slide access configured)',
        isError: true,
        summary: 'set_element_style failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex',
        isError: true,
        summary: 'set_element_style failed',
      );
    }

    final slide = slides[slideIndex];
    if (elementIndex < 0 || elementIndex >= slide.elements.length) {
      return ToolExecution(
        output: 'Invalid element index $elementIndex',
        isError: true,
        summary: 'set_element_style failed',
      );
    }

    final element = slide.elements[elementIndex];
    if (element.type != ElementType.text) {
      return ToolExecution(
        output: 'Element is not a text element',
        isError: true,
        summary: 'set_element_style failed',
      );
    }

    // Mutate text style directly
    if (element.textStyle == null) {
      element.textStyle = TextStyleData();
    }
    if (fontSize != null) element.textStyle!.fontSize = fontSize;
    if (color != null) element.textStyle!.colorValue = _hexToInt(color);
    if (bold != null) element.textStyle!.fontWeight = bold ? 'bold' : 'normal';

    return ToolExecution(
      output: 'Updated style of element $elementIndex on slide ${slideIndex + 1}',
      mutated: true,
      summary: 'Updated element style',
    );
  }

  Future<ToolExecution> _executeSetElementFill(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final elementIndex = (input['elementIndex'] as int?) ?? 0;
    final color = (input['color'] as String?)?.trim() ?? '';

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Element editing not available (no slide access configured)',
        isError: true,
        summary: 'set_element_fill failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex',
        isError: true,
        summary: 'set_element_fill failed',
      );
    }

    final slide = slides[slideIndex];
    if (elementIndex < 0 || elementIndex >= slide.elements.length) {
      return ToolExecution(
        output: 'Invalid element index $elementIndex',
        isError: true,
        summary: 'set_element_fill failed',
      );
    }

    final element = slide.elements[elementIndex];
    if (element.type != ElementType.shape) {
      return ToolExecution(
        output: 'Element is not a shape element',
        isError: true,
        summary: 'set_element_fill failed',
      );
    }

    // Mutate shape fill directly
    if (element.shapeStyle == null) {
      element.shapeStyle = ShapeStyleData();
    }
    element.shapeStyle!.fillColorValue = _hexToInt(color);

    return ToolExecution(
      output: 'Updated fill of element $elementIndex on slide ${slideIndex + 1} to $color',
      mutated: true,
      summary: 'Updated element fill',
    );
  }

  Future<ToolExecution> _executeSetElementTransform(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final elementIndex = (input['elementIndex'] as int?) ?? 0;
    final x = (input['x'] as num?)?.toDouble();
    final y = (input['y'] as num?)?.toDouble();
    final width = (input['width'] as num?)?.toDouble();
    final height = (input['height'] as num?)?.toDouble();
    final rotation = (input['rotation'] as num?)?.toDouble();

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Element editing not available',
        isError: true,
        summary: 'set_element_transform failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex',
        isError: true,
        summary: 'set_element_transform failed',
      );
    }

    final slide = slides[slideIndex];
    if (elementIndex < 0 || elementIndex >= slide.elements.length) {
      return ToolExecution(
        output: 'Invalid element index $elementIndex',
        isError: true,
        summary: 'set_element_transform failed',
      );
    }

    final element = slide.elements[elementIndex];
    if (x != null) element.x = x;
    if (y != null) element.y = y;
    if (width != null) element.width = width;
    if (height != null) element.height = height;
    if (rotation != null) element.rotation = rotation;

    return ToolExecution(
      output: 'Updated transform of element $elementIndex on slide ${slideIndex + 1}',
      mutated: true,
      summary: 'Updated element transform',
    );
  }

  Future<ToolExecution> _executeAddTextBox(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final text = (input['text'] as String?)?.trim() ?? '';
    final x = (input['x'] as num?)?.toDouble() ?? 100.0;
    final y = (input['y'] as num?)?.toDouble() ?? 100.0;
    final width = (input['width'] as num?)?.toDouble() ?? 400.0;
    final height = (input['height'] as num?)?.toDouble() ?? 60.0;
    final fontSize = (input['fontSize'] as num?)?.toDouble() ?? 24.0;
    final color = (input['color'] as String?)?.trim() ?? '#FFFFFF';
    final bold = input['bold'] as bool? ?? false;

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Element creation not available',
        isError: true,
        summary: 'add_text_box failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex',
        isError: true,
        summary: 'add_text_box failed',
      );
    }

    if (text.isEmpty) {
      return ToolExecution(
        output: 'text must not be empty',
        isError: true,
        summary: 'add_text_box failed',
      );
    }

    final slide = slides[slideIndex];
    final newElement = SlideElement(
      id: 'txt_${DateTime.now().millisecondsSinceEpoch}',
      type: ElementType.text,
      x: x,
      y: y,
      width: width,
      height: height,
      content: text,
      zIndex: slide.elements.length,
      textStyle: TextStyleData(
        fontSize: fontSize,
        colorValue: _hexToInt(color),
        fontWeight: bold ? 'bold' : 'normal',
      ),
    );

    slide.elements.add(newElement);

    return ToolExecution(
      output: 'Added text box "${text.length > 30 ? text.substring(0, 30) + '...' : text}" on slide ${slideIndex + 1}',
      mutated: true,
      summary: 'Added text box',
    );
  }

  Future<ToolExecution> _executeAddShape(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final shapeType = (input['shapeType'] as String?)?.trim() ?? 'rect';
    final x = (input['x'] as num?)?.toDouble() ?? 100.0;
    final y = (input['y'] as num?)?.toDouble() ?? 100.0;
    final width = (input['width'] as num?)?.toDouble() ?? 200.0;
    final height = (input['height'] as num?)?.toDouble() ?? 200.0;
    final fillColor = (input['fillColor'] as String?)?.trim() ?? '#6366F1';

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Element creation not available',
        isError: true,
        summary: 'add_shape failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex',
        isError: true,
        summary: 'add_shape failed',
      );
    }

    final slide = slides[slideIndex];
    final newElement = SlideElement(
      id: 'shp_${DateTime.now().millisecondsSinceEpoch}',
      type: ElementType.shape,
      x: x,
      y: y,
      width: width,
      height: height,
      zIndex: slide.elements.length,
      shapeStyle: ShapeStyleData(
        fillColorValue: _hexToInt(fillColor),
        shapeType: shapeType,
      ),
    );

    slide.elements.add(newElement);

    return ToolExecution(
      output: 'Added $shapeType shape on slide ${slideIndex + 1}',
      mutated: true,
      summary: 'Added $shapeType shape',
    );
  }

  Future<ToolExecution> _executeDeleteElement(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final elementIndex = (input['elementIndex'] as int?) ?? 0;

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Element editing not available',
        isError: true,
        summary: 'delete_element failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex',
        isError: true,
        summary: 'delete_element failed',
      );
    }

    final slide = slides[slideIndex];
    if (elementIndex < 0 || elementIndex >= slide.elements.length) {
      return ToolExecution(
        output: 'Invalid element index $elementIndex',
        isError: true,
        summary: 'delete_element failed',
      );
    }

    final removed = slide.elements.removeAt(elementIndex);

    return ToolExecution(
      output: 'Deleted ${removed.type.name} element at index $elementIndex on slide ${slideIndex + 1}',
      mutated: true,
      summary: 'Deleted element',
    );
  }

  Future<ToolExecution> _executeSetSpeakerNotes(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final notes = (input['notes'] as String?)?.trim() ?? '';

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Slide editing not available',
        isError: true,
        summary: 'set_speaker_notes failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex',
        isError: true,
        summary: 'set_speaker_notes failed',
      );
    }

    final slide = slides[slideIndex];
    slide.extra ??= {};
    slide.extra!['speakerNotes'] = notes;

    return ToolExecution(
      output: 'Set speaker notes for slide ${slideIndex + 1} ("${slide.title ?? 'Untitled'}")',
      mutated: true,
      summary: 'Set speaker notes',
    );
  }

  Future<ToolExecution> _executeAddTable(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final rows = (input['rows'] as int?) ?? 3;
    final cols = (input['cols'] as int?) ?? 3;
    final x = (input['x'] as num?)?.toDouble() ?? 100.0;
    final y = (input['y'] as num?)?.toDouble() ?? 100.0;
    final width = (input['width'] as num?)?.toDouble() ?? 600.0;
    final height = (input['height'] as num?)?.toDouble() ?? 300.0;
    final hasHeader = input['hasHeader'] as bool? ?? true;

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Element creation not available',
        isError: true,
        summary: 'add_table failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex',
        isError: true,
        summary: 'add_table failed',
      );
    }

    // Parse optional cells
    List<List<String>>? cells;
    final cellsInput = input['cells'] as List<dynamic>?;
    if (cellsInput != null && cellsInput.isNotEmpty) {
      cells = cellsInput.map((row) =>
        (row as List<dynamic>).map((c) => c.toString()).toList()
      ).toList();
    }

    final slide = slides[slideIndex];
    final newElement = SlideElement(
      id: 'tbl_${DateTime.now().millisecondsSinceEpoch}',
      type: ElementType.table,
      x: x,
      y: y,
      width: width,
      height: height,
      zIndex: slide.elements.length,
      tableData: TableData(
        rows: rows,
        cols: cols,
        cells: cells,
        hasHeader: hasHeader,
      ),
    );

    slide.elements.add(newElement);

    return ToolExecution(
      output: 'Added ${rows}x${cols} table on slide ${slideIndex + 1}',
      mutated: true,
      summary: 'Added table',
    );
  }

  Future<ToolExecution> _executeEditTableCell(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final elementIndex = (input['elementIndex'] as int?) ?? 0;
    final row = (input['row'] as int?) ?? 0;
    final col = (input['col'] as int?) ?? 0;
    final value = (input['value'] as String?) ?? '';

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Element editing not available',
        isError: true,
        summary: 'edit_table_cell failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex',
        isError: true,
        summary: 'edit_table_cell failed',
      );
    }

    final slide = slides[slideIndex];
    if (elementIndex < 0 || elementIndex >= slide.elements.length) {
      return ToolExecution(
        output: 'Invalid element index $elementIndex',
        isError: true,
        summary: 'edit_table_cell failed',
      );
    }

    final element = slide.elements[elementIndex];
    if (element.type != ElementType.table || element.tableData == null) {
      return ToolExecution(
        output: 'Element is not a table',
        isError: true,
        summary: 'edit_table_cell failed',
      );
    }

    final table = element.tableData!;
    if (row < 0 || row >= table.rows || col < 0 || col >= table.cols) {
      return ToolExecution(
        output: 'Invalid cell position ($row, $col) for ${table.rows}x${table.cols} table',
        isError: true,
        summary: 'edit_table_cell failed',
      );
    }

    // Ensure cells array is large enough
    while (table.cells.length <= row) {
      table.cells.add(List.filled(table.cols, ''));
    }
    while (table.cells[row].length <= col) {
      table.cells[row].add('');
    }

    table.cells[row][col] = value;

    return ToolExecution(
      output: 'Set cell ($row, $col) to "$value" on slide ${slideIndex + 1}',
      mutated: true,
      summary: 'Edited table cell',
    );
  }

  Future<ToolExecution> _executeEditTableStructure(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final elementIndex = (input['elementIndex'] as int?) ?? 0;
    final action = (input['action'] as String?) ?? '';
    final index = (input['index'] as int?) ?? 0;

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Element editing not available',
        isError: true,
        summary: 'edit_table_structure failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex',
        isError: true,
        summary: 'edit_table_structure failed',
      );
    }

    final slide = slides[slideIndex];
    if (elementIndex < 0 || elementIndex >= slide.elements.length) {
      return ToolExecution(
        output: 'Invalid element index $elementIndex',
        isError: true,
        summary: 'edit_table_structure failed',
      );
    }

    final element = slide.elements[elementIndex];
    if (element.type != ElementType.table || element.tableData == null) {
      return ToolExecution(
        output: 'Element is not a table',
        isError: true,
        summary: 'edit_table_structure failed',
      );
    }

    final table = element.tableData!;

    switch (action) {
      case 'insertRow':
        if (index < 0 || index > table.rows) {
          return ToolExecution(output: 'Invalid row index $index', isError: true, summary: 'edit_table_structure failed');
        }
        table.cells.insert(index, List.filled(table.cols, ''));
        table.rows++;
        break;
      case 'deleteRow':
        if (index < 0 || index >= table.rows || table.rows <= 1) {
          return ToolExecution(output: 'Cannot delete row $index', isError: true, summary: 'edit_table_structure failed');
        }
        table.cells.removeAt(index);
        table.rows--;
        break;
      case 'insertCol':
        if (index < 0 || index > table.cols) {
          return ToolExecution(output: 'Invalid col index $index', isError: true, summary: 'edit_table_structure failed');
        }
        for (final row in table.cells) {
          row.insert(index, '');
        }
        table.cols++;
        break;
      case 'deleteCol':
        if (index < 0 || index >= table.cols || table.cols <= 1) {
          return ToolExecution(output: 'Cannot delete col $index', isError: true, summary: 'edit_table_structure failed');
        }
        for (final row in table.cells) {
          row.removeAt(index);
        }
        table.cols--;
        break;
      default:
        return ToolExecution(output: 'Unknown action: $action', isError: true, summary: 'edit_table_structure failed');
    }

    return ToolExecution(
      output: '$action at index $index on slide ${slideIndex + 1}. Table is now ${table.rows}x${table.cols}',
      mutated: true,
      summary: 'Edited table structure',
    );
  }

  Future<ToolExecution> _executeAddChart(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final chartType = (input['chartType'] as String?) ?? 'bar';
    final x = (input['x'] as num?)?.toDouble() ?? 100.0;
    final y = (input['y'] as num?)?.toDouble() ?? 100.0;
    final width = (input['width'] as num?)?.toDouble() ?? 500.0;
    final height = (input['height'] as num?)?.toDouble() ?? 350.0;
    final title = (input['title'] as String?) ?? '';

    final labelsInput = input['labels'] as List<dynamic>? ?? [];
    final valuesInput = input['values'] as List<dynamic>? ?? [];

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Element creation not available',
        isError: true,
        summary: 'add_chart failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex',
        isError: true,
        summary: 'add_chart failed',
      );
    }

    if (labelsInput.isEmpty || valuesInput.isEmpty) {
      return ToolExecution(
        output: 'labels and values must not be empty',
        isError: true,
        summary: 'add_chart failed',
      );
    }

    final labels = labelsInput.map((l) => l.toString()).toList();
    final values = valuesInput.map((v) => (v as num).toDouble()).toList();

    final slide = slides[slideIndex];
    final newElement = SlideElement(
      id: 'chr_${DateTime.now().millisecondsSinceEpoch}',
      type: ElementType.chart,
      x: x,
      y: y,
      width: width,
      height: height,
      zIndex: slide.elements.length,
      chartData: ChartData(
        chartType: chartType,
        labels: labels,
        dataSets: [ChartDataSet(values: values, label: title.isNotEmpty ? title : 'Series 1')],
      ),
    );

    slide.elements.add(newElement);

    return ToolExecution(
      output: 'Added $chartType chart with ${labels.length} categories on slide ${slideIndex + 1}',
      mutated: true,
      summary: 'Added $chartType chart',
    );
  }

  Future<ToolExecution> _executeEditChart(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final elementIndex = (input['elementIndex'] as int?) ?? 0;
    final chartType = input['chartType'] as String?;
    final title = input['title'] as String?;

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Element editing not available',
        isError: true,
        summary: 'edit_chart failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex',
        isError: true,
        summary: 'edit_chart failed',
      );
    }

    final slide = slides[slideIndex];
    if (elementIndex < 0 || elementIndex >= slide.elements.length) {
      return ToolExecution(
        output: 'Invalid element index $elementIndex',
        isError: true,
        summary: 'edit_chart failed',
      );
    }

    final element = slide.elements[elementIndex];
    if (element.type != ElementType.chart || element.chartData == null) {
      return ToolExecution(
        output: 'Element is not a chart',
        isError: true,
        summary: 'edit_chart failed',
      );
    }

    final chart = element.chartData!;
    if (chartType != null) chart.chartType = chartType;
    if (title != null && chart.dataSets.isNotEmpty) {
      chart.dataSets[0].label = title;
    }

    final labelsInput = input['labels'] as List<dynamic>?;
    final valuesInput = input['values'] as List<dynamic>?;
    if (labelsInput != null) {
      chart.labels = labelsInput.map((l) => l.toString()).toList();
    }
    if (valuesInput != null && chart.dataSets.isNotEmpty) {
      chart.dataSets[0].values = valuesInput.map((v) => (v as num).toDouble()).toList();
    }

    return ToolExecution(
      output: 'Updated chart on slide ${slideIndex + 1}',
      mutated: true,
      summary: 'Updated chart',
    );
  }

  Future<ToolExecution> _executeInsertWebImage(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final url = (input['url'] as String?)?.trim() ?? '';
    final x = (input['x'] as num?)?.toDouble() ?? 100.0;
    final y = (input['y'] as num?)?.toDouble() ?? 100.0;
    final width = (input['width'] as num?)?.toDouble() ?? 400.0;
    final height = (input['height'] as num?)?.toDouble() ?? 300.0;

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Element creation not available',
        isError: true,
        summary: 'insert_web_image failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex',
        isError: true,
        summary: 'insert_web_image failed',
      );
    }

    if (url.isEmpty || !url.startsWith('http')) {
      return ToolExecution(
        output: 'Invalid image URL',
        isError: true,
        summary: 'insert_web_image failed',
      );
    }

    final slide = slides[slideIndex];
    final newElement = SlideElement(
      id: 'img_${DateTime.now().millisecondsSinceEpoch}',
      type: ElementType.image,
      x: x,
      y: y,
      width: width,
      height: height,
      zIndex: slide.elements.length,
      imageStyle: ImageStyleData(src: url),
    );

    slide.elements.add(newElement);

    return ToolExecution(
      output: 'Inserted image on slide ${slideIndex + 1}',
      mutated: true,
      summary: 'Inserted image',
    );
  }

  Future<ToolExecution> _executeCropImage(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final elementIndex = (input['elementIndex'] as int?) ?? 0;
    final srcX = (input['srcX'] as num?)?.toDouble() ?? 0;
    final srcY = (input['srcY'] as num?)?.toDouble() ?? 0;
    final srcWidth = (input['srcWidth'] as num?)?.toDouble() ?? 100;
    final srcHeight = (input['srcHeight'] as num?)?.toDouble() ?? 100;

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Element editing not available',
        isError: true,
        summary: 'crop_image failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex',
        isError: true,
        summary: 'crop_image failed',
      );
    }

    final slide = slides[slideIndex];
    if (elementIndex < 0 || elementIndex >= slide.elements.length) {
      return ToolExecution(
        output: 'Invalid element index $elementIndex',
        isError: true,
        summary: 'crop_image failed',
      );
    }

    final element = slide.elements[elementIndex];
    if (element.type != ElementType.image) {
      return ToolExecution(
        output: 'Element is not an image',
        isError: true,
        summary: 'crop_image failed',
      );
    }

    element.extra ??= {};
    element.extra!['srcRect'] = {'x': srcX, 'y': srcY, 'width': srcWidth, 'height': srcHeight};

    return ToolExecution(
      output: 'Cropped image on slide ${slideIndex + 1}',
      mutated: true,
      summary: 'Cropped image',
    );
  }

  Future<ToolExecution> _executeReplaceImage(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final elementIndex = (input['elementIndex'] as int?) ?? 0;
    final url = (input['url'] as String?)?.trim() ?? '';

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Element editing not available',
        isError: true,
        summary: 'replace_image failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex',
        isError: true,
        summary: 'replace_image failed',
      );
    }

    final slide = slides[slideIndex];
    if (elementIndex < 0 || elementIndex >= slide.elements.length) {
      return ToolExecution(
        output: 'Invalid element index $elementIndex',
        isError: true,
        summary: 'replace_image failed',
      );
    }

    final element = slide.elements[elementIndex];
    if (element.type != ElementType.image) {
      return ToolExecution(
        output: 'Element is not an image',
        isError: true,
        summary: 'replace_image failed',
      );
    }

    if (element.imageStyle == null) {
      element.imageStyle = ImageStyleData();
    }
    element.imageStyle!.src = url;

    return ToolExecution(
      output: 'Replaced image on slide ${slideIndex + 1}',
      mutated: true,
      summary: 'Replaced image',
    );
  }

  Future<ToolExecution> _executeSlideScript(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final script = (input['script'] as String?)?.trim() ?? '';

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Script execution not available',
        isError: true,
        summary: 'execute_slide_script failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex',
        isError: true,
        summary: 'execute_slide_script failed',
      );
    }

    if (script.isEmpty) {
      return ToolExecution(
        output: 'script must not be empty',
        isError: true,
        summary: 'execute_slide_script failed',
      );
    }

    final slide = slides[slideIndex];
    final lines = script.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final logs = <String>[];
    int opsCount = 0;

    for (final line in lines) {
      if (opsCount > 50) {
        logs.add('⚠️ Max 50 ops reached, stopping');
        break;
      }

      final trimmed = line.trim();
      if (trimmed.startsWith('//') || trimmed.startsWith('#')) continue;

      try {
        _executeScriptCommand(slide, trimmed, logs);
        opsCount++;
      } catch (e) {
        logs.add('❌ Error: $trimmed → $e');
      }
    }

    return ToolExecution(
      output: 'Executed ${lines.length} commands on slide ${slideIndex + 1}\n${logs.join('\n')}',
      mutated: opsCount > 0,
      summary: 'Executed slide script',
    );
  }

  void _executeScriptCommand(Slide slide, String command, List<String> logs) {
    // Parse: command(args) — handles nested parens like setText(0, "Hello (world)")
    final cmdMatch = RegExp(r'^(\w+)\(').firstMatch(command);
    if (cmdMatch == null) {
      logs.add('⚠️ Invalid syntax: $command');
      return;
    }

    final cmd = cmdMatch.group(1)!;
    // Find matching closing paren (handles nesting)
    final openIdx = command.indexOf('(');
    int depth = 0;
    int closeIdx = -1;
    for (int i = openIdx; i < command.length; i++) {
      if (command[i] == '(') depth++;
      if (command[i] == ')') {
        depth--;
        if (depth == 0) {
          closeIdx = i;
          break;
        }
      }
    }

    if (closeIdx == -1 || closeIdx <= openIdx + 1) {
      logs.add('⚠️ Unmatched parentheses: $command');
      return;
    }

    final argsStr = command.substring(openIdx + 1, closeIdx);
    final args = _parseArgs(argsStr);

    switch (cmd) {
      case 'setBox':
        if (args.length >= 5) {
          final idx = _toInt(args[0]);
          if (idx >= 0 && idx < slide.elements.length) {
            final el = slide.elements[idx];
            el.x = _toDouble(args[1]);
            el.y = _toDouble(args[2]);
            el.width = _toDouble(args[3]);
            el.height = _toDouble(args[4]);
            logs.add('setBox($idx) → x=${el.x}, y=${el.y}, w=${el.width}, h=${el.height}');
          }
        }
        break;
      case 'moveBy':
        if (args.length >= 3) {
          final idx = _toInt(args[0]);
          if (idx >= 0 && idx < slide.elements.length) {
            final el = slide.elements[idx];
            el.x += _toDouble(args[1]);
            el.y += _toDouble(args[2]);
            logs.add('moveBy($idx) → x=${el.x}, y=${el.y}');
          }
        }
        break;
      case 'resizeBy':
        if (args.length >= 3) {
          final idx = _toInt(args[0]);
          if (idx >= 0 && idx < slide.elements.length) {
            final el = slide.elements[idx];
            el.width += _toDouble(args[1]);
            el.height += _toDouble(args[2]);
            logs.add('resizeBy($idx) → w=${el.width}, h=${el.height}');
          }
        }
        break;
      case 'setText':
        if (args.length >= 2) {
          final idx = _toInt(args[0]);
          if (idx >= 0 && idx < slide.elements.length) {
            final el = slide.elements[idx];
            el.content = _unquote(args[1]);
            el.richRuns = null;
            logs.add('setText($idx) → "${el.content}"');
          }
        }
        break;
      case 'setFill':
        if (args.length >= 2) {
          final idx = _toInt(args[0]);
          if (idx >= 0 && idx < slide.elements.length) {
            final el = slide.elements[idx];
            final color = _unquote(args[1]);
            if (el.type == ElementType.shape && el.shapeStyle != null) {
              el.shapeStyle!.fillColorValue = _hexToInt(color);
            }
            logs.add('setFill($idx) → $color');
          }
        }
        break;
      case 'setStroke':
        if (args.length >= 3) {
          final idx = _toInt(args[0]);
          if (idx >= 0 && idx < slide.elements.length) {
            final el = slide.elements[idx];
            final color = _unquote(args[1]);
            final width = _toDouble(args[2]);
            if (el.type == ElementType.shape && el.shapeStyle != null) {
              el.shapeStyle!.strokeColorValue = _hexToInt(color);
              el.shapeStyle!.strokeWidth = width;
            }
            logs.add('setStroke($idx) → $color, ${width}pt');
          }
        }
        break;
      case 'log':
        logs.add('📝 ${args.map((a) => _unquote(a)).join(' ')}');
        break;
      default:
        logs.add('⚠️ Unknown command: $cmd');
    }
  }

  List<String> _parseArgs(String argsStr) {
    final args = <String>[];
    final buffer = StringBuffer();
    bool inQuote = false;
    for (int i = 0; i < argsStr.length; i++) {
      final c = argsStr[i];
      if (c == '"' || c == "'") {
        inQuote = !inQuote;
        buffer.write(c);
      } else if (c == ',' && !inQuote) {
        args.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(c);
      }
    }
    if (buffer.isNotEmpty) args.add(buffer.toString().trim());
    return args;
  }

  String _unquote(String s) {
    if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
      return s.substring(1, s.length - 1);
    }
    return s;
  }

  int _toInt(String s) => int.tryParse(_unquote(s)) ?? 0;
  double _toDouble(String s) => double.tryParse(_unquote(s)) ?? 0;

  Future<ToolExecution> _executeApplyOps(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final opsInput = input['ops'] as List<dynamic>? ?? [];

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Ops execution not available',
        isError: true,
        summary: 'apply_ops failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex',
        isError: true,
        summary: 'apply_ops failed',
      );
    }

    if (opsInput.isEmpty) {
      return ToolExecution(
        output: 'ops must not be empty',
        isError: true,
        summary: 'apply_ops failed',
      );
    }

    if (opsInput.length > 50) {
      return ToolExecution(
        output: 'Max 50 ops allowed, got ${opsInput.length}',
        isError: true,
        summary: 'apply_ops failed',
      );
    }

    final slide = slides[slideIndex];
    final logs = <String>[];

    for (final op in opsInput) {
      if (op is! Map<String, dynamic>) {
        logs.add('⚠️ Invalid op: $op');
        continue;
      }

      final opName = op['op'] as String? ?? '';
      final idx = (op['idx'] as int?) ?? 0;

      if (idx < 0 || idx >= slide.elements.length) {
        logs.add('⚠️ Invalid idx $idx for op $opName');
        continue;
      }

      final el = slide.elements[idx];

      switch (opName) {
        case 'setBox':
          el.x = (op['x'] as num?)?.toDouble() ?? el.x;
          el.y = (op['y'] as num?)?.toDouble() ?? el.y;
          el.width = (op['w'] as num?)?.toDouble() ?? el.width;
          el.height = (op['h'] as num?)?.toDouble() ?? el.height;
          logs.add('setBox($idx)');
          break;
        case 'moveBy':
          el.x += (op['dx'] as num?)?.toDouble() ?? 0;
          el.y += (op['dy'] as num?)?.toDouble() ?? 0;
          logs.add('moveBy($idx)');
          break;
        case 'resizeBy':
          el.width += (op['dw'] as num?)?.toDouble() ?? 0;
          el.height += (op['dh'] as num?)?.toDouble() ?? 0;
          logs.add('resizeBy($idx)');
          break;
        case 'setText':
          el.content = op['text'] as String? ?? el.content;
          el.richRuns = null;
          logs.add('setText($idx)');
          break;
        case 'setFill':
          final color = op['color'] as String? ?? '#000000';
          if (el.type == ElementType.shape && el.shapeStyle != null) {
            el.shapeStyle!.fillColorValue = _hexToInt(color);
          }
          logs.add('setFill($idx) → $color');
          break;
        case 'setStyle':
          if (el.type == ElementType.text && el.textStyle != null) {
            if (op['fontSize'] != null) el.textStyle!.fontSize = (op['fontSize'] as num).toDouble();
            if (op['color'] != null) el.textStyle!.colorValue = _hexToInt(op['color'] as String);
            if (op['bold'] != null) el.textStyle!.fontWeight = (op['bold'] as bool) ? 'bold' : 'normal';
          }
          logs.add('setStyle($idx)');
          break;
        default:
          logs.add('⚠️ Unknown op: $opName');
      }
    }

    return ToolExecution(
      output: 'Applied ${opsInput.length} ops on slide ${slideIndex + 1}\n${logs.join('\n')}',
      mutated: true,
      summary: 'Applied ${opsInput.length} ops',
    );
  }

  Future<ToolExecution> _executeAddSmartArt(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final layout = (input['layout'] as String?) ?? 'list';
    final itemsInput = input['items'] as List<dynamic>? ?? [];
    final x = (input['x'] as num?)?.toDouble() ?? 100.0;
    final y = (input['y'] as num?)?.toDouble() ?? 100.0;
    final width = (input['width'] as num?)?.toDouble() ?? 500.0;
    final height = (input['height'] as num?)?.toDouble() ?? 400.0;

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Element creation not available',
        isError: true,
        summary: 'add_smartart failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex',
        isError: true,
        summary: 'add_smartart failed',
      );
    }

    if (itemsInput.isEmpty) {
      return ToolExecution(
        output: 'items must not be empty',
        isError: true,
        summary: 'add_smartart failed',
      );
    }

    final items = itemsInput.map((i) => i.toString()).toList();
    final slide = slides[slideIndex];

    // Create SmartArt based on layout type
    final children = <SlideElement>[];
    final colors = [0xFF4472C4, 0xFFED7D31, 0xFFA5A5A5, 0xFFFFC000, 0xFF5B9BD5, 0xFF70AD47];

    switch (layout) {
      case 'process':
        // Horizontal process flow with arrows
        final itemWidth = (width - 40) / items.length;
        for (int i = 0; i < items.length; i++) {
          final shape = SlideElement(
            id: 'sma_${DateTime.now().millisecondsSinceEpoch}_$i',
            type: ElementType.shape,
            x: x + 20 + (i * itemWidth),
            y: y + height * 0.2,
            width: itemWidth - 15,
            height: height * 0.35,
            zIndex: i,
            shapeStyle: ShapeStyleData(
              fillColorValue: colors[i % colors.length],
              shapeType: 'roundRect',
            ),
          );
          children.add(shape);

          // Arrow between items
          if (i < items.length - 1) {
            final arrow = SlideElement(
              id: 'sma_arr_${DateTime.now().millisecondsSinceEpoch}_$i',
              type: ElementType.shape,
              x: x + 20 + ((i + 1) * itemWidth) - 12,
              y: y + height * 0.32,
              width: 10,
              height: 10,
              zIndex: items.length + i,
              shapeStyle: ShapeStyleData(
                fillColorValue: 0xFF333333,
                shapeType: 'triangle',
              ),
            );
            children.add(arrow);
          }

          final text = SlideElement(
            id: 'smt_${DateTime.now().millisecondsSinceEpoch}_$i',
            type: ElementType.text,
            x: x + 20 + (i * itemWidth),
            y: y + height * 0.6,
            width: itemWidth - 15,
            height: height * 0.3,
            zIndex: items.length * 2 + i,
            content: items[i],
            textStyle: TextStyleData(
              fontSize: 12,
              colorValue: 0xFF1a1a2e,
              fontWeight: 'bold',
            ),
          );
          children.add(text);
        }
        break;

      case 'cycle':
        // Circular arrangement
        final centerX = x + width / 2;
        final centerY = y + height / 2;
        final radius = (width < height ? width : height) * 0.35;
        final angleStep = 2 * math.pi / items.length;

        for (int i = 0; i < items.length; i++) {
          final angle = angleStep * i - math.pi / 2;
          final itemX = centerX + radius * math.cos(angle) - 50;
          final itemY = centerY + radius * math.sin(angle) - 25;

          final shape = SlideElement(
            id: 'sma_${DateTime.now().millisecondsSinceEpoch}_$i',
            type: ElementType.shape,
            x: itemX,
            y: itemY,
            width: 100,
            height: 50,
            zIndex: i,
            shapeStyle: ShapeStyleData(
              fillColorValue: colors[i % colors.length],
              shapeType: 'roundRect',
            ),
          );
          children.add(shape);

          final text = SlideElement(
            id: 'smt_${DateTime.now().millisecondsSinceEpoch}_$i',
            type: ElementType.text,
            x: itemX,
            y: itemY + 55,
            width: 100,
            height: 25,
            zIndex: items.length + i,
            content: items[i],
            textStyle: TextStyleData(
              fontSize: 10,
              colorValue: 0xFF1a1a2e,
              fontWeight: 'bold',
            ),
          );
          children.add(text);
        }
        break;

      case 'hierarchy':
        // Tree/hierarchy layout
        final itemWidth = width / items.length;
        final topItem = items.first;
        final bottomItems = items.sublist(1);

        // Top node (parent)
        final parentShape = SlideElement(
          id: 'sma_${DateTime.now().millisecondsSinceEpoch}_parent',
          type: ElementType.shape,
          x: x + width / 2 - 60,
          y: y,
          width: 120,
          height: 50,
          zIndex: 0,
          shapeStyle: ShapeStyleData(
            fillColorValue: colors[0],
            shapeType: 'roundRect',
          ),
        );
        children.add(parentShape);

        final parentText = SlideElement(
          id: 'smt_${DateTime.now().millisecondsSinceEpoch}_parent',
          type: ElementType.text,
          x: x + width / 2 - 60,
          y: y + 55,
          width: 120,
          height: 25,
          zIndex: items.length,
          content: topItem,
          textStyle: TextStyleData(
            fontSize: 11,
            colorValue: 0xFF1a1a2e,
            fontWeight: 'bold',
          ),
        );
        children.add(parentText);

        // Child nodes
        for (int i = 0; i < bottomItems.length; i++) {
          final childShape = SlideElement(
            id: 'sma_${DateTime.now().millisecondsSinceEpoch}_$i',
            type: ElementType.shape,
            x: x + (i * itemWidth) + 10,
            y: y + height * 0.55,
            width: itemWidth - 20,
            height: 40,
            zIndex: i + 1,
            shapeStyle: ShapeStyleData(
              fillColorValue: colors[(i + 1) % colors.length],
              shapeType: 'roundRect',
            ),
          );
          children.add(childShape);

          final childText = SlideElement(
            id: 'smt_${DateTime.now().millisecondsSinceEpoch}_$i',
            type: ElementType.text,
            x: x + (i * itemWidth) + 10,
            y: y + height * 0.55 + 45,
            width: itemWidth - 20,
            height: 25,
            zIndex: items.length + i + 1,
            content: bottomItems[i],
            textStyle: TextStyleData(
              fontSize: 10,
              colorValue: 0xFF1a1a2e,
              fontWeight: 'bold',
            ),
          );
          children.add(childText);
        }
        break;

      case 'pyramid':
        // Pyramid layout (wider at bottom)
        final itemCount = items.length;
        for (int i = 0; i < itemCount; i++) {
          final progress = i / (itemCount > 1 ? itemCount - 1 : 1);
          final itemW = width * (0.3 + 0.7 * (1 - progress));
          final itemX = x + (width - itemW) / 2;
          final itemY = y + (height / itemCount) * i;
          final itemH = height / itemCount - 5;

          final shape = SlideElement(
            id: 'sma_${DateTime.now().millisecondsSinceEpoch}_$i',
            type: ElementType.shape,
            x: itemX,
            y: itemY,
            width: itemW,
            height: itemH,
            zIndex: i,
            shapeStyle: ShapeStyleData(
              fillColorValue: colors[i % colors.length],
              shapeType: 'roundRect',
            ),
          );
          children.add(shape);

          final text = SlideElement(
            id: 'smt_${DateTime.now().millisecondsSinceEpoch}_$i',
            type: ElementType.text,
            x: itemX,
            y: itemY + itemH / 2 - 8,
            width: itemW,
            height: 20,
            zIndex: itemCount + i,
            content: items[i],
            textStyle: TextStyleData(
              fontSize: 11,
              colorValue: 0xFFFFFFFF,
              fontWeight: 'bold',
            ),
          );
          children.add(text);
        }
        break;

      case 'matrix':
        // 2x2 or NxN grid
        final cols = items.length <= 4 ? 2 : 3;
        final rows = (items.length / cols).ceil();
        final cellW = width / cols;
        final cellH = height / rows;

        for (int i = 0; i < items.length; i++) {
          final row = i ~/ cols;
          final col = i % cols;
          final itemX = x + col * cellW + 5;
          final itemY = y + row * cellH + 5;

          final shape = SlideElement(
            id: 'sma_${DateTime.now().millisecondsSinceEpoch}_$i',
            type: ElementType.shape,
            x: itemX,
            y: itemY,
            width: cellW - 10,
            height: cellH - 10,
            zIndex: i,
            shapeStyle: ShapeStyleData(
              fillColorValue: colors[i % colors.length],
              shapeType: 'roundRect',
            ),
          );
          children.add(shape);

          final text = SlideElement(
            id: 'smt_${DateTime.now().millisecondsSinceEpoch}_$i',
            type: ElementType.text,
            x: itemX,
            y: itemY + cellH / 2 - 8,
            width: cellW - 10,
            height: 20,
            zIndex: items.length + i,
            content: items[i],
            textStyle: TextStyleData(
              fontSize: 11,
              colorValue: 0xFFFFFFFF,
              fontWeight: 'bold',
            ),
          );
          children.add(text);
        }
        break;

      default: // 'list'
        // Vertical list layout
        final itemHeight = height / items.length;
        for (int i = 0; i < items.length; i++) {
          final shape = SlideElement(
            id: 'sma_${DateTime.now().millisecondsSinceEpoch}_$i',
            type: ElementType.shape,
            x: x,
            y: y + (i * itemHeight),
            width: width,
            height: itemHeight - 5,
            zIndex: i,
            shapeStyle: ShapeStyleData(
              fillColorValue: colors[i % colors.length],
              shapeType: 'roundRect',
            ),
          );
          children.add(shape);

          final text = SlideElement(
            id: 'smt_${DateTime.now().millisecondsSinceEpoch}_$i',
            type: ElementType.text,
            x: x + 10,
            y: y + (i * itemHeight) + itemHeight / 2 - 8,
            width: width - 20,
            height: 20,
            zIndex: items.length + i,
            content: items[i],
            textStyle: TextStyleData(
              fontSize: 13,
              colorValue: 0xFFFFFFFF,
              fontWeight: 'bold',
            ),
          );
          children.add(text);
        }
        break;
    }

    // Add as individual elements (grouping not fully supported yet)
    for (final child in children) {
      slide.elements.add(child);
    }

    return ToolExecution(
      output: 'Added $layout SmartArt with ${items.length} items on slide ${slideIndex + 1}',
      mutated: true,
      summary: 'Added SmartArt',
    );
  }

  Future<ToolExecution> _executeUngroupElement(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final elementIndex = (input['elementIndex'] as int?) ?? 0;

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Element editing not available',
        isError: true,
        summary: 'ungroup_element failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex',
        isError: true,
        summary: 'ungroup_element failed',
      );
    }

    final slide = slides[slideIndex];
    if (elementIndex < 0 || elementIndex >= slide.elements.length) {
      return ToolExecution(
        output: 'Invalid element index $elementIndex',
        isError: true,
        summary: 'ungroup_element failed',
      );
    }

    final element = slide.elements[elementIndex];
    // Check if element has children (group-like structure)
    final children = element.extra?['children'] as List<dynamic>?;
    if (children == null || children.isEmpty) {
      return ToolExecution(
        output: 'Element is not a group or has no children',
        isError: true,
        summary: 'ungroup_element failed',
      );
    }

    // Remove group and add children
    slide.elements.removeAt(elementIndex);
    for (final childData in children) {
      if (childData is Map<String, dynamic>) {
        // Safely parse element type with fallback to shape
        final typeStr = childData['type'] as String? ?? 'shape';
        final type = ElementType.values.where((e) => e.name == typeStr).firstOrNull ?? ElementType.shape;
        final child = SlideElement(
          id: childData['id'] ?? 'ungrouped_${DateTime.now().millisecondsSinceEpoch}',
          type: type,
          x: (childData['x'] as num?)?.toDouble() ?? 0,
          y: (childData['y'] as num?)?.toDouble() ?? 0,
          width: (childData['width'] as num?)?.toDouble() ?? 100,
          height: (childData['height'] as num?)?.toDouble() ?? 100,
          content: childData['content'],
          zIndex: slide.elements.length,
        );
        slide.elements.add(child);
      }
    }

    return ToolExecution(
      output: 'Ungrouped element at index $elementIndex into ${children.length} children',
      mutated: true,
      summary: 'Ungrouped element',
    );
  }

  Future<ToolExecution> _executeSaveBlueprint(Map<String, dynamic> input) async {
    final name = (input['name'] as String?)?.trim() ?? '';
    final topic = (input['topic'] as String?)?.trim() ?? _topic;

    if (name.isEmpty) {
      return ToolExecution(
        output: 'name must not be empty',
        isError: true,
        summary: 'save_blueprint failed',
      );
    }

    // Store blueprint in state
    _state.blueprints ??= [];
    _state.blueprints!.add({
      'id': 'bp_${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'topic': topic,
      'styleSkill': _state.lastStyleSkill ?? '',
      'pageCount': _pages.length,
      'createdAt': DateTime.now().toIso8601String(),
    });

    return ToolExecution(
      output: 'Saved blueprint "$name" with ${_pages.length} pages',
      mutated: false,
      summary: 'Saved blueprint "$name"',
    );
  }

  Future<ToolExecution> _executeLoadBlueprint(Map<String, dynamic> input) async {
    final blueprintId = (input['blueprintId'] as String?)?.trim() ?? '';

    if (blueprintId.isEmpty) {
      return ToolExecution(
        output: 'blueprintId must not be empty',
        isError: true,
        summary: 'load_blueprint failed',
      );
    }

    final blueprints = _state.blueprints ?? [];
    final bp = blueprints.firstWhere(
      (b) => b['id'] == blueprintId,
      orElse: () => {},
    );

    if (bp.isEmpty) {
      return ToolExecution(
        output: 'Blueprint not found: $blueprintId',
        isError: true,
        summary: 'load_blueprint failed',
      );
    }

    return ToolExecution(
      output: 'Loaded blueprint "${bp['name']}" (topic: ${bp['topic']}, ${bp['pageCount']} pages)',
      mutated: false,
      summary: 'Loaded blueprint "${bp['name']}"',
    );
  }

  Future<ToolExecution> _executeListBlueprints() async {
    final blueprints = _state.blueprints ?? [];

    if (blueprints.isEmpty) {
      return ToolExecution(
        output: 'No saved blueprints',
        mutated: false,
        summary: 'No blueprints',
      );
    }

    final buffer = StringBuffer();
    buffer.writeln('Saved blueprints:');
    for (final bp in blueprints) {
      buffer.writeln('- ${bp['name']} (${bp['topic']}, ${bp['pageCount']} pages)');
    }

    return ToolExecution(
      output: buffer.toString(),
      mutated: false,
      summary: 'Listed ${blueprints.length} blueprints',
    );
  }

  Future<ToolExecution> _executeSetElementStroke(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final elementIndex = (input['elementIndex'] as int?) ?? 0;
    final color = (input['color'] as String?)?.trim();
    final width = (input['width'] as num?)?.toDouble();

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Element editing not available',
        isError: true,
        summary: 'set_element_stroke failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex',
        isError: true,
        summary: 'set_element_stroke failed',
      );
    }

    final slide = slides[slideIndex];
    if (elementIndex < 0 || elementIndex >= slide.elements.length) {
      return ToolExecution(
        output: 'Invalid element index $elementIndex',
        isError: true,
        summary: 'set_element_stroke failed',
      );
    }

    final element = slide.elements[elementIndex];
    if (element.shapeStyle == null) {
      element.shapeStyle = ShapeStyleData();
    }
    if (color != null) element.shapeStyle!.strokeColorValue = _hexToInt(color);
    if (width != null) element.shapeStyle!.strokeWidth = width;

    return ToolExecution(
      output: 'Updated stroke of element $elementIndex on slide ${slideIndex + 1}',
      mutated: true,
      summary: 'Updated element stroke',
    );
  }

  Future<ToolExecution> _executeSetPictureOpacity(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final elementIndex = (input['elementIndex'] as int?) ?? 0;
    final opacity = (input['opacity'] as num?)?.toDouble() ?? 1.0;

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Element editing not available',
        isError: true,
        summary: 'set_picture_opacity failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex',
        isError: true,
        summary: 'set_picture_opacity failed',
      );
    }

    final slide = slides[slideIndex];
    if (elementIndex < 0 || elementIndex >= slide.elements.length) {
      return ToolExecution(
        output: 'Invalid element index $elementIndex',
        isError: true,
        summary: 'set_picture_opacity failed',
      );
    }

    final element = slide.elements[elementIndex];
    if (element.type != ElementType.image) {
      return ToolExecution(
        output: 'Element is not an image',
        isError: true,
        summary: 'set_picture_opacity failed',
      );
    }

    if (element.imageStyle == null) {
      element.imageStyle = ImageStyleData();
    }
    element.imageStyle!.opacity = opacity.clamp(0.0, 1.0);

    return ToolExecution(
      output: 'Set opacity of image $elementIndex to ${opacity.toStringAsFixed(2)}',
      mutated: true,
      summary: 'Set image opacity',
    );
  }

  Future<ToolExecution> _executeEditTableStyle(Map<String, dynamic> input) async {
    final slideIndex = (input['slideIndex'] as int?) ?? 0;
    final elementIndex = (input['elementIndex'] as int?) ?? 0;
    final style = (input['style'] as String?) ?? 'default';

    if (_slidesGetter == null || _slideReplacer == null) {
      return ToolExecution(
        output: 'Element editing not available',
        isError: true,
        summary: 'edit_table_style failed',
      );
    }

    final slides = _slidesGetter!();
    if (slideIndex < 0 || slideIndex >= slides.length) {
      return ToolExecution(
        output: 'Invalid slide index $slideIndex',
        isError: true,
        summary: 'edit_table_style failed',
      );
    }

    final slide = slides[slideIndex];
    if (elementIndex < 0 || elementIndex >= slide.elements.length) {
      return ToolExecution(
        output: 'Invalid element index $elementIndex',
        isError: true,
        summary: 'edit_table_style failed',
      );
    }

    final element = slide.elements[elementIndex];
    if (element.type != ElementType.table || element.tableData == null) {
      return ToolExecution(
        output: 'Element is not a table',
        isError: true,
        summary: 'edit_table_style failed',
      );
    }

    // Store style in extra
    element.extra ??= {};
    element.extra!['tableStyle'] = style;

    return ToolExecution(
      output: 'Applied "$style" style to table on slide ${slideIndex + 1}',
      mutated: true,
      summary: 'Applied table style',
    );
  }

  Future<ToolExecution> _executePlanDeck(Map<String, dynamic> input) async {
    final topic = (input['topic'] as String?)?.trim() ?? '';
    final approxPages = (input['approxPages'] as int?) ?? 6;
    final context = (input['context'] as String?)?.trim();

    if (topic.isEmpty) {
      return ToolExecution(
        output: 'topic must not be empty',
        isError: true,
        summary: 'plan_deck failed',
      );
    }

    // Store planning request for the AI to process
    _state.plannedPages = approxPages;
    _state.lastTopic = topic;

    final buffer = StringBuffer();
    buffer.writeln('Planning deck: "$topic"');
    buffer.writeln('Target: ~$approxPages pages');
    if (context != null && context.isNotEmpty) {
      buffer.writeln('Context: ${context.length > 200 ? context.substring(0, 200) + '...' : context}');
    }

    // Actually trigger planning if available
    if (_outlinePlanner != null) {
      try {
        final planResult = await _outlinePlanner!(
          topic: topic,
          count: approxPages,
          startPage: 1,
          context: context,
          styleSkill: _state.lastStyleSkill,
        );

        if (planResult.ok && planResult.outline?.pages != null) {
          final pages = planResult.outline!.pages!;
          // Store the planned pages for use by generate_deck
          _pages = pages.map((p) => OutlinePage(
            title: p.title ?? '',
            brief: p.brief ?? '',
            layout: p.layout ?? '',
            index: 0, // will be renumbered later when used
          )).toList();
          _reindexPages();
          // Update state
          _state.plannedPages = _pages.length;
          _state.plannedTitles = _pages.map((p) => p.title).toList();
          _state.pageDone = List.filled(_pages.length, false);
          buffer.writeln('');
          buffer.writeln('Core hook: ${planResult.outline!.coreHook ?? "none"}');
          buffer.writeln('Outline (${pages.length} pages):');
          for (int i = 0; i < pages.length; i++) {
            final p = pages[i];
            buffer.writeln('${i + 1}. [${p.type ?? "content"}] ${p.title}: ${p.brief}');
          }
        } else {
          buffer.writeln('');
          buffer.writeln('Planning failed: ${planResult.error ?? "unknown error"}');
        }
      } catch (e) {
        buffer.writeln('');
        buffer.writeln('Planning error: $e');
      }
    } else {
      buffer.writeln('');
      buffer.writeln('No planner available — use generate_deck to plan + generate in one step.');
    }

    return ToolExecution(
      output: buffer.toString(),
      mutated: false,
      summary: 'Planning deck "$topic"',
    );
  }

  Future<ToolExecution> _executeAskClarification(Map<String, dynamic> input) async {
    final question = (input['question'] as String?)?.trim() ?? '';
    final optionsInput = input['options'] as List<dynamic>?;

    if (question.isEmpty) {
      return ToolExecution(
        output: 'question must not be empty',
        isError: true,
        summary: 'ask_clarification failed',
      );
    }

    final buffer = StringBuffer();
    buffer.writeln('❓ $question');
    if (optionsInput != null && optionsInput.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Options:');
      for (int i = 0; i < optionsInput.length; i++) {
        buffer.writeln('  ${i + 1}. ${optionsInput[i]}');
      }
    }
    buffer.writeln('');
    buffer.writeln('(Waiting for user response)');

    return ToolExecution(
      output: buffer.toString(),
      mutated: false,
      summary: 'Asked clarification',
    );
  }

  Future<ToolExecution> _executeImageSearch(Map<String, dynamic> input) async {
    final query = (input['query'] as String?)?.trim() ?? '';
    final maxResults = (input['maxResults'] as int?) ?? 5;

    if (query.isEmpty) {
      return ToolExecution(
        output: 'query must not be empty',
        isError: true,
        summary: 'image_search failed',
      );
    }

    if (_imageSearcher == null) {
      return ToolExecution(
        output: 'Image search not available',
        isError: true,
        summary: 'image_search failed',
      );
    }

    try {
      final urls = await _imageSearcher!(query, maxResults);
      if (urls.isEmpty) {
        return ToolExecution(
          output: 'No images found for "$query"',
          mutated: false,
          summary: 'No images found',
        );
      }

      final buffer = StringBuffer();
      buffer.writeln('Found ${urls.length} images for "$query":');
      for (int i = 0; i < urls.length; i++) {
        buffer.writeln('${i + 1}. ${urls[i]}');
      }

      return ToolExecution(
        output: buffer.toString(),
        mutated: false,
        summary: 'Found ${urls.length} images',
      );
    } catch (e) {
      return ToolExecution(
        output: 'Image search failed: $e',
        isError: true,
        summary: 'image_search failed',
      );
    }
  }

  Future<ToolExecution> _executeGenerateImage(Map<String, dynamic> input) async {
    final prompt = (input['prompt'] as String?)?.trim() ?? '';
    final width = (input['width'] as int?) ?? 1024;
    final height = (input['height'] as int?) ?? 1024;

    if (prompt.isEmpty) {
      return ToolExecution(
        output: 'prompt must not be empty',
        isError: true,
        summary: 'generate_image failed',
      );
    }

    // AI image generation requires cloud services
    return ToolExecution(
      output: 'AI image generation requires cloud service integration. Use image_search to find existing images instead.',
      isError: true,
      summary: 'generate_image not available',
    );
  }

  Future<ToolExecution> _executeAnalyzeMedia(Map<String, dynamic> input) async {
    final url = (input['url'] as String?)?.trim() ?? '';

    if (url.isEmpty) {
      return ToolExecution(
        output: 'url must not be empty',
        isError: true,
        summary: 'analyze_media failed',
      );
    }

    // Media analysis requires vision model
    return ToolExecution(
      output: 'Media analysis requires vision model integration. Image URL: $url',
      isError: true,
      summary: 'analyze_media not available',
    );
  }

  Future<ToolExecution> _executeWebSearch(Map<String, dynamic> input) async {
    final query = (input['query'] as String?)?.trim() ?? '';

    if (query.isEmpty) {
      return ToolExecution(
        output: 'query must not be empty',
        isError: true,
        summary: 'web_search failed',
      );
    }

    // Web search requires external API
    return ToolExecution(
      output: 'Web search requires external API integration. Use the AI model to answer questions about "$query" instead.',
      isError: true,
      summary: 'web_search not available',
    );
  }

  ToolExecution _cancelResult(int landed, int total) {
    return ToolExecution(
      output: 'User stopped generation. $landed page(s) kept.',
      mutated: landed > 0,
      summary: 'generate_deck stopped',
    );
  }

  void _emitProgress(DeckProgressEvent event) {
    _onProgress?.call(event);
  }

  SlideElement _errorElement(String title, String error) {
    return SlideElement(
      type: ElementType.text,
      x: 100,
      y: 100,
      width: 800,
      height: 80,
      content: '$title — generation failed: $error',
      zIndex: 1,
    );
  }

  String _serializeOutline() {
    return jsonEncode(_pages.map((p) => {
      'index': p.index,
      'title': p.title,
      'brief': p.brief,
      if (p.layout != null) 'layout': p.layout,
    }).toList());
  }

  List<OutlinePage> _parseOutline(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! List) return const [];
      return [
        for (final entry in json)
          if (entry is Map)
            OutlinePage(
              index: (entry['index'] as num?)?.toInt() ?? 0,
              title: (entry['title'] as String?) ?? '',
              brief: (entry['brief'] as String?) ?? '',
              layout: entry['layout'] as String?,
            ),
      ];
    } catch (_) {
      return const [];
    }
  }
}
