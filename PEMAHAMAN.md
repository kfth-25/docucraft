# 🐬 Keqo — Mobile PPT Editor

> **Pemahaman Project** — 28 Juli 2026
> Berdasarkan hasil mapping menyeluruh dari `docucraft_app` (kini: **Keqo**)

---

## 🧠 Apa Itu Keqo?

**Keqo** adalah aplikasi editor presentasi (PPT) mobile-first berbasis **Flutter** yang memungkinkan pengguna membuat, mengedit, dan mengekspor slide presentasi dengan bantuan **AI**, dukungan **kolaborasi real-time**, dan sistem **template** yang kaya.

Aplikasi ini adalah **frontend presentation layer** dari ekosistem Keqo — berbeda dengan Keqo SOC (security operations) yang sudah ada sebelumnya. Fokusnya murni pada **produktivitas dokumen dan presentasi**.

---

## 🎯 Target & Tujuan

| Aspek | Detil |
|-------|-------|
| **Platform** | Android, iOS, Web |
| **Target User** | Individu & tim yang butuh bikin presentasi cepat — mobile-first |
| **Value Proposition** | AI generate slide + edit touch-friendly + export .pptx + kolaborasi tim |
| **Competitive Edge** | Bisa jalan offline (Hive local storage), collab real-time via WebSocket, dark theme premium |

---

## 🔧 Stack Teknologi

| Lapisan | Teknologi |
|---------|-----------|
| **Framework** | Flutter 3.13+ / Dart |
| **State Management** | Provider (ChangeNotifier) |
| **Local Storage** | Hive + SharedPreferences |
| **AI / LLM** | 9router endpoint (`http://127.0.0.1:20128/v1`) |
| **Export** | XML builder + archive library → .pptx |
| **Collab Server** | Dart/shelf + WebSocket (`ws://:9101`) |
| **Templates** | TypeScript/TSX-based preset layouts (`presenton-templates/`) |
| **Theme** | Dark theme, Material Design, Google Fonts |

---

## 📁 Struktur Folder

```
keqo_ppt/                          # Root project
├── lib/                           # 🎯 Source utama (13.5K baris Dart)
│   ├── main.dart                  # Entry point + CollabManager + BottomNav
│   ├── models/                    # Data models (Slide, Template, Registry)
│   ├── providers/                 # State management (SlideProvider)
│   ├── screens/                   # Halaman utama (Dashboard, Editor, Template Browser)
│   ├── services/                  # AI, Export, Import, Storage, Template Engine
│   ├── collab/                    # WebSocket, Sync Engine, Conflict Resolution, Presence
│   ├── themes/                    # Dark theme
│   └── widgets/                   # 18 widget reusable (Canvas, Present Mode, AI Chat, dll)
│
├── server/
│   └── collab_server.dart         # WebSocket collab server (Dart/shelf, port 9101)
│
├── web/                           # Flutter Web entry (index.html, manifest, favicon)
├── presenton-templates/           # Template preset (TSX) — modern, standard, swift, neo-*
├── assets/                        # App assets
├── android/ + ios/                # Native platform config
└── test/                          # Unit tests
```

---

## 🏗️ Arsitektur: Layered + Provider-Driven

```
┌─────────────────────────────────────┐
│         SCREENS + WIDGETS           │  ← Presentation Layer
│  Dashboard / SlideEditor / Canvas   │     (screens/ + widgets/)
│  PresentMode / AI Chat / Template   │
└──────────────┬──────────────────────┘
               │ notifyListeners / callbacks
┌──────────────▼──────────────────────┐
│        SlideProvider                │  ← State Layer
│  ChangeNotifier + Undo/Redo (30)    │     (providers/)
│  auto-save → Hive                   │
└──────┬──────────────┬───────────────┘
       │              │
┌──────▼──────┐ ┌─────▼──────────────┐
│   MODELS    │ │     SERVICES       │  ← Domain + Service Layer
│ Slide       │ │ AI Generation      │     (models/ + services/)
│ SlideElement│ │ PPTX Export/Import │
│ Template    │ │ Storage (Hive)     │
│ Registry    │ │ Template Engine    │
└─────────────┘ └─────┬──────────────┘
                      │
┌─────────────────────▼────────────────┐
│           COLLAB LAYER               │  ← Network Layer
│  SyncEngine ↔ WebSocket → Server:9101│     (collab/)
│  Conflict Resolver (LWW)             │
│  Offline Queue + Presence            │
└──────────────────────────────────────┘
```

