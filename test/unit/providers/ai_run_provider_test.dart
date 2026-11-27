// DocuCraft Flutter — AiRunProvider unit tests (Sprint 12)

import 'package:flutter_test/flutter_test.dart';
import 'package:docucraft_app/providers/ai_run_provider.dart';
import 'package:docucraft_app/ai/run_state_machine.dart';

void main() {
  group('AiRunProvider — lifecycle', () {
    test('initial state is idle with empty snapshot', () {
      final p = AiRunProvider();
      expect(p.state, isA<RunIdle>());
      expect(p.isBusy, isFalse);
      expect(p.snapshot.instruction, '');
      expect(p.snapshot.streamedText, '');
    });

    test('start() transitions to starting and seeds snapshot', () {
      final p = AiRunProvider();
      p.start(instruction: 'ppt about cats');
      expect(p.state, isA<RunStarting>());
      expect(p.snapshot.instruction, 'ppt about cats');
      expect(p.snapshot.lastInstruction, 'ppt about cats');
    });

    test('start() while busy is a no-op', () {
      final p = AiRunProvider();
      p.start(instruction: 'first');
      p.onText('a');
      p.start(instruction: 'second');
      expect(p.snapshot.instruction, 'first', reason: 'second start must be ignored');
    });

    test('newChat resets to idle and clears snapshot', () {
      final p = AiRunProvider();
      p.start(instruction: 'p');
      p.onText('streamed');
      p.newChat();
      expect(p.state, isA<RunIdle>());
      expect(p.snapshot.instruction, '');
      expect(p.snapshot.streamedText, '');
    });

    test('dispose() drains pending outline review as cancelled', () async {
      final p = AiRunProvider();
      p.start(instruction: 'p');
      p.onText('a');
      final future = p.enterOutlineReview(
        topic: 'p',
        pages: const [OutlinePage(index: 1, title: 'A', brief: 'a')],
      );
      // Drain by disposing (not by resolving)
      p.dispose();
      // Should complete with null (cancelled)
      final result = await future;
      expect(result, isNull);
    });
  });

  group('AiRunProvider — streaming', () {
    test('onText transitions starting → streaming and appends text', () {
      final p = AiRunProvider();
      p.start(instruction: 'p');
      p.onText('hello ');
      expect(p.state, isA<RunStreaming>());
      expect(p.snapshot.streamedText, 'hello ');
      p.onText('world');
      expect(p.snapshot.streamedText, 'hello world');
    });

    test('onToolStart marks tool as running', () {
      final p = AiRunProvider();
      p.start(instruction: 'p');
      p.onText('a');
      p.onToolStart('web_search');
      expect(p.snapshot.runTools, hasLength(1));
      expect(p.snapshot.runTools.first.name, 'web_search');
      expect(p.snapshot.runTools.first.running, isTrue);
    });

    test('onToolExecuted marks tool as not running', () {
      final p = AiRunProvider();
      p.start(instruction: 'p');
      p.onText('a');
      p.onToolStart('web_search');
      p.onToolExecuted('web_search');
      expect(p.snapshot.runTools.first.running, isFalse);
    });

    test('onToolExecuted captures blueprint meta for generate_deck', () {
      final p = AiRunProvider();
      p.start(instruction: 'p');
      p.onText('a');
      p.onToolExecuted('generate_deck', result: {
        'topic': 'cats',
        'styleSkill': 'modern',
        'pageCount': 5,
      });
      expect(p.snapshot.docucraftMeta, isNotNull);
      expect(p.snapshot.docucraftMeta!.topic, 'cats');
      expect(p.snapshot.docucraftMeta!.styleSkill, 'modern');
      expect(p.snapshot.docucraftMeta!.pageCount, 5);
    });

    test('onDone transitions to done and clears silence timer', () {
      final p = AiRunProvider();
      p.start(instruction: 'p');
      p.onText('a');
      p.onDone(cancelled: false, ok: true, duration: const Duration(seconds: 1));
      expect(p.state, isA<RunDone>());
      expect((p.state as RunDone).ok, isTrue);
    });

    test('onError transitions to error and clears blueprint meta', () {
      final p = AiRunProvider();
      p.start(instruction: 'p');
      p.onText('a');
      p.onToolExecuted('generate_deck', result: {'topic': 't'});
      p.onError('boom');
      expect(p.state, isA<RunError>());
      expect(p.snapshot.docucraftMeta, isNull, reason: 'half-baked blueprint must be cleared');
    });
  });

  group('AiRunProvider — cancel', () {
    test('cancel() from streaming sets cancellingSince', () {
      final p = AiRunProvider();
      p.start(instruction: 'p');
      p.onText('a');
      p.cancel();
      final s = p.state as RunStreaming;
      expect(s.cancellingSince, isNotNull);
    });

    test('cancel() from idle is a no-op', () {
      final p = AiRunProvider();
      p.cancel();
      expect(p.state, isA<RunIdle>());
    });
  });

  group('AiRunProvider — outline review', () {
    test('enterOutlineReview → resolveOutlineReview round-trip', () async {
      final p = AiRunProvider();
      p.start(instruction: 'p');
      p.onText('a');
      final future = p.enterOutlineReview(
        topic: 'p',
        pages: const [OutlinePage(index: 1, title: 'A', brief: 'a')],
      );
      expect(p.state, isA<RunAwaitingOutlineReview>());
      final edited = [const OutlinePage(index: 1, title: 'A2', brief: 'a2')];
      p.resolveOutlineReview(pages: edited);
      final result = await future;
      expect(result, edited);
      expect(p.state, isA<RunStreaming>());
    });

    test('resolveOutlineReview with cancelled completes with null', () async {
      final p = AiRunProvider();
      p.start(instruction: 'p');
      p.onText('a');
      final future = p.enterOutlineReview(
        topic: 'p',
        pages: const [OutlinePage(index: 1, title: 'A', brief: 'a')],
      );
      p.resolveOutlineReview(cancelled: true);
      final result = await future;
      expect(result, isNull);
      expect(p.state, isA<RunIdle>());
    });
  });

  group('AiRunProvider — QC', () {
    test('enterQc / tickQcProgress / exitQc lifecycle', () {
      final p = AiRunProvider();
      p.start(instruction: 'p');
      p.onText('a');
      p.enterQc(total: 5);
      expect(p.state, isA<RunQc>());
      expect((p.state as RunQc).total, 5);
      p.tickQcProgress(done: 2);
      expect((p.state as RunQc).done, 2);
      p.tickQcProgress(done: 5);
      expect((p.state as RunQc).done, 5);
      p.exitQc();
      expect(p.state, isA<RunIdle>());
    });
  });
}
