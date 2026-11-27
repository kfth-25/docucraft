# 📐 Arsitektur PPT Master — Dokumentasi Lengkap

> **Versi**: 4.5.0
> **Lisensi**: MIT
> **Repo**: https://github.com/hugohe3/ppt-master
> **Terakhir diperbarui**: 2026-08-27

---

## 📑 Daftar Isi

1. [Filosofi & Paradigma](#1-filosofi--paradigma)
2. [Arsitektur Tinggi](#2-arsitektur-tinggi)
3. [Struktur Direktori](#3-struktur-direktori)
4. [Sistem Routing](#4-sistem-routing)
5. [Empat Route Top-Level](#5-empat-route-top-level)
6. [Pipeline Default Generate (Step 1–7)](#6-pipeline-default-generate-step-17)
7. [Tiga Runtime Role](#7-tiga-runtime-role)
8. [Profiles (Quick, Beautify, Image-to-PPTX)](#8-profiles)
9. [Stages (Sub-Routines)](#9-stages)
10. [Scripts & Tools](#10-scripts--tools)
11. [Quality Gates & Checker](#11-quality-gates--checker)
12. [Alur Data & Artifact Ownership](#12-alur-data--artifact-ownership)
13. [Konvensi Wajib & Hard Rules](#13-konvensi-wajib--hard-rules)
14. [Diagram Alur Lengkap](#14-diagram-alur-lengkap)

---

## 1. Filosofi & Paradigma

PPT Master adalah **routed workflow** — bukan linear pipeline. Setiap request masuk melalui **deterministic routing** yang memilih tepat **satu** route, lalu route tersebut memiliki otoritas penuh atas eksekusi.

### Prinsip Inti

| Prinsip | Arti |
|---|---|
| **Serial execution** | Langkah dieksekusi berurutan, tidak boleh loncat |
| **Blocking = stop** | Di setiap gate `⛔ BLOCKING`, agent WAIT konfirmasi user |
| **No cross-phase bundling** | Tidak boleh gabung kerja di atas gate yang belum tertutup |
| **Selected authority only** | Setelah routing, hanya baca dokumen route terpilih — tidak boleh load route lain |
| **Deterministic routing** | Tidak boleh tanya "mau route A atau B?" kalau request sudah jelas cocok satu route |
| **SVG = page design source** | `svg_output/` adalah sumber kebenaran visual — bukan template, bukan spec |

### Satu-satunya PPTX Route yang Didukung

```
svg_output/  →  svg_to_pptx.py converter  →  DrawingML/Native PPTX
```

Tidak ada jalan pintas. Tidak ada generator Python/Node yang menulis PPTX langsung. Semua melewati SVG sebagai intermediate representation.

---

## 2. Arsitektur Tinggi

```
┌─────────────────────────────────────────────────────────────────┐
│                     USER REQUEST                                │
│         (topik, file, gambar, template, perintah)               │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │   SKILL.md (Entry)     │
              │  attribution_guard.py  │
              └────────────┬───────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │    routing.md          │
              │  (Deterministic Route  │
              │   Selection)           │
              └────────────┬───────────┘
                           │
           ┌───────────────┼───────────────┬────────────────┐
           ▼               ▼               ▼                ▼
    ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
    │  Generate   │ │   Create    │ │    Fill     │ │   Enhance   │
    │    PPTX     │ │  Template   │ │ Native PPTX │ │ Native PPTX │
    └──────┬──────┘ └──────┬──────┘ └──────┬──────┘ └──────┬──────┘
           │               │               │               │
           ▼               ▼               ▼               ▼
    ┌──────────────────────────────────────────────────────────────┐
    │              RUNTIME AUTHORITY                               │
    │  (generate-pptx.md / quick-generate.md / create-template.md  │
    │   / template-fill-pptx.md / native-enhance-pptx.md)          │
    └──────────────────────────────────────────────────────────────┘
                           │
                           ▼
    ┌──────────────────────────────────────────────────────────────┐
    │              ROLES & STAGES & SCRIPTS                        │
    │  Strategist │ Executor │ Image Generator │ Template Designer │
    └──────────────────────────────────────────────────────────────┘
```

---

## 3. Struktur Direktori

```
skills/ppt-master/
├── SKILL.md                          # Entry point — global discipline
├── .env.example                      # Environment variables template
├── LICENSE                           # MIT License
├── SPONSORS.md / SPONSORS_CN.md      # Optional sponsor info
│
├── workflows/                        # ══ ROUTE AUTHORITIES ══
│   ├── routing.md                    # ← Deterministic route selection
│   ├── generate-pptx.md              # ← Default Generate (Step 1–7)
│   ├── create-template.md            # ← Create Template route
│   ├── template-fill-pptx.md         # ← Fill Native PPTX route
│   ├── native-enhance-pptx.md        # ← Enhance Native PPTX route
│   ├── index.md                      # Workflow index
│   │
│   ├── profiles/                     # ← Generate sub-profiles
│   │   ├── quick-generate.md         #   Quick runtime (no interaction)
│   │   ├── beautify-pptx.md          #   1:1 visual upgrade
│   │   └── image-to-pptx.md          #   Codex page reconstruction
│   │
│   ├── stages/                       # ← Conditional sub-routines
│   │   ├── topic-research.md         #   Fact research gate
│   │   ├── apply-template-workspace.md
│   │   ├── customize-animations.md
│   │   ├── generate-audio.md
│   │   ├── live-preview.md
│   │   ├── refine-spec.md
│   │   ├── resume-execute.md
│   │   ├── verify-charts.md
│   │   └── visual-review.md
│   │
│   ├── create-template/              # ← Create Template children
│   │   ├── create-brand.md
│   │   ├── create-style.md
│   │   ├── create-layout.md
│   │   └── create-deck.md
│   │
│   └── governance/
│       └── failure-recovery.md       # Stop/continue policy
│
├── references/                       # ══ ROLE CORES & TECH MODULES ══
│   ├── shared-standards-core.md      # Mandatory SVG foundation
│   ├── svg-effects.md                # Advanced effects & geometry
│   ├── semantic-svg.md               # Semantic marker system
│   ├── canvas-formats.md             # Canvas format table
│   ├── animations.md                 # Animation system
│   ├── video-design.md               # Video/narration design
│   ├── native-data-interface.md      # Chart/table native metadata
│   ├── pptx-structure-interface.md   # Structured PPTX contract
│   ├── native-shape-authoring.md     # Native shape authoring
│   ├── svg-image-embedding.md        # Image embedding rules
│   │
│   ├── strategist.md                 # ← Strategist role core
│   ├── strategist-template.md        # Strategist + template logic
│   ├── strategist-image.md           # Strategist image planning
│   │
│   ├── executor-base.md              # ← Executor flat core
│   ├── executor-structured.md        # Executor structured mode
│   ├── executor-chart.md             # Chart construction
│   ├── executor-image.md             # Image handling
│   ├── executor-notes.md             # Speaker notes
│   ├── executor-structure.md         # Qualitative geometry
│   ├── executor-table.md             # Table construction
│   ├── executor-visualization.md     # Chart/table SVG
│   ├── executor-web-image.md         # Web-sourced images
│   │
│   ├── template-designer.md          # ← Template Designer role
│   ├── image-base.md                 # Image foundation
│   ├── image-generator.md            # AI image generation
│   ├── image-layout-spec.md          # Image layout spec
│   ├── image-layout-patterns.md      # Image layout patterns
│   ├── image-searcher.md             # Image search
│   ├── visual-review.md              # Visual review rules
│   ├── artifact-ownership.md         # Artifact ownership rules
│   │
│   ├── modes/                        # Narrative modes (briefing, narrative, etc.)
│   ├── visual-styles/                # Visual style presets (18 styles)
│   ├── image-palettes/               # AI image palettes (12 palettes)
│   ├── image-renderings/             # AI image renderings (18 renderings)
│   ├── image-type-templates/         # Image type templates (11 types)
│   └── ai-image-comparison/          # Visual comparison assets
│
├── scripts/                          # ══ RUNNABLE TOOLS ══
│   ├── source_to_md.py               # Universal source → Markdown
│   ├── project_manager.py            # Project lifecycle (init/validate/scaffold)
│   ├── svg_quality_checker.py        # SVG contract validation
│   ├── svg_to_pptx.py                # SVG → PPTX converter (main)
│   ├── image_gen.py                  # AI image generation
│   ├── latex_render.py               # LaTeX formula rendering
│   ├── icon_sync.py                  # Icon library sync
│   ├── sound_sync.py                 # Sound library sync
│   ├── native_enhance_pptx.py        # Native PPTX enhancement
│   ├── template_fill_pptx.py         # Template fill engine
│   ├── animation_config.py           # Animation scaffolding
│   ├── confirm_ui/                   # Confirm UI server (HTML/JS)
│   ├── svg_editor/                   # Live SVG editor server
│   ├── pptx_to_svg/                  # PPTX → SVG converter (for import)
│   ├── svg_to_pptx/                  # Full SVG→PPTX conversion engine
│   ├── image_backends/               # Multi-provider image generation backends
│   ├── image_sources/                # Free image search providers
│   ├── tts_backends/                 # TTS backends (Edge, ElevenLabs, etc.)
│   └── docs/                         # Script documentation
│
└── templates/                        # ══ TEMPLATE LIBRARY ══
    ├── brands/                       # Brand presets + brands_index.json
    ├── styles/                       # Style presets + styles_index.json
    ├── layouts/                      # Layout presets + layouts_index.json
    ├── decks/                        # Deck presets + decks_index.json
    ├── icons/                        # Icon library (curated bundled pool)
    ├── design_spec_reference.md      # Design Spec template
    └── spec_lock_reference.md        # Spec Lock template
```

---

## 4. Sistem Routing

### Routing Authority: `workflows/routing.md`

Routing adalah proses **deterministic** memilih tepat **satu** route top-level. Agent TIDAK BOLEH menawarkan menu pilihan route kalau request sudah cocok satu route.

### Routing Matrix

| Route | Request Shape | Authority |
|---|---|---|
| **Generate PPTX** | Buat/reconstruct/regenerate dari topik atau sumber | `generate-pptx.md` / `quick-generate.md` / profiles |
| **Create Template** | Buat reusable brand/style/layout/deck workspace | `create-template.md` |
| **Fill Native PPTX** | Isi slide shell PPTX yang sudah ada dengan konten baru | `template-fill-pptx.md` |
| **Enhance Native PPTX** | Tambah notes/audio/timings ke PPTX jadi | `native-enhance-pptx.md` |

### Disambiguasi Route

Kalau request ambigu tentang deck yang sudah ada, agent tanya **satu** discriminator question saja:

> "Mau regenerate slide yang terlihat, isi native slide shell dengan konten baru, atau pertahankan slide dan tambah native behavior?"

---

## 5. Empat Route Top-Level

### 5.1 Generate PPTX

**Pipeline**: `Sources → Research → Project → Template Candidates → Stage-1 Confirm → Stage-2 Solution → Images → SVG Authoring → Quality Check → Export`

**Dua Runtime**:
- **Default** (`generate-pptx.md`): Step 1–7, interactive confirmation, spec/lock
- **Quick** (`quick-generate.md`): No interaction, no spec/lock, direct SVG→PPTX

**Dua Fidelity Profile** (mutually exclusive):
- **Image to PPTX** (`image-to-pptx.md`): Codex-supported, always Quick, reconstruct page frames
- **Beautify** (`beautify-pptx.md`): 1:1 preserve wording/page count, Default or Quick

### 5.2 Create Template

**Pipeline**: `Reference → Brief → Workspace → Authoring → Validation → Review`

**Empat Child Workflow** (mutually exclusive):
| Kind | Output |
|---|---|
| `brand` | Identity only (colors, typography, logo) — no SVG roster |
| `style` | Communication method + design direction — no SVG roster |
| `layout` | Brand-neutral structure + SVG roster |
| `deck` | Integrated identity + structure + SVG roster |

### 5.3 Fill Native PPTX

**Pipeline**: `Source PPTX → Analyze → Scaffold → Fill → Validate → Export`

**Mutation model**: Clone + patch melalui OOXML — **tanpa SVG pipeline**.

### 5.4 Enhance Native PPTX

**Pipeline**: `Source PPTX → Module Selection → Patch → Validate → Export`

**Mutation model**: Append/update scoped OOXML parts — **tanpa slide regeneration**.

---

## 6. Pipeline Default Generate (Step 1–7)

Ini adalah jantung PPT Master. Step 1–7 adalah urutan wajib yang tidak boleh diacak.

```
Step 1: Source Content Processing
    │
    │  (PDF/DOCX/PPTX/HTML/URL → source_to_md.py → Markdown)
    │  (Topic-only → topic-research.md → facts)
    │
    ▼
Step 2: Create Project
    │
    │  (project_manager.py init → workspace skeleton)
    │  (import-sources → analysis/)
    │
    ▼
Step 3: Template Candidate Preparation
    │
    │  (Non-interactive: prepare candidates only)
    │
    ▼
Step 4: Stage-1 + Stage-2 Confirmation
    │
    │  ┌─────────────────────────────────────┐
    │  │  STAGE 1 (BLOCKING)                 │
    │  │  • Communication contract           │
    │  │  • Template/free-design choice      │
    │  │  → Install selected workspace       │
    │  └──────────────────┬──────────────────┘
    │                     │
    │  ┌──────────────────▼──────────────────┐
    │  │  STAGE 2 (BLOCKING)                 │
    │  │  • Reading mode + visual style      │
    │  │  • Page count + color + typography  │
    │  │  • Image source + rendering         │
    │  │  • 3 design directions → select 1   │
    │  │  → Write design_spec.md + spec_lock │
    │  └──────────────────┬──────────────────┘
    │                     │
    ▼
Step 5: Image Acquisition
    │
    │  (image_gen.py / image_search.py / slice_images.py)
    │
    ▼
Step 6: SVG Authoring (Executor)
    │
    │  (Hand-write every page SVG in svg_output/)
    │  (P01 → first-page gate → remaining pages → final gate)
    │
    ▼
Step 7: Quality Check + Post-processing + Export
    │
    │  (svg_quality_checker.py → finalize_svg.py → svg_to_pptx.py)
    │  (animations/transitions/notes/audio patch)
    │  (pptx_delivery_check.py → exports/)
    │
    ▼
    ✅ FINAL PPTX
```

### Step 1: Source Content Processing

**Input**: PDF, DOCX, XLSX, PPTX, EPUB, HTML, LaTeX, RST, URL, CSV, Markdown

**Tool**: `source_to_md.py` — universal dispatcher yang route by source type.

**Topic-only trigger**: Kalau input cuma topik tanpa fakta, jalankan `topic-research.md` untuk kumpulkan fakta.

**Sufficiency test**: Research hanya untuk avoid inventing/omitting factual claims — bukan untuk panjang-pendeknya sumber.

### Step 2: Create Project

**Tool**: `project_manager.py init <name> --format ppt169`

Membuat workspace skeleton:
```
<project>/
├── images/
├── icons/
├── svg_output/
├── svg_final/
├── templates/
├── analysis/
├── design_spec.md
├── spec_lock.md
└── exports/
```

### Step 3: Template Candidate Preparation

**Non-interactive**: Agent prepare candidates tanpa bertanya. Template content TIDAK boleh dibaca sampai Stage-1 confirmation.

### Step 4: Stage-1 + Stage-2 Confirmation

**Dua stage confirmation** (default flow via Confirm UI):

| Stage | Apa yang dikonfirmasi |
|---|---|
| **Stage 1** | `primary_language`, audience, communication intent, core message, canvas, template/free-design choice |
| **Stage 2** | Reading mode, visual style, page count, color, icon, typography, image source, 3 design directions |

**Output**: `design_spec.md` + `spec_lock.md` — ditulis sekali, tidak di-scaffold.

### Step 5: Image Acquisition

**Multi-path**:
- AI generation: `image_gen.py --manifest`
- Free search: `image_search.py` (Pexels, Pixabay, Wikimedia, Openverse)
- Formula: `latex_render.py`
- Slice grid: `slice_images.py`

### Step 6: SVG Authoring (Executor)

**Hard rule**: Agent **hand-write** setiap page SVG. Tidak boleh delegate ke Python/Node generator.

**Cadence**: `P01 → first-page gate → remaining pages → final gate`

**Grouped batches dan mid-run checker calls DILARANG.**

### Step 7: Quality Check + Export

```
svg_output/
    │
    ▼
svg_quality_checker.py    ← Validasi kontrak SVG
    │
    ▼
finalize_svg.py           ← Self-contained visual preview (svg_final/)
    │
    ▼
svg_to_pptx.py            ← SVG → DrawingML converter
    │
    ▼
[Optional Patches]
    ├── pptx_animations.py
    ├── pptx_transitions.py
    ├── notes_to_audio.py
    └── narration_sync.py
    │
    ▼
pptx_delivery_check.py    ← Final validation
    │
    ▼
exports/<project>.pptx    ← ✅ FINAL OUTPUT
```

---

## 7. Tiga Runtime Role

PPT Master membagi eksekusi menjadi **tiga role** yang punya otoritas terpisah:

### 7.1 Strategist

**File**: `references/strategist.md`

**Pipeline Position**: Step 3–4 (setelah project creation, sebelum Executor)

**Tugas**:
- Content analysis & design planning
- Author `design_spec.md` (Design Specification & Content Outline)
- Stage-1 communication contract confirmation
- Stage-2 solution + 3 design directions
- Template application planning (setelah workspace installed)

**Hard rule**: Stage-1 source boundary — tidak boleh baca candidate workspace sebelum Stage-1 confirmed.

### 7.2 Executor

**File**: `references/executor-base.md` + conditional branches

**Pipeline Position**: Step 6 (SVG authoring)

**Tugas**:
- Hand-write setiap page SVG di `svg_output/`
- Apply visual style, color, typography dari spec_lock
- Integrate images, charts, tables, icons
- Run Visual Job Router dari `svg-effects.md` §6.1

**Conditional branches** (load only when triggered):
| Trigger | Branch |
|---|---|
| `pptx_structure.mode: structured` | `executor-structured.md` |
| Chart/Table reference | `executor-visualization.md` + `executor-chart.md` |
| Value-driven geometry | `executor-chart.md` |
| Qualitative geometry | `executor-structure.md` |
| Cell grid / table | `executor-table.md` |
| Image/formula | `executor-image.md` + layout specs |
| Web-sourced image | `executor-web-image.md` |
| Speaker notes enabled | `executor-notes.md` |

### 7.3 Image Generator

**File**: `references/image-generator.md`

**Pipeline Position**: Step 5 (setelah Stage-2 confirmed)

**Tugas**:
- Generate AI images via `image_gen.py`
- Search free images via `image_search.py`
- Render formulas via `latex_render.py`
- Slice grid sheets via `slice_images.py`

**Multi-provider backends**: OpenAI, Gemini, Ideogram, BFL, Fal, Replicate, Stability, Qwen, Minimax, SiliconFlow, Volcengine, Zhipu, ModelScope, OpenRouter

### 7.4 Template Designer

**File**: `references/template-designer.md`

**Pipeline Position**: Create Template route (create-layout / create-deck)

**Tugas**:
- Generate reusable structured page templates
- Write `design_spec.md` for template workspace
- Handle PPTX reference import via `pptx_template_import.py`
- Support replication modes: `standard`, `fidelity`, `mirror`

---

## 8. Profiles

### 8.1 Quick Generate

**Trigger**: Explicit "quick", "fast", "skip-strategy", "langsung"

**Ciri**:
- No interaction / no confirmation gates
- No spec/lock
- Agent decides everything
- Hand-author SVG directly
- Run lockless final checker
- Export

**Hard rule**: Once selected, Quick adalah complete runtime — tidak boleh load `generate-pptx.md`.

### 8.2 Beautify

**Trigger**: Existing PPTX harus preserve wording, page count, page order 1:1

**Ciri**:
- Default runtime (kalau tidak explicit Quick)
- Quick runtime (kalau explicit Quick intent)
- Visual upgrade tanpa mengubah konten

**Mutually exclusive** dengan Image to PPTX.

### 8.3 Image to PPTX

**Trigger**: One or more raster files represent page frames untuk reconstruct

**Ciri**:
- Always Quick (no Default option)
- Codex-supported
- Normalize page frames
- One frame → one slide
- Restore text natively
- Reconstruct low-resolution graphics without changing identity

**Mutually exclusive** dengan Beautify.

---

## 9. Stages (Sub-Routines)

Stages adalah sub-routines yang **conditional** — hanya dijalankan ketika trigger-nya aktif.

| Stage | Trigger | Fungsi |
|---|---|---|
| `topic-research.md` | Topic-only atau factual gaps | Kumpulkan fakta eksternal |
| `apply-template-workspace.md` | Template selected in Stage-1 | Validate + install workspace |
| `customize-animations.md` | `animations.json` exists OR explicit per-slide control | Per-slide/object animation |
| `generate-audio.md` | Narration enabled OR explicit narration request | TTS audio generation |
| `live-preview.md` | Preview/selection request outside Image-to-PPTX | Interactive live preview |
| `refine-spec.md` | Explicit spec refinement opt-in | Chat-based spec revision |
| `resume-execute.md` | Split-mode project resumes | Resume mid-run |
| `verify-charts.md` | Data charts exist | Chart validation |
| `visual-review.md` | Explicit visual review request | Visual review gate |

---

## 10. Scripts & Tools

### 10.1 Source Conversion

| Tool | Fungsi |
|---|---|
| `source_to_md.py` | Universal dispatcher: PDF/DOCX/PPTX/HTML/URL → Markdown |
| `pptx_to_svg/` | PPTX → SVG converter (untuk import/analysis) |
| `pptx_template_import.py` | PPTX template import workspace preparation |

### 10.2 Project Management

| Tool | Fungsi |
|---|---|
| `project_manager.py` | Init, import-sources, scaffold-spec, scaffold-lock, validate |
| `update_spec.py` | Deck-wide color/typography substitution |
| `register_template.py` | Register workspace to index |

### 10.3 Image & Media

| Tool | Fungsi |
|---|---|
| `image_gen.py` | AI image generation (manifest mode) |
| `image_search.py` | Free image search (Pexels/Pixabay/Wikimedia/Openverse) |
| `slice_images.py` | Grid sheet → individual elements |
| `analyze_images.py` | Image analysis |
| `rotate_images.py` | Image orientation correction |
| `latex_render.py` | LaTeX formula → PNG/SVG |
| `gemini_watermark_remover.py` | Watermark removal |

### 10.4 SVG Pipeline

| Tool | Fungsi |
|---|---|
| `svg_quality_checker.py` | SVG contract validation (mandatory) |
| `finalize_svg.py` | Self-contained visual preview |
| `svg_to_pptx.py` | SVG → PPTX converter (main export) |
| `svg_editor/server.py` | Live SVG editor (browser) |
| `compact_svg_coordinates.py` | Coordinate compaction |
| `extract_svg_pictures.py` | Complex `<g>` → SVG picture asset |
| `shape_boolean_svg.py` | Shape boolean operations (stdout only) |
| `preset_shape_svg.py` | Preset shape SVG fragments (stdout only) |

### 10.5 PPTX Pipeline

| Tool | Fungsi |
|---|---|
| `svg_to_pptx/` | Full SVG→PPTX conversion engine |
| `native_enhance_pptx.py` | Native PPTX enhancement (OOXML patch) |
| `template_fill_pptx.py` | Template fill engine |
| `pptx_animations.py` | Animation patching |
| `pptx_transitions.py` | Transition patching |
| `pptx_delivery_check.py` | Final delivery validation |
| `pptx_opc_validation.py` | OPC validation |

### 10.6 Audio & Video

| Tool | Fungsi |
|---|---|
| `notes_to_audio.py` | Speaker notes → TTS audio |
| `narration_sync.py` | Narration sync |
| `sound_sync.py` | Sound library sync |
| `video_motion_plan.py` | Video motion planning |
| `video_sound_mix.py` | Audio/video mixing |
| `video_subtitles.py` | Subtitle generation |
| `powerpoint_video.py` | PPTX → MP4 export |

### 10.7 UI Servers

| Tool | Fungsi |
|---|---|
| `confirm_ui/server.py` | Stage-1/Stage-2 confirmation UI |
| `svg_editor/server.py` | Live SVG editor UI |

---

## 11. Quality Gates & Checker

### 11.1 SVG Quality Checker

**Tool**: `svg_quality_checker.py`

**Mandatory**: Jalankan sebelum export.

**Yang dicek**:
- XML validity
- Required/Forbidden properties contract
- Conditional interface compliance
- Unknown inline visual property detection
- Converter compatibility

**Fail-closed**: Hanya properties dan conditional interfaces yang terdaftar di `shared-standards-core.md` dan `svg-effects.md` yang diizinkan.

### 11.2 Fidelity Labels

| Label | Arti |
|---|---|
| `Native-stable` | PPTX menggunakan native DrawingML property — semantics retained |
| `Native-normalized` | Target editable DrawingML equivalent, tapi dinormalisasi (freeform, run property, simplified paint) |
| `Approximate` | DrawingML tidak punya exact equivalent — perlu output review |
| `Bake-required` | Effect di luar native contract — pre-render ke image atau rebuild dengan supported geometry |

### 11.3 Delivery Check

**Tool**: `pptx_delivery_check.py`

Final validation sebelum output masuk `exports/`.

---

## 12. Alur Data & Artifact Ownership

### 12.1 Artifact Hierarchy

```
Sources (user input)
    │
    ▼
source_to_md.py → Markdown + conversion profile
    │
    ▼
project_manager.py init → Workspace skeleton
    │
    ▼
project_manager.py import-sources → analysis/
    │
    ▼
[Strategist] → design_spec.md + spec_lock.md
    │
    ▼
[Image Generator] → images/ + image_manifest.json
    │
    ▼
[Executor] → svg_output/*.svg
    │
    ▼
svg_quality_checker.py → validation report
    │
    ▼
finalize_svg.py → svg_final/*.svg (visual preview)
    │
    ▼
svg_to_pptx.py → exports/*.pptx
    │
    ▼
[Optional Patches] → animations/transitions/notes/audio
    │
    ▼
pptx_delivery_check.py → ✅ FINAL PPTX
```

### 12.2 Artifact Ownership Rules

**File**: `references/artifact-ownership.md`

| Artifact | Owner | Boleh di-write oleh |
|---|---|---|
| `design_spec.md` | Strategist | Strategist only (Step 4) |
| `spec_lock.md` | Strategist | Strategist only (Step 4) |
| `svg_output/*.svg` | Executor | Executor only (Step 6) |
| `images/*` | Image Generator | Image Generator only (Step 5) |
| `exports/*.pptx` | Pipeline | svg_to_pptx.py + patches |

**Regeneration rule**: Kalau gagal, repair atau regenerate artifact yang memiliki masalah — tidak boleh downgrade silently.

---

## 13. Konvensi Wajib & Hard Rules

### 13.1 SVG Authoring

| Rule | Arti |
|---|---|
| **Generated authoring is fail-closed** | Hanya properties/interfaces yang terdaftar di `shared-standards-core.md` / `svg-effects.md` yang diizinkan |
| **One-way fidelity vocabulary** | Label `Native-stable/dll` hanya menjelaskan path `svg_output/` → PPTX, bukan sebaliknya |
| **Shape-first page authority** | Setiap visible object ADA di final page SVG — template/spec bukan overlay |
| **Flat structure default** | Free-design/brand-only/style-only = `pptx_structure.mode: flat` — no Master/Layout |
| **No direct structure grafting** | Tidak boleh tambah Master/Layout ke PPTX/SVG yang sudah ada — harus via Create Template |

### 13.2 Execution Discipline

| Rule | Arti |
|---|---|
| **Serial execution** | Ikut urutan step, tidak boleh loncat |
| **Blocking = stop** | Di gate `⛔ BLOCKING`, WAIT user confirmation |
| **No cross-phase bundling** | Tidak gabung kerja di atas gate terbuka |
| **No speculative execution** | Tidak prepare artifact fase berikutnya lebih awal |
| **Deterministic routing** | Tidak tanya route kalau sudah jelas |
| **Owning-source recovery** | Fix dari sumber, jangan downgrade |

### 13.3 Template Boundaries

| Rule | Arti |
|---|---|
| **No automatic structure upgrade** | Repeated objects tidak trigger `structured` mode |
| **No fuzzy resolution** | Jangan resolve bare name ke local template directory |
| **One Stage-1 confirmation** | Template content tidak dibaca sampai confirmation |
| **Delayed template reading** | Install selected roots baru setelah Stage-1 confirmed |

### 13.4 Role Boundaries

| Rule | Arti |
|---|---|
| **Selected authority only** | Setelah routing, hanya baca dokumen route terpilih |
| **Stage-1 source boundary** | Strategist tidak baca candidate workspace sebelum Stage-1 confirmed |
| **Executor hand-write** | Agent hand-write setiap SVG — tidak delegate ke generator |
| **No grouped batches** | SVG cadence: P01 → gate → remaining → final gate |

---

## 14. Diagram Alur Lengkap

```
╔══════════════════════════════════════════════════════════════════════════╗
║                        PPT MASTER v4.5.0                                ║
║                  AI-Driven Presentation Workflow                        ║
╚══════════════════════════════════════════════════════════════════════════╝

                         ┌─────────────────┐
                         │   USER INPUT    │
                         └────────┬────────┘
                                  │
                                  ▼
                    ┌─────────────────────────┐
                    │  attribution_guard.py   │
                    │  (Integrity Gate)       │
                    └────────────┬────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │     routing.md          │
                    │  (Route Selection)      │
                    └────────────┬────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
         ▼                       ▼                       ▼
   ┌──────────┐           ┌──────────┐           ┌──────────┐
   │ GENERATE │           │  CREATE  │           │  NATIVE  │
   │   PPTX   │           │ TEMPLATE │           │  PPTX    │
   └────┬─────┘           └────┬─────┘           └────┬─────┘
        │                      │                     │
        ▼                      ▼                     ▼
   ┌──────────────────────────────────────────────────────────┐
   │                    ROUTE AUTHORITY                       │
   │  generate-pptx.md │ quick-generate.md │ create-template │
   │  template-fill-pptx.md │ native-enhance-pptx.md         │
   └──────────────────────────┬───────────────────────────────┘
                              │
                              ▼
   ┌──────────────────────────────────────────────────────────┐
   │                    STEP 1: SOURCE                        │
   │  source_to_md.py → Markdown │ topic-research.md → facts │
   └──────────────────────────┬───────────────────────────────┘
                              │
                              ▼
   ┌──────────────────────────────────────────────────────────┐
   │                    STEP 2: PROJECT                       │
   │  project_manager.py init → workspace skeleton            │
   └──────────────────────────┬───────────────────────────────┘
                              │
                              ▼
   ┌──────────────────────────────────────────────────────────┐
   │               STEP 3: TEMPLATE CANDIDATES                │
   │  Non-interactive preparation                             │
   └──────────────────────────┬───────────────────────────────┘
                              │
                              ▼
   ┌──────────────────────────────────────────────────────────┐
   │              STEP 4: STRATEGIST CONFIRMATION             │
   │  ┌────────────────────────────────────────────────────┐  │
   │  │ STAGE 1 (BLOCKING)                                 │  │
   │  │  Communication contract + template choice          │  │
   │  └────────────────────┬───────────────────────────────┘  │
   │                       ▼                                  │
   │  ┌────────────────────────────────────────────────────┐  │
   │  │ STAGE 2 (BLOCKING)                                 │  │
   │  │  3 design directions → select 1 → write spec+lock  │  │
   │  └────────────────────┬───────────────────────────────┘  │
   └───────────────────────┼──────────────────────────────────┘
                           │
                           ▼
   ┌──────────────────────────────────────────────────────────┐
   │               STEP 5: IMAGE ACQUISITION                  │
   │  image_gen.py │ image_search.py │ latex_render.py       │
   └──────────────────────────┬───────────────────────────────┘
                              │
                              ▼
   ┌──────────────────────────────────────────────────────────┐
   │               STEP 6: EXECUTOR SVG AUTHORING             │
   │  Hand-write every page SVG in svg_output/                │
   │  P01 → first-page gate → remaining → final gate          │
   └──────────────────────────┬───────────────────────────────┘
                              │
                              ▼
   ┌──────────────────────────────────────────────────────────┐
   │            STEP 7: QUALITY CHECK + EXPORT                │
   │  svg_quality_checker.py → finalize_svg.py → svg_to_pptx  │
   │  → animations/transitions/notes/audio → delivery_check   │
   └──────────────────────────┬───────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  exports/*.pptx │
                    │   ✅ FINAL      │
                    └─────────────────┘


╔══════════════════════════════════════════════════════════════════════════╗
║                         ROLE ARCHITECTURE                               ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║   ┌──────────────┐     ┌──────────────┐     ┌──────────────┐            ║
║   │  STRATEGIST  │     │   EXECUTOR   │     │   IMAGE      │            ║
║   │              │     │              │     │  GENERATOR   │            ║
║   │ Step 3-4     │     │ Step 6       │     │ Step 5       │            ║
║   │              │     │              │     │              │            ║
║   │ design_spec  │     │ svg_output/  │     │ images/      │            ║
║   │ spec_lock    │     │ (hand-write) │     │ image_manifest│           ║
║   └──────────────┘     └──────────────┘     └──────────────┘            ║
║          │                    │                    │                    ║
║          ▼                    ▼                    ▼                    ║
║   ┌──────────────────────────────────────────────────────────┐          ║
║   │              CONDITIONAL BRANCHES                        │          ║
║   │  strategist-template.md │ executor-chart.md              │          ║
║   │  strategist-image.md   │ executor-image.md              │          ║
║   │  executor-structured   │ executor-notes.md              │          ║
║   │  executor-table.md     │ executor-visualization.md      │          ║
║   └──────────────────────────────────────────────────────────┘          ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝


╔══════════════════════════════════════════════════════════════════════════╗
║                      QUALITY GATE LIFECYCLE                             ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║   svg_output/                                                            ║
║       │                                                                  ║
║       ▼                                                                  ║
║   ┌─────────────────────┐                                                ║
║   │ svg_quality_checker │ ← Validasi kontrak SVG (mandatory)             ║
║   └──────────┬──────────┘                                                ║
║              │                                                           ║
║              ▼                                                           ║
║   ┌─────────────────────┐                                                ║
║   │   finalize_svg.py   │ ← Self-contained visual preview (svg_final/)   ║
║   └──────────┬──────────┘                                                ║
║              │                                                           ║
║              ▼                                                           ║
║   ┌─────────────────────┐                                                ║
║   │   svg_to_pptx.py    │ ← SVG → DrawingML converter                    ║
║   └──────────┬──────────┘                                                ║
║              │                                                           ║
║              ▼                                                           ║
║   ┌─────────────────────────────────────────────────────┐                ║
║   │              OPTIONAL PATCHES                       │                ║
║   │  pptx_animations.py │ pptx_transitions.py          │                ║
║   │  notes_to_audio.py  │ narration_sync.py            │                ║
║   └──────────┬──────────────────────────────────────────┘                ║
║              │                                                           ║
║              ▼                                                           ║
║   ┌─────────────────────┐                                                ║
║   │ pptx_delivery_check │ ← Final validation                             ║
║   └──────────┬──────────┘                                                ║
║              │                                                           ║
║              ▼                                                           ║
║       exports/*.pptx  ✅                                                 ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
```

---

## 📚 Referensi Cepat

| Butuh | File |
|---|---|
| Route selection | `workflows/routing.md` |
| Default pipeline | `workflows/generate-pptx.md` |
| Quick runtime | `workflows/profiles/quick-generate.md` |
| SVG foundation | `references/shared-standards-core.md` |
| SVG effects | `references/svg-effects.md` |
| Strategist role | `references/strategist.md` |
| Executor role | `references/executor-base.md` |
| Template Designer | `references/template-designer.md` |
| Image generation | `references/image-generator.md` |
| Artifact ownership | `references/artifact-ownership.md` |
| Failure recovery | `workflows/governance/failure-recovery.md` |
| Confirm UI | `scripts/docs/confirm_ui.md` |
| Conversion docs | `scripts/docs/conversion.md` |
| SVG pipeline docs | `scripts/docs/svg-pipeline.md` |

---

*Dokumentasi ini mencakup seluruh arsitektur PPT Master v4.5.0 — 4 route top-level, 3 runtime role, 9 stages, 100+ scripts, dan ratusan reference files yang membentuk satu routed presentation workflow yang koheren.*
