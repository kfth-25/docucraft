# DocuCraft Skills

## Overview
DocuCraft adalah AI-driven presentation workflow untuk Flutter applications. Skill ini terinspirasi dari PPT Master dan diadaptasi untuk mobile-first experience.

## Struktur Folder

```
skills/
├── SKILL.md                           # PPT Master skill (original)
├── SKILL-DOCUCRAFT.md                 # DocuCraft skill (new)
├── ARSITEKTUR-PPT-MASTER-LENGKAP.md   # Referensi PPT Master
├── LICENSE
├── requirements.txt
│
├── workflows/                         # ══ ROUTE AUTHORITIES ══
│   ├── routing.md                     # ← Route selection
│   ├── generate-presentation.md       # ← Default Generate (DocuCraft)
│   ├── generate-pptx.md               # ← Default Generate (PPT Master)
│   ├── create-template.md             # ← Create Template (PPT Master)
│   ├── template-fill-pptx.md          # ← Fill Native PPTX
│   ├── native-enhance-pptx.md         # ← Enhance Native PPTX
│   ├── docucraft-create-template.md   # ← Create Template (DocuCraft)
│   ├── docucraft-enhance-presentation.md # ← Enhance (DocuCraft)
│   │
│   ├── profiles/                      # ← Generate sub-profiles
│   │   ├── quick-generate.md          #   Quick runtime (PPT Master)
│   │   ├── beautify-pptx.md           #   1:1 visual upgrade
│   │   ├── image-to-pptx.md           #   Codex reconstruction
│   │   ├── docucraft-quick-generate.md #  Quick runtime (DocuCraft)
│   │   └── docucraft-sketch-to-design.md # Sketch to Design (DocuCraft)
│   │
│   ├── stages/                        # ← Conditional sub-routines
│   │   ├── apply-template-workspace.md #  Template installation
│   │   ├── apply-template.md          #  Template application (DocuCraft)
│   │   ├── customize-animations.md    #  Animation
│   │   ├── generate-audio.md          #  TTS audio
│   │   ├── live-preview.md            #  Live preview
│   │   ├── refine-spec.md             #  Spec refinement (PPT Master)
│   │   ├── docucraft-refine-spec.md   #  Spec refinement (DocuCraft)
│   │   ├── resume-execute.md          #  Split-mode resume
│   │   ├── topic-research.md          #  Fact research
│   │   ├── verify-charts.md           #  Chart validation
│   │   └── visual-review.md           #  Visual review
│   │
│   └── governance/
│       └── failure-recovery.md        #  Stop/continue policy
│
├── references/                        # ══ ROLE CORES ══
│   ├── strategist.md                  #  Strategist role (DocuCraft)
│   ├── executor.md                    #  Executor role (DocuCraft)
│   └── ... (PPT Master references)
│
├── scripts/                           # ══ DOCUMENTATION ══
│   └── docs/
│       └── ai-generation.md           #  AI generation docs
│
└── templates/                         # ══ TEMPLATE LIBRARY ══
    └── ... (PPT Master templates)
```

## 7-Step Pipeline (DocuCraft)

| Step | File | Description |
|------|------|-------------|
| 1 | `workflows/01-source-content.md` | Source Content Processing |
| 2 | `workflows/02-project-init.md` | Project Initialization |
| 3 | `workflows/03-template-prep.md` | Template Candidate Preparation |
| 4 | `workflows/04-strategist.md` | Strategist Phase |
| 5 | `workflows/05-design-spec.md` | Design Spec Authoring |
| 6 | `workflows/06-executor.md` | Executor Live Preview |
| 7 | `workflows/07-quality-export.md` | Quality Check + Export |

## Routes

| Route | Authority | Description |
|-------|-----------|-------------|
| Generate Presentation | `generate-presentation.md` | Default route |
| Quick Generate | `docucraft-quick-generate.md` | No interaction |
| Sketch to Design | `docucraft-sketch-to-design.md` | From sketch |
| Create Template | `docucraft-create-template.md` | Create template |
| Enhance | `docucraft-enhance-presentation.md` | Add enhancements |

## AI Models

| Model ID | Type | Use Case |
|----------|------|----------|
| `gc/gemini-3-flash-preview` | Vision | Image understanding |
| `oc/laguna-s-2.1-free` | Vision | Fast generation |
| `kc/nvidia/nemotron-3-ultra-550b-a55f:free` | Quality | High quality |
| `kc/meituan/longcat-2.0-free` | Reasoning | Complex reasoning |

## Quick Reference

| Need | File |
|------|------|
| Route selection | `workflows/routing.md` |
| Default pipeline | `workflows/generate-presentation.md` |
| Quick runtime | `workflows/profiles/docucraft-quick-generate.md` |
| Sketch to design | `workflows/profiles/docucraft-sketch-to-design.md` |
| Strategist role | `references/strategist.md` |
| Executor role | `references/executor.md` |
| AI generation | `scripts/docs/ai-generation.md` |

---

*This skill documentation is compatible with AI agents like Claude Code, Codex, and similar tools.*
