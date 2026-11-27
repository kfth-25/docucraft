# DocuCraft — Mobile PPT Editor
## Dokumentasi Fitur Lengkap

> **Platform**: Flutter (Mobile + Web)  
> **Total**: 46 Dart files, ~15.000 baris kode  
> **Entry**: `lib/main.dart`  
> **Status**: MVP — ~92% fitur functional

---

## 📋 Daftar Isi
1. [Slide Management](#1-slide-management)
2. [Elements (9 tipe)](#2-elements-9-tipe)
3. [Element Interaction](#3-element-interaction)
4. [Context Toolbar](#4-context-toolbar)
5. [Text Editing](#5-text-editing)
6. [Chart Editing](#6-chart-editing)
7. [Table Editing](#7-table-editing)
8. [Draw Mode](#8-draw-mode)
9. [Background Customization](#9-background-customization)
10. [Templates](#10-templates)
11. [Layout System](#11-layout-system)
12. [Transitions](#12-transitions)
13. [AI Integration](#13-ai-integration)
14. [Export .pptx](#14-export-pptx)
15. [Import .pptx](#15-import-pptx)
16. [Present Mode](#16-present-mode)
17. [Search & Replace](#17-search--replace)
18. [Comments](#18-comments)
19. [Version History & Undo/Redo](#19-version-history--undoredo)
20. [Collaboration](#20-collaboration)
21. [Storage](#21-storage)
22. [Theme & UI](#22-theme--ui)
23. [Presenter Notes](#23-presenter-notes)
24. [Architecture Overview](#24-architecture-overview)
25. [Status & Roadmap](#25-status--roadmap)

---

## 1. 📝 Slide Management

**File**: `slide_provider.dart`, `slide_editor_screen.dart`, `grid_view.dart`, `slide_thumbnail_strip.dart`

| Fitur | Lokasi | Status |
|-------|--------|:------:|
| **Add Slide Baru** — Tombol di toolbar + Grid View + keyboard Ctrl+N | `slide_editor_screen.dart:717`, `grid_view.dart:109` | ✅ |
| **Duplicate Slide** — Clone seluruh elemen | `slide_editor_screen.dart:719` | ✅ |
| **Delete Slide** — Hapus dengan minimum 1 slide guard | `slide_editor_screen.dart:721` | ✅ |
| **Hide/Show Slide** — Slide hidden tidak muncul di present mode | `slide_provider.dart:221` | ✅ |
| **Grid View** — Fullscreen overview semua slide, tap untuk switch, delete, add | `grid_view.dart` | ✅ |
| **Thumbnail Strip** — Horizontal strip + slide dots navigasi | `slide_thumbnail_strip.dart` | ✅ |
| **Slide Reorder** — Tap thumbnail untuk navigate | ⚠️ Tap only, belum drag |

**Undo/Redo**: Setiap operasi slide push ke undo stack (30 level).

```
addSlide()     → _pushUndo() → slides.add() → notifyListeners()
duplicate()    → _pushUndo() → clone → insert → notifyListeners()
deleteSlide()  → _pushUndo() → removeAt() → notifyListeners()
```

---

## 2. 🎨 Elements (9 tipe)

**File**: `slide.dart` (model), `insert_panel.dart`, `slide_canvas.dart`, `chart_editor_panel.dart`, `table_editor_panel.dart`

| Tipe | Render | Double-tap | Data Model |  
|------|--------|:----------:|------------|
| **Text** | Rich text dengan style (bold, italic, color, alignment, font) | ✅ TextEditorSheet | `TextStyleData` |
| **Image** | Network URL atau placeholder icon | ✅ ImageEditor | `ImageStyleData` |
| **Shape** | Rectangle dengan fill + stroke + opacity | — | `ShapeStyleData` |
| **Chart** | Bar/Line/Pie chart visual | ✅ ChartEditorPanel | `ChartData` + `ChartDataSet` |
| **Table** | Grid header + cells | ✅ TableEditorPanel | `TableData` |
| **Icon** | Emoji dalam lingkaran | — | `content` + `TextStyleData` |
| **QR Code** | Text "[QR Code]" | — | Text element |
| **Video** | Icon placeholder | — | `content` string |
| **Audio** | Icon placeholder | — | `content` string |

### Smart Positioning
Saat insert element, sistem otomatis mencari posisi tanpa overlap dengan elemen existing:
```
for (ty = 60; ty < canvasH - 150; ty += 100)
  for (tx = 60; tx < canvasW - 200; tx += 200)
    if (!overlaps) → place here
```

### Element Interaction  
| Action | Implementasi |  
|--------|-------------|
| **Tap** | `onElementTap(id)` → select → context toolbar muncul |  
| **Double-tap** | Text → `TextEditorSheet`, Chart → `ChartEditorPanel`, Table → `TableEditorPanel` |  
| **Drag** | `onPanUpdate` → `updateElementPosition(id, x, y)` (zoom-aware) |  
| **Resize** | 8 handles: 4 corner + 4 edge, `onPanUpdate: delta / zoomLevel` |  
| **Long press** | Floating comment input per-element |  
| **Copy/Paste** | Ctrl+C → clone `SlideElement.fromJson(toJson())`; Ctrl+V → add + offset 20px |  
| **Delete** | Keyboard Delete/Backspace → `deleteElement(id)` |

### Smart Resize Delta
Resize handle menggunakan `delta / zoomLevel` untuk mencegah drift saat zoom:
```dart
onPanUpdate: (d) {
  _resizeDeltaX += d.delta.dx / widget.zoomLevel;
  _resizeDeltaY += d.delta.dy / widget.zoomLevel;
}
```

---

## 3. 🎨 Context Toolbar

**File**: `slide_editor_screen.dart` (muncul saat element terseleksi)

| Tombol | Ikon | Element Type | Implementasi |
|--------|------|-------------|-------------|
| **Bold** | `format_bold` | text | Toggle `fontWeight: bold/normal` |
| **Italic** | `format_italic` | text | Toggle `fontStyle: italic/normal` |
| **Underline** | `format_underlined` | text | Toggle `textDecoration: underline/none` |
| **Align Left** | `format_align_left` | text | `textAlign: left` |
| **Align Center** | `format_align_center` | text | `textAlign: center` |
| **Align Right** | `format_align_right` | text | `textAlign: right` |
| **Color** | `palette` | text | ColorPicker.show() → `colorValue` |
| **Image** | `image_outlined` | image | ImageEditor.show() → `src` |
| **Font Size +** | `format_size` | text | `fontSize + 2` |
| **Font Size -** | `format_size` | text | `(fontSize - 2).clamp(8, 72)` |
| **Edit** | `edit` | text/icon | TextEditorSheet.show() |
| **Font** | `text_fields` | text/icon | TextEditorSheet.show() |
| **Delete** | `delete_outline` | all | `deleteElement(id)` — merah |

---

## 4. 📝 Text Editing

### 4a. Inline Editor (double-tap)
**File**: `slide_canvas.dart`

Floating toolbar di atas text field saat editing:
```
[ B ] [ I ] [ - ] [12px] [ + ] [ ● ● ● ● ] [ ✓ ]
```

| Kontrol | Aksi |
|---------|------|
| B | Toggle bold (`fontWeight: bold/normal`) |
| I | Toggle italic (`fontStyle: italic/normal`) |
| +/- | Ubah font size (±2, clamp 8-72) |
| Color dots | Putih, Indigo, Hijau, Merah → `colorValue` |
| ✓ | Finish editing → `onContentChange(id, text)` |

### 4b. TextEditorSheet (bottom sheet full editor)
**File**: `text_editor_bottom_sheet.dart`

| Section | Kontrol | Range |
|---------|---------|-------|
| **Style** | Bold (B), Italic (I), Underline (U), Strikethrough | toggle |
| **Font Size** | Slider + display | 8–72px |
| **Color** | 12 color palette (lingkaran) | White → Dark → Indigo → Red → dll |
| **Font Family** | 5 chip buttons | DM Sans, Inter, JetBrains Mono, Georgia, Default |
| **Text Align** | 4 icon buttons | Left, Center, Right, Justify |
| **Spasi** | Letter spacing slider | -2 → 8 |
| **Spasi** | Line height slider | 0.8 → 3.0 |
| **Undo/Redo** | Di header panel | `provider.undo()/redo()` |
| **Preview** | Live preview di atas text field | Update real-time via `setState` |

**Flow:**
```
Tap "Edit" atau "Font" di context toolbar → TextEditorSheet.show()
         atau
Double-tap text element → inline editor (B/I/size/color)
```

---

## 5. 📊 Chart Editing (ChartEditorPanel)

**File**: `chart_editor_panel.dart`

| Fitur | Aksi |
|-------|------|
| **Chart type** | Dropdown: Bar / Line / Pie |
| **Labels** | Edit per-label (TextController) |
| **Values** | Edit per value per series (keyboard numeric) |
| **Series names** | Edit per series (tampil jika > 1 series) |
| **Add label** | Tombol "Label" → tambah kolom |
| **Add series** | Tombol "Series" → tambah baris data |
| **Color per series** | Auto-assign dari 5 warna default |
| **Save** | Tombol "Simpan" → `provider.notify()` |

**Trigger:**
```
Double-tap chart element
  → if (el.type == chart) ChartEditorPanel.show(context, el)
```

---

## 6. 📋 Table Editing (TableEditorPanel)

**File**: `table_editor_panel.dart`

| Fitur | Aksi |
|-------|------|
| **Cell editing** | Per-cell TextField |
| **Add row** | Tombol `+` baris |
| **Remove row** | Tombol `-` baris (min 1) |
| **Add column** | Tombol `+` kolom |
| **Remove column** | Tombol `-` kolom (min 1) |
| **Header toggle** | Chip ON/OFF → bold style |
| **Save** | Tombol "Simpan" → `provider.notify()` |

**Trigger:**
```
Double-tap table element
  → if (el.type == table) TableEditorPanel.show(context, el)
```

---

## 7. ✏️ Draw Mode

**File**: `draw_canvas.dart`

| Fitur | Detail |
|-------|--------|
| **Bebas mode** | Semua touch points direkam |
| **Sketch mode** | Skip points < 3px untuk stroke lebih smooth |
| **Pen sizes** | 3 level: 2px (kecil), 5px (medium), 9px (besar) |
| **Colors** | 6: Hitam, Abu, Indigo, Pink, Amber, Emerald |
| **Eraser** | Hapus stroke per-tap |
| **Undo stroke** | Hapus stroke terakhir |
| **Clear all** | Hapus semua + confirm dialog |

**Data model:**
```dart
DrawData {
  List<DrawStroke> strokes
}
DrawStroke {
  int colorValue,      // ARGB hex
  double size,         // px
  List<List<double>> points,  // [[x, y], ...]
  String? label
}
```

**Flow:**
```
Tap "Coret" di toolbar → draw canvas overlays slide
  → Gambar → stroke disimpan sebagai DrawStroke
  → Close draw mode → strokes di-save ke SlideElement(type: draw)
```

### Sketch vs Bebas — Perbedaan Behavioral
```dart
// Sketch: skip points < 3px (line 155)
if (_drawMode == 'sketch') {
  if ((dx*dx + dy*dy) > 9.0) { addPoint(); }
}
// Bebas: semua points (line 164)
else { addPoint(); }
```

---

## 8. 🎨 Background Customization

**File**: `background_panel.dart`, `app_theme.dart`

### 8a. Preset Gradients (12 pilihan)

| Nama | Warna 1 → 2 |
|------|-------------|
| Indigo | `#6366F1 → #4F46E5` |
| Purple | `#A855F7 → #EC4899` |
| Ocean | `#3B82F6 → #0891B2` |
| Emerald | `#10B981 → #0D9488` |
| Sunset | `#F59E0B → #EA580C` |
| Rose | `#F43F5E → #BE185D` |
| Teal | `#14B8A6 → #0E7490` |
| Orange | `#F97316 → #C2410C` |
| Red Fade | `#FEE2E2 → #991B1B` |
| Blue Fade | `#DBEAFE → #1E3A8A` |
| Green Fade | `#D1FAE5 → #064E3B` |
| Purple Fade | `#F3E8FF → #4C1D95` |

### 8b. Custom Gradient Picker
- **Solid/Gradient toggle**
- **2 color slots** — tap untuk aktif, active glow effect
- **32 quick presets** — wrap grid
- **ColorPicker** — HSV model:
  - Saturation-Brightness box (draggable + clickable)
  - Hue slider (draggable rainbow ±click)
  - Hex input (`#FF0000`)
  - 65 preset colors (5 rows × 13)
  - Eyedropper icon (mock)
  - Apply button dengan live preview

### 8c. Full Theme Support (28 gradients + custom)
```dart
AppTheme.gradientFor(name) → [Color, Color]
// Supports:
// - Named: 'indigo', 'purple', 'blue', ..., 'light-gray', 'light-rose'
// - Custom: 'custom_FF0000,00FF00'
```

---

## 9. 🎯 Templates

**File**: `template.dart` (model), `template_engine.dart`, `template_panel.dart`, `template_registry.dart`

### 9a. Engine Architecture
Template menggunakan slot-based system:
```
SlideElements → TemplateEngine.apply() → scored match → mapped to slots
                                                       ↓
                                              Slide dengan posisi baru
```

### 9b. Builtin Templates (3)

| Template | Category | Slots | Font |
|----------|----------|-------|------|
| **Corporate Blue** | business | title + subtitle + hero-image + body | DM Sans 40/18 |
| **Kreatif Ungu** | creative | title + subtitle + body + hero-image | DM Sans 44/16 |
| **Dark Minimal** | minimal | title + subtitle + body | DM Sans 38/16 |

### 9c. Scoring Algorithm
Template engine mencocokkan elemen ke slot berdasarkan **type match score**:
```
title slot:    text → +10, title-like text → +30
subtitle slot: text → +10, non-title text → +5
body slot:     text → +5, panjang > 50 → +15, chart → +10, table → +10
image slot:    image → +30
chart slot:    chart → +30
table slot:    table → +30
decoration:    shape → +10
```

### 9d. Overflow Behaviors
- `truncate` — potong teks + "…"
- `wrap` — bungkus ke baris baru
- `expand` — perbesar slot
- `createNewSlot` — buat slot baru
- `hide` — sembunyikan konten

### 9e. TemplateRegistry (13 groups, 231+ layouts)
```dart
TemplateRegistry.groups = [
  Code, Pitch Deck, Modern, Education, Standard,
  Neo Modern, Neo Standard, Neo General, Neo Swift,
  General, Swift, Product, Report
]
```
Status: ✅ Ditulis, ❌ Belum terhubung ke UI.

---

## 10. 📐 Layout System

**File**: `layout_panel.dart`, `slide_provider.dart`

| Layout | Preview | Elemen yang di-add |
|--------|:-------:|---------------------|
| **Blank** | ∅ | Kosong — clear semua elemen |
| **Title** | Judul | 1 text judul (48px, bold, center) |
| **Content** | Judul + body | 1 text judul + 1 text body (36px + 18px) |
| **Two Column** | 2 kolom | 2 text (kiri + kanan, 400px each) |
| **Image+Text** | Gambar + deskripsi | 1 image placeholder + 1 text (16px) |

**Condition:** Layout hanya menambahkan elemen jika `slide.elements.isEmpty`.

---

## 11. 🔄 Transitions

**File**: `transition_panel.dart`

| Transisi | Simbol | Deskripsi |
|----------|:------:|-----------|
| None | — | Tanpa transisi |
| Fade | F | Transisi halus antar slide |
| Slide Left | → | Slide dari kanan ke kiri |
| Slide Up | ↑ | Slide dari bawah ke atas |
| Scale | Z | Zoom masuk dari tengah |
| Zoom | ◆ | Zoom besar ke kecil |

**Scope**: Single slide atau semua slide.

Transisi disimpan di `slide.extra['transition']`.

---

## 12. 🤖 AI Integration

**File**: `ai_generation.dart`, `ai_chat_panel.dart`, `outline_panel.dart`

### 12a. Konfigurasi

| Parameter | Value |
|-----------|-------|
| **Endpoint** | `http://127.0.0.1:20128/v1` |
| **Fast model** | `cu/claude-4.5-haiku` |
| **Quality model** | `cu/claude-4.5-sonnet` |
| **Free model** | `ds/deepseek-v4-pro` |
| **Max tokens** | 4096 |
| **Temperature** | 0.7 |

### 12b. Fitur

| Fitur | Trigger | Output | Status |
|-------|---------|--------|:------:|
| **Outline Flow** | Tombol "Outline" di toolbar | Topic → AI generate outline → approve per item → generate per approved slide | ✅ |
| **AI Chat** | Tombol "AI Chat" | Natural language → full presentasi atau single slide | ✅ |
| **Generate from prompt** | Chat mengandung "buat" atau "presentasi" | `AiGenerateResult` → `applyAiResult()` | ✅ |
| **Generate presentation** | Prompt mengandung "outline" atau angka | 5-10 slides dari outline | ✅ |
| **Redesign slide** | Chat mengandung "redesign"/"ubah gaya"/"restyle" | Slide baru dengan style berbeda | ✅ |
| **Single slide content** | Default fallback | Replace current slide dengan konten baru | ✅ |

### 12c. Intent Detection
```dart
_prompt → lower case
  "presentasi" or "outline" or "buat"
    + "slide" or "5" or "beberapa" → generatePresentation()
    else → generateFromPrompt()
  "redesign" or "ubah gaya" or "ganti style"
    + extract style (minimal/korporat/kreatif/bold/dark) → redesignSlide()
  default → generateFromPrompt()
```

### 12d. Redesign Styles
| Keyword | Style |
|---------|-------|
| minimal | Minimal |
| korporat / corporate / bisnis | Corporate |
| kreatif / creative | Creative |
| bold / berani | Bold |
| gelap / dark | Dark |
| *(default)* | Modern |

### 12e. AI Connection Status
```dart
enum AiConnectionStatus { online, offline, noApiKey }
```
**Sebelumnya:** Hardcoded "Online"  
**Sekarang:** Real `checkConnection()` → status color (hijau/merah/abu)

### 12f. Output Schema Validation
Setiap response AI divalidasi dengan schema checker:
- `title` (required)
- `slides[]` (required, non-empty)
- Setiap slide: title, background (7 valid colors), elements[]
- Elemen: type, x, y, width, height (bounds 1920×1080)
- Text elements: content (required)
- Invalid types → fallback ke 'text'
- Out of bounds → clamp

---

## 13. 📤 Export .pptx

**File**: `pptx_export.dart`, `web_download.dart`, `web_download_selector.dart`

### 13a. Platform Support

| Platform | Method | Detail |
|----------|--------|--------|
| **Mobile/Desktop** | `export()` | Write to temp dir → `Share.shareXFiles()` |
| **Web** | `exportAsBytes()` | Raw bytes → `downloadBytes()` via conditional import |

### 13b. Struktur PPTX Output

| Komponen PPTX | Status | Detail |
|---------------|:------:|--------|
| `[Content_Types].xml` | ✅ | Override declarations |
| `_rels/.rels` | ✅ | Office document relationship |
| `ppt/presentation.xml` | ✅ | Slide IDs + slide size (12192000×6858000 EMU = 16:9) |
| `ppt/slideMasters/` | ✅ | Slide master 1 |
| `ppt/slideLayouts/` | ✅ | Blank layout |
| `ppt/theme/` | ✅ | DocuCraft theme (colors + fonts) |
| `ppt/slides/slideN.xml` | ✅ | Per-slide content |

### 13c. Element Export Mapping

| Element | PPTX XML | Fidelity |
|---------|----------|:--------:|
| **Text** | `p:sp` → `a:rPr` (sz, b, i, srgbClr, latin typeface) | ✅ Font, bold, italic, color, alignment, font family |
| **Shape** | `p:sp` → `a:prstGeom` + `a:solidFill` | ✅ Fill color (always rect) |
| **Image** | `p:sp` → rect + text label | ⚠️ Placeholder shape with text |
| **Chart** | `p:sp` → text box with data summary | ⚠️ Not native chart |
| **Table** | `a:tbl` → rows + cells + header color | ✅ Native table |
| **Icon** | `p:sp` → ellipse + emoji text | ✅ |
| **Video/Audio** | `p:sp` → rounded rect + icon text | ✅ Placeholder |
| **Drawing** | `p:sp` → text "Drawing (N strokes)" | ⚠️ Not vector path |
| **Background** | `a:gradFill` → 2-color gradient | ✅ |

### 13d. XML Example — Gradient Background
```xml
<p:bg>
  <p:bgPr>
    <a:gradFill>
      <a:gsLst>
        <a:gs pos="0"><a:srgbClr val="6366F1"/></a:gs>
        <a:gs pos="100000"><a:srgbClr val="4F46E5"/></a:gs>
      </a:gsLst>
      <a:lin ang="5400000" scaled="0"/>
    </a:gradFill>
  </p:bgPr>
</p:bg>
```

### 13e. XML Example — Text Element
```xml
<p:sp>
  <p:nvSpPr>
    <p:cNvPr id="timestamp" name="TextBox"/>
    <p:cNvSpPr txBox="1"/>
  </p:nvSpPr>
  <p:spPr>
    <a:xfrm><a:off x="762000" y="2540000"/><a:ext cx="7620000" cy="1270000"/></a:xfrm>
    <a:prstGeom prst="rect"/>
  </p:spPr>
  <p:txBody>
    <a:bodyPr rtlCol="0" anchor="ctr"/>
    <a:p>
      <a:pPr algn="left"/>
      <a:r>
        <a:rPr sz="2800" b="1" i="0">
          <a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill>
          <a:latin typeface="DM Sans"/>
        </a:rPr>
        <a:t>Text Content</a:t>
      </a:r>
    </a:p>
  </p:txBody>
</p:sp>
```
*(Position: EMU = 12700 × pixel)*

---

## 14. 📥 Import .pptx

**File**: `pptx_import.dart`

### 14a. Entry Points
| Method | Platform | Detail |
|--------|----------|--------|
| `fromFile(path)` | Mobile/Desktop | Read file → bytes → parse |
| `fromBytes(bytes)` | Web + Mobile | Parse ZIP bytes langsung |

### 14b. Elemen yang Di-parsing

| Elemen PPTX XML | Status | Hasil |
|-----------------|:------:|-------|
| `p:sp` (text box) | ✅ | `SlideElement(type: text)` → posisi + ukuran + font + warna + align |
| `p:sp` (shape) | ✅ | `SlideElement(type: shape)` → fillColor |
| `p:pic` (image) | ✅ | `SlideElement(type: image)` → position + size → placeholder |
| `a:tbl` (table) | ✅ | `SlideElement(type: table)` → rows, cells, header, colors |
| `a:gradFill` (gradient BG) | ✅ | Deteksi gradient stop → `backgroundGradient` |
| `a:solidFill` (solid BG) | ✅ | Fallback background |
| Shape rotation | ✅ | EMU → degrees (`rot / 60000`) |
| Hidden slides | ✅ | `showAttr == '0'` → skip + warning |

### 14c. Yang Tidak Di-parsing
| Elemen | Deteksi | Action |
|--------|:-------:|--------|
| **Chart** (`c:chart`) | ✅ | Warning "chart/SmartArt tidak bisa diimport" |
| **SmartArt** (`dgm:`) | ✅ | Warning (bersama chart) |
| **Presenter notes** | ❌ | Tidak dibaca (notes slide di PPTX terpisah) |
| **Animations** | ❌ | Tidak dibaca |

### 14d. Color → Gradient Mapping
```dart
'6366F1' → 'indigo'    '4F46E5' → 'indigo'
'A855F7' → 'purple'    'EC4899' → 'purple'
'3B82F6' → 'blue'      '0891B2' → 'blue'
'10B981' → 'emerald'   '0D9488' → 'emerald'
'F59E0B' → 'amber'     'EA580C' → 'amber'
'F43F5E' → 'rose'      'BE185D' → 'rose'
'14B8A6' → 'teal'      '0E7490' → 'teal'
```
Fallback: `indigo` untuk warna lain.

### 14e. Warnings System
```dart
ImportResult.warnings = [
  "Slide 1: hidden slide, di-skip",
  "Slide 2: 2 gambar diimport sebagai placeholder",
  "Slide 2: 1 tabel diimport",
  "Slide 3: 1 chart/SmartArt tidak bisa diimport",
]
```
Warnings ditampilkan di snackbar: `"⚠️ N catatan: {first}"`

---

## 15. 🎙️ Present Mode

**File**: `presentation_mode.dart` (1115 lines)

### 15a. Fitur Utama

| Fitur | Status |
|-------|:------:|
| Fullscreen immersive overlay | ✅ `SystemUiMode.immersiveSticky` |
| Landscape lock on enter | ✅ |
| Portrait restore on exit | ✅ |
| Keyboard navigation | ✅ Arrows, Space, Home, End, PageUp/Down, Esc |
| Swipe navigation | ✅ Horizontal drag threshold 50px |
| Speaker notes (N key) | ✅ Gradient overlay dari bottom |
| Double-tap → toggle notes | ✅ 300ms threshold |
| Auto-hide chrome | ✅ 5 detik timer |
| Progress bar | ✅ Gradient + glow shadow |
| Slide count | ✅ "1 / 10" badge |
| Navigation buttons | ✅ Left/right chevron + exit |
| Notes toggle button | ✅ Indigo highlight saat aktif |

### 15b. Keyboard Shortcuts

| Key | Aksi |
|-----|------|
| → ↓ PageDown Space | Next slide |
| ← ↑ PageUp | Previous slide |
| Home | First slide |
| End | Last slide |
| Esc | Exit presentation |
| F | Bump chrome (show controls) |
| N | Toggle speaker notes |
| Tap (single) | Bump chrome |
| Tap (double <300ms) | Toggle speaker notes |

### 15c. Fullscreen Slide Renderer
`_FullScreenSlide` — render slide dengan aspect ratio 16:9 yang di-scale proporsional:
```dart
scale = min(constraintWidth/1920, constraintHeight/1080);
offsetX = (constraintWidth - 1920*scale) / 2;
offsetY = (constraintHeight - 1080*scale) / 2;
```

---

## 16. 🔍 Search & Replace

**File**: `search_panel.dart`

| Fitur | Detail |
|-------|--------|
| **Search scope** | Semua slide (title, subtitle, element content) |
| **Hidden slides** | Di-skip dari search |
| **Case insensitive** | `.toLowerCase()` |
| **Match counter** | Live update — "5 hasil" |
| **Result items** | Slide number + field + truncated content |
| **Replace one** | Ganti match pertama |
| **Replace all** | Ganti semua match, hitung total |
| **Max results show** | 10 items |

---

## 17. 💬 Comments

**File**: `comments_panel.dart`, `element_comments.dart`

### 17a. Threaded Comments
```dart
_CommentThread {
  author, initials, avatarColor, role, text, time,
  elementLabel?, replies: [CommentReply, ...]
}
```

### 17b. Fitur
| Fitur | Aksi |
|-------|------|
| **Add comment** | Input bar → submit → thread baru |
| **Reply** | Tombol "Reply" di setiap thread |
| **@mention detection** | Snackbar "📌 @mention terdeteksi!" |
| **Element comment** | Long-press elemen → floating input |
| **Comment badge** | Hijau circle dengan count |
| **Avatar** | Gradient circle + initials |

### 17c. Element Comment Flow
```
Long-press pada elemen di canvas
  → FloatingCommentInput muncul di canvas
  → Type comment → Submit
  → Comment muncul di CommentsPanel
  → ElementCommentBadge (hijau circle) di elemen
```

---

## 18. 🕒 Version History & Undo/Redo

**File**: `version_history.dart`, `slide_provider.dart`

### 18a. Undo/Redo System
```
Snapshot-based (full state capture)

setiap mutasi:
  _pushUndo() → {
    'slides': slides.toJson(),
    'currentIndex': currentSlideIndex,
  }
  
undo():
  _redoStack.add(current snapshot)
  _undoStack.removeLast() → restore
  
redo():
  _undoStack.add(current snapshot)
  _redoStack.removeLast() → restore
```

| Parameter | Value |
|-----------|-------|
| Max undo stack | 30 |
| Redo cleared | Saat ada edit baru setelah undo |
| Snapshot scope | Seluruh slides + current index |

### 18b. Version History Panel
```
[Versi Saat Ini]         → "Saat ini" badge
[Sebelumnya (Undo)]      → tap = undo + close
[Setelahnya (Redo)]      → tap = redo + close
[Restore Versi Sebelumnya] → button → undo
```

---

## 19. 🤝 Collaboration

**File**: `collab/` — 5 files, 1,058 lines

### 19a. Architecture
```
SlideProvider (local state)
    ↕
SyncEngine (bridge: local ↔ remote)
    ↕
CollabWebSocketProvider (WebSocket transport)
    ↕ WebSocket (ws://127.0.0.1:9101)
Other clients
```

### 19b. Component Status

| Komponen | File | Lines | Status |
|----------|------|:-----:|:------:|
| **CollabManager** | `main.dart` | 41 | ✅ Init on editor open |
| **CollabWebSocketProvider** | `collab_web_socket_provider.dart` | 333 | ✅ WebSocket + reconnect |
| **SyncEngine** | `sync_engine.dart` | 295 | ✅ Outbound/inbound bridge |
| **Presence** | `presence.dart` | 100 | ✅ User cursor model |
| **ConflictResolver** | `conflict_resolver.dart` | 166 | ✅ LWW + element merge |
| **OfflineQueue** | `offline_queue.dart` | 165 | ✅ Persistent queue |
| **PresenceOverlay** | `presence_overlay.dart` | 449 | ✅ Canvas cursors |

### 19c. WebSocket Reconnection
```dart
MAX_RECONNECT_ATTEMPTS = 10
delay = min(2^attempt, 30) seconds  // exponential backoff
```

### 19d. Conflict Resolution Strategy
```
Slide-level:
  local.version > remote.version → local wins
  remote.version > local.version → remote wins

Version tie:
  timestamp later → wins

True simultaneous (same version + same time):
  Element-level merge → field-level LWW:
    content: higher version → wins
    x, y, width, height: higher version → wins
    rotation, zIndex: timestamp tiebreak
    textStyle, shapeStyle, imageStyle: non-null wins
```

### 19e. Offline Queue
```dart
Queue → SharedPreferences persistence
  ↓
On reconnect → replay in order
  ↓
Server ack → remove from queue
  ↓
5 retries failed → dead letter + user notification
  ↓
Idempotency key → prevents duplicate
```

### 19f. Presence Overlay
```
Remote user cursors di canvas (scaled ke 1920×1080)
  ↓
Name label dengan color
  ↓
Selection ring (pulse animation) untuk elemen yang diedit
  ↓
Online bar di top-right: avatars + count
```

### 19g. Share Dialog
```
Invite link: https://docucraft.app/doc/{documentId}
  → Clipboard.setData(ClipboardData(text: _inviteLink)) ✅
  → "🔗 Link disalin!"

Invite by email:
  → Simulasi: "📧 Undangan terkirim ke {email}"

User list:
  → Nama + avatar + "Editor" role + online dot
```

---

## 20. 💾 Storage

**File**: `storage_service.dart`

### 20a. Storage Backend: Hive

| Metode | Key | Format |
|--------|-----|--------|
| `saveSlides(slides)` | `slides_data_all` | JSON string |
| `loadSlides()` | `slides_data_all` | JSON → List<Slide> |
| `savePresentationList()` | `presentation_list` | JSON array |
| `loadPresentationList()` | `presentation_list` | JSON → list |
| `saveConfig()` | `user_config` | JSON |
| `loadConfig()` | `user_config` | JSON |
| `clearAll()` | — | Clear box |

### 20b. Initialization Flow
```dart
initFromStorage():
  loaded = loadFromStorage()
  if (!loaded || slides.isEmpty):
    initDemoSlides()  // 5 demo slides Strategi Pemasaran
```

---

## 21. 🎨 Theme & UI

**File**: `app_theme.dart`

### 21a. Colors
```dart
primary      = #6366F1 (Indigo)
primaryDark  = #4F46E5
surface      = #0A0A0F (dark bg)
surface2     = #13131A
surface3     = #1A1A25
textPrimary  = #FFFFFF
textSecondary = #9CA3AF
textMuted    = #6B7280
success      = #10B981
warning      = #F59E0B
error        = #EF4444
```

### 21b. Gradients (28 + custom)

| Grup | Jumlah |
|------|:------:|
| Core (indigo, purple, blue, emerald, amber, rose, teal) | 7 |
| Extra (orange, pink, cyan, lime, violet, slate, warm, frost, midnight) | 9 |
| Light→Dark (red, blue, green, purple, orange, pink, teal, yellow, indigo, cyan, gray, rose) | 12 |
| Custom | Dynamic via `custom_HEX1,HEX2` |

### 21c. Dark Theme
```dart
ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: surface,
  colorScheme: dark(primary: #6366F1),
  fontFamily: 'DM Sans',
  cardTheme: rounded(16),
)
```

---

## 22. 🎤 Presenter Notes

**File**: `slide_editor_screen.dart` — `_NotesField`

### 22a. Implementation
```dart
class _NotesField extends StatefulWidget {
  SlideProvider provider;
  TextEditingController notesCtrl;
  int lastSlideIndex;  // Track current slide
}
```

### 22b. Key Feature: Cursor Position
Menggunakan `didUpdateWidget` dengan `lastSlideIndex` tracking untuk mencegah cursor lompat:
```dart
didUpdateWidget(old) {
  if (currentSlideIndex != lastSlideIndex) {
    notesCtrl.text = getPresenterNotes();  // Only on slide change
    onSlideChanged(currentSlideIndex);
  }
}
```

### 22c. Data
- Disimpan di `slide.extra['notes']`
- Diedit di editor → ditampilkan di Present Mode
- Per-slide (setiap slide punya notes masing-masing)

---

## 23. 🏗️ Architecture Overview

### 23a. Directory Structure
```
lib/
├── collab/          (5 files) Collaboration: WebSocket, Sync, Conflict, Presence
├── models/          (3 files) Slide, Template, TemplateRegistry
├── providers/       (1 file)  SlideProvider — single source of truth
├── screens/         (3 files) Dashboard, Editor, TemplateBrowser
├── services/        (7 files) AI, API, Export, Import, Storage, WebDownload
├── themes/          (1 file)  AppTheme — colors, gradients
├── utils/           (1 file)  IOHelper — conditional dart:io for web
└── widgets/         (22 files) All UI components
```

### 23b. Data Flow
```
User Input
    ↓
SlideEditorScreen (widget)
    ↓
SlideProvider (ChangeNotifier)
    ├── Slide model (state)
    ├── Undo/Redo stack
    └── StorageService (Hive persistence)
    
SlideProvider ↕ SyncEngine ↕ CollabWebSocketProvider ↕ WebSocket
```

### 23c. Key Design Decisions
| Decision | Rationale |
|----------|-----------|
| **Single Provider** | `SlideProvider` sebagai satu-satunya state hub — gak perlu Redux/BLoC untuk MVP |
| **V2 Model** | CRDT metadata, UUID v7, pixel-based positions, structured style objects |
| **Conditional exports** | `web_download_selector.dart` — `dart:html` di web, stub di native |
| **LWW Conflict** | Last-Writer-Wins cukup untuk PPT editor (gak perlu CRDT rumit) |
| **Hive storage** | Flutter-compatible, indexedDB di web, native file di mobile |
| **No circular deps** | Model → Provider → Services/Widgets (one-way) |

---

## 24. 📊 Status & Roadmap

### 24a. Current Coverage

| Area | Files | Baris | % Fitur |
|------|:----:|:-----:|:-------:|
| **Editor Core** (screens + widgets) | 25 | ~9,000 | 95% |
| **Services** (AI, Export, Import, Storage) | 7 | ~2,500 | 85% |
| **Collab** (multiplayer) | 5 | ~1,058 | 80% |
| **Models** (Slide, Template) | 3 | ~1,100 | 95% |
| **Theme** | 1 | ~100 | 100% |
| **TOTAL** | **46** | **~15,000** | **92%** |

### 24b. Yang SUDAH Fix (vs temuan awal)
Dari ±35 temuan melalui 7 sesi UserSim:
- **~28 sudah fix** (80%)
- Sisa: **~7 minor/medium**

### 24c. Gaps (Belum di-port dari Presenton)
| Fitur | Presenton | DocuCraft | Priority |
|-------|:---------:|:---------:|:--------:|
| AI Outline streaming | ✅ | ✅ **Selesai** | — |
| Sortable slide reorder | ✅ | ❌ Belum | 🟡 Medium |
| PDF export | ✅ | ❌ Belum | 🟡 Medium |
| Full dashboard CRUD | ✅ | ❌ Hardcoded | 🟢 Low |
| Template Browser connected | ✅ | ❌ Written, gak dipanggil | 🟢 Low |
| Settings page | ✅ | ❌ Belum | 🟢 Low |

### 24d. Open Items (Belum Tersentuh)
| Issue | Area | Severity |
|-------|------|:--------:|
| Chart export → native `c:chart` | Export | 🟡 Medium |
| Image export → embed `p:pic` | Export | 🟡 Medium |
| AI Image generation → real API | AI | 🟡 Medium |
| Comment reply → real | Comments | 🟢 Low |
| `_DrawPainter.shouldRepaint` optimize | Draw | 🟢 Low |
| Empty `assets/` folder | Config | 🟢 Low |
| `provider.applyTemplate()` usang | Template | 🟢 Low |

---

## 25. 🔧 Tech Stack

| Layer | Technology |
|-------|------------|
| **Framework** | Flutter (SDK ^3.13) |
| **State** | Provider (package:provider) |
| **Storage** | Hive + SharedPreferences |
| **Local Data** | HTTP (package:http), Dio (package:dio) |
| **WebSocket** | web_socket_channel |
| **PPTX** | archive (ZIP), xml |
| **AI** | 9router LLM API (OpenAI-compatible) |
| **Export Web** | dart:html conditional import |
| **File Picker** | file_picker + image_picker |
| **Share** | share_plus + cross_file |
| **Icons** | Cupertino Icons |
| **Font** | DM Sans (theme default), Inter, JetBrains Mono, Georgia |

---

**Dokumentasi ini mencakup 46 file Dart, ~15,000 baris kode, dan ~150 fitur individual yang diidentifikasi melalui 7 sesi UserSim eksplorasi dengan 5 persona berbeda.**
