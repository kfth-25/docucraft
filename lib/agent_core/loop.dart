// DocuCraft Flutter — AgentLoop orchestrator (Sprint 13)
//
// Port Dart murni dari GenOffice `packages/agent-core/src/loop.ts`. Loop
// mengelola siklus turn demi turn: stream satu turn model → parse tool call →
// eksekusi tool skill → kirim hasil kembali → ulangi sampai model tidak
// lagi menghasilkan tool call atau anggaran turn tercapai.

import 'dart:async';
import 'skill.dart';
import 'types.dart';

/// Final result of a complete run.
class AgentRunResult {
  /// Final assistant text of the run (`''` when cut off).
  final String text;
  final bool cancelled;
  /// True when the run ended due to a transport or tool error (not abort).
  final bool isError;
  /// True when `maxTurns` was reached; text is the partial answer from the
  /// no-tools finalizing turn.
  final bool turnLimit;
  /// The final turn hit the token limit (stop_reason max_tokens): text is
  /// incomplete; set only when true.
  final bool? truncated;

  const AgentRunResult({
    required this.text,
    required this.cancelled,
    this.isError = false,
    this.turnLimit = false,
    this.truncated,
  });
}

/// Hooks for run-level events. Mirrors `AgentLoopEvents` in GenOffice.
class AgentLoopEvents {
  /// Cumulative assistant text of the current turn (call per delta).
  final void Function(String text)? onText;
  /// A tool is about to execute (UI shows a live "running" indicator;
  /// `onToolExecuted` always follows).
  final void Function(AgentToolCall call)? onToolStart;
  final void Function(AgentToolCall call, ToolExecution execution)? onToolExecuted;
  /// A turn requested tools and they ran; the loop is going back to the model.
  final void Function()? onTurnEnd;
  final void Function(AgentRunResult result)? onDone;
  final void Function(String error)? onError;

  const AgentLoopEvents({
    this.onText,
    this.onToolStart,
    this.onToolExecuted,
    this.onTurnEnd,
    this.onDone,
    this.onError,
  });
}

/// Compaction config (budget tracked in UTF-8 bytes rather than message count).
class CompactionOptions {
  /// History size that triggers compaction (UTF-8 bytes, default 256KB).
  final int maxBytes;
  /// Size of recent messages kept after compaction (bytes, default 96KB, cut
  /// at a user boundary).
  final int keepRecentBytes;
  /// Disable LLM summarization and use only the mechanical digest.
  final bool disableLlmSummary;

  const CompactionOptions({
    this.maxBytes = 256 * 1024,
    this.keepRecentBytes = 96 * 1024,
    this.disableLlmSummary = false,
  });
}

/// Configuration for one [AgentLoop] instance.
class AgentLoopOptions {
  final AgentTransport transport;
  final AgentSkill skill;
  final AgentLoopEvents events;
  /// Hard cap on model round-trips per run.
  final int maxTurns;
  /// History cap in messages, trimmed at user-turn boundaries.
  final int maxHistory;
  /// Context compaction config; null disables.
  final CompactionOptions? compaction;
  /// Appended to the system prompt each turn (e.g. reply-language directive).
  final String Function()? systemSuffix;
  /// Wrap instruction + skill context into the user message text.
  final String Function(String instruction, String context)? formatUserMessage;

  const AgentLoopOptions({
    required this.transport,
    required this.skill,
    this.events = const AgentLoopEvents(),
    this.maxTurns = defaultMaxTurns,
    this.maxHistory = 40,
    this.compaction,
    this.systemSuffix,
    this.formatUserMessage,
  });
}

const int defaultMaxTurns = 100;
const int maxInputParseRetries = 3;
const int maxIdenticalTurns = 3;
const int maxAllErrorTurns = 8;

/// One tool call actually executed during a run.
class _ExecutedCall {
  final String name;
  final bool ok;
  const _ExecutedCall(this.name, this.ok);
}

/// Main run loop. Holds a single `messages` history and a per-run
/// `AbortController` for the user's stop button.
class AgentLoop {
  final AgentLoopOptions opts;
  final List<AgentMessage> _messages = [];
  final List<_ExecutedCall> _executed = [];
  final AbortController _abort = AbortController();
  AgentStreamHandle? _activeHandle;
  String _lastAssistantText = '';
  int _lastAssistantTurnIndex = -1;
  int _consecutiveIdenticalTurns = 0;
  int _consecutiveErrorTurns = 0;
  int _inputParseFailures = 0;
  bool _correctionApplied = false;
  String? _lastFingerprint;

  AgentLoop(this.opts);

  /// Public abort entry point. Wired to the chat panel's stop button.
  void cancel() {
    _abort.abort();
    _activeHandle?.cancel();
  }

