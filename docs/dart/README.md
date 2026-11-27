# DocuCraft Dart Documentation

## Overview
Dokumentasi lengkap untuk setiap file Dart di DocuCraft. Setiap file punya dokumentasi yang menjelaskan class, method, dan integrasinya.

## Struktur Folder

```
docs/dart/
├── README.md                    # File ini - Navigasi dokumentasi
├── models/                      # Data models
│   ├── slide.md                 # Slide model
│   ├── template_registry_v2.md  # Template system
│   └── template_suggestion.md   # Template recommendations
├── services/                    # Business logic
│   ├── ai_generation.md         # AI API communication
│   ├── quality_check.md         # Quality validation
│   ├── svg_to_slide_elements.md # SVG parser
│   ├── import_service.md        # Input processing
│   ├── project_service.md       # Project state
│   └── preview_service.md       # Preview & diagnostics
└── widgets/                     # UI components
    ├── ai_chat_panel.md         # AI Chat UI
    └── sketch_ai_panel.md       # Sketch AI UI (TODO)
```

## Documentation Status

### Models (3/5)
| File | Status | Coverage |
|------|--------|----------|
| `slide.md` | ✅ | 100% |
| `template_registry_v2.md` | ✅ | 100% |
| `template_suggestion.md` | ✅ | 100% |
| `template_layout.md` | ❌ | TODO |
| `template_registry.md` | ❌ | TODO |

### Services (6/12)
| File | Status | Coverage |
|------|--------|----------|
| `ai_generation.md` | ✅ | 100% |
| `quality_check.md` | ✅ | 100% |
| `svg_to_slide_elements.md` | ✅ | 100% |
| `import_service.md` | ✅ | 100% |
| `project_service.md` | ✅ | 100% |
| `preview_service.md` | ✅ | 100% |
| `api_client.md` | ❌ | TODO |
| `pptx_export.md` | ❌ | TODO |
| `pptx_import.md` | ❌ | TODO |
| `storage_service.md` | ❌ | TODO |
| `template_converter.md` | ❌ | TODO |
| `template_renderer.md` | ❌ | TODO |

### Widgets (1/25)
| File | Status | Coverage |
|------|--------|----------|
| `ai_chat_panel.md` | ✅ | 100% |
| `sketch_ai_panel.md` | ❌ | TODO |
| `slide_canvas.md` | ❌ | TODO |
| `draw_canvas.md` | ❌ | TODO |
| `editor_*.md` | ❌ | TODO |
| Other widgets | ❌ | TODO |

## Step Mapping

| Step | Documentation | Dart File |
|------|--------------|-----------|
| 1 | `services/import_service.md` | `import/import_service.dart` |
| 2 | `services/project_service.dart` | `project_service.dart` |
| 3 | `models/template_suggestion.md` | `template_suggestion.dart` |
| 4 | `widgets/ai_chat_panel.md` | `ai_chat_panel.dart` |
| 5 | `services/project_service.dart` | `project_service.dart` |
| 6 | `services/preview_service.md` | `preview_service.dart` |
| 7 | `services/quality_check.md` | `quality_check.dart` |

## Quick Access

| Need | File |
|------|------|
| How to add new AI model? | `services/ai_generation.md` |
| How to add new template? | `models/template_suggestion.md` |
| How to add new quality check? | `services/quality_check.md` |
| How to add new input type? | `services/import_service.md` |
| How to modify chat UI? | `widgets/ai_chat_panel.md` |
| How to add new export format? | `services/pptx_export.md` (TODO) |

## Contributing
1. Untuk menambah dokumentasi, buat file `.md` di folder yang sesuai
2. Gunakan template yang sudah ada sebagai referensi
3. Update README ini dengan status terbaru
