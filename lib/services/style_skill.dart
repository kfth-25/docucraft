// DocuCraft — Style Skill (terinspirasi GenOffice)
//
// Panduan gaya visual khusus yang dihasilkan AI sebelum generate halaman.
// Memastikan desain yang konsisten di seluruh halaman dalam satu deck.
//
// Berdasarkan generateStyleSkill di AiPanel.tsx milik GenOffice:
//   - Aturan warna (bg utama, bg per jenis halaman, teks, aksen)
//   - Aturan font (judul CJK, judul Latin, body)
//   - Varian layout per jenis halaman (cover/content/data/closing)
//   - Deskripsi gaya keseluruhan

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'ai_generation.dart';

/// Layout variant for a specific page type.
/// GenOffice has 17 variants: 6 cover, 6 content, 3 data, 2 closing.
class LayoutVariant {
  final String id;
  final String name;
  final String description;

  const LayoutVariant({
    required this.id,
    required this.name,
    required this.description,
  });

  factory LayoutVariant.fromJson(Map<String, dynamic> json) => LayoutVariant(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
  };
}

/// Color rules for the style skill.
class ColorRules {
  final String mainBackground;
  final Map<String, String> perPageTypeBackgrounds;
  final String mainTextColor;
  final String primaryAccent;
  final String secondaryAccent;
  final String cardBackground;
  final String? borderColor;

  const ColorRules({
    required this.mainBackground,
    required this.perPageTypeBackgrounds,
    required this.mainTextColor,
    required this.primaryAccent,
    required this.secondaryAccent,
    required this.cardBackground,
    this.borderColor,
  });

  factory ColorRules.fromJson(Map<String, dynamic> json) => ColorRules(
    mainBackground: json['mainBackground']?.toString() ?? '#1a1a2e',
    perPageTypeBackgrounds: Map<String, String>.from(json['perPageTypeBackgrounds'] ?? {}),
    mainTextColor: json['mainTextColor']?.toString() ?? '#ffffff',
    primaryAccent: json['primaryAccent']?.toString() ?? '#6366f1',
    secondaryAccent: json['secondaryAccent']?.toString() ?? '#ec4899',
    cardBackground: json['cardBackground']?.toString() ?? '#1e1b4b',
    borderColor: json['borderColor']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'mainBackground': mainBackground,
    'perPageTypeBackgrounds': perPageTypeBackgrounds,
    'mainTextColor': mainTextColor,
    'primaryAccent': primaryAccent,
    'secondaryAccent': secondaryAccent,
    'cardBackground': cardBackground,
    if (borderColor != null) 'borderColor': borderColor,
  };
}

/// Font rules for the style skill.
class FontRules {
  final String latinTitleFont;
  final String bodyFont;
  final String titleSizeRange;
  final String bodySizeRange;

  const FontRules({
    required this.latinTitleFont,
    required this.bodyFont,
    required this.titleSizeRange,
    required this.bodySizeRange,
  });

  factory FontRules.fromJson(Map<String, dynamic> json) => FontRules(
    latinTitleFont: json['latinTitleFont']?.toString() ?? 'DM Sans',
    bodyFont: json['bodyFont']?.toString() ?? 'Inter',
    titleSizeRange: json['titleSizeRange']?.toString() ?? '32-48',
    bodySizeRange: json['bodySizeRange']?.toString() ?? '12-15',
  );

  Map<String, dynamic> toJson() => {
    'latinTitleFont': latinTitleFont,
    'bodyFont': bodyFont,
    'titleSizeRange': titleSizeRange,
    'bodySizeRange': bodySizeRange,
  };
}

/// Complete Style Skill output from AI.
class StyleSkill {
  final ColorRules colors;
  final FontRules fonts;
  final Map<String, List<LayoutVariant>> layoutVariants;
  final String overallStyle;

  const StyleSkill({
    required this.colors,
    required this.fonts,
    required this.layoutVariants,
    required this.overallStyle,
  });

  factory StyleSkill.fromJson(Map<String, dynamic> json) => StyleSkill(
    colors: ColorRules.fromJson(json['colors'] ?? {}),
    fonts: FontRules.fromJson(json['fonts'] ?? {}),
    layoutVariants: (json['layoutVariants'] as Map<String, dynamic>?)?.map(
      (key, value) => MapEntry(
        key,
        (value as List?)?.map((v) => LayoutVariant.fromJson(v as Map<String, dynamic>)).toList() ?? [],
      ),
    ) ?? {},
    overallStyle: json['overallStyle']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    'colors': colors.toJson(),
    'fonts': fonts.toJson(),
    'layoutVariants': layoutVariants.map(
      (key, value) => MapEntry(key, value.map((v) => v.toJson()).toList()),
    ),
    'overallStyle': overallStyle,
  };

