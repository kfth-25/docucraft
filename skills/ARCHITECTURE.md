# DocuCraft AI Skill Architecture

## Overview
Arsitektur ini menjelaskan bagaimana AI agent (Claude Code, Codex, dll) membaca dan mengeksekusi skill DocuCraft.

---

## How AI Reads Skills

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        AI AGENT (Claude Code)                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. User Request                                                        │
│     "Buat presentasi tentang AI"                                        │
│           │                                                             │
│           ▼                                                             │
│  2. Read SKILL-DOCUCRAFT.md                                            │
│     → Understand available routes                                       │
│     → Select appropriate route                                          │
│           │                                                             │
│           ▼                                                             │
│  3. Read workflows/routing.md                                          │
│     → Match user intent to route                                        │
│     → Route: "generate-presentation"                                    │
│           │                                                             │
│           ▼                                                             │
│  4. Read workflows/generate-presentation.md                            │
│     → Understand 7-step pipeline                                        │
│     → Know which Dart files to edit                                     │
│           │                                                             │
│           ▼                                                             │
│  5. Read specific Dart documentation                                   │
│     → docs/dart/services/ai_generation.md                               │
│     → Understand API and parameters                                     │
│           │                                                             │
│           ▼                                                             │
│  6. Edit Dart code                                                      │
│     → lib/widgets/ai_chat_panel.dart                                    │
│     → Implement the feature                                             │
│           │                                                             │
│           ▼                                                             │
│  7. Run Flutter commands                                                │
│     → flutter analyze                                                   │
│     → flutter build web --release                                       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Skill Entry Points

### Primary Entry
```
SKILL-DOCUCRAFT.md
├── name: docucraft
├── description: When to use this skill
├── metadata: AI models, platform info
└── Mandatory Load Order
    ├── 1. Read this file
    ├── 2. Read workflows/routing.md
    ├── 3. Select route
    └── 4. Read route authority
```

### Route Selection
```
workflows/routing.md
├── Intent Detection
│   ├── "buat presentasi" → Generate Presentation
│   ├── "coret" → Sketch to Design
│   ├── "quick" → Quick Generate
│   └── "template" → Create Template
└── Route Matrix
    ├── Generate Presentation → workflows/generate-presentation.md
    ├── Create Template → workflows/create-template.md
    └── Enhance → workflows/enhance-presentation.md
```

---

## AI Execution Flow

### Step 1: Intent Detection
```dart
// AI reads: workflows/routing.md
// AI detects user intent

String detectRoute(String userPrompt) {
  final lower = userPrompt.toLowerCase();
  
  if (lower.contains('coret') || lower.contains('sketch')) {
    return 'sketch-to-design';
  }
  if (lower.contains('quick') || lower.contains('cepat')) {
    return 'quick-generate';
  }
  if (lower.contains('template')) {
    return 'create-template';
  }
  return 'generate-presentation'; // default
}
```

### Step 2: Load Route Authority
```dart
// AI reads: workflows/generate-presentation.md
// AI understands the 7-step pipeline

final route = loadRoute('generate-presentation');
// Returns: Steps 1-7 with implementation files
```

### Step 3: Load Implementation Docs
```dart
// AI reads: docs/dart/services/ai_generation.md
// AI understands the API

final serviceDoc = loadDoc('services/ai_generation');
// Returns: Class methods, parameters, examples
```

### Step 4: Edit Dart Code
```dart
// AI edits: lib/widgets/ai_chat_panel.dart
// AI implements the feature based on docs

class _AiChatPanelState {
  // AI adds new feature here
}
```

### Step 5: Run Commands
```bash
# AI runs Flutter commands
flutter analyze
flutter build web --release
flutter test
```

---

## File Structure for AI

```
skills/
├── SKILL-DOCUCRAFT.md              ← AI reads this first
├── ARCHITECTURE.md                 ← This file
│
├── workflows/
│   ├── routing.md                  ← AI detects intent here
│   ├── generate-presentation.md    ← AI loads route authority
│   ├── create-template.md          ← AI loads route authority
│   └── ...
│
├── references/
│   ├── strategist.md               ← AI understands role
│   └── executor.md                 ← AI understands role
│
└── docs/dart/                      ← AI learns Dart API
    ├── README.md
    ├── models/
    │   ├── slide.md
    │   └── template_suggestion.md
    ├── services/
    │   ├── ai_generation.md
    │   ├── quality_check.md
    │   └── ...
    └── widgets/
        └── ai_chat_panel.md
```

---

## AI Context Loading

### Minimal Context (Fast)
```
User: "Buat presentasi tentang AI"

AI reads:
1. SKILL-DOCUCRAFT.md (50 lines)
2. workflows/routing.md (30 lines)
3. workflows/generate-presentation.md (100 lines)

Total: ~180 lines
```