  /// Drive one run. Returns when the model emits no tool calls (final text
  /// reply), `maxTurns` is hit, or the user aborts.
  Future<AgentRunResult> run(String instruction) async {
    final ctx = opts.skill.buildContext();
    final userText = (opts.formatUserMessage != null)
        ? opts.formatUserMessage!(instruction, ctx)
        : (ctx.isEmpty ? instruction : '$instruction\n\n$ctx');
    _messages.add(AgentUserMessage(text: userText));

    final toolDefs = opts.skill.tools;

    int turn = 0;
    String lastText = '';
    bool turnLimit = false;
    bool truncated = false;

    while (turn < opts.maxTurns) {
      if (_abort.signal.aborted) break;
      turn++;

      // Rebuild system prompt each turn so <deck meta> stays current
      final system = _buildSystem();

      // Stream one model turn. Collect deltas into a text buffer and tool
      // calls into a list.
      final turnText = StringBuffer();
      final toolCalls = <AgentToolCall>[];
      String? stopReason;
      String? streamError;

      final completer = Completer<void>();
      _activeHandle = opts.transport.stream(
        AgentStreamRequest(system: system, messages: List.of(_messages), tools: toolDefs),
        AgentStreamCallbacks(
          onDelta: (t) {
            turnText.write(t);
            opts.events.onText?.call(t);
          },
          onToolCall: (call) {
            toolCalls.add(call);
          },
          onStopReason: (r) => stopReason = r,
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
          onError: (e) {
            streamError = e;
            if (!completer.isCompleted) completer.complete();
          },
        ),
      );

      await completer.future;
      _activeHandle = null;

      if (_abort.signal.aborted) break;

      if (streamError != null) {
        final cancelled = _looksLikeAbort(streamError!);
        final result = AgentRunResult(
          text: lastText,
          cancelled: cancelled,
          isError: !cancelled,
          turnLimit: false,
        );
        opts.events.onError?.call(streamError!);
        opts.events.onDone?.call(result);
        return result;
      }

      lastText = turnText.toString();
      _lastAssistantText = lastText;
      truncated = stopReason == 'max_tokens';

      // Push the assistant message into history.
      _messages.add(AgentAssistantMessage(
        text: lastText,
        toolCalls: toolCalls.isEmpty ? null : toolCalls,
      ));

      // If no tool calls, check verifyResponse before finalizing.
      if (toolCalls.isEmpty) {
        // Optional verifyResponse correction (apply at most once per run).
        // This catches runs that end without required tool calls (e.g. generate_deck).
        if (!_correctionApplied) {
          final correction = opts.skill.verifyResponse(
            lastText,
            _executed.map((e) => ExecutedToolCall(name: e.name, ok: e.ok)).toList(),
          );
          if (correction != null) {
            _correctionApplied = true;
            _messages.add(AgentUserMessage(text: correction));
            // Continue to next turn with the correction — don't break yet.
            opts.events.onTurnEnd?.call();
            continue;
          }
        }

        _consecutiveIdenticalTurns = 0;
        _consecutiveErrorTurns = 0;
        // Degenerate-loop: identical final text back-to-back.
        if (_lastFingerprint != null && _lastFingerprint == lastText) {
          _consecutiveIdenticalTurns++;
          if (_consecutiveIdenticalTurns >= maxIdenticalTurns) {
            final result = AgentRunResult(text: lastText, cancelled: false, turnLimit: false);
            opts.events.onDone?.call(result);
            return result;
          }
        } else {
          _lastFingerprint = lastText;
          _consecutiveIdenticalTurns = 1;
        }
        break;
      }

      // Execute the tool calls. Tool-call agents run sequentially.
      final results = <AgentToolResult>[];
      bool anyMutated = false;
      bool anyOk = false;
      for (final call in toolCalls) {
        if (_abort.signal.aborted) break;
        opts.events.onToolStart?.call(call);
        final ToolExecution exec;
        try {
          exec = await opts.skill.executeTool(call, signal: _abort.signal);
        } catch (e) {
          results.add(AgentToolResult(
            id: call.id,
            name: call.name,
            output: 'Tool execution threw: $e',
            isError: true,
          ));
          _executed.add(_ExecutedCall(call.name, false));
          opts.events.onToolExecuted?.call(call, ToolExecution(
            output: 'Tool execution threw: $e',
            isError: true,
            summary: call.name,
          ));
          continue;
        }
        results.add(AgentToolResult(
          id: call.id,
          name: call.name,
          output: exec.output,
          isError: exec.isError,
        ));
        _executed.add(_ExecutedCall(call.name, !exec.isError));
        if (!exec.isError) anyOk = true;
        if (exec.mutated) anyMutated = true;
        opts.events.onToolExecuted?.call(call, exec);
      }

      _messages.add(AgentToolMessage(results: results));
      opts.events.onTurnEnd?.call();

      // Degenerate-loop: every tool errored.
      if (!anyOk) {
        _consecutiveErrorTurns++;
        if (_consecutiveErrorTurns >= maxAllErrorTurns) {
          final result = AgentRunResult(text: lastText, cancelled: false, turnLimit: false);
          opts.events.onDone?.call(result);
          return result;
        }
      } else {
        _consecutiveErrorTurns = 0;
      }

      // Optional verifyResponse correction (apply at most once per run).
      if (!_correctionApplied) {
        final correction = opts.skill.verifyResponse(
          lastText,
          _executed.map((e) => ExecutedToolCall(name: e.name, ok: e.ok)).toList(),
        );
        if (correction != null) {
          _correctionApplied = true;
          _messages.add(AgentUserMessage(text: correction));
        }
      }
    }

    if (turn >= opts.maxTurns) turnLimit = true;

    final result = AgentRunResult(
      text: lastText,
      cancelled: _abort.signal.aborted,
      turnLimit: turnLimit,
      truncated: truncated ? true : null,
    );
    opts.events.onDone?.call(result);
    return result;
  }

  /// Read-only view of the messages history (for tests and the chat panel's
  /// persistence step).
  List<AgentMessage> get messages => List.unmodifiable(_messages);

  String _buildSystem() {
    final base = opts.skill.systemPrompt;
    final suffix = opts.systemSuffix?.call() ?? '';
    if (suffix.isEmpty) return base;
    return '$base\n\n$suffix';
  }

  bool _looksLikeAbort(String error) {
    return _abort.signal.aborted || error.toLowerCase().contains('abort');
  }
}