  /// Convert to string for prompt injection.
  String toPromptString() {
    final sb = StringBuffer();
    sb.writeln('## Style Skill');
    sb.writeln();
    sb.writeln('### Colors');
    sb.writeln('- Main background: ${colors.mainBackground}');
    sb.writeln('- Main text color: ${colors.mainTextColor}');
    sb.writeln('- Primary accent: ${colors.primaryAccent}');
    sb.writeln('- Secondary accent: ${colors.secondaryAccent}');
    sb.writeln('- Card background: ${colors.cardBackground}');
    if (colors.borderColor != null) {
      sb.writeln('- Border color: ${colors.borderColor}');
    }
    sb.writeln();
    sb.writeln('Per-page-type backgrounds:');
    for (final entry in colors.perPageTypeBackgrounds.entries) {
      sb.writeln('- ${entry.key}: ${entry.value}');
    }
    sb.writeln();
    sb.writeln('### Fonts');
    sb.writeln('- Latin title font: ${fonts.latinTitleFont}');
    sb.writeln('- Body font: ${fonts.bodyFont}');
    sb.writeln('- Title size range: ${fonts.titleSizeRange}pt');
    sb.writeln('- Body size range: ${fonts.bodySizeRange}pt');
    sb.writeln();
    sb.writeln('### Layout Variants');
    for (final entry in layoutVariants.entries) {
      sb.writeln('${entry.key}:');
      for (final variant in entry.value) {
        sb.writeln('  - ${variant.id}: ${variant.description}');
      }
    }
    sb.writeln();
    sb.writeln('### Overall Style');
    sb.writeln(overallStyle);
    return sb.toString();
  }
}

/// Result of style skill generation.
class StyleSkillResult {
  final bool ok;
  final StyleSkill? skill;
  final String? error;

  const StyleSkillResult({
    required this.ok,
    this.skill,
    this.error,
  });
}

/// Style Skill generator (GenOffice-inspired).
class StyleSkillGenerator {
  /// Generate a complete Style Skill for a presentation topic.
  ///
  /// This mirrors GenOffice's `generateStyleSkill` in AiPanel.tsx:
  /// - Dedicated LLM call focused only on visual style
  /// - Outputs structured color rules, font rules, layout variants
  /// - Promotes style from "outline side-product" to "dedicated deliverable"
  static Future<StyleSkillResult> generate({
    required String topic,
    String? styleHint,
    String? questionnaire,
  }) async {
    debugPrint('🎨 [StyleSkill] Generating for topic: $topic');

    final systemPrompt = _buildSystemPrompt();
    final userPrompt = _buildUserPrompt(
      topic: topic,
      styleHint: styleHint,
      questionnaire: questionnaire,
    );

    // Combine prompts - system prompt first to establish constraints,
    // then user prompt with the specific request
    final result = await AiGenerationService.generateClassified(
      prompt: '$systemPrompt\n\n$userPrompt',
    );

    if (!result.ok || result.text == null) {
      debugPrint('❌ [StyleSkill] Generation failed: ${result.error}');
      return StyleSkillResult(ok: false, error: result.displayMessage);
    }

    // Parse the response as JSON
    try {
      final raw = result.text!;
      final json = _extractJson(raw);
      if (json == null) {
        debugPrint('❌ [StyleSkill] Failed to extract JSON from response');
        return const StyleSkillResult(ok: false, error: 'Invalid style skill format');
      }

      final skill = StyleSkill.fromJson(json);
      debugPrint('✅ [StyleSkill] Generated successfully');
      debugPrint('🎨 [StyleSkill] Colors: ${skill.colors.primaryAccent}, ${skill.colors.secondaryAccent}');
      debugPrint('🎨 [StyleSkill] Layout variants: ${skill.layoutVariants.length} types');

      return StyleSkillResult(ok: true, skill: skill);
    } catch (e) {
      debugPrint('❌ [StyleSkill] Parse error: $e');
      return StyleSkillResult(ok: false, error: 'Parse error: $e');
    }
  }

