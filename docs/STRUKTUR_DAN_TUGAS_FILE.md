# 📁 DocuCraft — Dokumen Struktur Direktori & Tugas Tiap File

> **Tujuan dokumen ini:** supaya kamu paham setiap direktori dan setiap file
> di project DocuCraft, apa tugasnya, dan di mana letaknya.
>
> **Catatan komentar di code:** hampir setiap file Dart punya header komentar
> di baris pertama berformat `// DocuCraft — <nama> (<fungsi>)`, contoh:
> ```dart
> // DocuCraft — Slide Provider (Core State Management)
> // Refactored to delegate persistence, undo/redo, collab, AI to specialized adapters
> ```
> Komentar `// ...` di dalam code menjelaskan **apa yang dilakukan blok kode
> tersebut** — baca header file dulu untuk gambaran umum, lalu komentar inline
> untuk detail tiap fungsi.

---

## 🗂️ Peta Direktori (Top Level)

```
docucraft_app/
├── lib/                  ← SELURUH SOURCE CODE APP (Dart) ⭐
├── test/                 ← Unit & widget test
├── android/              ← Build config Android (Gradle)
├── ios/                  ← Build config iOS
├── web/                  ← Build config Web
├── windows/              ← Build config Windows desktop
├── assets/               ← Font, gambar, ikon, template statis
├── docs/                 ← Dokumentasi (termasuk file ini)
├── prompts/              ← Template prompt untuk AI
├── skills/               ← Skill file untuk AI agent
├── examples/             ← Contoh file/data
├── server/               ← Server pendukung (Node/Python)
├── bridge-server/        ← Bridge HTTP lokal
├── hocuspocus-server/    ← Server collab (Yjs/WebSocket)
├── rust/                 ← Kode Rust (CRDT/Loro FFI)
├── tools/                ← Script tooling dev
├── pubspec.yaml          ← Manifest dependency Flutter
├── analysis_options.yaml ← Aturan linting Dart
└── README.md             ← Deskripsi project
```

---

## ⭐ `lib/` — Jantung Aplikasi

### Struktur lengkap:

```
lib/
├── main.dart                  ← ENTRY POINT aplikasi
├── slide_editor_intents.dart  ← Shortcut keyboard editor
│
├── models/        ← SKEMA DATA (class murni, tanpa UI)
├── providers/     ← STATE MANAGEMENT (ChangeNotifier)
├── screens/       ← HALAMAN/HALAMAN PENUH (full screen)
├── widgets/       ← KOMPONEN UI yang bisa dipakai ulang
├── services/      ← LOGIKA & INTEGRASI (API, storage, export)
├── agent_core/    ← MESIN AI AGENT (loop, skill, transport)
├── ai/            ← STATE MACHINE generate PPT
├── collab/        ← KOLABORASI REAL-TIME
├── src/           ← Kode internal (CRDT, FFI)
├── templates/     ← TEMPLATE SLIDE per gaya
├── themes/        ← Tema warna/typography
├── l10n/          ← LOKALISASI (Indonesia + Inggris)
└── utils/         ← Helper util
```

---

## 📄 `lib/main.dart`
**Tugas:** Entry point. Daftarkan semua `Provider` global, route, locale, dan
theme. `MultiProvider` di sini menyediakan `SlideProvider` + `DocumentProvider`
ke seluruh widget tree.

---

## 📦 `lib/models/` — Skema Data

| File | Tugas |
|------|-------|
| `slide.dart` | Model 1 slide + `SlideElement` (teks, gambar, shape) + `toJson/fromJson` |
| `document.dart` | Model dokumen: `Document`, `DocumentBlock` (paragraph/heading/table), `TextRun` |
| `deck_blueprint.dart` | Blueprint deck (struktur presentasi tersimpan) |
| `design_spec.dart` | Spesifikasi desain (warna, font, gaya) |
| `ppt_metadata.dart` | Metadata PPT (judul, author, jumlah slide) |
| `template_layout.dart` | Definisi layout template |
| `template_registry.dart` | Registry template v1 (lookup by ID) |
| `template_registry_v2.dart` | Registry v2 dengan SVG slots |
| `template_suggestion.dart` | Saran template dari AI |

