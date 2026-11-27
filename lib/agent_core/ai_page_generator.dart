// DocuCraft Flutter — AiGenerationServicePageGenerator (Sprint 14 + JSON spec)
//
// [PageGenerator] nyata yang mendelegasikan ke
// `AiGenerationService.generateFromPrompt` yang sudah ada untuk satu SVG
// per halaman. Membungkus API statis agar slides-skill tetap ringan tanpa
// framework; transport di-inject agar test bisa mengganti dengan fake.
//
// Terinspirasi GenOffice: mencoba JSON spec dulu, fallback ke SVG.

import 'package:flutter/foundation.dart' show debugPrint;
import '../services/ai_generation.dart';
import '../services/slide_spec.dart';
import 'slides_skill.dart';

class AiGenerationServicePageGenerator implements PageGenerator {
  final String? model;
  final String style;
  final String colorScheme;
  final String? styleSkill;
  final String? coreHook;
  final List<String> imageUrls;
  final String? referenceMaterial;

  const AiGenerationServicePageGenerator({
    this.model,
    this.style = 'modern',
    this.colorScheme = 'indigo',
    this.styleSkill,
    this.coreHook,
    this.imageUrls = const [],
    this.referenceMaterial,
  });

  @override
  Future<String> generateSvg({
    required String topic,
    required int pageIndex,
    required int totalPages,
    required String title,
    required String brief,
    String layout = '',
  }) async {
    // ── Try JSON spec first (GenOffice-style, more reliable) ──
    final jsonResult = await _tryGenerateJsonSpec(
      topic: topic,
      pageIndex: pageIndex,
      totalPages: totalPages,
      title: title,
      brief: brief,
      layout: layout,
    );
    if (jsonResult != null) return jsonResult;

    // ── Fallback to SVG generation with classified errors ──
    return _generateSvgClassified(
      topic: topic,
      pageIndex: pageIndex,
      totalPages: totalPages,
      title: title,
      brief: brief,
    );
  }

