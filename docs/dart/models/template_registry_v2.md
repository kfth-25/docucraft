# Template Registry V2

**File:** `lib/models/template_registry_v2.dart`
**Role:** Template System
**Step:** Step 3 (Template Candidate Preparation)

## Overview
4-layer template system: Brand → Style → Layout → Deck. SVG-based templates with slot binding for AI generation.

## Class Hierarchy

```
TemplateRegistryV2 (Singleton)
├── _brands: Map<String, BrandTemplate>
├── _styles: Map<String, StyleTemplate>
├── _layouts: Map<String, LayoutTemplate>
└── _decks: Map<String, DeckTemplate>
```

## BrandTemplate

```
BrandTemplate
├── id: String
├── name: String
├── colors: Map<String, String> (accent1, dk1, lt1, dll)
├── fonts: Map<String, String> (major, minor)
└── effects: Map<String, String> (shadow, glow)
```

## StyleTemplate

```
StyleTemplate
├── id: String
├── name: String
├── description: String
├── brandId: String (references BrandTemplate)
└── cssVars: Map<String, dynamic>
```

## LayoutTemplate

```
LayoutTemplate
├── id: String
├── name: String
├── description: String
├── styleId: String (references StyleTemplate)
├── svgTemplate: String (SVG with slots)
└── slots: List<TemplateSlot>
```

## TemplateSlot

```
TemplateSlot
├── id: String
├── type: String (text, image, chart, table, media)
├── label: String
├── required: bool
└── defaultValue: Map<String, dynamic>
```

## DeckTemplate

```
DeckTemplate
├── id: String
├── name: String
├── description: String
├── layoutId: String (references LayoutTemplate)
├── styleId: String (references StyleTemplate)
├── brandId: String (references BrandTemplate)
└── slideLayoutIds: List<String>
```

## ResolvedTemplate

```
ResolvedTemplate (inheritance applied)
├── brand: BrandTemplate
├── style: StyleTemplate
├── layout: LayoutTemplate
└── deck: DeckTemplate

Methods:
├── cssVars: Map<String, String> (combined)
├── themeColorMap: Map<String, String>
└── themeFontMap: Map<String, String>
```

## Public API

### Initialize
```dart
final registry = TemplateRegistryV2();
await registry.initialize();
```

### Get Template
```dart
final brand = registry.getBrand('brand-id');
final style = registry.getStyle('style-id');
final layout = registry.getLayout('layout-id');
final deck = registry.getDeck('deck-id');
```

### Resolve Template
```dart
final resolved = registry.resolve('deck-id');
// Returns fully resolved template with inheritance
```

### Bind SVG Template
```dart
final svg = registry.bindTemplateSvg('layout-id', {
  'title': 'My Title',
  'paragraph': 'My Content',
});
```

## Index Files
| File | Path |
|------|------|
| Brands | `assets/templates/brands/brands_index.json` |
| Styles | `assets/templates/styles/styles_index.json` |
| Layouts | `assets/templates/layouts/layouts_index.json` |
| Decks | `assets/templates/decks/decks_index.json` |

## SVG Slot Binding

### Placeholders
```xml
<text data-pptx-slot="title">{{title}}</text>
<text data-pptx-slot="paragraph">{{paragraph}}</text>
```

### Chart Metadata
```xml
<g data-pptx-slot="chart" data-pptx-object="chart">
  <metadata type="application/json" data-pptx-kind="chart">
    {"type":"bar","data":{}}
  </metadata>
</g>
```

## Related Files
- `template_suggestion.dart` - Template recommendations
- `template_widget_registry.dart` - Widget builders
- `template_renderer.dart` - Template rendering
- `template_converter.dart` - Template conversion
