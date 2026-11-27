# Gap Analysis: GenOffice (Reference) vs DocuCraft Flutter

**Tanggal**: 2026-09-12
**Referensi**: GenOffice `apps/slides/` → Target: `docucraft_app/lib/`

---

## Ringkasan Eksekutif

GenOffice memiliki **10+ fitur DocuCraft** yang belum di-port ke Flutter. Flutter sudah memiliki fondasi kuat (state machine, agent core, slides skill, coordinator) tetapi kehilangan beberapa komponen UX kritis yang membuat DocuCraft menjadi产品 yang kohesif.

### Status Kesiapan

| Area | GenOffice | Flutter | Status |
|------|-----------|---------|--------|
| State Machine | ✅ 8 states, 29 tests | ✅ 8 states, 29 tests | **100%** |
| Agent Core | ✅ AgentLoop + Skills | ✅ AgentLoop + Skills | **100%** |
| Slides Skill | ✅ 30+ tools | ✅ 30+ tools | **95%** |
| Coordinator | ✅ 2-stage flow | ✅ 2-stage flow | **90%** |
| Outline Preview | ✅ Editable list | ✅ Editable list | **85%** |
| Progress Card | ✅ 5 stages + real-time | ✅ 6 stages + animated | **80%** |
| **Mode Toggle** | ✅ Edit/DocuCraft tabs | ❌ Missing | **0%** |
| **Blueprint Picker** | ✅ Search + filter + fork | ❌ Missing | **0%** |
| **Session Context** | ✅ Palette + blueprint meta | ⚠️ Basic deck meta only | **20%** |
| **Live Reveal** | ✅ Streaming preview | ❌ Missing | **0%** |
| **QC Pin Store** | ✅ Subscribe pattern | ❌ Missing | **0%** |
| **Silence Watchdog** | ✅ 45s + "Thinking deeper" | ⚠️ Basic dots only | **30%** |
| **i18n** | ✅ 19 locales | ❌ EN only | **5%** |
| **CSS Design System** | ✅ Semantic tokens | ✅ Material 3 ColorScheme | **70%** |

---

## Gap Detail per Fitur

### 1. 🔴 DocuCraft Mode Tabs (CRITICAL)
**GenOffice**: `DocuCraftModeTabs.tsx` — toggle antara "Edit" (per-element) dan "DocuCraft" (full-deck generation). State `aiMode` di AiPanel. Switch disable saat busy.

**Flutter**: Tidak ada mode toggle. App selalu dalam satu mode.

**Impact**: User tidak bisa switch antara editing per-element dan full-deck generation. Ini fitur UX fundamental.

**Rekomendasi**: Buat `_ModeToggle` widget segmented button di header AI panel. State `aiMode` di `AiRunProvider`.

---

### 2. 🔴 Blueprint Picker (CRITICAL)
**GenOffice**: `BlueprintPicker.tsx` — modal picker dengan:
- Search input (case-insensitive substring match)
- Tag filter: All / Forked / Recent (5 terbaru)
- List blueprints dengan name, topic, createdAt
- Actions: Open, Fork, Delete (dengan confirm)
- GSAP-style enter/leave animation
- Escape close

**Flutter**: `SlidesSkill` punya tools `save_blueprint`, `load_blueprint`, `list_blueprints` tetapi **tidak ada UI** untuk save/load/fork/search.

**Impact**: User tidak bisa menyimpan, memuat, atau mem-fork blueprints. Fitur ini kritis untuk "build once, reuse many" workflow.

**Rekomendasi**: Buat `BlueprintPickerScreen` (modal route) dengan:
- `BlueprintPickerProvider` (tag enum + search + derived list)
- ChoiceChip filter (All/Forked/Recent)
- Search input
- BlueprintRow dengan Open/Fork/Delete actions
- Confirm-before-delete dialog

---

### 3. 🟡 Session Context (useDocucraftContext)
**GenOffice**: `useDocucraftContext.ts` — hook yang build `DeckMeta` snapshot:
- `mode`: 'docucraft' | 'edit'
- `pageCount`: total pages
- `palette`: top 3 fills + 3 text colors (e.g. `"#3B82F6×4 #1F2937×2"`)
- `blueprintId`: saved blueprint reference
- `topic`: current deck topic
- `styleSkill`: recent style template (truncated to 800 chars)
- Ref-based getter supaya skill closure selalu lihat fresh data

**Flutter**: `SlidesSkill.buildContext()` inject `<deck meta>` dengan mode + pages + topic + style. Tidak ada palette computation, tidak ada blueprint tracking.

**Impact**: Multi-turn refinement kurang aware. User bilang "ubah warna jadi biru" tapi AI tidak tahu palette saat ini.

**Rekomendasi**: Buat `useDocucraftContext` hook (atau equivalent Provider) yang compute palette dari slides + track blueprint meta.

---

### 4. 🟡 Live Reveal (useDocucraftReveal)
**GenOffice**: `useDocucraftReveal.ts` — hook observer yang:
- Observe delta `slides.length`
- Flash thumbnail saat page baru muncul
- Auto-scroll ke page terakhir
- Canvas overlay flash effect
- `prefers-reduced-motion` aware

**Flutter**: Tidak ada live streaming preview. Slides muncul satu per satu tapi tidak ada animasi reveal.

**Impact**: User tidak melihat page muncul secara real-time. Pengalaman generation terasa "batch" bukan "streaming".

