# Strategist Role (DocuCraft)

**Pipeline Position**: Step 3-4 (setelah project init, sebelum executor)
**Platform**: Flutter/Dart
**Entry Point**: `lib/widgets/ai_chat_panel.dart`

## Tugas
- Content analysis & design planning
- Template recommendations (Step 3)
- Lightweight gate confirmation (Step 4)
- User interaction handling (retry/edit)
- Conversation memory management

## Implementation

**File:** `lib/widgets/ai_chat_panel.dart`

## Responsibilities

### 1. Template Suggestions
```dart
// On first message
if (_messages.isEmpty) {
  final suggestions = TemplateSuggestions.suggest(prompt);
  if (suggestions.isNotEmpty) {
    // Display top 3 suggestions
  }
}
```

### 2. Lightweight Gate
```dart
// Check if prompt is complete
final hasColor = ['biru', 'merah', 'hijau', ...].any((c) => prompt.contains(c));
final hasStyle = ['modern', 'minimalis', ...].any((s) => prompt.contains(s));

if (!hasColor || !hasStyle) {
  // Show summary with [Generate] [Edit] buttons
  return 'Saya akan buat desain dengan:\n'
      '• Topik: $prompt\n'
      '• Warna: ${hasColor ? "sesuai" : "default"}\n'
      '• Style: ${hasStyle ? "sesuai" : "default"}\n\n'
      '[✅ Generate Sekarang] [✏️ Ubah Detail]';
}
```

### 3. Conversation Memory
```dart
String _buildConversationContext() {
  final recentMessages = _messages.length > 10 
      ? _messages.sublist(_messages.length - 10) 
      : _messages;
  
  final sb = StringBuffer();
  sb.writeln('RIWAYAT PERCAKAPAN:');
  for (final msg in recentMessages) {
    if (msg.role == 'user') {
      sb.writeln('User: ${msg.text}');
    } else {
      String aiText = msg.text;
      if (aiText.length > 200) {
        aiText = aiText.substring(0, 200) + '...';
      }
      sb.writeln('AI: $aiText');
    }
  }
  return sb.toString();
}
```

### 4. Retry Handling
```dart
Future<void> _retry() async {
  if (_lastPrompt == null || _isGenerating) return;
  await _sendMessage(_lastPrompt!);
}
```

### 5. Edit Form
```dart
void _showEdit() {
  setState(() {
    _editTopik = _lastPrompt!;
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

## User Actions
| Action | Handler | Result |
|--------|---------|--------|
| Generate | `_processPrompt()` | Continue to Step 5 |
| Edit | `_showEdit()` | Show edit form |
| Retry | `_retry()` | Regenerate with same prompt |
| Cancel | `_cancelEdit()` | Hide form |

## Related Files
- `lib/models/template_suggestion.dart` - Template system
- `lib/services/ai_generation.dart` - AI service
- `references/executor.md` - Next role