> 💰 **Prinsip:** Model **tidak pernah** import Flutter UI — murni data +
> serialisasi JSON, supaya aman untuk storage & transfer.

---

## 🧠 `lib/providers/` — State Management

| File | Tugas |
|------|-------|
| `slide_provider.dart` | ⭐ **State utama slide**: daftar slide, slide aktif, undo/redo, `applyAiResult()` untuk menerima hasil AI, `_save()` ke storage setiap mutasi |
| `slide_repository.dart` | **Lapisan persistensi slide**: load/save ke Hive per project, auto-save tiap 30 detik, CRUD project |
| `document_provider.dart` | **State dokumen**: CRUD dokumen, edit block, folder, `replaceContent()` / `replaceFromGenOffice()` untuk terima konten dari GenOffice, auto-save |
| `undo_redo_manager.dart` | Stack undo/redo (snapshot slide sebelum berubah) |
| `collab_sync_adapter.dart` | Jembatan state ↔ sistem kolaborasi |
| `ai_generation_adapter.dart` | Adapter pemanggilan AI generate |
| `ai_run_provider.dart` | State progres run AI (sedang generate? error?) |
| `blueprint_picker_provider.dart` | State pemilih blueprint |

> 🔑 **Alur penyimpanan (penting!):**
> ```
> Provider ubah state → notifyListeners() → _save() →
> Repository.updateState() → StorageService.saveXxx() → Hive (disk)
> ```
> **Semua mutasi WAJIB panggil `_save()`** — kalau tidak, konten hilang
> (bug yang pernah terjadi: konten AI hilang karena cuma `_markDirty()` tanpa save).

---

## 🖥️ `lib/screens/` — Halaman Penuh

| File | Tugas |
|------|-------|
| `dashboard_screen.dart` | ⭐ **Home**: header "Good morning, Designer", daftar project, search bar AI, buat PPT/Doc/Sheet baru |
| `slide_editor_screen.dart` | ⭐ **Editor PPT**: canvas, thumbnail strip, toolbar, auto-buka AI chat (`autoOpenAi`) |
| `document_editor_screen.dart` | **Editor Dokumen**: kertas A4, toolbar bawah (Teks/Paragraf/Sisipkan), WS listener `document-ai-response` → `replaceFromGenOffice()` |
| `spreadsheet_viewer_screen.dart` | **Viewer Excel**: grid sel, formula bar, sheet tabs, AI copilot, fetch dari GenOffice `/sheet/data` |
| `presentation_viewer_screen.dart` | Mode presentasi fullscreen (slide show) |
| `profile_screen.dart` | Profil & pengaturan user |
| `template_browser.dart` | Jelajahi template |
| `templates_storage_screen.dart` | Storage template tersimpan; `_useTemplate()` buka editor |
| `blueprint_picker_screen.dart` | Pilih blueprint sebelum generate |
| `profile_screen.dart` | Halaman profil |

---

## 🧩 `lib/widgets/` — Komponen UI

### `widgets/editor/` (bagian dari editor PPT)
| File | Tugas |
|------|-------|
| `editor_screen.dart` | Kerangka layar editor (wrapper) |
| `editor_top_nav.dart` | Nav atas: judul, tombol simpan/share |
| `editor_canvas_area.dart` | Area kanvas slide |
| `editor_toolbar.dart` | Toolbar bawah (tambah elemen, dsb.) |
| `editor_thumbnail_strip.dart` | Strip miniatur slide di samping |
| `editor_context_toolbar.dart` | Toolbar kontekstual saat elemen dipilih |
| `editor_slide_actions.dart` | Aksi per slide (duplikat, hapus, hide) |

