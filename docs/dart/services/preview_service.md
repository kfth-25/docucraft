# Preview Service

**File:** `lib/services/preview_service.dart`
**Role:** Preview & Diagnostics
**Step:** Step 6 (Executor Live Preview)

## Overview
Render slides untuk preview sebelum final export dan jalankan quality checks dengan diagnostics.

## Class Hierarchy

```
PreviewService (Static Class)
├── renderPreview(List<Slide> slides) → Future<PreviewResult>
├── autoFixAll(List<Slide> slides) → List<Slide>
└── getPreviewSummary(PreviewResult result) → String

PreviewResult
├── state: PreviewState (enum)
├── slides: List<Slide>
├── qualityResults: List<QualityCheckResult>
├── error: String?
├── hasIssues: bool (computed)
└── totalIssues: int (computed)

PreviewState (enum)
├── idle
├── rendering
├── ready
└── error
```

## Public API

### renderPreview()
```dart
final result = await PreviewService.renderPreview(slides);
if (result.state == PreviewState.ready) {
  if (result.hasIssues) {
    print('Issues: ${result.totalIssues}');
  } else {
    print('All slides passed!');
  }
}
```

### autoFixAll()
```dart
final fixedSlides = PreviewService.autoFixAll(slides);
// Returns new list with all issues fixed
```

### getPreviewSummary()
```dart
final summary = PreviewService.getPreviewSummary(result);
print(summary);
```

## Preview Summary Format
```
📊 Preview Summary:
• Total slides: 3
• Slides with issues: 1

⚠️ Issues found:
  Slide 2: 2 issues
    - Element keluar kanan canvas: x=1800, width=200
    - Teks terlalu kecil: 12px (min 16px)
```

## Quality Check Integration
```dart
// In renderPreview()
for (final slide in slides) {
  final qc = QualityChecker.check(slide.elements);
  qualityResults.add(qc);
}
```

## Auto-Fix Integration
```dart
// In autoFixAll()
for (final slide in slides) {
  final qc = QualityChecker.check(slide.elements);
  if (!qc.passed) {
    final fixedElements = QualityChecker.autoFix(slide.elements, qc);
    // Create new slide with fixed elements
  }
}
```

## State Flow
```
idle → rendering → ready
                 → error
```

## Related Files
- `quality_check.dart` - Quality validation
- `slide.dart` - Slide model
- `ai_chat_panel.dart` - UI integration
- `sketch_ai_panel.dart` - Sketch UI integration
