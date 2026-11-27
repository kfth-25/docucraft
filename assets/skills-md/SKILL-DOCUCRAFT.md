---
name: docucraft
description: >
  AI-driven presentation workflow for generating editable presentations in Flutter,
  reconstructing page visuals from sketches, creating reusable Brand/Style/Layout/Deck
  workspaces, filling native templates, and enhancing finished presentations.
  Use when the user asks to create, reconstruct, regenerate, template, fill, or
  enhance a presentation, requests a sketch-to-design conversion, or mentions docucraft.
metadata:
  version: "1.0.0"
  copyright: "Copyright (c) 2025-2026 DocuCraft"
  license: "MIT"
  platform: "Flutter/Dart"
  ai_models:
    - "vision: gc/gemini-3-flash-preview"
    - "fast: oc/laguna-s-2.1-free"
    - "quality: kc/nvidia/nemotron-3-ultra-550b-a55f:free"
    - "reasoning: kc/meituan/longcat-2.0-free"
---

# DocuCraft Skill

DocuCraft is a routed presentation workflow for Flutter applications. This entry owns global execution discipline and route selection only; each selected route owns its procedure.

---

## 📋 Pemahaman Alur Kerja (How It Works)

### Arsitektur Overview

```
User Request
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│                     SKILL-DOCUCRAFT.md                         │
│  → Entry point, load discipline, AI models, fallback chain     │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                     workflows/routing.md                        │
│  → Detect intent → Select route → Select profile              │
│  → 3 Routes: Generate, Create Template, Enhance               │
└────────────────────────┬────────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────�
│  Generate   │  │  Create     │  │  Enhance    │
│  Presentation│  │  Template   │  │  Presentation│
│  (Default/   │  │  (4 kinds)  │  │  (PPTX)     │
│   Quick/     │  └─────────────┘  └─────────────┘
│   Sketch)    │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────────┐
│                   7-Step Pipeline (Default)                    │
│  Step 1: Import → Step 2: Project Init → Step 3: Template     │
│  Step 4: Strategist → Step 5: Design Spec → Step 6: Executor  │
│  Step 7: Quality Check + Export                               │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Flutter/Dart App (Runtime)                   │
│  lib/                                                           │
│  ├── services/     ← Business logic (AI, QC, Import, etc)      │
│  ├── models/       ← Data structures (Slide, Template, etc)    │
│  ├── widgets/      ← UI (Chat panel, Sketch panel, etc)        │
│  └── providers/    ← State management (Provider)               │
└─────────────────────────────────────────────────────────────────┘
```

### Cara Kerja AI Chat (LLM Integration)

```
User types prompt in AiChatPanel
    │
    ▼
_processPrompt(prompt)
    │
    ├─ SkillLoader.load('workflows/generate-pptx.md')  ← SYSTEM PROMPT
    │   (dimuat dari assets/skills-md/, dibaca via rootBundle)
    │
    ├─ Detect mode: quick? sketch? default?
    │
    ├─ Build conversation context (10 pesan terakhir)
    │
    ├─ AiGenerationService.generateFromPrompt(prompt, model)
    │   │
    │   ├─ systemPrompt = skill files (generate-pptx.md)
    │   ├─ userPrompt = conversation context + user message
    │   │
    │   └─ API call → 9router (http://127.0.0.1:20128/v1)
    │       │
    │       ├─ Fallback chain:
    │       │   1. gc/gemini-3-flash-preview (vision)
    │       │   2. oc/laguna-s-2.1-free (fast)
    │       │   3. kc/nvidia/nemotron-3-ultra-550b-a55f:free (quality)
    │       │   4. kc/meituan/longcat-2.0-free (reasoning)
    │       │
    │       └─ Response: SVG string OR question
    │
    ├─ Response is SVG?
    │   ├─ YES → SvgToSlideElements.parse(svg) → Add to slide
    │   └─ NO  → Display question to user
    │
    └─ QualityChecker.check(elements) → autoFix if needed
```

