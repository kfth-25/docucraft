# 📐 Alignment DocuCraft ↔ Presenton — Arsitektur Template Rendering

> **Tanggal**: 9 Agustus 2026
> **Goal**: Bikin DocuCraft render template dengan cara yang SAMA dengan Presenton

---

## 🔬 Presenton Architecture (Source Code Analysis)

### 1. Data Model

```typescript
// Presenton Slide:
{
  layout: "intro-slide-layout",      // ← ID layout (unique)
  layout_group: "swift",             // ← ID template group
  content: {                          // ← DATA, bukan elemen!
    title: "Quarterly Review",
    paragraph: "Performance summary",
    metrics: [{ label: "Revenue", value: "$2.4M" }]
  },
  properties: { ... },
  index: 0
}
```

**KUNCI:** `content` = **plain data** (JSON), bukan elemen dengan posisi (x,y,w,h). Layout component yang menentukan posisi.

### 2. Rendering Flow

```
V1ContentRender(slide)
    ↓
Layout = getLayoutByLayoutId(slide.layout, slide.layout_group)
    ↓ return React Component
<LayoutComp data={slide.content} />
    ↓
Template TSX component render HTML dengan CSS:
  <h1 style="font-size:64px; position:absolute; left:96px; top:220px">
    {data.title}
  </h1>
    ↓
Scale ke workspace:
  transform: scale(0.24)  // 1280x720 → preview size
```

### 3. Edit Flow

```
User tap teks di dalam template
    ↓
TiptapTextReplacer intercepts text change
    ↓
dispatch(updateSlideContent({ slideIndex, dataPath: "title", content: "New Title" }))
    ↓
slide.content.title = "New Title"  // ← update DATA, bukan position
    ↓
Re-render template component → posisi/style TIDAK berubah, cuma konten berubah
```

### 4. Key Principle

```
TEMPLATE = Component (React/Flutter) yang TAHU bagaimana render data
CONTENT  = Plain data (JSON) yang TIDAK TAHU bagaimana di-render
EDITOR   = Wrapper yang intercept edit → update content → re-render
```

---

## 🏗️ DocuCraft Current vs Target

### CURRENT (salah)

```dart
// DocuCraft sekarang:
slide = Slide(
  elements: [
    SlideElement(x: 96, y: 220, width: 900, height: 80,
      type: text, content: "Title", textStyle: ...)
  ]
)
// → elemen dengan posisi = FRAGILE, susah maintain, susah ganti template
```

### TARGET (sesuai Presenton)

```dart
// DocuCraft target:
slide = Slide(
  layoutId: 'intro-slide-layout',     // ← template reference
  layoutGroup: 'swift',               // ← template group
  content: {                          // ← plain data
    'title': 'Strategi Pemasaran Digital 2026',
    'paragraph': 'Membangun brand awareness...',
    'companyName': 'Acme Corp',
  }
)
// → template component yang render data = FLEXIBLE, maintainable
```

---

## 🔄 Mapping Presenton → DocuCraft

| Presenton (React) | DocuCraft Target (Flutter) | Status |
|---|---|---|
| `LayoutComp` (TSX component) | `IntroSlideTemplate` (Widget) | ✅ Sudah dibuat |
| `slide.layout` | `slide.layoutId` | ✅ Sudah ada (templateId) |
| `slide.content` | `slide.templateData` | ⚠️ Perlu rename dari `extra` |
| `TiptapTextReplacer` | Inline edit di dalam template | ⚠️ Perlu diimplementasi |
| `ScaledSlidePreview(scale: 0.24)` | `Transform.scale + AspectRatio` | ✅ Sudah ada |
| `getLayoutByLayoutId()` | `getTemplateWidget(layoutId)` | ⚠️ Perlu dibuat |
| Template registry (allLayouts[]) | TemplateWidgetRegistry | ⚠️ Perlu dibuat |

---

## 📋 Implementation Plan

### Phase 1: Data Model Alignment
1. Rename `slide.extra` → `slide.templateData` (plain content data)
2. Rename `slide.templateId` → `slide.layoutId` (template reference)
3. Tambah `slide.layoutGroup` field

### Phase 2: Template Widget Registry
Buat `TemplateWidgetRegistry` — map layoutId → Widget builder:
```dart
class TemplateWidgetRegistry {
  static final _templates = {
    'intro-slide-layout': (data) => IntroSlideTemplate(data: data),
    'metrics-numbers': (data) => MetricsTemplate(data: data),
  };
  
  static Widget? build(String layoutId, Map<String, dynamic> data) {
    final builder = _templates[layoutId];
    return builder != null ? builder(data) : null;
  }
}
```

### Phase 3: SlideCanvas Refactor
```dart
// Ganti:
if (slide.extra?['templateType'] == 'intro')
  IntroSlideTemplate(...)

// Jadi:
if (slide.layoutId != null)
  TemplateWidgetRegistry.build(slide.layoutId!, slide.templateData ?? {})
```

### Phase 4: Inline Text Edit
Sama seperti TiptapTextReplacer — intercept tap di text → update content → re-render.

---

## 🎯 Kesimpulan

Presenton render template sebagai **component utuh yang receive data**, bukan sebagai **kumpulan elemen dengan posisi**. DocuCraft sudah punya `IntroSlideTemplate` (widget native) — tinggal align data model dan registry supaya flow-nya sama.

**Yang sudah jalan:**
- ✅ IntroSlideTemplate widget (render design asli)
- ✅ SlideCanvas render via templateType check
- ✅ Transform.scale + AspectRatio untuk scaling

**Yang perlu di-align:**
- Data model: `extra` → `templateData`, `templateId` → `layoutId`
- Template registry: `getTemplateWidget(layoutId)` 
- Inline edit: tap text → update content → re-render