  /// Extract JSON from AI response (handles markdown fences, extra text).
  static Map<String, dynamic>? _extractJson(String raw) {
    // Try to find JSON object
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
    if (jsonMatch == null) return null;

    try {
      return jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Build system prompt for style skill generation.
  static String _buildSystemPrompt() {
    return '''You are a professional deck visual designer. Given the presentation topic and style preferences, produce a complete Style Skill (visual style guide).

Output strictly in JSON format, no explanations/markdown/code fences.

## Required JSON Structure

{
  "colors": {
    "mainBackground": "#RRGGBB",
    "perPageTypeBackgrounds": {
      "cover": "#RRGGBB",
      "content": "#RRGGBB",
      "data": "#RRGGBB",
      "closing": "#RRGGBB"
    },
    "mainTextColor": "#RRGGBB",
    "primaryAccent": "#RRGGBB",
    "secondaryAccent": "#RRGGBB",
    "cardBackground": "#RRGGBB",
    "borderColor": "#RRGGBB (optional)"
  },
  "fonts": {
    "latinTitleFont": "Font Name",
    "bodyFont": "Font Name",
    "titleSizeRange": "32-48",
    "bodySizeRange": "12-15"
  },
  "layoutVariants": {
    "cover": [
      {"id": "cover_typography_hero", "name": "Typography Hero", "description": "Huge pure typography"},
      {"id": "cover_dark_minimal", "name": "Dark Minimal", "description": "Dark background, centered large title"}
    ],
    "content": [
      {"id": "left_text_right_image", "name": "Left Text Right Image", "description": "Text left, image right"},
      {"id": "three_column_cards", "name": "Three Column Cards", "description": "3 parallel points in cards"}
    ],
    "data": [
      {"id": "kpi_cards_row", "name": "KPI Cards Row", "description": "Horizontal KPI cards"},
      {"id": "chart_with_insight", "name": "Chart with Insight", "description": "Chart left + insight right"}
    ],
    "closing": [
      {"id": "closing_cta", "name": "Closing CTA", "description": "Centered title + contact info"}
    ]
  },
  "overallStyle": "One sentence describing the overall design language"
}

## Color Rules

1. Main background: pick based on topic mood (dark for serious/tech, light for casual/creative)
2. Per-page-type backgrounds: content pages share one background; cover/closing can differ
3. Main text color: must have sufficient contrast with main background (WCAG AA)
4. Primary accent: ONE color for the whole deck
5. Secondary accent: ONE complementary color for the whole deck
6. Card background: slightly different from main background for depth
7. Border color: optional, subtle

## Font Rules

1. Latin title font: pick from DM Sans, Inter, Poppins, Montserrat, or similar
2. Body font: pick from Inter, DM Sans, or similar
3. Title size range: 32-48pt for titles
4. Body size range: 12-15pt for body text

## Layout Variants

Provide at least 2 variants per page type:

### Cover (6 variants)
- cover_typography_hero: Huge pure typography
- cover_dark_minimal: Dark background, centered large title
- cover_split_color: Side-by-side color blocks
- cover_full_image_overlay: Full-bleed photo + dark overlay
- cover_magazine: Magazine-style large title + partial imagery
- cover_split_image: Text left, image right

### Content (6 variants)
- left_text_right_image: Text left, image right
- three_column_cards: 3 parallel points in cards
- hero_big_number: Key number as hero element
- two_column_comparison: Comparison layout
- timeline_horizontal: Horizontal timeline
- full_image_text_overlay: Full image with text overlay

### Data (3 variants)
- kpi_cards_row: Horizontal KPI cards
- chart_with_insight: Chart left + insight right
- two_by_two_grid: 2x2 quadrants

### Closing (2 variants)
- closing_cta: Centered title + contact info
- closing_thank_you: Full-bleed thank-you page

## Overall Style

One sentence describing the overall design language (e.g., "Modern minimal with bold typography and deep purple accents").''';
  }

  /// Build user prompt for style skill generation.
  static String _buildUserPrompt({
    required String topic,
    String? styleHint,
    String? questionnaire,
  }) {
    final sb = StringBuffer();
    sb.write('Topic and style preferences: $topic');
    if (styleHint != null && styleHint.isNotEmpty) {
      sb.write('\nStyle preference: $styleHint');
    }
    if (questionnaire != null && questionnaire.isNotEmpty) {
      sb.write('\nUser questionnaire answers: $questionnaire');
    }
    sb.write('\n\nCRITICAL: Output ONLY the raw JSON object matching the required structure above. NO markdown, NO code fences, NO explanations. Just the JSON.');
    return sb.toString();
  }
}