### Pola Desain

1. **Provider Pattern** — `ChangeNotifier` + `MultiProvider` untuk state management
2. **Snapshot-based Undo/Redo** — Full serialized snapshots, max 30 level
3. **CRDT Metadata** — Setiap slide/element punya `version` + `lastModifiedBy` + `lastModifiedAt`
4. **LWW Conflict Resolution** — Last-Writer-Wins per element & per slide
5. **Offline Queue** — Pending changes di-buffer saat disconnect, di-flush saat reconnect
6. **Repository Pattern** — StorageService abstract Hive, ApiClient abstract HTTP

---

## 🔄 Alur Eksekusi Utama

### 1. Startup → Dashboard
```
main() → Hive.init() → StorageService.init() → registerAllTemplates()
      → DocuCraftApp (MaterialApp) → MultiProvider (SlideProvider)
      → MainShell (BottomNavigationBar: Beranda | Dokumen | AI | Market | Profil)
      → DashboardScreen
```

### 2. Edit Presentasi
```
Dashboard → SlideEditorScreen
              ├── SlideCanvas (drag, tap, select element)
              ├── Context Toolbar (bold, italic, font size, color, underline)
              ├── Bottom Toolbar → InsertPanel / AIChat / Template / Background / Layout / Transition
              ├── Export → PptxExporter → .pptx → Share
              └── Present → PresentationMode (fullscreen, keyboard nav, speaker notes)
```

### 3. AI Generate Slide
```
AIChatPanel → prompt user → AiGeneration (HTTP ke 9router LLM)
           → parse JSON response → SlideElement objects
           → SlideProvider.applyAiResult() → UI update
```

### 4. Kolaborasi Real-time
```
SlideProvider ↔ SyncEngine ↔ CollabWebSocketProvider ↔ WebSocket :9101
     ↑                                              ↓
     └────────────────── Server ────────────────────┘
     (LWW conflict resolution, presence broadcast, offline queue)
```

### 5. Export → .pptx
```
SlideEditorScreen → PptxExporter.export()
                  → XML builder (Office Open XML Standard)
                  → archive (ZIP) → .pptx file
                  → Share.shareXFiles (native share sheet)
```

---

## 📊 Model Data Inti

### Slide (1 slide = 1 halaman presentasi)
- `id` (UUID v7, time-ordered) · `title` · `subtitle` · `backgroundGradient`
- `hidden` · `elements: List<SlideElement>`
- CRDT: `version` · `lastModifiedBy` · `lastModifiedAt`
- `templateId` — template linkage

### SlideElement (1 elemen dalam slide)
- `id` (UUID v7) · `type` (enum: text | image | shape | chart | table | icon | video | audio | draw)
- Posisi: `x, y, width, height` (1920×1080 design space, pixel-based)
- `rotation` · `zIndex` · `content`
- Style data (per-tipe): `TextStyleData` · `ShapeStyleData` · `ImageStyleData` · `ChartData` · `TableData` · `DrawData`
- `templateSlotId` — slot mapping untuk template engine

### Elemen Styles
- **TextStyleData**: fontSize, color, fontWeight, fontStyle, textAlign, fontFamily, letterSpacing, lineHeight, textDecoration
- **ShapeStyleData**: fillColor, strokeColor, strokeWidth, borderRadius, opacity
- **ImageStyleData**: src, placeholderLabel, opacity, borderRadius
- **ChartData**: chartType (bar/line/pie/donut), dataSets (values + label + color), labels
- **TableData**: rows, cols, cells (List of List), hasHeader
- **DrawData**: strokes (colorValue + size + points)

