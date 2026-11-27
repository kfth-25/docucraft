# AI Generation Service

**File:** `lib/services/ai_generation.dart`
**Role:** AI API Communication
**Step:** Step 4-6 (Strategist → Executor)

## Overview
Service untuk berkomunikasi dengai AI (via 9router) untuk generate SVG dari prompt dan coretan. Mendukung vision AI untuk melihat gambar coretan.

## Class Hierarchy

```
AiGenerationService (Static Class)
├── sketchToDesignSvg()     - Generate dari coretan (vision AI)
├── generateFromSketchSvg() - Fallback dari stroke data
├── generateFromPrompt()    - Generate dari teks saja
├── generateImage()         - Generate image (stub)
├── searchStockImages()     - Search images (stub)
├── generateOutline()       - Generate outline (stub)
└── generateSingleSlide()   - Generate single slide (stub)
```

## Configuration

```dart
class AiConfig {
  static const String baseUrl = 'http://127.0.0.1:20128/v1';
  static const String fastModel = 'Open-Code';
  static const String qualityModel = 'kc/nvidia/nemotron-3-ultra-550b-a55b:free';
  static const String freeModel = 'oc/laguna-s-2.1-free';
  static const String longcatModel = 'kc/meituan/longcat-2.0-free';
  static const String visionModel = 'gc/gemini-3-flash-preview';
  
  // Fallback chain
  static const List<String> fallbackModels = [
    visionModel,    // Gemini Flash (vision)
    freeModel,      // Laguna (vision)
    qualityModel,   // Nemotron (quality)
    fastModel,      // Open-Code (fast)
    longcatModel,   // Longcat (reasoning)
  ];
}
```

## Rate Limiter

```dart
class _RateLimiter {
  static const int _maxRequestsPerMinute = 10;
  
  Duration get waitTime {
    // Remove requests older than 1 minute
    // If >= 10 requests, wait until oldest expires
  }
  
  void recordRequest() {
    _requestTimes.add(DateTime.now());
  }
}
```

## Public API

### sketchToDesignSvg()
```dart
static Future<SvgGenerateResult> sketchToDesignSvg(
  Uint8List sketchPng,        // Gambar coretan (PNG)
  String userPrompt,          // Instruksi user
  {
    Slide? currentSlide,      // Slide saat ini (optional)
    String? model,            // Model AI (optional)
    int canvasWidth = 1920,   // Lebar canvas
    int canvasHeight = 1080,  // Tinggi canvas
    Map<String, dynamic>? sketchBounds,  // Bounds coretan
  }
)
```

### generateFromPrompt()
```dart
static Future<SvgGenerateResult> generateFromPrompt(
  String prompt,              // Prompt teks
  {
    Slide? currentSlide,      // Slide saat ini (optional)
    String? model,            // Model AI (optional)
  }
)
```

### generateFromSketchSvg()
```dart
static Future<SvgGenerateResult> generateFromSketchSvg(
  Map<String, dynamic> sketchData,  // Data stroke JSON
  String prompt,                    // Instruksi user
  {
    Slide? currentSlide,
    String? model,
    int canvasWidth = 1920,
    int canvasHeight = 1080,
  }
)
```

## SvgGenerateResult

```dart
class SvgGenerateResult {
  final bool success;        // Berhasil atau tidak
  final String? svg;         // SVG string (jika berhasil)
  final String? error;       // Error message (jika gagal)
  final String? question;    // Pertanyaan AI (jika prompt ambigu)
}
```

## System Prompt (Step 4-6)

```
Anda adalah AI designer presentasi expert. User memberikan instruksi 
teks dan Anda harus membuat desain PRESENTASI yang MENARIK dan KOMPLEKS.

ATURAN UNTUK PROMPT AMBIGU:
Jika user memberikan prompt yang ambigu, MAKA:
1. TANYAKAN user terlebih dahulu
2. JANGAN langsung generate SVG
3. Format jawaban: "PERTANYAAN: [pertanyaan untuk user]"

ATURAN UNTUK KONTEN TEKS:
- TEKS HARUS BERISI KONTEN NYATA tentang topik yang diminta!
- JANGAN gunakan placeholder seperti "Judul Here"
- Gunakan bahasa yang sesuai dengan prompt user
```

## Fallback Chain

```
1. Gemini Flash (vision) → Coba pertama
2. Laguna (vision)       → Jika Gemini gagal
3. Nemotron (quality)    → Jika Laguna gagal
4. Open-Code (fast)       → Jika Nemotron gagal
5. Longcat (reasoning)    → Jika Open-Code gagal
```

## Error Handling

| Error | Action |
|-------|--------|
| Model timeout | Retry dengan model berikutnya |
| CORS error | Stop, tidak retry |
| Non-SVG response | Retry dengan model berikutnya |
| PERTANYAAN: response | Return sebagai `result.question` |

## Related Files
- `svg_to_slide_elements.dart` - Parse SVG output
- `quality_check.dart` - Validasi hasil
- `ai_chat_panel.dart` - UI integration
- `sketch_ai_panel.dart` - Sketch UI integration
