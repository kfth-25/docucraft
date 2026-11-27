# Quick Generate Profile (DocuCraft)

**Trigger**: Explicit "quick", "fast", "langsung", "cepat"
**Platform**: Flutter/Dart
**Entry Point**: `lib/widgets/ai_chat_panel.dart`

## Overview
Quick runtime tanpa interaksi user. AI memutuskan semua parameter dan langsung generate. Menggunakan AI model fallback chain untuk hasil optimal.

## Ciri
- No interaction / no confirmation gates
- No spec/lock
- AI decides everything
- Direct generate SVG → Export

## Pipeline
```
User Prompt → [Skip Step 3-4] → Generate SVG → QC → Export
```

## Implementation

```dart
// In AiChatPanel._processPrompt()
if (prompt.toLowerCase().contains('quick') || 
    prompt.toLowerCase().contains('fast')) {
  // Skip template suggestions
  // Skip lightweight gate
  // Direct generate
  final result = await AiGenerationService.generateFromPrompt(prompt);
  // ... handle result
}
```

## When to Use
| Scenario | Action |
|----------|--------|
| User says "quick generate" | Activate Quick |
| User says "langsung buat" | Activate Quick |
| User says "cepat" | Activate Quick |
| Default request | Use Default runtime |

## Related Files
- `workflows/generate-presentation.md` - Default runtime
- `workflows/profiles/docucraft-sketch-to-design.md` - Sketch variant
