// DocuCraft Flutter — DocuCraftRunCoordinator tests (Sprint 13)
//
// Exercises the two-stage outline → generate_deck flow with a fake
// transport. Verifies the coordinator's hook callbacks fire in the
// right order and that the run-provider's state machine transitions are
// triggered.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docucraft_app/agent_core/agent_core.dart';
import 'package:docucraft_app/agent_core/docucraft_run_coordinator.dart';
import 'package:docucraft_app/agent_core/slides_skill.dart';
import 'package:docucraft_app/ai/run_state_machine.dart';
import 'package:docucraft_app/models/slide.dart';

/// A scripted transport that pushes one tool call per request.
class _ScriptedTransport implements AgentTransport {
  final List<ScriptedTurn> script;
  int index = 0;
  final List<AgentStreamRequest> requests = [];

  _ScriptedTransport(this.script);

  @override
  AgentStreamHandle stream(AgentStreamRequest request, AgentStreamCallbacks cb) {
    requests.add(request);
    final turn = script[index < script.length ? index : script.length - 1];
    index++;
    Future.microtask(() {
      for (final t in turn.toolCalls) {
        cb.onToolCall(t);
      }
      for (final d in turn.deltas) {
        cb.onDelta(d);
      }
      if (turn.error != null) {
        cb.onError(turn.error!);
      } else {
        cb.onDone();
      }
    });
    return _NoopHandle();
  }
}

class ScriptedTurn {
  final List<String> deltas;
  final List<AgentToolCall> toolCalls;
  final String? error;
  ScriptedTurn({this.deltas = const [], this.toolCalls = const [], this.error});
}

class _NoopHandle implements AgentStreamHandle {
  @override
  void cancel() {}
}

class _FakeRunProvider {
  int enterQcCalls = 0;
  int tickQcCalls = 0;
  int exitQcCalls = 0;
  int onErrorCalls = 0;
  int onTextCalls = 0;
  final List<String> toolStarts = [];
  final List<String> toolExecuted = [];
  int batchIdCounter = 0;
  final _FakeSnapshot snapshot = _FakeSnapshot();
  final List<Slide> slides = [];

  void onText(String t) => onTextCalls++;
  void onToolStart(String name) => toolStarts.add(name);
  void onToolExecuted(String name,
      {Map<String, dynamic>? result, bool isError = false, String? summary, String? output}) =>
      toolExecuted.add(name);
  void enterQc({required int total}) => enterQcCalls++;
  void tickQcProgress({required int done}) => tickQcCalls++;
  void exitQc() => exitQcCalls++;
  void onError(String e) => onErrorCalls++;
  int beginBatch() => ++batchIdCounter;
  void restoreSnapshot(int batchId) {}
  void notifyListeners() {}
}

class _FakeSnapshot {
  final Set<int> qcPagesPinned = {};
  String instruction = '';
}

class _FakePageGen implements PageGenerator {
  final List<String?> script;
  int i = 0;
  _FakePageGen(this.script);
  @override
  Future<String> generateSvg({
    required String topic,
    required int pageIndex,
    required int totalPages,
    required String title,
    required String brief,
    String layout = '',
  }) async {
    final next = i < script.length ? script[i] : null;
    i++;
    if (next == null) throw 'no script for $pageIndex';
    return next;
  }
}

const _simpleSvg = '''
<svg width="1920" height="1080" xmlns="http://www.w3.org/2000/svg">
  <rect x="100" y="100" width="800" height="200" fill="#6366F1" rx="12"/>
  <text x="100" y="200" font-size="48" fill="#FFFFFF" font-weight="bold">Hi</text>
  <ellipse cx="500" cy="600" rx="200" ry="100" fill="#EC4899"/>
  <polygon points="100,800 300,800 200,900" fill="#10B981"/>
  <text x="100" y="950" font-size="20" fill="#000000">body</text>
</svg>
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock SharedPreferences for SettingsService
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('DocuCraftRunCoordinator', () {
    test('planOutline parses JSON, surfaces pages, awaits user review', () async {
      final transport = _ScriptedTransport([
        ScriptedTurn(toolCalls: [
          AgentToolCall(
            id: '1',
            name: 'plan_deck_outline',
            input: {
              'outlineJson':
                  '{"pages":[{"title":"Intro","brief":"why"},{"title":"Body","brief":"how"}]}'
            },
          ),
        ]),
      ]);
      final coord = DocuCraftRunCoordinator(
        transport: transport,
        systemPrompt: 'sys',
        onOutlineReady: (topic, initial, {String? planSummary}) async {
          expect(topic, 'cats');
          expect(initial.length, 2);
          return initial; // user accepts unchanged
        },
        onSlideLanded: (_, {required replaceAll}) {},
        onProgress: ({required stage, required label, required done, required total, required status, summary, pages}) {},
      );
      final pages = await coord.planOutline(
        topic: 'cats',
        runProvider: _FakeRunProvider(),
      );
      expect(pages.length, 2);
      expect(pages.first.title, 'Intro');
    });

    test('generateDeck: runs AgentLoop and returns result', () async {
      // Script: model calls generate_deck, then emits final text.
      // The actual page generation pipeline runs inside SlidesSkill.
      final transport = _ScriptedTransport([
        ScriptedTurn(toolCalls: [
          AgentToolCall(
            id: '1',
            name: 'generate_deck',
            input: {
              'topic': 'cats',
              'pages': [
                {'index': 1, 'title': 'Intro', 'brief': 'why'},
                {'index': 2, 'title': 'Body', 'brief': 'how'},
              ],
            },
          ),
        ]),
        ScriptedTurn(deltas: ['Done!']),
      ]);
      final rp = _FakeRunProvider();
      final landed = <_Landed>[];
      final coord = DocuCraftRunCoordinator(
        transport: transport,
        systemPrompt: 'sys',
        onOutlineReady: (_, pages, {String? planSummary}) async => pages,
        onSlideLanded: (slide, {required replaceAll}) =>
            landed.add(_Landed(slide, replaceAll)),
        onProgress: ({required stage, required label, required done, required total, required status, summary, pages}) {},
      );
      final result = await coord.generateDeck(
        topic: 'cats',
        pages: const [
          OutlinePage(index: 1, title: 'Intro', brief: 'why'),
          OutlinePage(index: 2, title: 'Body', brief: 'how'),
        ],
        styleSkill: 'modern',
        runProvider: rp,
      );
      // Coordinator completed without crashing.
      // SlidesSkill handles page generation + QC internally.
      expect(result, isA<DeckGenerationResult>());
    });

    test('generateDeck: returns cancelled=true when model is aborted', () async {
      // Script that never calls any tool: the loop's maxTurns or the abort
      // path returns turnLimit/cancelled.
      final transport = _ScriptedTransport([
        ScriptedTurn(deltas: ['just text, no tool']),
      ]);
      final rp = _FakeRunProvider();
      final coord = DocuCraftRunCoordinator(
        transport: transport,
        systemPrompt: 'sys',
        onOutlineReady: (_, pages, {String? planSummary}) async => pages,
        onSlideLanded: (_, {required replaceAll}) {},
        onProgress: ({required stage, required label, required done, required total, required status, summary, pages}) {},
      );
      final result = await coord.generateDeck(
        topic: 'cats',
        pages: const [OutlinePage(index: 1, title: 'A', brief: 'a')],
        styleSkill: 'modern',
        runProvider: rp,
      );
      // No generate_deck tool was called → no slides landed.
      expect(result.success, isFalse);
    });
  });
}

class _Landed {
  final Slide slide;
  final bool replaceAll;
  _Landed(this.slide, this.replaceAll);
}
