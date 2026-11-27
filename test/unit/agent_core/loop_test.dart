// DocuCraft Flutter — agent-core loop + skill tests (Sprint 13)
//
// Pure unit tests for the AgentLoop orchestrator. Uses a FakeTransport
// (test-only) that emits scripted deltas + tool calls, so the loop logic
// is exercised without any HTTP/network.

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:docucraft_app/agent_core/agent_core.dart';

/// Records all events the loop emits. Mirrors the `AgentLoopEvents` surface.
class _Recorder {
  final List<String> texts = [];
  final List<String> toolsStarted = [];
  final List<ToolExecution> toolsExecuted = [];
  int turnEnds = 0;
  AgentRunResult? done;
  String? error;

  AgentLoopEvents attach() => AgentLoopEvents(
        onText: (t) => texts.add(t),
        onToolStart: (c) => toolsStarted.add(c.name),
        onToolExecuted: (c, e) => toolsExecuted.add(e),
        onTurnEnd: () => turnEnds++,
        onDone: (r) => done = r,
        onError: (e) => error = e,
      );
}

/// A test-only transport. Each test pushes a script of [ScriptedTurn]s;
/// the transport pops one per `stream()` call.
class FakeTransport implements AgentTransport {
  final List<ScriptedTurn> script;
  int index = 0;
  final List<AgentStreamRequest> requests = [];

  FakeTransport(this.script);

  @override
  AgentStreamHandle stream(AgentStreamRequest request, AgentStreamCallbacks cb) {
    requests.add(request);
    final turn = script[index < script.length ? index : script.length - 1];
    index++;
    return ScriptedStreamHandle(turn, cb).go();
  }
}

class ScriptedTurn {
  final List<String> deltas;
  final List<AgentToolCall> toolCalls;
  final String? stopReason;
  final String? error;
  ScriptedTurn({this.deltas = const [], this.toolCalls = const [], this.stopReason, this.error});
}

class ScriptedStreamHandle implements AgentStreamHandle {
  final ScriptedTurn turn;
  final AgentStreamCallbacks cb;
  bool _cancelled = false;

  ScriptedStreamHandle(this.turn, this.cb);

  ScriptedStreamHandle go() {
    Future.microtask(() async {
      if (_cancelled) {
        cb.onDone();
        return;
      }
      for (final d in turn.deltas) {
        cb.onDelta(d);
      }
      for (final call in turn.toolCalls) {
        cb.onToolCall(call);
      }
      if (turn.error != null) {
        cb.onError(turn.error!);
        return;
      }
      if (turn.stopReason != null) cb.onStopReason!(turn.stopReason!);
      cb.onDone();
    });
    return this;
  }

  @override
  void cancel() {
    _cancelled = true;
  }
}

/// Skill that echoes one tool call: returns a deterministic payload.
class _EchoSkill implements AgentSkill {
  @override
  String get id => 'echo';
  @override
  String get systemPrompt => 'You are an echo.';
  @override
  List<AgentToolDef> get tools => const [
        AgentToolDef(name: 'echo', description: 'echo input', inputSchema: {}),
      ];
  @override
  String buildContext() => '';
  @override
  String? verifyResponse(String finalText, List<ExecutedToolCall> executed) => null;
  @override
  Future<ToolExecution> executeTool(AgentToolCall call, {AbortSignal? signal}) async {
    return ToolExecution(
      output: 'echoed: ${call.input['msg']}',
      mutated: false,
      summary: 'echo',
    );
  }
}

