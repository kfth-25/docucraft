# DocuCraft Server

## Overview
Server Python untuk menjalankan script PPT Master sebagai API. Flutter app berkomunikasi via HTTP ke server ini.

## Arsitektur

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        DOCUCRAFT ARCHITECTURE                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    FLUTTER APP (Frontend)                        │   │
│  │                                                                  │   │
│  │  ┌─────────────────────┐    ┌─────────────────────┐            │   │
│  │  │   AI Chat Panel     │    │   Sketch AI Panel   │            │   │
│  │  └──────────┬──────────┘    └──────────┬──────────┘            │   │
│  │             │                          │                        │   │
│  │             └────────────┬─────────────┘                        │   │
│  │                          │                                      │   │
│  │                          ▼                                      │   │
│  │  ┌─────────────────────────────────────────────────────────┐   │   │
│  │  │              API Client (Dart)                           │   │   │
│  │  │              http://localhost:5000/api/...               │   │   │
│  │  └─────────────────────────────────────────────────────────┘   │   │
│  │                                                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                              │                                          │
│                              │ HTTP                                     │
│                              ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    PYTHON SERVER (Backend)                       │   │
│  │                                                                  │   │
│  │  ┌─────────────────────────────────────────────────────────┐   │   │
│  │  │                    Flask App                              │   │   │
│  │  │                    (app.py)                               │   │   │
│  │  └─────────────────────────────────────────────────────────┘   │   │
│  │                              │                                   │   │
│  │                              ▼                                   │   │
│  │  ┌─────────────────────────────────────────────────────────┐   │   │
│  │  │              PPT Master Scripts                          │   │   │
│  │  │              (skills/ppt-master/...)                     │   │   │
│  │  │                                                          │   │   │
│  │  │  • source_to_md.py      → Step 1                         │   │   │
│  │  │  • project_manager.py   → Step 2                         │   │   │
│  │  │  • svg_quality_checker  → Step 7                         │   │   │
│  │  │  • svg_to_pptx.py       → Export                         │   │   │
│  │  │  • image_gen.py         → Images                         │   │   │
│  │  │  • ...                                                   │   │   │
│  │  └─────────────────────────────────────────────────────────┘   │   │
│  │                                                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## API Endpoints

### Step 1: Source Content Processing
```
POST /api/step1/process-source
{
    "type": "text" | "file" | "url",
    "content": "...",
    "file_path": "...",
    "url": "..."
}
```

### Step 2: Project Initialization
```
POST /api/step2/init-project
{
    "project_name": "Presentasi AI",
    "format": "ppt169"
}
```

### Step 3: Template Candidates
```
POST /api/step3/template-candidates
{
    "prompt": "Buat presentasi tentang AI"
}
```

### Step 4: Confirm Design
```
POST /api/step4/confirm
{
    "project_id": "project_123",
    "template_id": "tech-modern",
    "topic": "AI",
    "warna": "biru",
    "style": "modern",
    "page_count": 5
}
```

### Step 5: Image Acquisition
```
POST /api/step5/acquire-images
{
    "project_id": "project_123",
    "prompts": ["AI robot", "Machine learning"],
    "source": "ai" | "web"
}
```

### Step 6: Generate SVG
```
POST /api/step6/generate-svg
{
    "project_id": "project_123",
    "pages": [
        {"title": "Cover", "content": "AI Presentation"},
        ...
    ]
}
```

### Step 7: Quality Check + Export
```
POST /api/step7/quality-check
{
    "project_id": "project_123"
}

POST /api/step7/export-pptx
{
    "project_id": "project_123",
    "filename": "presentasi_ai.pptx"
}
```

### Live Preview
```
POST /api/preview/start
{
    "project_id": "project_123"
}

GET /api/preview/<project_id>
```

## Cara Menjalankan

### 1. Install Dependencies
```bash
cd server
pip install flask flask-cors
```

### 2. Jalankan Server
```bash
python app.py
```

Server akan berjalan di `http://localhost:5000`

### 3. Test API
```bash
# Test Step 1
curl -X POST http://localhost:5000/api/step1/process-source \
  -H "Content-Type: application/json" \
  -d '{"type": "text", "content": "Buat presentasi tentang AI"}'

# Test Step 2
curl -X POST http://localhost:5000/api/step2/init-project \
  -H "Content-Type: application/json" \
  -d '{"project_name": "Presentasi AI", "format": "ppt169"}'
```

## Integrasi dengan Flutter

```dart
// lib/services/api_client.dart
class ApiClient {
  static const String baseUrl = 'http://localhost:5000/api';

  static Future<Map<String, dynamic>> processSource(String content) async {
    final response = await http.post(
      Uri.parse('$baseUrl/step1/process-source'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'type': 'text', 'content': content}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> initProject(String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/step2/init-project'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'project_name': name, 'format': 'ppt169'}),
    );
    return jsonDecode(response.body);
  }

  // ... other methods
}
```

## Struktur Folder

```
server/
├── app.py                    ← Main Flask app
├── README.md                 ← Dokumentasi ini
├── projects/                 ← Project storage
│   └── project_123/
│       ├── config.json
│       ├── design_spec.json
│       ├── sources/
│       ├── analysis/
│       ├── svg_output/
│       ├── images/
│       └── exports/
└── requirements.txt          ← Python dependencies
```

## Requirements

```
flask==3.0.0
flask-cors==4.0.0
python-pptx==0.6.21
Pillow==10.0.0
```

## Related Files
- `skills/ppt-master/` ← PPT Master scripts
- `lib/services/api_client.dart` ← Flutter API client
- `lib/widgets/ai_chat_panel.dart` ← Flutter UI