### Full Context (Complex Feature)
```
User: "Tambah fitur retry dengan fallback model"

AI reads:
1. SKILL-DOCUCRAFT.md (50 lines)
2. workflows/routing.md (30 lines)
3. workflows/generate-presentation.md (100 lines)
4. docs/dart/services/ai_generation.md (80 lines)
5. lib/widgets/ai_chat_panel.dart (actual code)

Total: ~260 lines + code
```

---

## AI Command Execution

### Flutter Commands
```bash
# AI runs these commands
flutter analyze                    # Check code
flutter build web --release       # Build web
flutter test                      # Run tests
dart format .                     # Format code
dart pub get                      # Get dependencies
```

### Git Commands
```bash
# AI runs these commands
git status                        # Check changes
git diff                          # View changes
git add .                         # Stage files
git commit -m "..."               # Commit changes
```

---

## AI Decision Tree

```
                    ┌─────────────────┐
                    │  User Request   │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ Load SKILL.md   │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ Detect Intent   │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│    Generate     │ │  Create Template│ │    Enhance      │
└────────┬────────┘ └────────┬────────┘ └────────┬────────┘
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ Load generate-  │ │ Load create-    │ │ Load enhance-   │
│ presentation.md │ │ template.md     │ │ presentation.md │
└────────┬────────┘ └────────┬────────┘ └────────┬────────┘
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ Load Dart docs  │ │ Load Dart docs  │ │ Load Dart docs  │
└────────┬────────┘ └────────┬────────┘ └────────┬────────┘
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│   Edit Dart     │ │   Edit Dart     │ │   Edit Dart     │
└────────┬────────┘ └────────┬────────┘ └────────┬────────┘
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  flutter build  │ │  flutter build  │ │  flutter build  │
└────────┬────────┘ └────────┬────────┘ └────────┬────────┘
         │                   │                   │
         ▼                   ▼                   ▼
                    ┌─────────────────┐
                    │    Complete     │
                    └─────────────────┘
```

---

## Integration with DocuCraft App

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        DOCUCRAFT APP                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                        lib/                                     │   │
│  │                                                                  │   │
│  │  ┌─────────────────────┐    ┌─────────────────────┐            │   │
│  │  │   AI Chat Panel     │    │   Sketch AI Panel   │            │   │
│  │  │   (ai_chat_panel)   │    │   (sketch_ai_panel) │            │   │
│  │  └──────────┬──────────┘    └──────────┬──────────┘            │   │
│  │             │                          │                        │   │
│  │             └────────────┬─────────────┘                        │   │
│  │                          │                                      │   │
│  │                          ▼                                      │   │
│  │  ┌─────────────────────────────────────────────────────────┐   │   │
│  │  │              AiGenerationService                         │   │   │
│  │  │              (ai_generation.dart)                        │   │   │
│  │  └──────────┬──────────────────────────────────────────────┘   │   │
│  │             │                                                   │   │
│  │             ▼                                                   │   │
│  │  ┌─────────────────────┐    ┌─────────────────────┐            │   │
│  │  │  SvgToSlideElements │    │   QualityChecker    │            │   │
│  │  │  (svg_to_slide)     │    │   (quality_check)   │            │   │
│  │  └──────────┬──────────┘    └──────────┬──────────┘            │   │
│  │             │                          │                        │   │
│  │             └────────────┬─────────────┘                        │   │
│  │                          │                                      │   │
│  │                          ▼                                      │   │
│  │  ┌─────────────────────────────────────────────────────────┐   │   │
│  │  │                    SlideProvider                          │   │   │
│  │  │                    (slide_provider.dart)                  │   │   │
│  │  └─────────────────────────────────────────────────────────┘   │   │
│  │                                                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## AI Token Usage

| Operation | Files Read | Token Estimate |
|-----------|------------|----------------|
| Route selection | 3 files | ~1k tokens |
| Load implementation | 5 files | ~2k tokens |
| Edit code | 2 files | ~3k tokens |
| Build & test | 0 files | ~0.5k tokens |
| **Total** | **~10 files** | **~6.5k tokens** |

---

## Quick Reference

| AI Need | File to Read |
|---------|--------------|
| What can I do? | `SKILL-DOCUCRAFT.md` |
| Which route? | `workflows/routing.md` |
| How to generate? | `workflows/generate-presentation.md` |
| How to create template? | `workflows/create-template.md` |
| How does AI service work? | `docs/dart/services/ai_generation.md` |
| How to validate? | `docs/dart/services/quality_check.md` |
| What's the data model? | `docs/dart/models/slide.md` |

---

## Summary

1. **AI reads SKILL-DOCUCRAFT.md** → Understands available routes
2. **AI reads routing.md** → Matches user intent to route
3. **AI reads route authority** → Understands the pipeline
4. **AI reads Dart docs** → Understands the API
5. **AI edits Dart code** → Implements the feature
6. **AI runs Flutter commands** → Builds and tests

**AI tidak perlu membaca semua file. AI hanya membaca file yang relevan dengan task.**