  /// Try to generate a JSON spec slide with repair loop (GenOffice-style).
  /// Returns the JSON string on success. On first failure, feeds error back
  /// to AI and retries once (2 attempts total).
  Future<String?> _tryGenerateJsonSpec({
    required String topic,
    required int pageIndex,
    required int totalPages,
    required String title,
    required String brief,
    String layout = '',
  }) async {
    final basePrompt = _buildJsonSpecPrompt(topic, pageIndex, totalPages, title, brief, layout: layout);
    String? lastError;

    // GenOffice-style repair loop: 2 attempts with error feedback
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final prompt = attempt == 0
            ? basePrompt
            : '$basePrompt\n\nYour previous output was rejected: $lastError. Output the corrected JSON object only.';

        debugPrint('🔄 [JSON Spec] Page $pageIndex/$totalPages attempt ${attempt + 1}/2 — calling LLM...');

        final result = await AiGenerationService.generateClassified(
          prompt: prompt,
          model: model,
        );

        debugPrint('📡 [JSON Spec] Page $pageIndex response: ok=${result.ok}, text=${result.text?.length ?? 0} chars, errKind=${result.errKind}');

        if (!result.ok || result.text == null) {
          lastError = result.displayMessage;
          debugPrint('⚠️ [JSON Spec] Page $pageIndex attempt ${attempt + 1} failed: $lastError');
          continue;
        }

        final raw = result.text!;
        final parsed = parseSlideSpec(raw);
        if (parsed.ok) {
          debugPrint('✅ [JSON Spec] Page $pageIndex generated successfully (attempt ${attempt + 1})');
          return raw;
        } else {
          lastError = parsed.error ?? 'Invalid JSON spec format';
          debugPrint('⚠️ [JSON Spec] Page $pageIndex parse failed (attempt ${attempt + 1}): $lastError');
        }
      } catch (e) {
        lastError = e.toString();
        debugPrint('⚠️ [JSON Spec] Page $pageIndex error (attempt ${attempt + 1}): $e');
      }
    }
    return null;
  }

  /// Generate SVG as fallback with classified error handling.
  Future<String> _generateSvgClassified({
    required String topic,
    required int pageIndex,
    required int totalPages,
    required String title,
    required String brief,
  }) async {
    final prompt = '''
Slide $pageIndex of $totalPages
Topic: $topic
Slide Title: $title
Style: $style
Color: $colorScheme
Context: This is slide $pageIndex in a $totalPages-slide presentation about "$topic".

Create a complete, visually appealing slide for "$title". Use REAL content about $topic — no placeholder text. Minimum 6 elements (title, body, decorative shapes).
''';

    // Use classified error handling with model fallback
    final result = await AiGenerationService.generateClassified(
      prompt: prompt,
      model: model,
    );

    if (!result.ok || result.text == null) {
      final errKind = result.errKind?.name ?? 'unknown';
      final reason = result.displayMessage;
      debugPrint('⚠️ [PageGen] Page $pageIndex failed ($errKind): $reason');
      // Throw with error kind prefix for upstream classification
      throw '[$errKind] page $pageIndex: $reason';
    }

    // Check if response is SVG or JSON
    final response = result.text!;
    if (response.trimLeft().startsWith('<svg')) {
      debugPrint('✅ [PageGen] Page $pageIndex: SVG (${response.length} chars)');
      return response;
    }

    // Try to find SVG inside response
    final svgMatch = RegExp(r'<svg[\s\S]*?</svg>', multiLine: true).firstMatch(response);
    if (svgMatch != null) {
      debugPrint('✅ [PageGen] Page $pageIndex: SVG found inside response (${svgMatch.group(0)!.length} chars)');
      return svgMatch.group(0)!;
    }

    // Check if it's JSON spec
    final parsed = parseSlideSpec(response);
    if (parsed.ok) {
      debugPrint('✅ [PageGen] Page $pageIndex: JSON spec (${response.length} chars)');
      return response;
    }

    // Neither SVG nor JSON — return as-is (will fail in parser upstream)
    debugPrint('⚠️ [PageGen] Page $pageIndex: non-SVG/non-JSON response (${response.length} chars)');
    return response;
  }

  /// Build prompt for JSON spec generation (GenOffice-inspired).
  String _buildJsonSpecPrompt(
    String topic, int pageIndex, int totalPages, String title, String brief, {
    String layout = '',
  }) {
    // Build image block (GenOffice-style)
    final imgBlock = imageUrls.isNotEmpty
        ? '\nAvailable image URLs (put them into image elements; do not invent placeholder blocks):\n${imageUrls.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}'
        : '';

    // Build reference material block (GenOffice-style, cap at 4000 chars)
    final ctxBlock = referenceMaterial != null && referenceMaterial!.isNotEmpty
        ? '\n\nReference material (all real names/figures/facts come from here; do not invent):\n${referenceMaterial!.length > 4000 ? referenceMaterial!.substring(0, 4000) : referenceMaterial!}'
        : '';

    // Build style skill block (GenOffice-style)
    final styleBlock = styleSkill != null && styleSkill!.isNotEmpty
        ? '\n\nDeck unified style (this page must follow it strictly to stay consistent across pages):\n$styleSkill'
        : '';

    // Build core hook block
    final coreHookBlock = coreHook != null && coreHook!.isNotEmpty
        ? '\nDeck-wide narrative Core Hook: $coreHook'
        : '';

    // GenOffice passes layout intent — DocuCraft should too
    final layoutBlock = layout.isNotEmpty ? '\nLayout: $layout' : '';

    return '''
CRITICAL: Output ONLY a JSON object. NO SVG. NO markdown. NO explanations. NO code fences. ONLY the raw JSON.

You are a professional slide visual designer. Create ONE visually stunning slide.$styleBlock$coreHookBlock

## Canvas: ${specCanvasW}x${specCanvasH} px
All coordinates are integers in px. Origin is top-left. Nothing may cross canvas edges. Elements paint in array order: background/decor shapes first, then images, text last (text must never end up underneath a shape).

## Format
{"background":"#RRGGBB","elements":[...]}

Element types:

1. Shape: {"type":"shape","shape":"roundRect","x":80,"y":120,"w":360,"h":200,"fill":"#RRGGBB or #RRGGBBAA (AA=alpha, 00 transparent)","stroke":{"color":"#RRGGBB","widthPt":1},"paragraphs":[{"runs":[{"text":"label","sizePt":14,"bold":true,"color":"#FFFFFF"}]}]}
   Allowed shape values: rect, roundRect, ellipse, triangle, rightArrow, leftArrow, upArrow, downArrow, chevron, diamond, parallelogram, trapezoid, hexagon, pentagon, star5, heart, cloud, line, lineArrow. line/lineArrow draw the diagonal of their box from top-left to bottom-right and need a stroke (a horizontal rule = a box with h:1).

2. Text: {"type":"text","x":80,"y":60,"w":800,"h":90,"valign":"top","paragraphs":[{"align":"left","lineSpacingPct":110,"spaceAfterPt":6,"bullet":false,"runs":[{"text":"...","sizePt":18,"bold":true,"italic":false,"color":"#RRGGBB","font":"Font Name"}]}]}
   A paragraph may mix runs of different weight/color/size (e.g. a big number run + a small unit run in one line).

3. Image: {"type":"image","url":"https://...","x":660,"y":80,"w":540,"h":560} — center-cropped to fill its box (object-fit: cover).

## Hard Layout Rules (CRITICAL)
- Text boxes have ZERO inner padding: the box top-left is exactly where the first glyph starts. Size every box from its content: one line is about sizePt×1.8 px tall at lineSpacingPct 110; a CJK character is about sizePt×1.35 px wide, a Latin character about sizePt×0.7 px wide. Text wraps at the box width — count the wrapped lines and make the box tall enough, plus one spare line.
- Text must never overflow its box or overlap other text. Keep >=8px between text and card edges, >=20px between a big title and its subtitle, >=5px between stacked text blocks in the same column — self-check every pair before output.
- Font sizes in pt: big titles 32-48, subtitles 18-24, body 12-15, hero KPI numbers up to 80.
- Spread content across the whole page; do not cram it into the top half leaving large blank areas; make text and images as large as the layout allows.

## Design System (MANDATORY)
- Pick ONE primary accent + ONE secondary accent for the whole slide. Use them consistently.
- Background: dark (#1a1a2e, #0f172a, #1e1b4b) OR light (#f8fafc, #f1f5f9). Never mid-gray.
- Text on dark bg: white/light (#ffffff, #e2e8f0). Text on light bg: dark (#1a1a2e, #334155).
- Contrast: background vs text must be high contrast (WCAG AA minimum).

## Anti-AI Design Rules (violation = unacceptable)
- NO thin vertical accent bar on the left of cards, NO colored bar on top of cards, NO small bar left of titles — express hierarchy with background color/font weight/size contrast.
- NO decorative corner blocks or short lines; decorative elements must be consistent in position and style across the deck.
- One primary + one secondary accent color for the whole page; even when comparing multiple entities, do not give each a different color (no rainbow cards).
- Cards: subtle border or shadow, NOT thick colored borders.
- Do not turn every page into a "shape + bold subtitle + description" list; the cover must not be a flat one-line title + subtitle layout — it needs a visual anchor (large color block/geometric composition/huge number/hero image).

## Visuals and Assets
- Photos may only use URLs from the "available images" list, at most as many image elements as URLs. With no available images, fill with typography/color blocks/shapes — never fake photos.
- Icon-like decoration uses the allowed shapes only (at most 4-5 per page, strongly content-related). **Never use emoji**.
- Data visuals: compose bars/rings/timelines from rect/donut/line shapes with sizes proportional to the real values from the brief.
- Solid colors only (alpha allowed) — no gradients. **No placeholders of any kind**: all copy comes from the brief's real content.

## Content Selection (CRITICAL)
- This is ONE slide in a deck. Do NOT try to fit all reference material onto it.
- Select only the 3-5 most important points from the brief that match this slide's title and layout.
- If the brief is long, truncate aggressively — the deck has other slides for the rest.
- Body text: max 3 lines per text box (about 40-60 words). If longer, cut or use fewer points.
- Title: max 8 words. Subtitle: max 12 words.
- If you cannot fit content within the canvas, you MUST reduce font sizes or remove elements — never let content overflow.

---
$ctxBlock$imgBlock

Slide $pageIndex of $totalPages in a presentation about "$topic"
Title: $title$layoutBlock
Content brief (use real data/facts): $brief

Return only this page's spec JSON:''';
  }
}
