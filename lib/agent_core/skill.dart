// DocuCraft Flutter — AgentSkill (Sprint 13)
//
// Port Dart murni dari GenOffice `packages/agent-core/src/skill.ts`. Sebuah
// skill membungkus satu domain kapabilitas untuk agent loop: bagian system
// prompt-nya, tool-nya, konteks per-turn, dan tool executor-nya.

import 'dart:async';
import 'types.dart';

/// One tool call actually executed during a run, as seen by `verifyResponse`.
class ExecutedToolCall {
  final String name;
  /// False when the execution returned an error result.
  final bool ok;

  const ExecutedToolCall({required this.name, required this.ok});
}

/// A skill packages one capability domain for the agent loop.
abstract class AgentSkill {
  String get id;

  /// System prompt section describing this skill's rules and tools.
  String get systemPrompt;

  /// Tool definitions exposed to the model.
  List<AgentToolDef> get tools;

  /// Fresh context sections attached to every user turn (e.g. document
  /// skeleton + selection). Return `''` when there is nothing to attach.
  String buildContext() => '';

  /// Execute a tool call. `signal` is aborted when the user hits stop.
  /// Long-running tools should check `signal.aborted` in their loops.
  Future<ToolExecution> executeTool(AgentToolCall call, {AbortSignal? signal});

  /// Claimed-action guard: inspect the run's final assistant text against the
  /// tools that actually executed. Return a corrective instruction to force
  /// one more model turn, or null to accept the reply. The loop applies the
  /// correction at most once per run.
  String? verifyResponse(String finalText, List<ExecutedToolCall> executed) => null;
}

/// Merge several skills into one. Tool names must be globally unique across
/// the composed set.
class ComposedSkill implements AgentSkill {
  @override
  final String id;
  final String intro;
  final List<AgentSkill> skills;

  ComposedSkill({required this.id, required this.intro, required this.skills});

  AgentSkill? _ownerOf(String name) {
    for (final s in skills) {
      if (s.tools.any((t) => t.name == name)) return s;
    }
    return null;
  }

  @override
  String get systemPrompt {
    final parts = <String>[intro, ...skills.map((s) => s.systemPrompt)]
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join('\n\n');
  }

  @override
  List<AgentToolDef> get tools {
    final all = <AgentToolDef>[];
    final seen = <String>{};
    for (final s in skills) {
      for (final t in s.tools) {
        if (seen.contains(t.name)) {
          throw StateError('duplicate tool name: ${t.name}');
        }
        seen.add(t.name);
        all.add(t);
      }
    }
    return all;
  }

  @override
  String buildContext() {
    return skills
        .map((s) => s.buildContext())
        .where((s) => s.isNotEmpty)
        .join('\n\n');
  }

  @override
  Future<ToolExecution> executeTool(AgentToolCall call, {AbortSignal? signal}) async {
    final skill = _ownerOf(call.name);
    if (skill == null) {
      return ToolExecution(
        output: 'Unknown tool: ${call.name}',
        isError: true,
        summary: call.name,
      );
    }
    return skill.executeTool(call, signal: signal);
  }

  @override
  String? verifyResponse(String finalText, List<ExecutedToolCall> executed) {
    for (final s in skills) {
      final correction = s.verifyResponse(finalText, executed);
      if (correction != null) return correction;
    }
    return null;
  }
}

// ── AbortSignal (lightweight dart:async-based) ─────────────────────

/// Minimal AbortSignal for tool executors. Mirrors the DOM `AbortSignal`
/// surface used by GenOffice's `loop.ts` (just `.aborted` and `onAbort`).
class AbortSignal {
  bool _aborted = false;
  final List<void Function()> _listeners = [];

  bool get aborted => _aborted;

  /// Subscribe to abort. Returns a function that unsubscribes.
  void Function() onAbort(void Function() cb) {
    _listeners.add(cb);
    if (_aborted) cb();
    return () => _listeners.remove(cb);
  }

  void _abort() {
    if (_aborted) return;
    _aborted = true;
    for (final l in List.of(_listeners)) {
      l();
    }
  }
}

/// Controller paired with an [AbortSignal].
class AbortController {
  final AbortSignal signal = AbortSignal();
  void abort() => signal._abort();
}