---

## ✨ Fitur Paling Matang

| Fitur | Lokasi | Baris | Kualitas |
|-------|--------|-------|----------|
| **Present Mode** | `widgets/presentation_mode.dart` | 1,114 | ⭐ Production-grade — keyboard nav, swipe, speaker notes, progress bar, auto-hide chrome |
| **Slide Editor** | `screens/slide_editor_screen.dart` | 877 | Layar utama dengan 18 panel/widget terintegrasi |
| **SlideProvider** | `providers/slide_provider.dart` | 655 | State management + undo/redo 30-level |
| **AI Generation** | `services/ai_generation.dart` | 576 | LLM client → slide JSON (9router) |
| **PPTX Export** | `services/pptx_export.dart` | 554 | XML builder → .pptx |
| **Draw Canvas** | `widgets/draw_canvas.dart` | 391 | Freehand drawing (6 colors, pen size, eraser, undo/redo) |
| **Model Design** | `models/slide.dart` | 694 | V2 model, 6 style types, backward compat V1→V2, CRDT metadata |
| **Collab Server** | `server/collab_server.dart` | — | Dart/shelf WebSocket, heartbeat, snapshot, LWW conflict |

---

## ⚠️ Kondisi Saat Ini (Dari Mapping)

### 🔴 Critical Blocker
1. **AI gak jalan out-of-the-box** — API key default kosong (`''`), status "Online" hardcoded
2. **Export .pptx error di Web** — `dart:io` dipake di `pptx_export.dart`, gak available di Flutter Web
3. **Resize handles gak ada** — `slide_canvas.dart:447` return `[]` — gak bisa resize elemen setelah di-add

### 🟡 Signifikan
4. **PPTX Importer (289 baris) udah ditulis tapi gak di-wire ke UI** — fitur impor ada kodenya, gak ada tombolnya
5. **Template apply cuma ganti background** — layout elemen gak berubah
6. **Underline button callback kosong** — `() {}` — misleading affordance
7. **Copy-paste mutasi objek** — `_clipboard.x += 20` sebelum di-add, bisa paste sekali aja
8. **Loading state kurang** — export/AI/collab sync tanpa spinner overlay

### 🟢 Minor
9. Nama user hardcoded "Rina Amalia" di dashboard
10. 4 dari 5 tab BottomNav masih placeholder screens
11. Chart label di-truncate ke 4 karakter
12. Template card di UI kelihatan sophisticated tapi apply-nya cuma warna

---

## 📈 Metrik

| Metrik | Nilai |
|--------|-------|
| **Total file Dart** | 39 files |
| **Total baris kode** | ~13,480 baris |
| **Rata-rata baris/file** | ~346 baris |
| **File terbesar** | `presentation_mode.dart` (1,114 baris) |
| **Widget reusable** | 18 widgets |
| **Direktori di lib/** | 8 direktori |

---

## 🔗 Relasi dengan Ekosistem Keqo

Project PPT editor ini adalah **produk turunan** dalam ekosistem Keqo. Sementara Keqo SOC fokus pada keamanan siber (XGBoost detection, RDT engine, SOAR automation, Naga gateway), aplikasi PPT editor ini mengisi celah **produktivitas dokumen** — bikin presentasi dengan bantuan AI, export .pptx, dan kolaborasi tim.

Keduanya dirancang dengan filosofi yang sama: **sovereign** (jalan di infrastruktur sendiri), **modular** (setiap fitur adalah service independen), dan **adaptive** (belajar dari feedback).

---

*Dokumen ini dibuat berdasarkan hasil mapping menyeluruh project `docucraft_app` (13.480 baris Dart, 39 files, 3 screens, 18 widgets, 6 services, 5 collab modules).*