### `widgets/ai/` & panel AI
| File | Tugas |
|------|-------|
| `ai_chat_panel.dart` | ⭐ **Chat AI utama** (ThinUI state machine): dengar WebSocket, stage outline→style→slide→done, `applyAiResult()` + `_persistChat()` |
| `ai_chat_slide_integration.dart` | Integrasi chat ↔ canvas slide |
| `thin_ui_outline_picker.dart` | Pilih outline hasil AI |
| `thin_ui_style_picker.dart` | Pilih gaya visual |
| `thin_ui_progress.dart` | Kartu progres generate |
| `outline_preview.dart` | Preview outline |
| `sketch_ai_panel.dart` | Panel "AI Coret" (vision model lihat sketsa) |

### Panel & tool editor
| File | Tugas |
|------|-------|
| `slide_canvas.dart` | ⭐ Render 1 slide (zoom, posisi, elemen) |
| `element_painter.dart` | Cat elemen ke canvas |
| `draw_canvas.dart` | Tangan bebas / coret-coret |
| `insert_panel.dart` | Sisip elemen baru |
| `layout_panel.dart` | Pilih layout |
| `template_panel.dart` | Pilih template |
| `background_panel.dart` | Ganti latar slide |
| `transition_panel.dart` | Transisi antar slide |
| `chart_editor_panel.dart` | Edit chart |
| `table_editor_panel.dart` | Edit tabel |
| `color_picker_dialog.dart` | Pilih warna |
| `icon_picker.dart` | Pilih ikon |
| `image_editor.dart` | Edit gambar |
| `text_editor_bottom_sheet.dart` | Edit teks via bottom sheet |
| `grid_view.dart` | View grid semua slide |
| `search_panel.dart` | Cari di dalam deck |
| `outline_panel.dart` | Panel outline |
| `comments_panel.dart` + `element_comments.dart` | Komentar per elemen |
| `presence_overlay.dart` | Siapa yang sedang online (collab) |
| `version_history.dart` | Riwayat versi |
| `share_dialog.dart` | Dialog share/export |
| `presentation_mode.dart` | Mode slideshow |
| `slide_thumbnail_strip.dart` | Strip thumbnail |
| `slide_error_boundary.dart` | Tangkap error render slide |
| `slide_options_picker.dart` + `slide_options_example.dart` | Pilih opsi gaya slide |
| `sheet_chart.dart` | Chart untuk sheet |
| `html_slide_template_view.dart` + `html_template_preview.dart` | Render template HTML |
| `deck_progress_card.dart` (di `widgets/ai/`) | Kartu progres deck |
| `outline_preview.dart` | Preview outline |

---

## 🔧 `lib/services/` — Logika & Integrasi

### Penyimpanan
| File | Tugas |
|------|-------|
| `storage_service.dart` | ⭐ **Hive local storage**: project, slides per project, dokumen, chat session, CRDT snapshot, schema versioning (reset otomatis kalau schema berubah) |
| `settings_service.dart` | Pengaturan app (shared_preferences) |
| `deck_blueprint_storage.dart` | Simpan muat blueprint |
| `project_service.dart` | Service CRUD project |

### AI & API
| File | Tugas |
|------|-------|
| `api_client.dart` | ⭐ HTTP client ke GenOffice (`127.0.0.1:3001`): `openDocumentWorkspace`, `chatCompletions`, prompt dokumen |
| `ai_generation.dart` | Generate slide via AI |
| `ai_errors.dart` | Penerjemah pesan error AI → bahasa manusia |
| `genoffice_sheets.dart` | Service Excel: `openSheet`, `getData`, `prompt`, `export` ke GenOffice |
| `skill_loader.dart` | Muat skill AI dari disk |
| `style_skill.dart` | Skill gaya visual |

### Export / Import PPT
| File | Tugas |
|------|-------|
| `pptx_export.dart` | Export slide → file `.pptx` |
| `pptx_builder.dart` | Bangun file PPTX (ZIP/XML) |
| `pptx_engine.dart` | Mesin rendering PPTX |
| `pptx_import.dart` | Import file `.pptx` → slide |
| `svg_export.dart` + `svg_export_service.dart` | Export slide → SVG |
| `svg_path.dart` | Parser path SVG (`M/L/Q/C/Z`) |
| `svg_to_slide_elements.dart` | Konversi SVG → `SlideElement` |
| `preview_service.dart` | Render preview |

