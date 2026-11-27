# SVG to SlideElements Parser

**File:** `lib/services/svg_to_slide_elements.dart`
**Role:** SVG Parser
**Step:** Step 6-7 (Executor → Export)

## Overview
Parse SVG string (dari AI) dan convert ke SlideElement objects untuk rendering di Flutter.

## Class Hierarchy

```
SvgToSlideElements (Static Class)
└── parse(String svg, {
      int sourceCanvasWidth = 380,
      int sourceCanvasHeight = 214,
      int targetCanvasWidth = 1920,
      int targetCanvasHeight = 1080,
    }) → List<SlideElement>
```

## Supported SVG Elements

| SVG Element | SlideElement Type | Parser |
|-------------|-------------------|--------|
| `<text>` | `ElementType.text` | `_parseText()` |
| `<rect>` | `ElementType.shape` | `_parseRect()` |
| `<ellipse>` | `ElementType.shape` (circle) | `_parseEllipse()` |
| `<polygon>` | `ElementType.shape` (polygon) | `_parsePolygon()` |
| `<image>` | `ElementType.image` | `_parseImage()` |

## Scaling Logic

```dart
final scaleX = targetCanvasWidth / sourceCanvasWidth;
final scaleY = targetCanvasHeight / sourceCanvasHeight;

// Apply to all coordinates
x = x * scaleX;
y = y * scaleX;
width = width * scaleX;
height = height * scaleY;
fontSize = fontSize * scaleX;
```

## Default Scale
| Source | Target | Scale |
|--------|--------|-------|
| 380×214 | 1920×1080 | 5.05x |
| 1920×1080 | 1920×1080 | 1.0x |

## Text Parsing

### Attributes Extracted
| SVG Attribute | SlideElement Field |
|---------------|-------------------|
| `x` | `x` (scaled) |
| `y` | `y` (scaled) |
| `font-size` | `textStyle.fontSize` |
| `fill` | `textStyle.colorValue` |
| `font-weight` | `textStyle.fontWeight` |
| `text-anchor` | `textStyle.textAlign` |
| Content | `content` |

### Text Alignment Mapping
| SVG `text-anchor` | Flutter `textAlign` |
|-------------------|---------------------|
| `start` | `TextAlign.left` |
| `middle` | `TextAlign.center` |
| `end` | `TextAlign.right` |

## Shape Parsing

### Rect
```xml
<rect x="100" y="50" width="200" height="150" fill="#6366F1" rx="12"/>
```
→ `SlideElement(type: shape, shapeType: rect, borderRadius: 12)`

### Ellipse
```xml
<ellipse cx="200" cy="150" rx="50" ry="50" fill="#EC4899"/>
```
→ `SlideElement(type: shape, shapeType: circle, x: cx-rx, y: cy-ry)`

### Polygon
```xml
<polygon points="100,50 200,50 150,150" fill="#10B981"/>
```
→ `SlideElement(type: shape, shapeType: polygon)`

## Background Detection
Rect with full canvas size (x=0, y=0, width=1920, height=1080) is treated as background and skipped.

## Image Parsing
```xml
<image x="100" y="100" width="400" height="300" href="https://..."/>
```
→ `SlideElement(type: image, imageStyle: ImageStyleData(src: href))`

## Color Parsing
```dart
static int _parseColor(String hex) {
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 6) hex = 'FF$hex';  // Add alpha
  return int.tryParse(hex, radix: 16) ?? 0xFFFFFFFF;
}
```

## Public API

### Basic Parse
```dart
final elements = SvgToSlideElements.parse(svgString);
```

### Parse with Scaling (AI Coret)
```dart
final elements = SvgToSlideElements.parse(
  svgString,
  sourceCanvasWidth: 380,
  sourceCanvasHeight: 214,
);
```

## Debug Logging
```dart
debugPrint('🔍 [SVG Parser] Input SVG length: ${svg.length}');
debugPrint('🔍 [SVG Parser] Scale: ${scaleX.toStringAsFixed(2)}x, ${scaleY.toStringAsFixed(2)}y');
debugPrint('🔍 [SVG Parser] Found ${textMatches.length} <text> elements');
debugPrint('🔍 [SVG Parser] Total elements parsed: ${elements.length}');
```

## Related Files
- `ai_generation.dart` - Generate SVG
- `quality_check.dart` - Validate output
- `slide.dart` - SlideElement model