### Alur Setiap Folder & File

```
skills/
├── SKILL.md                           ← ENTRY: PPT Master (Python) entry point
├── SKILL-DOCUCRAFT.md                 ← ENTRY: DocuCraft (Flutter/Dart) entry point
├── ARCHITECTURE.md                    ← DOC: How AI reads skills (diagram)
├── STATUS.md                          ← DOC: Implementation progress (100% workflows)
├── README.md                          ← DOC: Quick reference
│
├── workflows/                         ← ══ ROUTE AUTHORITIES ══
│   ├── routing.md                     ← INTENT DETECTION + route selection
│   │   ├── 4 Top-level routes (Generate, Create Template, Fill, Enhance)
│   │   ├── 5 Generation profiles (Default, Quick, Beautify, Image-to-PPTX, DocuCraft variants)
│   │   ├── Conditional stages (topic-research, resume-execute, etc.)
│   │   └── Deterministic rules (never ask when route is clear)
│   │
│   ├── generate-pptx.md               ← ROUTE: Default Generate (PPT Master pipeline)
│   │   ├── Step 1-7 sequence
│   │   ├── Gate checklists
│   │   ├── SVG page-design boundary
│   │   └── Cross-cutting authorities (artifact-ownership, failure-recovery, etc.)
│   │
│   ├── create-template.md             ← ROUTE: Create Template (4 child workflows)
│   │   ├── Shared contract (output scope: library vs project)
│   │   ├── 4 kinds: Brand, Style, Layout, Deck
│   │   └── Boundaries (no in-place structure edits, no direct page reconstruction)
│   │
│   ├── template-fill-pptx.md          ← ROUTE: Fill Native PPTX
│   │   ├── No SVG pipeline
│   │   ├── Direct OOXML patching
│   │   └── Clone + patch selected source slides
│   │
│   ├── native-enhance-pptx.md         ← ROUTE: Enhance Native PPTX
│   │   ├── Modules: notes, audio, timings, transitions, delivery check
│   │   ├── Append-oriented (no slide regeneration)
│   │   └── OOXML direct patching
│   │
│   ├── generate-presentation.md       ← ROUTE: DocuCraft Default Generate (alias/generate-pptx.md)
│   ├── docucraft-create-template.md   ← ROUTE: DocuCraft Create Template (Dart implementation)
│   ├── docucraft-enhance-presentation.md ← ROUTE: DocuCraft Enhance (Dart)
│   │
│   ├── profiles/                      ← ══ GENERATION PROFILES ══
│   │   ├── docucraft-quick-generate.md ← PROFILE: Quick runtime (no interaction)
│   │   ├── docucraft-sketch-to-design.md ← PROFILE: Sketch → Design (vision AI)
│   │   ├── quick-generate.md          ← PROFILE: PPT Master Quick (SVG → PPTX short circuit)
│   │   ├── beautify-pptx.md           ← PROFILE: 1:1 visual upgrade (preserve wording)
│   │   └── image-to-pptx.md           ← PROFILE: Codex page-frame reconstruction
│   │
│   ├── stages/                        ← ══ CONDITIONAL SUB-ROUTINES ══
│   │   ├── apply-template.md          ← STAGE: DocuCraft template application
│   │   ├── apply-template-workspace.md ← STAGE: PPT Master template installation
│   │   ├── docucraft-refine-spec.md   ← STAGE: Spec refinement (chat-based edit)
│   │   ├── refine-spec.md             ← STAGE: PPT Master spec refinement
│   │   ├── topic-research.md          ← STAGE: Fact research (topic-only input)
│   │   ├── resume-execute.md          ← STAGE: Split-mode project resume
│   │   ├── verify-charts.md           ← STAGE: Chart validation
│   │   ├── visual-review.md           ← STAGE: Visual review
│   │   ├── live-preview.md            ← STAGE: Interactive preview
│   │   ├── customize-animations.md    ← STAGE: Per-slide/object animation
│   │   └── generate-audio.md          ← STAGE: TTS narration audio
│   │
│   ├── governance/                    ← ══ POLICY ══
│   │   └── failure-recovery.md        ← POLICY: Stop/continue + resume pointers
│   │
│   └── create-template/               ← ══ CHILD WORKFLOWS ══
│       ├── create-brand.md            ← CHILD: Identity-only (colors, typography, logo)
│       ├── create-style.md            ← CHILD: Communication method + visual direction
│       ├── create-layout.md           ← CHILD: Brand-neutral structural skeleton
│       └── create-deck.md             ← CHILD: Branded structural system
│
├── references/                        ← ══ ROLE CORES ══
│   ├── strategist.md                  ← ROLE: Step 3-4 (content analysis, template suggestions)
│   │   ├── Template recommendations
│   │   ├── Lightweight gate (color/style detection)
│   │   ├── Conversation memory
│   │   └── User actions: Generate, Edit, Retry, Cancel
│   │
│   ├── executor.md                    ← ROLE: Step 6-7 (generation + QC)
│   │   ├── Generate SVG via AI (with fallback)
│   │   ├── Parse SVG to SlideElements
│   │   ├── Quality check + auto-fix
│   │   └── Add to slide via SlideProvider
│   │
│   └── ... (50+ PPT Master references) ← OTHER: video-design, animations, confirm_ui, etc.
│
├── scripts/                           ← ══ DOCUMENTATION & SCRIPTS ══
│   ├── docs/
│   │   └── ai-generation.md           ← DOC: AI generation docs
│   └── ... (PPT Master Python scripts) ← 100+ scripts for PPT generation
│
└── templates/                         ← ══ TEMPLATE LIBRARY ══
    ├── README.md                      ← Shared kind and workspace model
    ├── design_spec_reference.md       ← Design spec schema
    ├── spec_lock_reference.md         ← Spec lock schema
    ├── brands/                        ← Brand templates
    ├── styles/                        ← Style templates
    ├── layouts/                       ← Layout templates
    ├── decks/                         ← Deck templates
    ├── charts/                        ← Chart templates
    ├── tables/                        ← Table templates
    ├── icons/                         ← Icon assets
    ├── scaffolds/                     ← Scaffold templates
    ├── schemas/                       ← JSON schemas
    └── sounds/                        ← Sound assets
```

