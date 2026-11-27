// DocuCraft Flutter — DeckBlueprintStorage tests (Sprint 12)
//
// Uses a temp directory for Hive (Hive.init(path)) so we don't touch the
// real user data.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:docucraft_app/models/deck_blueprint.dart';
import 'package:docucraft_app/services/deck_blueprint_storage.dart';

void main() {
  late Directory tmp;
  late DeckBlueprintStorage storage;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('docucraft_blueprint_test_');
    Hive.init(tmp.path);
    storage = DeckBlueprintStorage();
    await storage.open();
  });

  tearDown(() async {
    await storage.close();
    await Hive.close();
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  group('DeckBlueprintStorage', () {
    test('save() persists and load() returns the blueprint', () async {
      final bp = DeckBlueprint(
        id: 'bp-1',
        name: 'Cats',
        topic: 'A presentation about cats',
        pageCount: 3,
        createdAt: '2026-09-05T12:00:00Z',
      );
      final r = await storage.save(bp);
      expect(r.ok, isTrue);

      final l = await storage.load('bp-1');
      expect(l.ok, isTrue);
      expect(l.value, isNotNull);
      expect(l.value!.name, 'Cats');
    });

    test('load() returns null for missing id', () async {
      final r = await storage.load('bp-does-not-exist');
      expect(r.ok, isTrue);
      expect(r.value, isNull);
    });

    test('save() overwrites on duplicate id', () async {
      await storage.save(DeckBlueprint(
        id: 'bp-1', name: 'A', topic: 't', createdAt: '2026-09-05T12:00:00Z',
      ));
      await storage.save(DeckBlueprint(
        id: 'bp-1', name: 'B', topic: 't', createdAt: '2026-09-05T12:00:00Z',
      ));
      final l = await storage.load('bp-1');
      expect(l.value!.name, 'B');
    });

    test('listAll() returns newest first', () async {
      await storage.save(DeckBlueprint(
        id: 'bp-1', name: 'A', topic: 't', createdAt: '2026-09-05T12:00:00Z',
      ));
      await storage.save(DeckBlueprint(
        id: 'bp-2', name: 'B', topic: 't', createdAt: '2026-09-06T12:00:00Z',
      ));
      await storage.save(DeckBlueprint(
        id: 'bp-3', name: 'C', topic: 't', createdAt: '2026-09-04T12:00:00Z',
      ));
      final r = await storage.listAll();
      expect(r.ok, isTrue);
      expect(r.value!.map((b) => b.id).toList(), ['bp-2', 'bp-1', 'bp-3']);
    });

    test('delete() removes a blueprint', () async {
      await storage.save(DeckBlueprint(
        id: 'bp-1', name: 'A', topic: 't', createdAt: '2026-09-05T12:00:00Z',
      ));
      final d = await storage.delete('bp-1');
      expect(d.ok, isTrue);
      final l = await storage.load('bp-1');
      expect(l.value, isNull);
    });

    test('delete() is a no-op for missing id', () async {
      final d = await storage.delete('bp-missing');
      expect(d.ok, isTrue);
      expect(d.value, isTrue);
    });
  });
}