void main() {
  group('AgentLoop', () {
    test('text-only turn resolves with final text and no tool calls', () async {
      final transport = FakeTransport([
        ScriptedTurn(deltas: ['Hello, ', 'world!']),
      ]);
      final rec = _Recorder();
      final loop = AgentLoop(AgentLoopOptions(
        transport: transport,
        skill: _EchoSkill(),
        events: rec.attach(),
      ));

      final result = await loop.run('hi');

      expect(result.cancelled, isFalse);
      expect(result.turnLimit, isFalse);
      expect(result.text, 'Hello, world!');
      expect(rec.texts.join(), 'Hello, world!');
      expect(rec.toolsExecuted, isEmpty);
      expect(transport.requests.length, 1);
    });

    test('tool call → execution → follow-up turn → final text', () async {
      final transport = FakeTransport([
        ScriptedTurn(
          deltas: ['Let me echo.'],
          toolCalls: [AgentToolCall(id: '1', name: 'echo', input: {'msg': 'ping'})],
        ),
        ScriptedTurn(deltas: ['Done: ping']),
      ]);
      final rec = _Recorder();
      final loop = AgentLoop(AgentLoopOptions(
        transport: transport,
        skill: _EchoSkill(),
        events: rec.attach(),
      ));

      final result = await loop.run('go');

      expect(result.text, 'Done: ping');
      expect(rec.toolsStarted, ['echo']);
      expect(rec.toolsExecuted.length, 1);
      expect(rec.toolsExecuted.first.output, 'echoed: ping');
      expect(rec.turnEnds, 1);
      // Two requests: initial + post-tool.
      expect(transport.requests.length, 2);
    });

    test('abort cancels mid-stream and stops the loop', () async {
      final transport = FakeTransport([
        ScriptedTurn(deltas: ['partial']),
        ScriptedTurn(deltas: ['should not see this']),
      ]);
      final rec = _Recorder();
      final loop = AgentLoop(AgentLoopOptions(
        transport: transport,
        skill: _EchoSkill(),
        events: rec.attach(),
      ));

      // Schedule a cancel right after the run starts.
      Future.microtask(() => loop.cancel());
      final result = await loop.run('go');

      expect(result.cancelled, isTrue);
    });

    test('maxTurns caps and returns turnLimit flag', () async {
      // Script that always returns a tool call. The skill returns ok so the
      // loop never degenerates, only maxTurns ends it.
      final transport = FakeTransport([
        ScriptedTurn(
          toolCalls: [AgentToolCall(id: '1', name: 'echo', input: {'msg': '1'})],
        ),
        ScriptedTurn(
          toolCalls: [AgentToolCall(id: '1', name: 'echo', input: {'msg': '2'})],
        ),
        ScriptedTurn(
          toolCalls: [AgentToolCall(id: '1', name: 'echo', input: {'msg': '3'})],
        ),
      ]);
      final rec = _Recorder();
      final loop = AgentLoop(AgentLoopOptions(
        transport: transport,
        skill: _EchoSkill(),
        events: rec.attach(),
        maxTurns: 2,
      ));

      final result = await loop.run('go');

      expect(result.turnLimit, isTrue);
      // Two turns consumed: tool, tool (capped at 2).
      expect(transport.requests.length, 2);
    });

    test('transport error propagates as AgentRunResult with cancelled=false', () async {
      final transport = FakeTransport([
        ScriptedTurn(error: 'gateway down'),
      ]);
      final rec = _Recorder();
      final loop = AgentLoop(AgentLoopOptions(
        transport: transport,
        skill: _EchoSkill(),
        events: rec.attach(),
      ));

      final result = await loop.run('go');

      expect(rec.error, 'gateway down');
      expect(result.cancelled, isFalse);
    });
  });

  group('ComposedSkill', () {
    test('merges system prompts and tool lists', () {
      final a = _StaticSkill('a', 'sys-a', const [
        AgentToolDef(name: 'ta', description: 'a', inputSchema: {}),
      ]);
      final b = _StaticSkill('b', 'sys-b', const [
        AgentToolDef(name: 'tb', description: 'b', inputSchema: {}),
      ]);
      final c = ComposedSkill(id: 'c', intro: 'intro-text', skills: [a, b]);
      expect(c.systemPrompt, contains('intro-text'));
      expect(c.systemPrompt, contains('sys-a'));
      expect(c.systemPrompt, contains('sys-b'));
      expect(c.tools.length, 2);
      expect(c.tools.map((t) => t.name).toSet(), {'ta', 'tb'});
    });

    test('throws on duplicate tool names', () {
      final a = _StaticSkill('a', 'a', const [
        AgentToolDef(name: 'shared', description: 'x', inputSchema: {}),
      ]);
      final b = _StaticSkill('b', 'b', const [
        AgentToolDef(name: 'shared', description: 'x', inputSchema: {}),
      ]);
      expect(() => ComposedSkill(id: 'c', intro: 'i', skills: [a, b]).tools,
          throwsA(isA<StateError>()));
    });

    test('routes executeTool by tool name', () async {
      final a = _StaticSkill('a', 'a', const [
        AgentToolDef(name: 'ta', description: 'a', inputSchema: {}),
      ], execOutput: 'from-a');
      final b = _StaticSkill('b', 'b', const [
        AgentToolDef(name: 'tb', description: 'b', inputSchema: {}),
      ], execOutput: 'from-b');
      final c = ComposedSkill(id: 'c', intro: 'i', skills: [a, b]);
      final ra = await c.executeTool(const AgentToolCall(id: '1', name: 'ta', input: {}));
      final rb = await c.executeTool(const AgentToolCall(id: '1', name: 'tb', input: {}));
      expect(ra.output, 'from-a');
      expect(rb.output, 'from-b');
    });
  });

  group('AbortSignal', () {
    test('initial state not aborted', () {
      final s = AbortSignal();
      expect(s.aborted, isFalse);
    });

    test('controller.abort flips signal', () {
      final c = AbortController();
      var fired = 0;
      c.signal.onAbort(() => fired++);
      c.abort();
      expect(c.signal.aborted, isTrue);
      expect(fired, 1);
      // Second abort does not re-fire listeners.
      c.abort();
      expect(fired, 1);
    });

    test('listener fires immediately if already aborted', () {
      final c = AbortController()..abort();
      var fired = 0;
      c.signal.onAbort(() => fired++);
      expect(fired, 1);
    });
  });
}

class _StaticSkill implements AgentSkill {
  @override
  final String id;
  @override
  final String systemPrompt;
  @override
  final List<AgentToolDef> tools;
  final String execOutput;
  _StaticSkill(this.id, this.systemPrompt, this.tools, {this.execOutput = 'ok'});

  @override
  String buildContext() => '';

  @override
  String? verifyResponse(String finalText, List<ExecutedToolCall> executed) => null;

  @override
  Future<ToolExecution> executeTool(AgentToolCall call, {AbortSignal? signal}) async {
    return ToolExecution(output: execOutput, mutated: false, summary: call.name);
  }
}
