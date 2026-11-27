// DocuCraft Flutter — DeckBlueprint model unit tests (Sprint 12)

import 'package:flutter_test/flutter_test.dart';
import 'package:docucraft_app/models/deck_blueprint.dart';

void main() {
  group('DeckBlueprint', () {
    test('toJson includes all fields', () {
      final bp = DeckBlueprint(
        id: 'bp-1',
        name: 'Cats',
        topic: 'A presentation about cats',
        styleSkill: 'modern',
        outlineJson: '{"pages":[]}',
        pageCount: 5,
        createdAt: '2026-09-05T12:00:00Z',
        sourcePath: '/x/cats.pptx',
        forkedFrom: 'bp-0',
      );
      final j = bp.toJson();
      expect(j['id'], 'bp-1');
      expect(j['name'], 'Cats');
      expect(j['topic'], 'A presentation about cats');
      expect(j['styleSkill'], 'modern');
      expect(j['outlineJson'], '{"pages":[]}');
      expect(j['pageCount'], 5);
      expect(j['createdAt'], '2026-09-05T12:00:00Z');
      expect(j['sourcePath'], '/x/cats.pptx');
      expect(j['forkedFrom'], 'bp-0');
    });

    test('toJson omits null optional fields', () {
      final bp = DeckBlueprint(
        id: 'bp-1',
        name: 'Cats',
        topic: 't',
        createdAt: '2026-09-05T12:00:00Z',
      );
      final j = bp.toJson();
      expect(j.containsKey('styleSkill'), isFalse);
      expect(j.containsKey('outlineJson'), isFalse);
      expect(j.containsKey('pageCount'), isFalse);
      expect(j.containsKey('sourcePath'), isFalse);
      expect(j.containsKey('forkedFrom'), isFalse);
    });

    test('fromJson round-trips a full blueprint', () {
      final original = DeckBlueprint(
        id: 'bp-1',
        name: 'Cats',
        topic: 't',
        styleSkill: 'modern',
        outlineJson: '{}',
        pageCount: 3,
        createdAt: '2026-09-05T12:00:00Z',
        forkedFrom: 'bp-0',
      );
      final restored = DeckBlueprint.fromJson(original.toJson());
      expect(restored, isNotNull);
      expect(restored!.id, 'bp-1');
      expect(restored.styleSkill, 'modern');
      expect(restored.forkedFrom, 'bp-0');
    });

    test('fromJson returns null if id is missing or empty', () {
      expect(DeckBlueprint.fromJson({}), isNull);
      expect(DeckBlueprint.fromJson({'id': ''}), isNull);
      expect(DeckBlueprint.fromJson({'id': 42}), isNull);
      expect(DeckBlueprint.fromJson(null), isNull);
    });

    test('fromJson tolerates missing optional fields', () {
      final bp = DeckBlueprint.fromJson({
        'id': 'bp-1',
        'name': 'n',
        'topic': 't',
        'createdAt': '2026-09-05T12:00:00Z',
      });
      expect(bp, isNotNull);
      expect(bp!.styleSkill, isNull);
      expect(bp.pageCount, isNull);
      expect(bp.forkedFrom, isNull);
    });

    test('copyWith updates only the specified fields', () {
      final bp = DeckBlueprint(id: 'bp-1', name: 'n', topic: 't', createdAt: 'c');
      final c = bp.copyWith(name: 'renamed', pageCount: 7);
      expect(c.id, 'bp-1');
      expect(c.name, 'renamed');
      expect(c.topic, 't');
      expect(c.pageCount, 7);
    });
  });
}
