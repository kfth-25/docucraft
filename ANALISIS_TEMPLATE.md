# 🔍 Analisis — Template HTML Tidak Muncul di Workspace

> **Tanggal**: 9 Agustus 2026
> **Status**: Root cause ditemukan — fix menunggu

---

## 🎯 Gejala

User membuat presentasi baru → template HTML (`intro-slide.html`) **tidak muncul** di workspace editor. Yang tampil hanya slide blank/default.

---

## 🔬 Investigasi

### Jalur Alur (trace lengkap)

```
Dashboard "Buat Baru"
    ↓
SlideProvider.createNewProject()
    → save project_list (tanpa slide) ✅
    ↓
openProject() → initFromStorage()
    → loadFromStorage() → slides kosong → fallback ✅
    ↓
initWithHtmlTemplate()
    → HtmlTemplateParser.loadFromAsset('assets/templates/intro-slide.html', data)
        ↓
        parse(html, data)
        ├── replace __PLACEHOLDER__ ✅
        ├── _extractBgColor() ✅
        ├── _extractElementsV3()  ← ❌ MUNGKIN GAGAL
        └── return Slide / null
    ↓
    slide == null → fallback ke Slide blank indigo ← ❌ YANG USER LIHAT
```

### 🚨 Root Cause Utama: `XmlDocument.parse()` GAGAL pada HTML non-well-formed

Parser V3 menggunakan `package:xml` → `XmlDocument.parse()` — **sangat strict** (harus XML valid).

`intro-slide.html` berisi tag **void tanpa self-closing**:

```html
<meta charset="UTF-8">          ← ❌ INVALID XML (tidak di-close, tidak self-closing)
```

XML/`package:xml` **mewajibkan** semua tag di-close atau self-closing (`<meta ... />`).
`XmlDocument.parse` akan **melempar exception** → `parse()` catch → `return null` → `initWithHtmlTemplate` fallback ke slide blank.

**Bukti:** Kode `print('HTML template parse error: $e')` di line 55 akan menampilkan error di console browser — tapi parser tidak pernah sampai ke `_extractElementsV3` karena parse XML gagal lebih dulu.

### Masalah Sekunder (kalau XML parse diperbaiki)

1. **`walk()` position inheritance tidak konsisten**:
   - `.content` (parent) → `left:96, top:220` — absolute → OK
   - Tapi `.title` (child) tanpa `position:absolute` → x,y inherited dari parent → OK
   - **Masalah**: childY di-recursed pakai `x` parent (bukan x child) — untuk `.image-panel` (absolute, right:0) children img di-position dari x=0, bukan dari x=1229

2. **Style tag di-parse sebagai XML element** — `<style>` berisi `{}` dan `:` — package:xml akan parse sebagai text node — OK, tapi content `{` `}` di dalamnya perlu di-escape kalau strict. (Kemungkinan aman.)

3. **`<title>Intro Slide</title>` di `<head>`** — innerText "Intro Slide" akan ikut ter-render sebagai elemen text (karena isLeaf + text isNotEmpty). Perlu di-skip tag `title`/`style`/`script`.

---

## 🛠️ Rencana Fix

### Fix 1 (CRITICAL): Pre-process HTML sebelum `XmlDocument.parse`

```dart
// Self-closing untuk void tags (meta, link, br, hr, input, img)
cleaned = cleaned.replaceAllMapped(
  RegExp(r'<(meta|link|br|hr|input|img)([^>]*)>', caseSensitive: false),
  (m) => m.group(0)!.endsWith('/>') ? m.group(0)! : '<${m.group(1)}${m.group(2)} />',
);
```

### Fix 2: Skip tag non-content (`title`, `style`, `script`, `head`)

```dart
// Di walk():
if (tag == 'style' || tag == 'script' || tag == 'title' || tag == 'head') return;
```

### Fix 3: Fallback ke regex V2 kalau XML parse tetap gagal

```dart
XmlDocument? doc;
try {
  doc = XmlDocument.parse(cleaned);
} catch (e) {
  print('⚠️ XML parse gagal, fallback ke regex V2: $e');
  return _extractElementsV2(html);  // regex-based, tidak strict
}
```

---

## ✅ Verifikasi

Setelah fix:
1. `dart analyze` → 0 errors
2. Buat project baru → console muncul `🎨 Parser V3: bg=custom_FFFFFF,FFFFFF elements=N`
3. Template muncul dengan: header, title 64px, paragraph, intro card, image panel, diamonds, footer

---

## 📌 Kesimpulan

**Template tidak muncul karena `XmlDocument.parse` gagal pada HTML yang tidak well-formed (`<meta charset="UTF-8">`).** Parser selalu return `null` → app fallback ke blank slide. Perlu pre-processing HTML + fallback ke regex parser supaya robust.