---

## Mandatory Load Order

1. Read this file.
2. Read [`workflows/routing.md`](workflows/routing.md).
3. Select exactly one top-level route and its active profile from the routing authority.
4. Read only the resulting runtime authority and its explicitly triggered supporting documents.

| Selected route / profile | Runtime authority |
|---|---|
| Generate Presentation — Default | [`workflows/generate-pptx.md`](workflows/generate-pptx.md) |
| Generate Presentation — Quick | [`workflows/profiles/docucraft-quick-generate.md`](workflows/profiles/docucraft-quick-generate.md) |
| Generate Presentation — Sketch to Design | [`workflows/profiles/docucraft-sketch-to-design.md`](workflows/profiles/docucraft-sketch-to-design.md) |
| Create Template | [`workflows/docucraft-create-template.md`](workflows/docucraft-create-template.md) |
| Enhance Presentation | [`workflows/docucraft-enhance-presentation.md`](workflows/docucraft-enhance-presentation.md) |

**Hard rule — selected authority only**: Do not load another top-level route's procedure after routing. Sketch to Design and Quick are mutually exclusive.

---

## Global Execution Discipline

1. **Serial execution** — Follow the selected authority's steps in order.
2. **Blocking means stop** — At every `⛔ BLOCKING` gate, wait for explicit user confirmation.
3. **No cross-phase bundling** — Do not combine work across an unclosed gate.
4. **Gate before entry** — Verify every listed prerequisite before entering a step.
5. **No speculative execution** — Do not prepare later-phase artifacts before their owning step.
6. **Deterministic routing** — Do not add a route-choice question when routing resolves the request.
7. **Owning-source recovery** — On failure, repair or regenerate the owning source artifact.
8. **Stable paths** — Use absolute skill/project paths; never derive them from CWD.

