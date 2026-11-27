// DocuCraft Flutter — DeckProgressCard smoke test (Sprint 12)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:docucraft_app/providers/ai_run_provider.dart';
import 'package:docucraft_app/widgets/ai/deck_progress_card.dart';

Widget _wrap(Widget child, AiRunProvider p) {
  return ChangeNotifierProvider<AiRunProvider>.value(
    value: p,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('renders 5 stage labels', (tester) async {
    final p = AiRunProvider()..start(instruction: 'p');
    await tester.pumpWidget(_wrap(const DeckProgressCard(), p));
    await tester.pump();

    expect(find.text('Style'), findsOneWidget);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Images'), findsOneWidget);
    expect(find.text('Pages'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('shows error message when state is RunError', (tester) async {
    final p = AiRunProvider()
      ..start(instruction: 'p')
      ..onText('a')
      ..onError('boom');
    await tester.pumpWidget(_wrap(const DeckProgressCard(), p));
    await tester.pump();

    expect(find.text('Generation failed'), findsOneWidget);
    expect(find.text('boom'), findsOneWidget);
  });

  testWidgets('shows success label on RunDone ok', (tester) async {
    final p = AiRunProvider()
      ..start(instruction: 'p')
      ..onText('a')
      ..onDone(cancelled: false, ok: true, duration: const Duration(seconds: 1));
    await tester.pumpWidget(_wrap(const DeckProgressCard(), p));
    await tester.pump();

    expect(find.text('Deck ready'), findsOneWidget);
  });

  testWidgets('renders nothing notable when idle', (tester) async {
    final p = AiRunProvider();
    await tester.pumpWidget(_wrap(const DeckProgressCard(), p));
    await tester.pump();

    // Card body is there but no stage progress yet.
    expect(find.text('Generating deck…'), findsNothing);
  });
}
