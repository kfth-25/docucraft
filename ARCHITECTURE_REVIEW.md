# DocuCraft Flutter PPT Editor — Arsitektur Review

> **Reviewer**: Project Mapper  
> **Date**: 2026-07-27  
> **Path**: `C:\Users\Pongo\docucraft_app\lib\`  
> **Total**: 38 Dart files, 12,853 baris  
> **Build**: 0 error, 10 warnings

---

## 1. File Structure Assessment

### ✅ Strengths
- **Clean separation of concerns**: `models/`, `providers/`, `screens/`, `widgets/`, `services/`, `collab/`, `themes/`
- **Provider pattern** konsisten untuk state management
- **Services layer** (ai_generation, pptx_export/import, template_engine) terpisah dari UI
- **Collab layer** terisolasi di folder `collab/` — tidak menyebar ke widgets

### ⚠️ Issues

| Issue | Severity | Detail |
|-------|----------|--------|
| **slide_editor_screen.dart (923 lines)** | 🟡 Medium | Terlalu besar — mengandung export, present dialog, context toolbar, zoom, undo UI. Perlu dipecah |
| **presentation_mode.dart (1114 lines)** | 🟡 Medium | Satu widget terlalu besar. Berisi presenter logic + slide transitions + gesture handler |
| **Unused widgets (ai_quick_actions.dart, editor_toolbar.dart)** | 🟢 Low | File yang tidak terpakai — hapus untuk kebersihan |
| **Duplicated draw logic** | 🟡 Medium | `draw_canvas.dart` di widgets + ada juga draw logic di `slide_editor_screen.dart` yang seharusnya delegate ke DrawCanvasState |

### Recommended Structure
```
lib/
├── models/          ✅ Sudah bagus (Slide V2 dengan CRDT metadata)
├── providers/       ✅ OK
├── screens/
│   ├── dashboard_screen.dart
│   ├── slide_editor_screen.dart  ← PERLU dipecah ke 3 file:
│   │   ├── editor_shell.dart (layout + nav)
│   │   ├── editor_canvas.dart (canvas + zoom + drag)
│   │   └── editor_toolbar.dart (toolbar + actions)
│   └── template_browser.dart
├── widgets/         ✅ 20+ files — clean separation
├── services/        ✅ AI, PPTX export/import, template engine
├── collab/          ✅ Yjs + sync engine
└── themes/          ✅
```

---

## 2. Circular Dependency Check

### Import Graph (Simplified)

```
models/slide.dart         ← 19 imports (most imported file — leaf node)
providers/slide_provider  ← 16 imports (central state hub)
widgets/*                 → providers + models (no circular)
screens/*                 → widgets + providers + services (no circular)
collab/*                  → models + providers (no circular back-imports)
services/*                → models only (no circular)
```

### ✅ No Circular Dependencies Detected
- `slide.dart` is the leaf — imported by everything, imports nothing from widgets/collab
- `slide_provider.dart` imports only `slide.dart` — safe hub
- Widgets import providers + models only — no reverse imports from providers to widgets
- Collab layer imports models + providers but providers don't import collab

### ⚠️ Potential Issue
- `template_panel.dart` imports `services/template_engine.dart` + `models/template.dart` + `models/template_registry.dart` — OK, but if template_engine ever needs SlideProvider, you'd get a cycle. Current state: safe.

---

## 3. Model Design Review

### `Slide` Model (V2, 694 lines in slide.dart)

**Elements covered:**
- ✅ `text` → `TextStyleData` (fontSize, color, fontWeight, fontStyle, textAlign, letterSpacing, lineHeight, textDecoration)
- ✅ `image` → `ImageStyleData` (src, placeholderLabel, opacity, borderRadius)
- ✅ `shape` → `ShapeStyleData` (fillColor, strokeColor, strokeWidth, borderRadius, opacity)
- ✅ `chart` → `ChartData` (chartType + `ChartDataSet[]` + labels) — supports bar/line/pie/donut
- ✅ `table` → `TableData` (rows, cols, cells[][], hasHeader)
- ✅ `draw` → `DrawData` + `DrawStroke[]` (colorValue, size, points[][], label)
- ✅ `icon`, `video`, `audio` — type enum exists, rendered via content string

**CRDT/Collab Metadata:** ✅
- `version`, `lastModifiedBy`, `lastModifiedAt` on both `Slide` and `SlideElement`
- `templateSlotId` for template engine
- UUID v7 (time-ordered) — correct for multi-user

**Backward Compatibility:** ✅
- V1 → V2 migration in `SlideElement.fromJson()`: percentage coords → pixel coords, loose fields → structured styles

### ⚠️ Issues

| Issue | Severity | Detail |
|-------|----------|--------|
| `content` field is `String?` for ALL types | 🟡 Medium | For text: this is the text content. For chart: this is "bar". For image: this is placeholder text. Overloaded — would be cleaner if `content` was text-only and type-specific data was always in `chartData`/`imageStyle` |
| `extra` is still `Map<String,dynamic>?` on both Slide and SlideElement | 🟢 Low | Used for presenter notes (`extra['notes']`) and ad-hoc data. Could be replaced by proper fields (e.g. `presenterNotes` on Slide) |
| No `AudioData`/`VideoData` models | 🟢 Low | Audio/Video elements exist in type enum but have no structured data model — only string content for URL/placeholder |
| `SlideElement.id` defaults to UUID but old data uses timestamp IDs | 🟢 Low | Migration handles this but could be smoother |

### ✅ Model is Sufficient for Current Features
The structured style data classes (`TextStyleData`, `ShapeStyleData`, `ChartData`, `TableData`, `DrawData`) cover all 9 element types. The model supports real-time editing, template linkage, and CRDT sync.

---

## 4. Collaboration Layer Review

### Architecture
```
SlideProvider (local state)
    ↕
SyncEngine (bridge: local ↔ remote)
    ↕
YjsProvider (WebSocket + CRDT)
    ↕ WebSocket
Other clients
```

### Files

| File | Lines | Status | Assessment |
|------|-------|--------|------------|
| `yjs_provider.dart` | 333 | ✅ Written | WebSocket connection, reconnect, doc stream |
| `sync_engine.dart` | 295 | ✅ Written | Outbound edits → broadcast, inbound → apply |
| `presence.dart` | 100 | ✅ Written | User presence data (userId, color, cursor position) |
| `conflict_resolver.dart` | 166 | ✅ Written | LWW (Last Write Wins) resolution |
| `offline_queue.dart` | 165 | ✅ Written | Queue edits during disconnect, replay on reconnect |
| `presence_overlay.dart` | 449 | ✅ Connected | Widget showing user cursors, imported in slide_editor_screen.dart |

### ✅ Connected to Provider
- `presence_overlay.dart` is imported in `slide_editor_screen.dart`
- `SyncEngine` has the right architecture (bridge between local SlideProvider and remote YjsProvider)

### ⚠️ Issues

| Issue | Severity | Detail |
|-------|----------|--------|
| **SyncEngine not instantiated anywhere** | 🔴 Critical | `SyncEngine` class exists but is NEVER instantiated in main.dart or slide_editor_screen.dart. The collab layer is fully implemented but **not wired** |
| **YjsProvider not initialized** | 🔴 Critical | Same — class exists but `YjsProvider(documentId: ..., userId: ...)` is never called |
| **No collab_server available** | 🟡 Medium | WebSocket target is `ws://localhost:9101` — collab_server (Node.js) doesn't exist yet in this repo |
| **LWW conflict resolution is naive** | 🟢 Low | LWW = last write always wins. For a PPT editor, this is acceptable for most cases but may cause data loss if two users edit the same element simultaneously |

### Verdict
**Collab layer is architecturally complete but not yet integrated.** All 5 files (1,058 lines) are well-structured and ready to wire. The missing piece is:
1. Instantiating `YjsProvider` + `SyncEngine` in the main app
2. Having the collab_server running on WebSocket port 9101
3. Connecting `SlideProvider` mutation callbacks to `SyncEngine.outbound`

---

## 5. Services Layer Review

| Service | Lines | Connected | Assessment |
|---------|-------|-----------|------------|
| `pptx_export.dart` | 554 | ✅ Yes | Called from `_exportPPT()` in editor screen |
| `pptx_import.dart` | 289 | ⚠️ Partial | Import code exists but is commented out (`// final importResult = await PptxImporter.fromFile(...)`) |
| `ai_generation.dart` | 543 | ⚠️ Partial | Imported in `ai_chat_panel.dart` but actual API call not confirmed |
| `template_engine.dart` | 261 | ✅ Yes | Connected in `template_panel.dart` |

---

## 6. Key Metrics

| Metric | Value | Assessment |
|--------|-------|------------|
| Total files | 38 | Good for a full PPT editor |
| Total lines | 12,853 | Reasonable |
| Largest file | `presentation_mode.dart` (1114 lines) | ⚠️ Too large |
| Model depth | 11 data classes in 1 file | ✅ Well structured |
| Provider count | 1 | ✅ Single source of truth (SlideProvider) |
| Screen count | 3 (dashboard, editor, template browser) | ✅ Clean |
| Widget count | 20 | ✅ Good granularity |
| Services | 4 | ✅ Good separation |
| Collab modules | 5 | ✅ Complete architecture |
| Circular deps | 0 | ✅ Clean |
| Unused imports/files | 3-5 | 🟢 Minor warnings |

---

## 7. Critical Recommendations

### 🔴 Must Fix (before production)
1. **Wire collab layer**: Instantiate `YjsProvider` + `SyncEngine` in `main.dart` or a `CollabProvider`
2. **Remove unused files**: `ai_quick_actions.dart` (4 lines, just export), `editor_toolbar.dart` (89 lines, unused)
3. **Fix `dart:io` import**: `slide_editor_screen.dart` imports `dart:io` (for File I/O) — will break on web build. Use conditional imports

### 🟡 Should Fix
1. **Split slide_editor_screen.dart** (923 lines) into 3 modules: shell, canvas area, toolbar
2. **Split presentation_mode.dart** (1114 lines) into: presenter_screen + slide_animations + gesture_handler
3. **Add proper AudioData/VideoData models** instead of relying on `content` string
4. **Wire PptxImporter** (currently commented out) in the editor UI
5. **Replace `extra` field** with proper named fields (`presenterNotes`, `transitions`)

### 🟢 Nice to Have
1. **Fix 10 warnings** (unused imports/fields) — clean build
2. **Add unit tests** for SlideProvider (undo/redo, CRUD) and Slide model (JSON serialization, V1→V2 migration)
3. **Add documentation** to complex widgets (slide_canvas.dart, draw_canvas.dart)

---

## 8. Overall Score

| Dimension | Score | Notes |
|-----------|-------|-------|
| File Structure | ⭐⭐⭐⭐ | Clean layers, good separation. Two files too large |
| Model Design | ⭐⭐⭐⭐⭐ | V2 model with CRDT, structured styles, backward compat — excellent |
| State Management | ⭐⭐⭐⭐ | Single Provider, good undo/redo. All mutations push undo properly |
| Persistence | ⭐⭐⭐⭐ | SharedPreferences auto-save/load. Demo fallback. Good |
| Collaboration | ⭐⭐⭐ | Complete architecture but **not wired** to app yet |
| Export/Import | ⭐⭐⭐⭐ | Export works with elements. Import exists but commented out |
| UI/UX | ⭐⭐⭐⭐ | 19+ features. Touch support. Mobile-first layout |
| **Overall** | **⭐⭐⭐⭐** | **Production-ready for MVP, but collab + services need wiring** |

---

*Generated by Project Mapper — Developer Project 3*
