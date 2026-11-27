# Template Suggestion

**File:** `lib/models/template_suggestion.dart`
**Role:** Template Recommendation System
**Step:** Step 3 (Template Candidate Preparation)

## Overview
Template suggestion system that recommends templates based on user prompt keywords using tag-based scoring.

## Class Hierarchy

```
TemplateSuggestion
├── id: String
├── name: String
├── description: String
├── colors: List<String>
├── style: String
└── tags: List<String>

TemplateSuggestions (Static Class)
├── all: List<TemplateSuggestion> (8 templates)
└── suggest(String prompt): List<TemplateSuggestion>
```

## Available Templates

| ID | Name | Colors | Style | Tags |
|----|------|--------|-------|------|
| tech-modern | Tech Modern | #6366F1, #8B5CF6, #FFFFFF | futuristik | tech, ai, startup, digital, cyber, robot |
| minimal-clean | Minimal Clean | #FFFFFF, #F3F4F6, #1F2937 | minimalis | portfolio, pitch, clean, simple |
| corporate | Corporate Professional | #1E3A8A, #374151, #FFFFFF | formal | business, corporate, report, finance, company |
| creative | Creative Playful | #EC4899, #F59E0B, #FFFFFF | playful | marketing, event, creative, festival, party |
| dark-elegant | Dark Elegant | #0F172A, #D4AF37, #FFFFFF | elegan | luxury, fashion, premium, gold |
| nature-green | Nature Green | #10B981, #059669, #FFFFFF | natural | nature, environment, green, eco, agriculture |
| education | Education | #3B82F6, #1D4ED8, #FFFFFF | educational | education, school, university, learning, student |
| healthcare | Healthcare | #06B6D4, #0891B2, #FFFFFF | medical | health, medical, hospital, doctor, pharmacy |

## Scoring Algorithm

```dart
int score = 0;
for (tag in template.tags) {
  if (prompt.contains(tag)) score += 3;  // Tag match = 3 points
}
if (prompt.contains(template.style)) score += 2;  // Style match = 2 points
if (prompt.contains(template.name.toLowerCase())) score += 2;  // Name match = 2 points
for (color in template.colors) {
  if (prompt.contains(color)) score += 1;  // Color match = 1 point
}
```

## Public API

### Get Suggestions
```dart
final suggestions = TemplateSuggestions.suggest('buat presentasi tentang AI');
// Returns: [Tech Modern, Minimal Clean, ...] (max 3)
```

### Get All Templates
```dart
final allTemplates = TemplateSuggestions.all;
// Returns all 8 templates
```

## Integration with AI Chat

```dart
// In AiChatPanel._processPrompt()
if (_messages.isEmpty) {
  final suggestions = TemplateSuggestions.suggest(prompt);
  if (suggestions.isNotEmpty) {
    final suggestionText = suggestions.take(3).map((s) =>
      '• **${s.name}** - ${s.description}'
    ).join('\n');

    return 'Berdasarkan prompt Anda, template yang cocok:\n'
        '$suggestionText\n\n'
        'Pilih template atau berikan detail lebih lanjut.';
  }
}
```

## Color Palettes

| Palette | Primary | Secondary | Accent |
|---------|---------|-----------|--------|
| Tech Modern | #6366F1 (Indigo) | #8B5CF6 (Violet) | #FFFFFF (White) |
| Minimal Clean | #FFFFFF (White) | #F3F4F6 (Gray 100) | #1F2937 (Gray 800) |
| Corporate | #1E3A8A (Blue 800) | #374151 (Gray 700) | #FFFFFF (White) |
| Creative | #EC4899 (Pink) | #F59E0B (Amber) | #FFFFFF (White) |
| Dark Elegant | #0F172A (Slate 900) | #D4AF37 (Gold) | #FFFFFF (White) |
| Nature Green | #10B981 (Emerald) | #059669 (Emerald 600) | #FFFFFF (White) |
| Education | #3B82F6 (Blue) | #1D4ED8 (Blue 700) | #FFFFFF (White) |
| Healthcare | #06B6D4 (Cyan) | #0891B2 (Cyan 600) | #FFFFFF (White) |

## Related Files
- `template_registry_v2.dart` - Full template system
- `template_widget_registry.dart` - Widget builders
- `ai_chat_panel.dart` - Integration point
