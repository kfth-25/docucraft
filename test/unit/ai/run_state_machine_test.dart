// DocuCraft Flutter — Run State Machine unit tests (Sprint 12)
//
// Pure-Dart tests (no flutter_test, no render tree). Run with:
//   cd C:/Users/Pongo/docucraft_app
//   flutter test test/unit/ai/run_state_machine_test.dart
// or
//   dart test test/unit/ai/run_state_machine_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:docucraft_app/ai/run_state_machine.dart';

void main() {
  final t0 = DateTime.utc(2026, 9, 5, 12, 0, 0);
  DateTime t(int seconds) => t0.add(Duration(seconds: seconds));

  group('initial state', () {
    test('idle is not busy', () {
      expect(const RunIdle().isBusy, isFalse);
      expect(const RunIdle().kind, 'idle');
    });
  });

  group('start', () {
    test('idle → starting', () {
      final s = reduce(const RunIdle(), StartRun(now: t(1), instruction: 'ppt'));
      expect(s, isA<RunStarting>());
      expect((s as RunStarting).instruction, 'ppt');
    });

    test('starting when already busy is a no-op', () {
      final busy = RunStreaming(
        startedAt: t(1),
        lastActivityAt: t(2),
        cancellingSince: null,
      );
      final s = reduce(busy, StartRun(now: t(5), instruction: 'x'));
      expect(s, same(busy));
    });

    test('done → starting is no-op (must newChat first)', () {
      final done = const RunDone(ok: true, cancelled: false, duration: Duration(seconds: 1));
      final s = reduce(done, StartRun(now: t(5), instruction: 'x'));
      expect(s, same(done));
    });
  });

  group('streaming transitions', () {
    test('starting → streaming on first text chunk', () {
      final start = RunStarting(instruction: 'p', since: t(1));
      final s = reduce(start, TextChunk(now: t(2), text: 'hello'));
      expect(s, isA<RunStreaming>());
      expect((s as RunStreaming).lastActivityAt, t(2));
      expect(s.cancellingSince, isNull);
    });

    test('starting → streaming on first tool start', () {
      final start = RunStarting(instruction: 'p', since: t(1));
      final s = reduce(start, ToolStart(now: t(2), toolName: 'web_search'));
      expect(s, isA<RunStreaming>());
    });

    test('streaming text keeps lastActivityAt fresh', () {
      final s0 = RunStreaming(startedAt: t(1), lastActivityAt: t(2), cancellingSince: null);
      final s1 = reduce(s0, TextChunk(now: t(3), text: 'more'));
      expect((s1 as RunStreaming).lastActivityAt, t(3));
    });

    test('tool_executed updates lastActivityAt', () {
      final s0 = RunStreaming(startedAt: t(1), lastActivityAt: t(2), cancellingSince: null);
      final s1 = reduce(s0, ToolExecuted(now: t(3), toolName: 'web_search'));
      expect((s1 as RunStreaming).lastActivityAt, t(3));
    });
  });

  group('cancel', () {
    test('streaming → streaming with cancellingSince set', () {
      final s0 = RunStreaming(startedAt: t(1), lastActivityAt: t(2), cancellingSince: null);
      final s1 = reduce(s0, CancelRun(now: t(3), reason: 'user'));
      expect(s1, isA<RunStreaming>());
      expect((s1 as RunStreaming).cancellingSince, t(3));
    });

    test('cancel from idle is no-op', () {
      final s0 = const RunIdle();
      final s1 = reduce(s0, CancelRun(now: t(3), reason: 'user'));
      expect(s1, same(s0));
    });

    test('cancel from starting is no-op', () {
      final s0 = RunStarting(instruction: 'p', since: t(1));
      final s1 = reduce(s0, CancelRun(now: t(3), reason: 'user'));
      expect(s1, same(s0));
    });
  });

  group('done / error', () {
    test('streaming → done on DoneRun', () {
      final s0 = RunStreaming(startedAt: t(1), lastActivityAt: t(2), cancellingSince: null);
      final s1 = reduce(
        s0,
        DoneRun(now: t(3), cancelled: false, ok: true, duration: const Duration(seconds: 2)),
      );
      expect(s1, isA<RunDone>());
      expect((s1 as RunDone).ok, isTrue);
      expect(s1.cancelled, isFalse);
    });

    test('cancelled DoneRun sets cancelled flag', () {
      final s0 = RunStreaming(startedAt: t(1), lastActivityAt: t(2), cancellingSince: t(2));
      final s1 = reduce(
        s0,
        DoneRun(now: t(3), cancelled: true, ok: false, duration: const Duration(seconds: 2)),
      );
      expect((s1 as RunDone).cancelled, isTrue);
    });

    test('streaming → error on ErrorRun', () {
      final s0 = RunStreaming(startedAt: t(1), lastActivityAt: t(2), cancellingSince: null);
      final s1 = reduce(s0, ErrorRun(now: t(3), message: 'timeout'));
      expect(s1, isA<RunError>());
      expect((s1 as RunError).message, 'timeout');
    });
  });

  group('newChat', () {
    test('any state → idle on newChat', () {
      final s0 = RunStreaming(startedAt: t(1), lastActivityAt: t(2), cancellingSince: null);
      final s1 = reduce(s0, NewChat(now: t(3)));
      expect(s1, isA<RunIdle>());
    });

    test('newChat from done → idle', () {
      final s0 = const RunDone(ok: true, cancelled: false, duration: Duration(seconds: 1));
      final s1 = reduce(s0, NewChat(now: t(3)));
      expect(s1, isA<RunIdle>());
    });

    test('newChat from error → idle', () {
      final s0 = const RunError(message: 'x', recoverable: true);
      final s1 = reduce(s0, NewChat(now: t(3)));
      expect(s1, isA<RunIdle>());
    });
  });

  group('outline review (Sprint 8)', () {
    test('streaming → awaiting_outline_review', () {
      final s0 = RunStreaming(startedAt: t(1), lastActivityAt: t(2), cancellingSince: null);
      final pages = [
        const OutlinePage(index: 1, title: 'A', brief: 'a'),
        const OutlinePage(index: 2, title: 'B', brief: 'b'),
      ];
      final s1 = reduce(s0, EnterOutlineReview(now: t(3), topic: 'ppt', pages: pages));
      expect(s1, isA<RunAwaitingOutlineReview>());
      expect((s1 as RunAwaitingOutlineReview).pages.length, 2);
    });

    test('confirming outline returns to streaming', () {
      final s0 = RunAwaitingOutlineReview(
        topic: 'p',
        pages: const [OutlinePage(index: 1, title: 'A', brief: 'a')],
        since: t(1),
      );
      final s1 = reduce(
        s0,
        ResolveOutlineReview(now: t(3), pages: [const OutlinePage(index: 1, title: 'A2', brief: 'a')]),
      );
      expect(s1, isA<RunStreaming>());
    });

    test('cancelling outline returns to idle', () {
      final s0 = RunAwaitingOutlineReview(
        topic: 'p',
        pages: const [OutlinePage(index: 1, title: 'A', brief: 'a')],
        since: t(1),
      );
      final s1 = reduce(s0, ResolveOutlineReview(now: t(3), cancelled: true));
      expect(s1, isA<RunIdle>());
    });

    test('EnterOutlineReview from idle is a no-op', () {
      final s0 = const RunIdle();
      final s1 = reduce(s0, EnterOutlineReview(now: t(1), topic: 'p', pages: const []));
      expect(s1, same(s0));
    });
  });

  group('qc', () {
    test('streaming → qc on EnterQc', () {
      final s0 = RunStreaming(startedAt: t(1), lastActivityAt: t(2), cancellingSince: null);
      final s1 = reduce(s0, EnterQc(now: t(3), total: 5));
      expect(s1, isA<RunQc>());
      expect((s1 as RunQc).total, 5);
      expect(s1.done, 0);
    });

    test('TickQcProgress advances done counter', () {
      final s0 = RunQc(total: 5, done: 0, startedAt: t(1));
      final s1 = reduce(s0, TickQcProgress(now: t(2), done: 3));
      expect((s1 as RunQc).done, 3);
    });

    test('ExitQc from qc returns to idle', () {
      final s0 = RunQc(total: 5, done: 5, startedAt: t(1));
      final s1 = reduce(s0, ExitQc(now: t(2)));
      expect(s1, isA<RunIdle>());
    });
  });

  group('isBusy', () {
    test('idle is the only non-busy state', () {
      expect(const RunIdle().isBusy, isFalse);
      expect(RunStarting(instruction: 'x', since: t(1)).isBusy, isTrue);
      expect(RunStreaming(startedAt: t(1), lastActivityAt: t(1), cancellingSince: null).isBusy, isTrue);
      expect(RunAwaitingOutlineReview(topic: 't', pages: const [], since: t(1)).isBusy, isTrue);
      expect(RunQc(total: 1, done: 0, startedAt: t(1)).isBusy, isTrue);
      expect(const RunDone(ok: true, cancelled: false, duration: Duration.zero).isBusy, isTrue);
      expect(const RunError(message: 'x', recoverable: true).isBusy, isTrue);
    });
  });

  group('RunSnapshot', () {
    test('default snapshot is empty', () {
      final s = RunSnapshot();
      expect(s.instruction, '');
      expect(s.streamedText, '');
      expect(s.qcPages, isEmpty);
      expect(s.runTools, isEmpty);
      expect(s.docucraftMeta, isNull);
    });

    test('reset() clears all fields', () {
      final s = RunSnapshot()
        ..instruction = 'p'
        ..streamedText = 'out'
        ..qcPages = [1, 2]
        ..runTools = [const ToolActivity(name: 'x', summary: 'x', running: false)]
        ..docucraftMeta = const DeckBlueprintMeta(topic: 't')
        ..lastInstruction = 'p';
      s.reset();
      expect(s.instruction, '');
      expect(s.streamedText, '');
      expect(s.qcPages, isEmpty);
      expect(s.runTools, isEmpty);
      expect(s.docucraftMeta, isNull);
      expect(s.lastInstruction, isNull);
    });

    test('copy() returns a deep-ish snapshot', () {
      final s = RunSnapshot()
        ..qcPages = [1, 2]
        ..runTools = [const ToolActivity(name: 'x', summary: 'x', running: false)];
      final c = s.copy();
      c.qcPages.add(3);
      expect(s.qcPages.length, 2, reason: 'original list must not be mutated');
    });
  });

  group('encodeRunState', () {
    test('encodes kind and isBusy', () {
      final j = encodeRunState(const RunIdle());
      expect(j, contains('"kind":"idle"'));
      expect(j, contains('"isBusy":false'));
    });
  });
}