**Rekomendasi**: Implement hook/observer yang detect new slides + trigger animation di thumbnail strip.

---

### 5. 🟡 QC Pinned Store
**GenOffice**: `qcPinnedStore.ts` — module-level store:
- `isPinned(i)`, `add(i)`, `remove(i)`, `toggle(i)`, `clear()`
- Subscribe pattern untuk re-render
- Hook `useQcPinned()` untuk React components
- Thumbnail pin button (hover-revealed, accent border)
- Cleared on `newChat()`

**Flutter**: `QualityChecker.check()` + `autoFix()` ada tetapi tidak ada mekanisme pin/unpin. User tidak bisa keep edit AI meskipun QC detect "audit worse".

**Impact**: User kehilangan kendali atas QC auto-revert. Tidak ada cara untuk override QC decisions.

**Rekomendasi**: Buat `QcPinnedStore` (module-level atau Provider) dengan subscribe pattern. Tambah pin button di thumbnail.

---

### 6. 🟢 Silence Watchdog
**GenOffice**: 
- 45s threshold → "Thinking deeper..." label
- 5s tick untuk check
- CSS animation `dc-silence-pulse` 1.6s ease-in-out
- `prefers-reduced-motion` fallback
- Localized di 19 shards

**Flutter**: Progress dots dengan "Thinking deeper..." label saat `isSilent` true. Tapi threshold implementation di `AiRunProvider` belum ada.

**Impact**: User tidak dapat feedback saat stream idle >45s. Bisa jadi user think app hang.

**Rekomendasi**: Implement silence watchdog di `AiRunProvider` dengan 45s threshold + 5s tick.

---

### 7. 🟢 i18n
**GenOffice**: 19 locale shards (zh, en, id, fr, de, ja, nl, it, pl, ru, th, hi, ms, ar, ko, he, es, pt, zh-TW). Type-safe via `satisfies Record<keyof typeof zh, string>`.

**Flutter**: Semua strings hardcoded English. Tidak ada i18n setup.

**Impact**: Tidak bisa localize untuk pasar non-English.

**Rekomendasi**: Setup `flutter_localizations` +ARB files. Start dengan EN + ID.

---

### 8. 🟢 System Prompt Completeness
**GenOffice**: ~300 baris system prompt dengan:
- Tool-selection principles (kapan pakai generate_deck vs regenerate_slide vs native tools)
- Editing rules (execute_slide_script preferred, batch changes)
- Deck generation pipeline (Step 0 Questionnaire → Step A Research → Step B Image → ...)
- Figure-provenance gate
- Element editing coordinate system

**Flutter**: System prompt via `SkillLoader.buildSystemPrompt('generate-pptx')` — lebih basic.

**Impact**: AI kurang guided dalam tool selection dan editing patterns.

**Rekomendasi**: Extend system prompt di Flutter dengan tool-selection principles dari GenOffice.

---

## Prioritas Implementasi

### P0 — Critical (harus segera)
1. **Blueprint Picker UI** — save/load/fork/search blueprints
2. **Mode Toggle** — switch antara edit dan docucraft mode

### P1 — Important (next sprint)
3. **Session Context Hook** — palette computation + blueprint tracking
4. **QC Pin Store** — pin/unpin mechanism dengan subscribe pattern

### P2 — Nice to Have
5. **Live Reveal Hook** — streaming preview animation
6. **Silence Watchdog** — 45s threshold + "Thinking deeper..."
7. **i18n Setup** — EN + ID minimum

### P3 — Future
8. **Extended System Prompt** — tool-selection principles
9. **Blueprint Fork UI** — fork action di picker
10. **Advanced CSS Animations** — GSAP-style keyframes

---

## File Mapping

| GenOffice File | Flutter Equivalent | Status |
|---|---|---|
| `DocuCraftModeTabs.tsx` | ❌ Not created | **Missing** |
| `BlueprintPicker.tsx` | ❌ Not created | **Missing** |
| `useDocucraftBlueprints.ts` | ❌ Not created | **Missing** |
| `useDocucraftContext.ts` | ⚠️ Basic in `slides_skill.dart:buildContext()` | **Partial** |
| `useDocucraftReveal.ts` | ❌ Not created | **Missing** |
| `qcPinnedStore.ts` | ❌ Not created | **Missing** |
| `useRunStateMachine.ts` | ✅ `providers/ai_run_provider.dart` | **Done** |
| `runStateMachine.ts` | ✅ `ai/run_state_machine.dart` | **Done** |
| `OutlinePreview.tsx` | ✅ `widgets/ai/outline_preview.dart` | **Done** |
| `slides-skill.ts` | ✅ `agent_core/slides_skill.dart` | **Done** |
| `AiPanel.tsx` | ⚠️ `widgets/ai_chat_panel.dart` | **Partial** |
| `styles.css` | ⚠️ Material 3 ColorScheme | **Partial** |

---

## Kesimpulan

Flutter sudah memiliki **fondasi arsitektur yang kuat** (state machine, agent core, coordinator). Gap utama adalah di **UX components** yang membuat DocuCraft menjadi produk yang kohesif:
1. Mode switching (edit vs docucraft)
2. Blueprint management (save/load/fork)
3. Session-aware context (palette, blueprint meta)
4. QC override mechanism (pin/unpin)

Prioritas P0 (Mode Toggle + Blueprint Picker) akan memberikan dampak UX terbesar.
