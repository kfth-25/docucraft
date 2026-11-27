// DocuCraft — Template Registry V2
// Sistem template 4 lapis: Brand → Style → Layout → Deck
// Template berbasis SVG dengan slot binding untuk AI generation
// @see skills/workflows/template-system.md
// @see skills/SKILL.md

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// 4-Layer Template Hierarchy
class BrandTemplate {
  final String id;
  final String name;
  final Map<String, String> colors;      // accent1, dk1, lt1, etc.
  final Map<String, String> fonts;       // major, minor
  final Map<String, String> effects;     // shadow, glow, etc.

  BrandTemplate({
    required this.id,
    required this.name,
    required this.colors,
    required this.fonts,
    required this.effects,
  });

  factory BrandTemplate.fromJson(Map<String, dynamic> json) {
    return BrandTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      colors: Map<String, String>.from(json['colors'] ?? {}),
      fonts: Map<String, String>.from(json['fonts'] ?? {}),
      effects: Map<String, String>.from(json['effects'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colors': colors,
    'fonts': fonts,
    'effects': effects,
  };
}

class StyleTemplate {
  final String id;
  final String name;
  final String description;
  final String brandId;           // References BrandTemplate
  final Map<String, dynamic> cssVars;  // CSS custom properties

  StyleTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.brandId,
    required this.cssVars,
  });

  factory StyleTemplate.fromJson(Map<String, dynamic> json) {
    return StyleTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      brandId: json['brandId'] as String,
      cssVars: Map<String, dynamic>.from(json['cssVars'] ?? {}),
    );
  }
}

class LayoutTemplate {
  final String id;
  final String name;
  final String description;
  final String styleId;           // References StyleTemplate
  final String svgTemplate;       // SVG template with slots
  final List<TemplateSlot> slots;

  LayoutTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.styleId,
    required this.svgTemplate,
    required this.slots,
  });

  factory LayoutTemplate.fromJson(Map<String, dynamic> json) {
    return LayoutTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      styleId: json['styleId'] as String,
      svgTemplate: json['svgTemplate'] as String,
      slots: (json['slots'] as List).map((s) => TemplateSlot.fromJson(s)).toList(),
    );
  }
}

class TemplateSlot {
  final String id;
  final String type;           // text, image, chart, table, media
  final String label;
  final bool required;
  final Map<String, dynamic> defaultValue;

  TemplateSlot({
    required this.id,
    required this.type,
    required this.label,
    this.required = false,
    this.defaultValue = const {},
  });

  factory TemplateSlot.fromJson(Map<String, dynamic> json) {
    return TemplateSlot(
      id: json['id'] as String,
      type: json['type'] as String,
      label: json['label'] as String,
      required: json['required'] as bool? ?? false,
      defaultValue: Map<String, dynamic>.from(json['defaultValue'] ?? {}),
    );
  }
}

class DeckTemplate {
  final String id;
  final String name;
  final String description;
  final String layoutId;        // References LayoutTemplate
  final String styleId;         // References StyleTemplate
  final String brandId;         // References BrandTemplate
  final List<String> slideLayoutIds;  // Ordered list of layout IDs for slides

  DeckTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.layoutId,
    required this.styleId,
    required this.brandId,
    required this.slideLayoutIds,
  });

  factory DeckTemplate.fromJson(Map<String, dynamic> json) {
    return DeckTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      layoutId: json['layoutId'] as String,
      styleId: json['styleId'] as String,
      brandId: json['brandId'] as String,
      slideLayoutIds: List<String>.from(json['slideLayoutIds'] ?? []),
    );
  }
}

/// Resolved template with all inheritance applied
class ResolvedTemplate {
  final BrandTemplate brand;
  final StyleTemplate style;
  final LayoutTemplate layout;
  final DeckTemplate deck;

  ResolvedTemplate({
    required this.brand,
    required this.style,
    required this.layout,
    required this.deck,
  });

