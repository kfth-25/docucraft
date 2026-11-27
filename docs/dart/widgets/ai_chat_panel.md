# AI Chat Panel

**File:** `lib/widgets/ai_chat_panel.dart`
**Role:** AI Chat UI + Strategist Phase
**Step:** Step 4 (Strategist Phase)

## Overview
Panel chat interaktif untuk berkomunikasi dengan AI. Mengimplementasikan lightweight gate, template suggestions, retry/edit buttons, dan conversation memory.

## Class Hierarchy

```
AiChatPanel (StatefulWidget)
├── show(BuildContext context, {String? initialPrompt}) → void
└── _AiChatPanelState
    ├── _messages: List<_ChatMessage>
    ├── _isGenerating: bool
    ├── _selectedModel: String
    ├── _lastPrompt: String?
    ├── _showEditForm: bool
    ├── _editTopik: String
    ├── _editWarna: String
    └── _editStyle: String
```

## Public API

### Show Panel
```dart
AiChatPanel.show(
  context,
  initialPrompt: 'Buat presentasi tentang AI',
);
```

## State Machine

```
idle → analyzing → [question | generating] → done
                                      → error
```

## Features

### 1. Template Suggestions (Step 3)
```dart
// Only on first message
if (_messages.isEmpty) {
  final suggestions = TemplateSuggestions.suggest(prompt);
  if (suggestions.isNotEmpty) {
    // Display suggestions
  }
}
```

### 2. Lightweight Gate (Step 4)
```dart
// Only on first message if prompt < 10 chars or missing color/style
if (_messages.isEmpty && prompt.length > 10) {
  final hasColor = [...].any((c) => prompt.contains(c));
  final hasStyle = [...].any((s) => prompt.contains(s));
  if (!hasColor || !hasStyle) {
    // Show summary with [Generate] [Edit] buttons
  }
}
```

### 3. Conversation Memory
```dart
String _buildConversationContext() {
  // Take last 10 messages
  // Format: "User: ... AI: ..."
  // Truncate AI responses to 200 chars
}
```

### 4. Retry Button
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

## UI Components

### Chat Bubble
```dart
Widget _chatBubble(_ChatMessage msg) {
  final isUser = msg.role == 'user';
  final isLastAiMessage = !isUser && msg == _messages.last;
  
  return Container(
    // User: right-aligned, primary color
    // AI: left-aligned, surface3 color
    // If last AI message with "Berhasil": show retry/edit buttons
  );
}
```

### Typing Indicator
```dart
Widget _typingIndicator() {
  return Row([
    CircularProgressIndicator(),
    Text('AI sedang berpikir...'),
  ]);
}
```

### Edit Form
```dart
Widget _editForm() {
  return Column([
    TextField(label: 'Topik', value: _editTopik),
    Row([
      TextField(label: 'Warna', value: _editWarna),
      TextField(label: 'Style', value: _editStyle),
    ]),
    Row([
      TextButton('Batal', onPressed: _cancelEdit),
      ElevatedButton('Generate', onPressed: _submitEdit),
    ]),
  ]);
}
```

## Message Flow

```
1. User types prompt
2. Add user message to _messages
3. Set _isGenerating = true
4. Call _processPrompt(prompt)
5. Add AI response to _messages
6. Set _isGenerating = false
7. Scroll to bottom
```

## Integration Points

| Component | Method | Purpose |
|-----------|--------|---------|
| TemplateSuggestions | `suggest()` | Get template recommendations |
| AiGenerationService | `generateFromPrompt()` | Generate SVG |
| SvgToSlideElements | `parse()` | Parse SVG to elements |
| QualityChecker | `check()` | Validate elements |
| SlideProvider | `notifyListeners()` | Update UI |

## Related Files
- `sketch_ai_panel.dart` - Sketch variant
- `ai_generation.dart` - AI service
- `template_suggestion.dart` - Template system
- `slide_provider.dart` - State management
