// DocuCraft Flutter — OutlinePreview smoke test (Sprint 12)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docucraft_app/ai/run_state_machine.dart';
import 'package:docucraft_app/widgets/ai/outline_preview.dart';

void main() {
  testWidgets('renders one row per page', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OutlinePreview(
          topic: 'Cats',
          pages: const [
            OutlinePage(index: 1, title: 'Why cats', brief: 'reasons'),
            OutlinePage(index: 2, title: 'How cats', brief: 'mechanics'),
          ],
          onConfirm: (_) {},
          onCancel: () {},
        ),
      ),
    ));

    expect(find.text('Review outline'), findsOneWidget);
    expect(find.text('Cats'), findsOneWidget);
    expect(find.text('Why cats'), findsOneWidget);
    expect(find.text('How cats'), findsOneWidget);
    expect(find.text('Generate'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('Generate button calls onConfirm with edited pages', (tester) async {
    List<OutlinePage>? confirmed;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OutlinePreview(
          topic: 'Cats',
          pages: const [OutlinePage(index: 1, title: 'A', brief: 'a')],
          onConfirm: (p) => confirmed = p,
          onCancel: () {},
        ),
      ),
    ));

    await tester.tap(find.text('Generate'));
    await tester.pump();

    expect(confirmed, isNotNull);
    expect(confirmed!.length, 1);
    expect(confirmed!.first.title, 'A');
  });

  testWidgets('Cancel button calls onCancel', (tester) async {
    var cancelled = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OutlinePreview(
          topic: 'Cats',
          pages: const [OutlinePage(index: 1, title: 'A', brief: 'a')],
          onConfirm: (_) {},
          onCancel: () => cancelled = true,
        ),
      ),
    ));

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(cancelled, isTrue);
  });
}
