// DocuCraft Flutter — agent-core types (Sprint 13)
//
// Port Dart murni dari GenOffice `packages/agent-core/src/types.ts`. Tanpa
// dependency Flutter — dapat dipakai dari lapisan mana pun. Mendefinisikan
// bentuk wire yang dipakai bersama oleh agent loop, skill, dan transport.
//
// Kenapa harus mencerminkan GenOffice secara persis:
//   - Model berbicara konvensi tool-call XML/JSON yang sama di kedua
//     runtime; satu set tipe berarti skill TS dan skill Dart punya luas
//     permukaan (surface area) yang identik.
//   - Cerita interop (satu sisi jembatan bisa di-implementasi ulang dalam
//     bahasa lain) tetap terbuka.

/// JSON-Schema described tool exposed to the model.
class AgentToolDef {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  const AgentToolDef({
    required this.name,
    required this.description,
    required this.inputSchema,
  });
}

/// A tool call issued by the model during a turn.
class AgentToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> input;
  /// Parse error when the model emitted invalid input JSON; the loop feeds
  /// back an `isError` result for retry instead of aborting the run.
  final String? inputError;
  /// Argument stream was cut off by the token limit (stop_reason max_tokens).
  final bool? truncated;

  const AgentToolCall({
    required this.id,
    required this.name,
    required this.input,
    this.inputError,
    this.truncated,
  });
}

/// Tool result that the loop feeds back to the model.
class AgentToolResult {
  final String id;
  /// Tool name (Gemini addresses function responses by name, not id).
  final String name;
  final String output;
  final bool isError;

  const AgentToolResult({
    required this.id,
    required this.name,
    required this.output,
    this.isError = false,
  });
}

/// Inline image attached to a user turn, fed to vision-capable providers as
/// multimodal input.
class AgentImage {
  /// Raw base64 (no `data:` URL prefix).
  final String base64;
  /// e.g. `'image/png'`.
  final String mime;

  const AgentImage({required this.base64, required this.mime});
}

/// A single message exchanged with the model.
sealed class AgentMessage {
  const AgentMessage();
}

/// User turn (instruction + optional images).
class AgentUserMessage extends AgentMessage {
  final String text;
  final List<AgentImage>? images;

  const AgentUserMessage({required this.text, this.images});
}

/// Assistant turn (text + optional tool calls + optional reasoning).
class AgentAssistantMessage extends AgentMessage {
  final String text;
  final List<AgentToolCall>? toolCalls;
  /// Opaque vendor thinking captured during the turn; interleaved-thinking
  /// models (MiniMax M3, DeepSeek V4) degrade in tool loops unless it is
  /// echoed back.
  final String? reasoning;

  const AgentAssistantMessage({
    required this.text,
    this.toolCalls,
    this.reasoning,
  });
}

/// Tool results message.
class AgentToolMessage extends AgentMessage {
  final List<AgentToolResult> results;

  const AgentToolMessage({required this.results});
}

/// Side-channel display data: UI-only, never merged into messages sent to the
/// LLM. Mirrors `ToolDisplay` in GenOffice.
sealed class ToolDisplay {
  const ToolDisplay();
}

class ToolDisplayImages extends ToolDisplay {
  final List<ToolDisplayItem> items;
  const ToolDisplayImages(this.items);
}

class ToolDisplayLinks extends ToolDisplay {
  final List<ToolDisplayItem> items;
  const ToolDisplayLinks(this.items);
}

class ToolDisplayText extends ToolDisplay {
  final String text;
  const ToolDisplayText(this.text);
}

class ToolDisplayItem {
  final String url;
  final String? title;
  final String? thumb;
  const ToolDisplayItem({required this.url, this.title, this.thumb});
}

/// Outcome of one tool execution.
class ToolExecution {
  /// Result text fed back to the model.
  final String output;
  final bool isError;
  /// True when the tool changed the underlying artifact (document / sheet /
  /// deck).
  final bool mutated;
  /// Short human-readable label for activity UI.
  final String summary;
  /// Side-channel display: for UI only, never enters the LLM context.
  final ToolDisplay? display;

  const ToolExecution({
    required this.output,
    this.isError = false,
    this.mutated = false,
    required this.summary,
    this.display,
  });
}

// ---- run phase (drives the in-progress status line in chat UIs) ----

/// Request sent, waiting for the model's first content block.
const String agentPhaseRequesting = 'requesting';

/// Model is thinking (reasoning blocks).
const String agentPhaseThinking = 'thinking';

/// Model is streaming a text reply.
const String agentPhaseResponding = 'responding';

/// Model is streaming tool arguments (e.g. a full outline) with no visible
/// text.
const String agentPhaseToolInput = 'tool-input';

/// Tool is currently running.
const String agentPhaseToolRunning = 'tool-running';

class AgentPhase {
  final String kind;
  final String? toolName;
  const AgentPhase({required this.kind, this.toolName});
}

// ---- LLM transport (how one model turn is streamed; app supplies the impl) ----

class AgentStreamRequest {
  final String system;
  final List<AgentMessage> messages;
  final List<AgentToolDef> tools;

  const AgentStreamRequest({
    required this.system,
    required this.messages,
    required this.tools,
  });
}

typedef AgentStreamOnDelta = void Function(String text);
typedef AgentStreamOnReasoning = void Function(String text);
typedef AgentStreamOnToolCall = void Function(AgentToolCall call);
typedef AgentStreamOnPhase = void Function(AgentPhase phase);
typedef AgentStreamOnStopReason = void Function(String reason);
typedef AgentStreamOnDone = void Function();
typedef AgentStreamOnError = void Function(String error);

class AgentStreamCallbacks {
  final AgentStreamOnDelta onDelta;
  final AgentStreamOnReasoning? onReasoning;
  final AgentStreamOnToolCall onToolCall;
  final AgentStreamOnPhase? onPhase;
  final AgentStreamOnStopReason? onStopReason;
  final AgentStreamOnDone onDone;
  final AgentStreamOnError onError;

  const AgentStreamCallbacks({
    required this.onDelta,
    this.onReasoning,
    required this.onToolCall,
    this.onPhase,
    this.onStopReason,
    required this.onDone,
    required this.onError,
  });
}

/// Handle to an in-flight model stream. `cancel()` aborts; the transport
/// must still emit `onDone` afterwards.
abstract class AgentStreamHandle {
  void cancel();
}

/// Strategy for issuing one model turn.
abstract class AgentTransport {
  AgentStreamHandle stream(AgentStreamRequest request, AgentStreamCallbacks callbacks);
}