  /// Get combined CSS variables (brand → style → layout)
  Map<String, String> get cssVars {
    final vars = <String, String>{};
    vars.addAll(brand.colors.map((k, v) => MapEntry('--theme-$k', v)));
    vars.addAll(brand.fonts.map((k, v) => MapEntry('--theme-font-$k', v)));
    vars.addAll(style.cssVars.map((k, v) => MapEntry(k, v.toString())));
    return vars;
  }

  /// Get theme color mapping for SVG
  Map<String, String> get themeColorMap {
    return {
      'accent1': brand.colors['accent1'] ?? '#6366F1',
      'dk1': brand.colors['dk1'] ?? '#1A1A25',
      'lt1': brand.colors['lt1'] ?? '#FFFFFF',
      'accent2': brand.colors['accent2'] ?? '#A855F7',
      'accent3': brand.colors['accent3'] ?? '#10B981',
    };
  }

  /// Get theme font mapping for SVG
  Map<String, String> get themeFontMap {
    return {
      'major': brand.fonts['major'] ?? 'DM Sans',
      'minor': brand.fonts['minor'] ?? 'DM Sans',
    };
  }
}

/// Template Registry V2 — Loads and manages 4-layer templates
class TemplateRegistryV2 {
  static final TemplateRegistryV2 _instance = TemplateRegistryV2._();
  factory TemplateRegistryV2() => _instance;
  TemplateRegistryV2._();

  final Map<String, BrandTemplate> _brands = {};
  final Map<String, StyleTemplate> _styles = {};
  final Map<String, LayoutTemplate> _layouts = {};
  final Map<String, DeckTemplate> _decks = {};

  // Index files for discovery
  static const String _brandsIndex = 'assets/templates/brands/brands_index.json';
  static const String _stylesIndex = 'assets/templates/styles/styles_index.json';
  static const String _layoutsIndex = 'assets/templates/layouts/layouts_index.json';
  static const String _decksIndex = 'assets/templates/decks/decks_index.json';

  bool _initialized = false;

  /// Initialize registry by loading all index files
  Future<void> initialize() async {
    if (_initialized) return;

    await _loadIndex(_brandsIndex, (json) => _brands[json['id']] = BrandTemplate.fromJson(json));
    await _loadIndex(_stylesIndex, (json) => _styles[json['id']] = StyleTemplate.fromJson(json));
    await _loadIndex(_layoutsIndex, (json) => _layouts[json['id']] = LayoutTemplate.fromJson(json));
    await _loadIndex(_decksIndex, (json) => _decks[json['id']] = DeckTemplate.fromJson(json));

    _initialized = true;
  }

  Future<void> _loadIndex(String path, void Function(Map<String, dynamic>) addItem) async {
    try {
      final content = await rootBundle.loadString(path);
      final index = jsonDecode(content) as Map<String, dynamic>;
      final items = index['items'] as List;
      for (final item in items) {
        addItem(item as Map<String, dynamic>);
      }
    } catch (e) {
      print('������ Failed to load template index $path: $e');
    }
  }

  // Getters
  BrandTemplate? getBrand(String id) => _brands[id];
  StyleTemplate? getStyle(String id) => _styles[id];
  LayoutTemplate? getLayout(String id) => _layouts[id];
  DeckTemplate? getDeck(String id) => _decks[id];

  List<BrandTemplate> get allBrands => _brands.values.toList();
  List<StyleTemplate> get allStyles => _styles.values.toList();
  List<LayoutTemplate> get allLayouts => _layouts.values.toList();
  List<DeckTemplate> get allDecks => _decks.values.toList();

  /// Resolve full template with inheritance cascade
  ResolvedTemplate resolve(String deckId) {
    final deck = _decks[deckId];
    if (deck == null) throw ArgumentError('Deck not found: $deckId');

    final layout = _layouts[deck.layoutId];
    if (layout == null) throw ArgumentError('Layout not found: ${deck.layoutId}');

    final style = _styles[deck.styleId] ?? _styles[layout.styleId];
    if (style == null) throw ArgumentError('Style not found: ${deck.styleId}');

    final brand = _brands[deck.brandId] ?? _brands[style.brandId];
    if (brand == null) throw ArgumentError('Brand not found: ${deck.brandId}');

    return ResolvedTemplate(
      brand: brand,
      style: style,
      layout: layout,
      deck: deck,
    );
  }

