# Refine Spec Stage (DocuCraft)

**Trigger**: User klik "Edit" atau explicit spec refinement
**Platform**: Flutter/Dart
**Entry Point**: `lib/widgets/ai_chat_panel.dart` (`_showEdit()`)

## Overview
Chat-based spec revision untuk mengubah detail desain (topik, warna, style) sebelum generate. Form edit muncul di bawah chat.

## Implementation

```dart
// In AiChatPanel
void _showEdit() {
  setState(() {
    _editTopik = _lastPrompt ?? '';
    _editWarna = '';
    _editStyle = '';
    _showEditForm = true;
  });
}

Future<void> _submitEdit() async {
  String newPrompt = _editTopik;
  if (_editWarna.isNotEmpty) newPrompt += ', warna $_editWarna';
  if (_editStyle.isNotEmpty) newPrompt += ', style $_editStyle';
  setState(() => _showEditForm = false);
  await _sendMessage(newPrompt);
}
```

## Edit Form Fields
| Field | Type | Description |
|-------|------|-------------|
| Topik | TextInput | Main topic |
| Warna | TextInput | Color preference |
| Style | TextInput | Style preference |

## Related Files
- `lib/widgets/ai_chat_panel.dart` - UI integration
- `references/strategist.md` - Strategist role
