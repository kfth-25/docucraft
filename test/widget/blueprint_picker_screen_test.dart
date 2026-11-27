// DocuCraft Flutter — BlueprintPickerScreen smoke test (Sprint 12)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:docucraft_app/models/deck_blueprint.dart';
import 'package:docucraft_app/providers/blueprint_picker_provider.dart';
import 'package:docucraft_app/screens/blueprint_picker_screen.dart';
import 'package:docucraft_app/services/deck_blueprint_storage.dart';

void main() {
  late Directory tmp;
  late DeckBlueprintStorage storage;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('docucraft_picker_test_');
    Hive.init(tmp.path);
    storage = DeckBlueprintStorage();
    await storage.open();

    await storage.save(DeckBlueprint(
      id: 'bp-1', name: 'Cats', topic: 'A presentation about cats',
      pageCount: 5, createdAt: '2026-09-05T12:00:00Z',
    ));
    await storage.save(DeckBlueprint(
      id: 'bp-2', name: 'Dogs', topic: 'About dogs',
      pageCount: 3, createdAt: '2026-09-04T12:00:00Z', forkedFrom: 'bp-1',
    ));
    await storage.save(DeckBlueprint(
      id: 'bp-3', name: 'Birds', topic: 'A presentation about birds',
      pageCount: 4, createdAt: '2026-09-03T12:00:00Z',
    ));
  });

  tearDown(() async {
    await storage.close();
    await Hive.close();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Widget wrap(Widget child) {
    return ChangeNotifierProvider<BlueprintPickerProvider>(
      create: (_) => BlueprintPickerProvider(storage: storage),
      child: MaterialApp(home: child),
    );
  }

  testWidgets('shows all blueprints initially', (tester) async {
    await tester.pumpWidget(wrap(BlueprintPickerScreen(onPick: (_, {required isFork}) {})));
    await tester.pumpAndSettle();

    expect(find.text('Cats'), findsOneWidget);
    expect(find.text('Dogs'), findsOneWidget);
    expect(find.text('Birds'), findsOneWidget);
  });

  testWidgets('Forked tag filters to only forked blueprints', (tester) async {
    await tester.pumpWidget(wrap(BlueprintPickerScreen(onPick: (_, {required isFork}) {})));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forked (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Dogs'), findsOneWidget);
    expect(find.text('Cats'), findsNothing);
    expect(find.text('Birds'), findsNothing);
  });

  testWidgets('Search query filters by name', (tester) async {
    await tester.pumpWidget(wrap(BlueprintPickerScreen(onPick: (_, {required isFork}) {})));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'cats');
    await tester.pumpAndSettle();

    expect(find.text('Cats'), findsOneWidget);
    expect(find.text('Dogs'), findsNothing);
  });

  testWidgets('Forked chip on a row renders when forkedFrom is set', (tester) async {
    await tester.pumpWidget(wrap(BlueprintPickerScreen(onPick: (_, {required isFork}) {})));
    await tester.pumpAndSettle();

    expect(find.textContaining('Forked from bp-1'), findsOneWidget);
  });
}