  /// Bind template SVG with slot data
  String bindTemplateSvg(String layoutId, Map<String, dynamic> slots) {
    final layout = _layouts[layoutId];
    if (layout == null) {
      // Fallback to default template
      return _defaultTemplateSvg(layoutId, slots);
    }

    String svg = layout.svgTemplate;

    // Replace {{slot}} placeholders
    for (final entry in slots.entries) {
      final placeholder = '{{${entry.key}}}';
      final value = entry.value?.toString() ?? '';
      svg = svg.replaceAll(placeholder, _escapeXml(value));
    }

    // Handle chart data - inject into metadata
    if (slots.containsKey('chartData') || slots.containsKey('chart')) {
      final chartData = slots['chartData'] ?? slots['chart'];
      if (chartData is Map) {
        final jsonStr = _escapeXml(jsonEncode(chartData));
        svg = svg.replaceAllMapped(
          RegExp(r'<metadata[^>]*type="application/json"[^>]*>(.*?)</metadata>', dotAll: true),
          (match) => '<metadata type="application/json" data-pptx-kind="chart">$jsonStr</metadata>',
        );
      }
    }

    // Handle image URLs
    if (slots.containsKey('imageUrl') || slots.containsKey('image')) {
      final imageUrl = slots['imageUrl'] ?? slots['image'] ?? '';
      svg = svg.replaceAllMapped(
        RegExp(r'href="\{{2}imageUrl\}{2}"'),
        (match) => 'href="$imageUrl"',
      );
      svg = svg.replaceAllMapped(
        RegExp(r'href="\{{2}image\}{2}"'),
        (match) => 'href="$imageUrl"',
      );
    }

    return svg;
  }

  String _defaultTemplateSvg(String layoutId, Map<String, dynamic> slots) {
    // Minimal fallback template
    final title = slots['title'] ?? 'Slide Title';
    final paragraph = slots['paragraph'] ?? '';
    return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1280 720"
  data-pptx-layout="$layoutId" data-pptx-theme-color-primary="accent1" data-pptx-theme-font-major="major">
  <rect x="0" y="0" width="1280" height="720" fill="url(#bgGradient)" data-pptx-object="shape" data-pptx-prst="rect"/>
  <text x="96" y="180" data-pptx-slot="title" data-pptx-object="text" data-pptx-theme-font="major" data-pptx-theme-color="dk1" font-size="56" font-weight="bold">${_escapeXml(title)}</text>
  <text x="96" y="280" width="900" data-pptx-slot="paragraph" data-pptx-object="text" data-pptx-theme-font="minor" data-pptx-theme-color="tx1" font-size="20">${_escapeXml(paragraph)}</text>
  <g data-pptx-slot="chart" data-pptx-object="chart" data-pptx-replace-with="chart">
    <metadata type="application/json" data-pptx-kind="chart">{"type":"bar","data":{}}</metadata>
    <rect x="96" y="400" width="500" height="250" fill="#F0F0F0"/>
    <text x="346" y="525" text-anchor="middle" fill="#999">[Chart: {{chartTitle}}]</text>
  </g>
  <image x="800" y="180" width="400" height="300" data-pptx-slot="image" data-pptx-object="image" href="{{imageUrl}}"/>
  <defs>
    <linearGradient id="bgGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="var(--theme-accent1)"/>
      <stop offset="100%" stop-color="var(--theme-dk1)"/>
    </linearGradient>
  </defs>
</svg>''';
  }

  String _escapeXml(String text) {
    return text
      .replaceAll('&', '&')
      .replaceAll('<', '<')
      .replaceAll('>', '>')
      .replaceAll('"', '"')
      .replaceAll("'", '&apos;');
  }
}