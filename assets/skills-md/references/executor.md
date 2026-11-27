# Executor Role (DocuCraft)

**Pipeline Position**: Step 6 (setelah strategist, sebelum export)
**Platform**: Flutter/Dart
**Entry Point**: `lib/services/ai_generation.dart`

## Tugas
- Generate SVG via AI (dengan fallback chain)
- Parse SVG ke SlideElement (dengan scaling)
- Quality check + auto-fix
- Add ke slide via SlideProvider

## Implementation

**Files:**
- `lib/services/ai_generation.dart` - AI generation + fallback
- `lib/services/svg_to_slide_elements.dart` - SVG parser + scaling
- `lib/services/quality_check.dart` - Quality validation + auto-fix

## Responsibilities

### 1. Generate SVG
```dart
final result = await AiGenerationService.generateFromPrompt(
  prompt,
  currentSlide: provider.currentSlide,
  model: _selectedModel,
);
```

### 2. Parse SVG
```dart
if (result.success && result.svg != null) {
  var elements = SvgToSlideElements.parse(result.svg!);
}
```

### 3. Quality Check
```dart
final qc = QualityChecker.check(elements);
if (!qc.passed) {
  elements = QualityChecker.autoFix(elements, qc);
}
```

### 4. Add to Slide
```dart
currentSlide.elements.addAll(elements);
provider.notifyListeners();
```

## Error Handling
| Error | Recovery |
|-------|----------|
| AI timeout | Retry with fallback model |
| SVG parse error | Retry generation |
| QC failed | Auto-fix then retry |
| Empty result | Ask user for more detail |

## Related Files
- `references/strategist.md` - Previous role
- `lib/widgets/ai_chat_panel.dart` - UI integration
