# Quality Check Service

**File:** `lib/services/quality_check.dart`
**Role:** Quality Validation & Auto-Fix
**Step:** Step 7 (Quality Check + Export)

## Overview
Validasi desain SVG setelah AI generate dan auto-fix untuk memastikan elemen dalam canvas yang benar.

## Class Hierarchy

```
QualityChecker (Static Class)
├── check(List<SlideElement> elements) → QualityCheckResult
└── autoFix(List<SlideElement> elements, QualityCheckResult check) → List<SlideElement>

QualityCheckResult
├── passed: bool
├── issues: List<String>
└── fixes: List<String>
```

## Quality Checks

### 1. Canvas Boundary Check
| Rule | Severity | Auto-Fix |
|------|----------|----------|
| x + width > 1920 | 🔴 Blocking | ✅ Reposition to `1920 - width - 20` |
| y + height > 1080 | 🔴 Blocking | ✅ Reposition to `1080 - height - 20` |
| x < 0 | 🔴 Blocking | ✅ Set x = 10 |
| y < 0 | 🔴 Blocking | ✅ Set y = 10 |

### 2. Text Readability Check
| Rule | Severity | Auto-Fix |
|------|----------|----------|
| fontSize < 16px | 🟡 Warning | ✅ Increase to 16px |

### 3. Element Count Check
| Rule | Severity | Auto-Fix |
|------|----------|----------|
| < 4 elements | 🟡 Warning | ❌ Manual fix |
| > 15 elements | 🟡 Warning | ❌ Manual fix |

## Constants

```dart
static const double canvasWidth = 1920;
static const double canvasHeight = 1080;
static const double minFontSize = 16;
static const int minElements = 4;
static const int maxElements = 15;
```

## Public API

### check()
```dart
final qc = QualityChecker.check(slide.elements);
if (!qc.passed) {
  print('Issues: ${qc.issues}');
}
```

### autoFix()
```dart
final fixedElements = QualityChecker.autoFix(elements, qc);
// Returns new list with fixed elements
```

## Auto-Fix Logic

```dart
// Fix canvas boundary
if (newEl.x + newEl.width > canvasWidth) {
  newEl.x = canvasWidth - newEl.width - 20;
}
if (newEl.y + newEl.height > canvasHeight) {
  newEl.y = canvasHeight - newEl.height - 20;
}
if (newEl.x < 0) newEl.x = 10;
if (newEl.y < 0) newEl.y = 10;

// Fix font size
if (newEl.type == ElementType.text && newEl.textStyle != null) {
  if (newEl.textStyle!.fontSize < minFontSize) {
    newEl.textStyle!.fontSize = minFontSize;
  }
}
```

## Integration

### AI Chat Panel
```dart
// In AiChatPanel._processPrompt()
var elements = SvgToSlideElements.parse(result.svg!);
final qc = QualityChecker.check(elements);
if (!qc.passed) {
  elements = QualityChecker.autoFix(elements, qc);
}
```

### Sketch AI Panel
```dart
// In SketchAiPanel._generateDesign()
var elements = SvgToSlideElements.parse(result.svg!);
final qc = QualityChecker.check(elements);
if (!qc.passed) {
  elements = QualityChecker.autoFix(elements, qc);
}
```

## Related Files
- `ai_generation.dart` - Generate SVG
- `svg_to_slide_elements.dart` - Parse SVG
- `preview_service.dart` - Preview integration
