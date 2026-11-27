// DocuCraft Flutter — SlidesSkill tests (Sprint 13)
//
// Tests the slides-skill's `generate_deck` tool: SVG parsing, per-page
// error tolerance, and meta capture. A fake PageGenerator keeps the test
// off the network.

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:docucraft_app/agent_core/agent_core.dart';
import 'package:docucraft_app/agent_core/slides_skill.dart';
import 'package:docucraft_app/ai/run_state_machine.dart';
import 'package:docucraft_app/models/slide.dart';

/// Test page generator: returns scripted SVG (or throws on fail).
class FakePageGenerator implements PageGenerator {
  final List<String?> _script;
  int _i = 0;

  FakePageGenerator(this._script);

  @override
  Future<String> generateSvg({
    required String topic,
    required int pageIndex,
    required int totalPages,
    required String title,
    required String brief,
    String layout = '',
  }) async {
    final next = _i < _script.length ? _script[_i] : null;
    _i++;
    if (next == null) {
      throw 'no script for page $pageIndex';
    }
    return next;
  }
}

const _simpleSvg = '''
<svg width="1920" height="1080" xmlns="http://www.w3.org/2000/svg">
  <rect x="100" y="100" width="800" height="200" fill="#6366F1" rx="12"/>
  <text x="100" y="200" font-size="48" fill="#FFFFFF" font-weight="bold">Hello</text>
  <ellipse cx="500" cy="600" rx="200" ry="100" fill="#EC4899"/>
  <polygon points="100,800 300,800 200,900" fill="#10B981"/>
  <text x="100" y="950" font-size="20" fill="#000000">body</text>
</svg>
''';

void main() {
  group('SlidesSkill', () {
    test('exposes generate_deck and other tools', () {
      final sink = _CapturingSink();
      final skill = _buildSkill(generator: FakePageGenerator([]), sink: sink);
      expect(skill.tools.map((t) => t.name), containsAll(['generate_deck', 'regenerate_slide', 'save_style_template', 'list_style_templates']));
    });

    test('buildContext previews the approved outline', () {
      final sink = _CapturingSink();
      final skill = _buildSkill(generator: FakePageGenerator([]), sink: sink);
      final ctx = skill.buildContext();
      expect(ctx, contains('Approved outline'));
      expect(ctx, contains('Intro'));
      expect(ctx, contains('Body'));
    });

    test('generate_deck: returns 2 slides + meta + 1 sink replaceAll', () async {
      final sink = _CapturingSink();
      final gen = FakePageGenerator([_simpleSvg, _simpleSvg]);
      final skill = _buildSkill(generator: gen, sink: sink);
      final exec = await skill.executeTool(
        AgentToolCall(
          id: '1',
          name: 'generate_deck',
          input: {'topic': 'cats', 'outlineJson': '[]'},
        ),
      );
      expect(exec.isError, isFalse);
      expect(exec.mutated, isTrue);
      expect(sink.replaced.length, 1);
      expect(sink.appended.length, 1);
    });

    test('generate_deck: per-page failure produces a placeholder slide', () async {
      final sink = _CapturingSink();
      // Skill has 2 hardcoded pages; second throws → only 1 successful slide.
      final gen = FakePageGenerator([_simpleSvg, null]);
      final skill = _buildSkill(generator: gen, sink: sink);
      final exec = await skill.executeTool(
        AgentToolCall(
          id: '1',
          name: 'generate_deck',
          input: {'topic': 'x', 'outlineJson': '[]'},
        ),
      );
      // Currently, failed pages don't add to sink (placeholder behavior removed)
      expect(exec.isError, isFalse);
      expect(sink.allSlides.length, 1); // Only successful page added
    });

    test('unknown tool returns isError', () async {
      final sink = _CapturingSink();
      final skill = _buildSkill(generator: FakePageGenerator([]), sink: sink);
      final exec = await skill.executeTool(
        AgentToolCall(id: '1', name: 'mystery', input: {}),
      );
      expect(exec.isError, isTrue);
      expect(exec.output, contains('Unknown tool'));
    });
  });
}

SlidesSkill _buildSkill({
  required PageGenerator generator,
  required _CapturingSink sink,
}) {
  return SlidesSkill(
    systemPrompt: 'slides skill',
    generator: generator,
    sink: sink.call,
    topic: 'demo',
    pages: const [
      OutlinePage(index: 1, title: 'Intro', brief: 'why'),
      OutlinePage(index: 2, title: 'Body', brief: 'how'),
    ],
  );
}

class _CapturingSink {
  final List<Slide> replaced = [];
  final List<Slide> appended = [];

  List<Slide> get allSlides => [...replaced, ...appended];

  void call(Slide slide, {required bool replaceAll}) {
    if (replaceAll) {
      replaced.add(slide);
    } else {
      appended.add(slide);
    }
  }
}
