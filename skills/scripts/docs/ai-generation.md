# AI Generation Script

**File:** `lib/services/ai_generation.dart`

## Overview
Service untuk berkomunikasi dengan AI via 9router API.

## Commands

### Generate from prompt
```dart
final result = await AiGenerationService.generateFromPrompt(
  'Buat presentasi tentang AI',
  model: 'oc/laguna-s-2.1-free',
);
```

### Generate from sketch
```dart
final result = await AiGenerationService.sketchToDesignSvg(
  pngBytes,
  'Buat desain profesional',
  sketchBounds: {'minX': 50, 'maxX': 200, 'minY': 50, 'maxY': 150},
);
```

### Analyze sketch
```dart
final result = await AiGenerationService.analyzeSketch(
  pngBytes,
  basicAnalysis: analysis,
);
```

## Configuration
| Setting | Value |
|---------|-------|
| Base URL | `http://127.0.0.1:20128/v1` |
| Max Tokens | 8192 |
| Rate Limit | 10 requests/minute |

## Fallback Chain
```
1. gc/gemini-3-flash-preview (vision)
2. oc/laguna-s-2.1-free (vision)
3. kc/nvidia/nemotron-3-ultra-550b-a55f:free (quality)
4. Open-Code (fast)
5. kc/meituan/longcat-2.0-free (reasoning)
```
