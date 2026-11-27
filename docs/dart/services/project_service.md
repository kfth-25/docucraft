# Project Service

**File:** `lib/services/project_service.dart`
**Role:** Project State Management
**Step:** Step 2 & 5 (Project Init + Design Spec)

## Overview
Manage project state, configuration, dan design specification. Menggunakan pattern singleton dengan in-memory storage.

## Class Hierarchy

```
ProjectService (Static Class)
├── currentProject: Project?
├── initProject({required String name, String format}) → Project
├── updateProject(Project project) → void
├── addSlide(Slide slide) → void
├── setDesignSpec(DesignSpec spec) → void
├── setSelectedTemplate(TemplateSuggestion template) → void
└── clear() → void

Project
├── id: String
├── name: String
├── createdAt: DateTime
├── modifiedAt: DateTime
├── slides: List<Slide>
├── config: ProjectConfig
├── designSpec: DesignSpec?
└── selectedTemplate: TemplateSuggestion?

ProjectConfig
├── canvasWidth: double (default: 1920)
├── canvasHeight: double (default: 1080)
└── format: String (default: 'ppt169')

DesignSpec
├── topic: String
├── subtitle: String
├── warna: String
├── style: String
├── elemen: List<String>
├── jumlahSlide: int
├── audience: String?
├── tone: String?
└── metadata: Map<String, dynamic>
```

## Public API

### Initialize Project
```dart
final project = ProjectService.initProject(
  name: 'Presentasi AI',
  format: 'ppt169',
);
```

### Get Current Project
```dart
final project = ProjectService.currentProject;
if (project != null) {
  print('Project: ${project.name}');
}
```

### Add Slide
```dart
ProjectService.addSlide(newSlide);
```

### Set Design Spec
```dart
final spec = DesignSpec(
  topic: 'Artificial Intelligence',
  warna: 'biru profesional',
  style: 'modern',
  elemen: ['judul', 'bullet points', 'shape'],
  jumlahSlide: 5,
);
ProjectService.setDesignSpec(spec);
```

### Set Selected Template
```dart
ProjectService.setSelectedTemplate(template);
```

### Clear Project
```dart
ProjectService.clear();
```

## DesignSpec Methods

### toJson()
```dart
final json = spec.toJson();
// Returns Map<String, dynamic>
```

### fromJson()
```dart
final spec = DesignSpec.fromJson(json);
```

### toPrompt()
```dart
final prompt = spec.toPrompt();
// Returns formatted prompt string for AI
```

## Output Format (toPrompt)
```
Buat presentasi dengan detail:
• Topik: Artificial Intelligence
• Warna: biru profesional
• Style: modern
• Elemen: judul, bullet points, shape
• Jumlah slide: 5
```

## Related Files
- `slide.dart` - Slide model
- `template_suggestion.dart` - Template model
- `slide_provider.dart` - State management (Provider)
