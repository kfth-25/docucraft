# Import Service

**File:** `lib/services/import/import_service.dart`
**Role:** Input Processing
**Step:** Step 1 (Source Content Processing)

## Overview
Handle berbagai tipe input dari user (teks, gambar, file) dan convert ke format standar `SourceContent`.

## Class Hierarchy

```
ImportService (Static Class)
├── fromText(String text) → SourceContent
├── fromImage(Uint8List bytes, {String? fileName}) → SourceContent
├── fromFile(Uint8List bytes, {required String fileName}) → Future<SourceContent>
└── isValid(SourceContent source) → bool

SourceContent
├── type: SourceType (enum)
├── text: String
├── bytes: Uint8List?
├── fileName: String?
└── metadata: Map<String, dynamic>?

SourceType (enum)
├── text
├── pdf
├── docx
├── image
└── sketch
```

## Public API

### fromText()
```dart
final content = ImportService.fromText('Buat presentasi tentang AI');
// Returns: SourceContent(type: text, text: 'Buat presentasi tentang AI')
```

### fromImage()
```dart
final content = ImportService.fromImage(pngBytes, fileName: 'sketch.png');
// Returns: SourceContent(type: image, bytes: pngBytes)
```

### fromFile()
```dart
final content = await ImportService.fromFile(fileBytes, fileName: 'document.pdf');
// Returns: SourceContent(type: pdf, text: '[PDF content - ...]')
```

### isValid()
```dart
if (!ImportService.isValid(content)) {
  return 'Input tidak valid';
}
```

## Supported File Types

| Extension | Type | Converter |
|-----------|------|-----------|
| `.pdf` | `SourceType.pdf` | Stub (not supported on web) |
| `.docx` | `SourceType.docx` | Stub (not supported on web) |
| `.txt` | `SourceType.text` | Direct read |
| `.md` | `SourceType.text` | Direct read |
| Other | `SourceType.text` | Unsupported message |

## Error Handling
| Error | Response |
|-------|----------|
| Empty text | `isValid()` returns false |
| Unsupported file | Returns message "[Unsupported file type: .ext]" |
| PDF/DOCX on web | Returns message "[PDF/DOCX content - conversion not yet supported on web]" |

## Related Files
- `ai_generation.dart` - Use SourceContent for AI calls
- `ai_chat_panel.dart` - UI for text input
- `sketch_ai_panel.dart` - UI for sketch input
