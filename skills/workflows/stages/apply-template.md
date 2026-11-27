# Apply Template Stage (DocuCraft)

**Trigger**: User selects template in Step 4
**Platform**: Flutter/Dart
**Entry Point**: `lib/models/template_suggestion.dart` + `lib/services/project_service.dart`

## Overview
Validate dan install selected template workspace. Template yang dipilih akan di-apply ke project saat ini.

## Implementation

```dart
// In TemplateRegistryV2
Future<void> applyTemplate(String templateId) async {
  // 1. Validate template exists
  final template = _brands[templateId] ?? _styles[templateId] ?? _layouts[templateId];
  if (template == null) throw ArgumentError('Template not found: $templateId');
  
  // 2. Install template
  ProjectService.setSelectedTemplate(template);
}
```

## Related Files
- `lib/models/template_registry_v2.dart` - Template system
- `lib/services/project_service.dart` - Project state
