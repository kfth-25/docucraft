# 🔍 Analisis Alur Template — Dari Data → Halaman → Workspace

> **Tanggal**: 9 Agustus 2026
> **Status**: Komplet — semua titik render terpetakan

---

## 🗺️ Peta Lengkap: Dimana Template Dirender

```
┌────────────────────────────────────────────────────────────────────────┐
│                    SUMBER DATA TEMPLATE (5 sumber)                      │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  1. HTML files          assets/templates/intro-slide.html              │
│  2. TSX presets         presenton-templates/*.tsx  (231+ layouts)      │
│  3. JSON layouts        assets/templates/{group}/*.json (249 files)    │
│  4. TemplateRegistry    lib/models/template_registry.dart              │
│     ├── loadSwiftLayouts() → layoutData{layoutId: TemplateLayoutData}  │
│     ├── loadStandardLayouts()                                          │
│     ├── loadModernLayouts()                                            │
│     └── loadGeneralLayouts()                                           │
│  5. TemplateWidgetRegistry (BARU)                                      │
│     └── layoutId → Widget Flutter (IntroSlideTemplate)                 │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────────────┐
│              HALAMAN TEMPLATE (4 tempat UI)                            │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  A. DashboardScreen          → _templateOption() 3 pilihan hardcoded   │
│  B. TemplatesStorageScreen   → _templateCard() Grid + detail dialog    │
│  C. TemplateBrowser          → _useTemplate() List + ExpansionTile     │
│  D. TemplatePanel (editor)   → _applyTheme() DraggableScrollableSheet  │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────────────┐
│              RENDER PREVIEW (2 mekanisme)                              │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  • TemplateRenderer  → render JSON layout → widget preview             │
│    (dipakai di B, C, D — pakai data JSON)                              │
│  • HtmlTemplatePreview → iframe HTML (web) / TemplateRenderer (mobile) │
│    (dipakai di C — pakai file HTML)                                    │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────────────┐
│              APPLY KE SLIDE (3 mekanisme — KONFLIK!)                   │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  1. Dashboard:    TemplateConverter.fromLayoutData → elements[]        │
│  2. Browser:      TemplateConverter.fromLayoutData → elements[]        │
│  3. Storage:      TemplateConverter.fromLayoutData → elements[]        │
│  4. Panel:        TemplateEngine.applyLayoutData → elements[]          │
│  5. initHtml:     layoutId + templateData → IntroSlideTemplate ✅      │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────────────┐
│              RENDER WORKSPACE (SlideCanvas)                            │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  if (TemplateWidgetRegistry.has(slide.layoutId))  → WIDGET penuh ✅    │
│  else if (slide.elements.isNotEmpty)              → elemen terpisah ❌ │
│  else                                             → title + subtitle   │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 🚨 Temuan Utama — 3 Masalah Struktural

### Masalah 1: 5 sumber data, 2 model data, 4 cara apply

| Sumber | Model yang dipakai | Hasil di Workspace |
|--------|-------------------|-------------------|
| HTML (`intro-slide.html`) | `layoutId` + `templateData` | ✅ Widget penuh |
| JSON (249 files) | `elements[]` (parse) | ❌ Elemen terpisah |
| TSX (231 layouts) | `elements[]` (parse) | ❌ Elemen terpisah |
| TemplateWidgetRegistry | `layoutId` + `templateData` | ✅ Widget penuh |
| TemplateRegistry | `layoutId` + `templateData` (baru) | ✅ (belum semua flow) |

### Masalah 2: Preview ≠ Apply (lihat beda, dapat beda)

```
User lihat di halaman template:
  TemplateRenderer (JSON) → render bagus 16:9

User tap "Use Template":
  TemplateConverter.fromLayoutData → elements[] parse
  → posisi hardcoded salah → BERANTAKAN di workspace
```

**Preview pakai renderer JSON (benar), apply pakai parse elements (salah).**
Preview dan apply pakai mekanisme berbeda → **ekspektasi vs realita gap**.

### Masalah 3: `TemplateWidgetRegistry` baru 1 template

```dart
static final Map<String, TemplateWidgetBuilder> _templates = {
  'intro-slide-layout': (data) => IntroSlideTemplate(...),  // ← cuma 1!
};
```

Dari 249 JSON layouts + 231 TSX layouts, cuma 1 yang punya widget Flutter. Sisanya fallback ke parse elements (berantakan).

---

## ✅ Logika yang BENAR (target)

```
User pilih template di halaman manapun
        │
        ▼
TemplateWidgetRegistry.build(layoutId, data)
        │
        ├── Ada widget? → render widget penuh ✅
        │
        └── Tidak ada → fallback TemplateRenderer (JSON) sebagai
            "template locked" — bukan elements parse
        │
        ▼
SlideCanvas:
  if layoutId != null:
    widget = TemplateWidgetRegistry.build(layoutId, data)
    if widget != null → render widget
    else → render TemplateRenderer(layoutData) (static preview)
  else:
    render elements[] (user-editable)
```

**Kunci:** Semua halaman harus pakai **model yang sama**:
```dart
slide.layoutId = layout.layoutId;
slide.templateData = {...};
slide.elements = [];  // KOSONG — jangan parse!
```

---

## 📋 Fix yang Dibutuhkan

| # | File | Fix |
|---|------|-----|
| 1 | `templates_storage_screen.dart` `_useTemplate()` | Ganti `TemplateConverter.fromLayoutData` → set `layoutId` + `templateData` |
| 2 | `template_browser.dart` `_useTemplate()` | Sudah fix ✅ (layoutId + templateData) |
| 3 | `template_panel.dart` `_applyTheme()` | Sudah fix ✅ (layoutId + templateData) |
| 4 | `dashboard_screen.dart` | Sudah fix ✅ (tidak override) |
| 5 | `SlideCanvas` | Tambah fallback: layoutId ada tapi widget tidak dikenal → render `TemplateRenderer` (static), bukan elements |
| 6 | `TemplateWidgetRegistry` | Tambah lebih banyak template widget (dari 231 layouts) |

---

## 🎯 Kesimpulan

**Preview vs Apply gap** adalah akar masalah "template berantakan di workspace":
- Preview: `TemplateRenderer` (JSON render) — benar
- Apply: `TemplateConverter` (parse elements) — salah posisi

**Solusi:** Semua apply harus set `layoutId` + `templateData` (model Presenton), dan `SlideCanvas` render widget dari registry. Kalau widget belum ada → render `TemplateRenderer` statis (sama dengan preview), bukan parse elements.