### Template
| File | Tugas |
|------|-------|
| `template_renderer.dart` | Render template → widget |
| `template_converter.dart` | Konversi antar format template |
| `template_widget_registry.dart` | Registry widget per jenis template |
| `html_template_parser.dart` | Parse template HTML |
| `slide_spec.dart` | Spesifikasi isi slide |

### Lain-lain
| File | Tugas |
|------|-------|
| `file_reader.dart` (+ `_mobile`/`_web`) | Baca file lintas platform (conditional import) |
| `web_download.dart` (+ `_selector`/`_stub`) | Download file di web vs desktop |
| `html_viewer_stub.dart` / `html_viewer_web.dart` | Buka HTML lintas platform |
| `import/import_service.dart` | Service import generik |
| `quality_check.dart` | QC slide hasil generate |

---

## 🤖 `lib/agent_core/` — Mesin AI Agent

| File | Tugas |
|------|-------|
| `agent_core.dart` | Ekspor publik seluruh agent core |
| `loop.dart` | ⭐ **Agent loop**: kirim pesan → tunggu balasan → putuskan aksi selanjutnya |
| `types.dart` | Tipe data agent (Message, Role, dsb.) |
| `http_chat_transport.dart` | Transport HTTP ke LLM API (bawa streaming) |
| `skill.dart` | Abstraksi skill yang bisa dipanggil agent |
| `slides_skill.dart` | Skill khusus generate slide |
| `outline_json.dart` | Parse/validasi outline JSON dari AI |
| `docucraft_run_coordinator.dart` | ⭐ Koordinator satu run generate (state machine + progress) |
| `ai_page_generator.dart` | Generator halaman/slide |
| `qc_service.dart` | QC hasil generate sebelum ditampilkan |

---

## ⚙️ `lib/ai/`

| File | Tugas |
|------|-------|
| `run_state_machine.dart` | State machine run AI: `outline → style → slide → progress → done` (dipakai ThinUI di chat panel) |

---

## 🤝 `lib/collab/` — Kolaborasi Real-time

| File | Tugas |
|------|-------|
| `collab_web_socket_provider.dart` | Koneksi WebSocket ke server collab |
| `sync_engine.dart` | Mesin sinkronisasi state antar klien |
| `conflict_resolver.dart` | Selesaikan konflik edit bersamaan |
| `offline_queue.dart` | Antrian edit saat offline |
| `presence.dart` | Status online user lain |

---

## 🔬 `lib/src/` — Kode Internal

### `src/crdt/` — CRDT (Conflict-free Replicated Data Type)
| File | Tugas |
|------|-------|
| `crdt.dart` | Core CRDT |
| `doc.dart`, `container.dart` | Dokumen & container CRDT |
| `text_crdt.dart` | CRDT untuk teks (operational transform) |
| `sequence_index.dart`, `fractional_index.dart` | Penomoran urutan stabil |
| `lww_map.dart` | Map Last-Write-Wins |
| `diff.dart` | Hitung beda antar versi |
| `encoding.dart`, `json_path.dart` | Encoding & path JSON |
| `id.dart`, `version_vector.dart` | ID unik & version vector |
| `undo.dart` | Undo untuk CRDT |
| `example_usage.dart` | Contoh pemakaian |

### `src/ffi/` — Foreign Function Interface (Rust)
| File | Tugas |
|------|-------|
| `collab_factory.dart` | Factory pilih implementasi collab (CRDT vs legacy) |
| `collab_websocket_crdt.dart` | WebSocket + CRDT (Loro via Rust) |
| `crdt_provider.dart` | Provider CRDT |
| `slide_provider_crdt.dart` | SlideProvider versi CRDT |

---

## 🎨 `lib/templates/` — Template Slide (widget per gaya)