## Global Communication Rules

- Match the user's language and source language unless the user explicitly overrides it.
- Localize user-facing option labels and explanations.
- Keep `design_spec.md` section headings and field names in the template's original English.
- Before switching roles, read the corresponding role reference and output:

```markdown
## [Role Switch: <Role Name>]
📖 Reading role definition: references/<filename>.md
📋 Current task: <brief description>
```

---

## Platform Compatibility

- This package is a Flutter/Dart workflow, not a generic application scaffold.
- All scripts are Dart commands or Flutter commands, not Python.
- Keep required workflow, reference, and template documentation inside this Skill directory.
- On Windows, use `flutter` and `dart` commands directly.

## Flutter Commands

| Command | Purpose |
|---------|---------|
| `flutter run -d chrome` | Run app in Chrome |
| `flutter build web --release` | Build web release |
| `flutter analyze` | Analyze code |
| `flutter test` | Run tests |
| `dart format .` | Format code |
| `dart pub get` | Get dependencies |

## AI Model Configuration

| Model ID | Type | Use Case |
|----------|------|----------|
| `gc/gemini-3-flash-preview` | Vision | Image understanding |
| `oc/laguna-s-2.1-free` | Vision | Fast generation |
| `kc/nvidia/nemotron-3-ultra-550b-a55f:free` | Quality | High quality |
| `kc/meituan/longcat-2.0-free` | Reasoning | Complex reasoning |

## Fallback Chain

```
1. Gemini Flash (vision) → Try first
2. Laguna (vision)       → If Gemini fails
3. Nemotron (quality)    → If Laguna fails
4. Longcat (reasoning)   → If Nemotron fails
```

## Implementation Files

| Step | Dart File | Workflow Authority | API Documentation |
|------|-----------|-------------------|-------------------|
| 1 | `lib/services/import/import_service.dart` | `workflows/generate-pptx.md` (Step 1) | `docs/dart/services/import_service.md` |
| 2 | `lib/services/project_service.dart` | `workflows/generate-pptx.md` (Step 2) | `docs/dart/services/project_service.md` |
| 3 | `lib/models/template_suggestion.dart` | `workflows/generate-pptx.md` (Step 3) | `docs/dart/models/template_suggestion.md` |
| 4 | `lib/widgets/ai_chat_panel.dart` | `references/strategist.md` | `docs/dart/widgets/ai_chat_panel.md` |
| 5 | `lib/services/project_service.dart` (DesignSpec) | `workflows/stages/docucraft-refine-spec.md` | `docs/dart/services/project_service.md` |
| 6 | `lib/services/preview_service.dart` | `references/executor.md` | `docs/dart/services/preview_service.md` |
| 7 | `lib/services/quality_check.dart` | `references/executor.md` | `docs/dart/services/quality_check.md` |

## Cross-Reference: PPT Master

DocuCraft berbagi beberapa konsep dengan PPT Master:

| Konsep | PPT Master | DocuCraft |
|--------|------------|-----------|
| Routing | `workflows/routing.md` | `workflows/routing.md` (updated) |
| Strategist | `references/strategist.md` | `references/strategist.md` (updated) |
| Executor | `references/executor-base.md` | `references/executor.md` (updated) |
| Templates | `templates/` | `lib/models/template_registry_v2.dart` |
| Quality Check | `svg_quality_checker.py` | `lib/services/quality_check.dart` |

## When to Use DocuCraft

| Request | Use |
|---------|-----|
| Edit Flutter/Dart code | DocuCraft |
| Generate via mobile app | DocuCraft |
| Sketch-to-design conversion | DocuCraft |
| Edit Python scripts | PPT Master |
| Generate PPTX via Claude Code | PPT Master |

---

*This skill documentation is compatible with AI agents like Claude Code, Codex, and similar tools.*
