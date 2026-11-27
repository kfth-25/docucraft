# Sketch to Design Profile (DocuCraft)

**Trigger**: User menggambar coretan di canvas dan minta AI ubah jadi desain
**Platform**: Flutter/Dart
**Entry Point**: `lib/widgets/sketch_ai_panel.dart`

## Overview
Convert coretan tangan (sketch) menjadi desain profesional menggunakan vision AI. Mendukung analisis bounds coretan dan scaling otomatis ke slide design space.

## Pipeline
```
User draws on canvas (380×214)
    │
    ▼
Capture to PNG (DrawCanvas.captureToImage())
    │
    ▼
Analyze strokes locally (_analyzeStrokes)
    │
    ▼
Send to AI with image + bounds (sketchToDesignSvg)
    │
    ▼
AI generates SVG (380×214 coordinate space)
    │
    ▼
Parse SVG → Scale to 1920×1080 (5.05x)
    │
    ▼
Quality Check + Auto-fix
    │
    ▼
Add to slide + Clear canvas
```

## Implementation

**File:** `lib/widgets/sketch_ai_panel.dart`

```dart
// 1. Auto-analyze on panel open
Future<void> _autoAnalyze() async {
  final pngBytes = await state.captureToImage();
  final analysis = _analyzeStrokes(state.strokes);
  
  // 2. Send to AI for analysis
  final result = await AiGenerationService.analyzeSketch(
    pngBytes,
    basicAnalysis: analysis,
  );
  
  // 3. Display analysis in chat
  _addAiMessage(result.svg!);
}

// 4. User chat → generate design
Future<void> _generateDesign(String userPrompt) async {
  final pngBytes = await state.captureToImage();
  final sketchBounds = _analyzeStrokes(state.strokes);
  
  final result = await AiGenerationService.sketchToDesignSvg(
    pngBytes,
    userPrompt,
    sketchBounds: sketchBounds,
  );
  
  // 5. Parse and scale
  var elements = SvgToSlideElements.parse(
    result.svg!,
    sourceCanvasWidth: 380,
    sourceCanvasHeight: 214,
  );
  
  // 6. Quality check
  final qc = QualityChecker.check(elements);
  if (!qc.passed) {
    elements = QualityChecker.autoFix(elements, qc);
  }
  
  // 7. Add to slide
  currentSlide.elements.addAll(elements);
  state.clearAll();
}
```

## Stroke Analysis

```dart
Map<String, dynamic> _analyzeStrokes(List<dynamic> strokes) {
  double minX = double.infinity, minY = double.infinity;
  double maxX = 0, maxY = 0;
  
  for (final stroke in strokes) {
    for (final point in stroke.points) {
      minX = min(minX, point[0]);
      minY = min(minY, point[1]);
      maxX = max(maxX, point[0]);
      maxY = max(maxY, point[1]);
    }
  }
  
  return {
    'minX': minX,
    'minY': minY,
    'maxX': maxX,
    'maxY': maxY,
    'width': maxX - minX,
    'height': maxY - minY,
    'centerX': (minX + maxX) / 2,
    'centerY': (minY + maxY) / 2,
    'strokeCount': strokes.length,
  };
}
```

## Coordinate Scaling

| Source | Target | Scale |
|--------|--------|-------|
| 380×214 (canvas) | 1920×1080 (slide) | 5.05x |

## AI Prompt for Sketch

```
Berikut adalah coretan pengguna (PNG). Canvas size: 380×214.

KOORDINAT CORETAN USER (HARUS DI-GUNAKAN):
- Area coretan: x=50-200, y=50-150
- Lebar coretan: 150px, Tinggi coretan: 100px
- Posisi pusat: cx=125, cy=100

BUAT ELEMEN SVG DI AREA INI!
```

## Related Files
- `lib/widgets/sketch_ai_panel.dart` - Main UI
- `lib/widgets/draw_canvas.dart` - Drawing canvas
- `lib/services/ai_generation.dart` - AI service