```
templates/
├── code/          ← Gaya "Code" (15 template):
│   ├── cover_slide_template.dart        ← Slide sampul
│   ├── table_of_content_slide_template.dart ← Daftar isi
│   ├── code_block_panel.dart            ← Panel blok kode
│   ├── code_block_fitting.dart          ← Pas ukuran blok kode
│   ├── full_code_block_template.dart    ← Kode full-width
│   ├── code_output_template.dart        ← Output terminal
│   ├── code_diff_comparison_template.dart ← Diff perbandingan
│   ├── api_request_response_template.dart ← Request/response API
│   ├── terminal_command_slide_template.dart ← Perintah terminal
│   ├── cards_grid_template.dart         ← Grid kartu
│   ├── metrics_grid_template.dart       ← Grid metrik
│   ├── table_slide_template.dart        ← Tabel
│   ├── description_text_template.dart   ← Deskripsi + teks
│   ├── description_and_metrics_template.dart ← Deskripsi + metrik
│   └── file_tree_structure_template.dart ← Struktur file tree
├── swift/         ← Gaya "Swift" (9 template):
│   ├── intro_slide_template.dart        ← Intro
│   ├── simple_bullet_points_template.dart ← Bullet sederhana
│   ├── bullets_with_icons_template.dart ← Bullet + ikon
│   ├── icon_bullet_list_template.dart   ← List ikon
│   ├── image_list_template.dart         ← Daftar gambar
│   ├── metrics_template.dart            ← Metrik
│   ├── table_or_chart_template.dart     ← Tabel/chart
│   ├── timeline_template.dart           ← Timeline
│   └── table_of_contents_template.dart  ← Daftar isi
├── product_overview/
│   └── table_of_content_slide_template.dart ← TOC product overview
└── icon_mapper.dart  ← Map nama ikon → data ikon
```

---

## 🎭 `lib/themes/`

| File | Tugas |
|------|-------|
| `app_theme.dart` | Definisi warna app: `AppTheme.surface`, `.textPrimary`, `.textMuted`, `.primary`, `.success`, dsb. **Selalu pakai token ini, jangan hex hardcoded.** |

---

## 🌐 `lib/l10n/` — Lokalisisasi

| File | Tugas |
|------|-------|
| `app_localizations.dart` | Abstract class semua string (`aiChatGreeting`, `appTitle`, ...) |
| `app_localizations_en.dart` | String bahasa Inggris |
| `app_localizations_id.dart` | String bahasa Indonesia |

---

## 🧪 `test/`

Berisi unit test (`test/unit/...`) dan widget test. Jalankan:
```bash
flutter test
```

---

## 🔗 Alur Besar Integrasi (3 konten utama)

### 1. PPT (Slide)
```
User prompt di ai_chat_panel
  → HTTP /api/v1/workspace/prompt (GenOffice :3001)
  → AI generate, broadcast WebSocket (outline → style → slide → done)
  → ai_chat_panel terima stage "done"
  → applyAiResult(slides, replaceAll: true)  [slide_provider]
  → _save() → repository.updateState() → Hive
  → _persistChat() simpan riwayat chat
```

### 2. Dokumen
```
document_editor_screen buka workspace (/api/v1/document/open)
  → AI kerja di GenOffice
  → WebSocket event 'document-ai-response' / 'document-content'
  → replaceFromGenOffice(blocks)  [document_provider]
  → _saveCurrent() langsung ke Hive  ✅ (fix terbaru)
```

### 3. Excel
```
spreadsheet_viewer_screen → /api/v1/sheet/open
  → _sendPrompt() → /api/v1/sheet/prompt
  → tunggu 800ms → _fetchCellData() → /api/v1/sheet/data
  → data tetap di disk GenOffice (file .xlsx)
```

---

## ✅ Checklist Menambah File Baru

1. **Model baru** → `lib/models/` + `toJson`/`fromJson`
2. **State baru** → `lib/providers/` (ChangeNotifier, selalu `_save()` setelah mutasi)
3. **Halaman baru** → `lib/screens/`
4. **Komponen UI** → `lib/widgets/`
5. **Integrasi API/storage** → `lib/services/`
6. **Tambah header komentar** di baris pertama:
   ```dart
   // DocuCraft — <Nama File> (<Tugas singkat>)
   // <Penjelasan 1-2 baris>
   ```
7. **Jangan hex hardcoded** untuk warna UI → pakai `AppTheme.*`
8. **Jalankan** `flutter analyze` dan `flutter test`
