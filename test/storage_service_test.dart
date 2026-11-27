// DocuCraft — StorageService Hive Test Suite
// Verifies: project list CRUD, slides per-project, delete, round-trip integrity

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import '../lib/services/storage_service.dart';
import '../lib/models/slide.dart';

void main() {
  late String tmpDir;

  setUp(() async {
    tmpDir = Directory.systemTemp.createTempSync('docucraft_test_').path;
    Hive.init(tmpDir);
    await StorageService.init();
  });

  tearDown(() async {
    await StorageService.clearAll();
    await Hive.close();
    Directory(tmpDir).deleteSync(recursive: true);
  });

  group('Project list CRUD', () {
    test('save and load empty project list', () {
      StorageService.saveProjectList([]);
      final list = StorageService.loadProjectList();
      expect(list, isEmpty);
    });

    test('save and load project list preserves order and fields', () async {
      final projects = [
        {'id': 'proj_1', 'title': 'Alpha', 'createdAt': '2026-01-01', 'slideCount': 5},
        {'id': 'proj_2', 'title': 'Beta', 'createdAt': '2026-02-01', 'slideCount': 3},
        {'id': 'proj_3', 'title': 'Gamma', 'createdAt': '2026-03-01', 'slideCount': 0},
      ];
      await StorageService.saveProjectList(projects);
      final loaded = StorageService.loadProjectList();

      expect(loaded.length, 3);
      expect(loaded[0]['id'], 'proj_1');
      expect(loaded[0]['title'], 'Alpha');
      expect(loaded[0]['slideCount'], 5);
      expect(loaded[1]['title'], 'Beta');
      expect(loaded[2]['slideCount'], 0);
    });

    test('deleteProject removes slide data AND project_list entry', () async {
      final projects = [
        {'id': 'p1', 'title': 'Delete me'},
        {'id': 'p2', 'title': 'Keep me'},
      ];
      await StorageService.saveProjectList(projects);

      final slides = [Slide(title: 'S1'), Slide(title: 'S2')];
      await StorageService.saveSlidesForProject('p1', slides);
      await StorageService.saveSlidesForProject('p2', [Slide(title: 'S3')]);

      await StorageService.deleteProject('p1');

      final after = StorageService.loadProjectList();
      expect(after.length, 1);
      expect(after[0]['id'], 'p2');

      final p1Slides = StorageService.loadSlidesForProject('p1');
      expect(p1Slides, isEmpty);

      final p2Slides = StorageService.loadSlidesForProject('p2');
      expect(p2Slides.length, 1);
    });
  });

  group('Slides per-project', () {
    test('round-trip: save and load slides for a project', () async {
      final slides = [
        Slide(
          title: 'Intro',
          subtitle: 'Welcome',
          backgroundGradient: 'indigo',
          elements: [
            SlideElement(
              type: ElementType.text,
              content: 'Hello',
              x: 100, y: 200, width: 600, height: 80,
              textStyle: TextStyleData(fontSize: 24, fontWeight: 'bold'),
            ),
          ],
          layoutId: 'intro-slide-layout',
          templateData: {'title': 'Hello', 'companyName': 'TestCo'},
        ),
        Slide(title: 'Data', elements: [
          SlideElement(type: ElementType.chart, chartData: ChartData(chartType: 'pie')),
        ]),
      ];

      await StorageService.saveSlidesForProject('proj_test', slides);
      final loaded = StorageService.loadSlidesForProject('proj_test');

      expect(loaded.length, 2);
      expect(loaded[0].title, 'Intro');
      expect(loaded[0].layoutId, 'intro-slide-layout');
      expect(loaded[0].templateData?['companyName'], 'TestCo');
      expect(loaded[0].elements.length, 1);
      expect(loaded[0].elements[0].type, ElementType.text);
      expect(loaded[1].elements[0].type, ElementType.chart);
    });

    test('empty project returns empty list (no crash)', () {
      final slides = StorageService.loadSlidesForProject('nonexistent');
      expect(slides, isEmpty);
    });

    test('different projects are isolated — no cross-contamination', () async {
      await StorageService.saveSlidesForProject('proj_a', [Slide(title: 'A')]);
      await StorageService.saveSlidesForProject('proj_b', [Slide(title: 'B'), Slide(title: 'B2')]);

      final a = StorageService.loadSlidesForProject('proj_a');
      final b = StorageService.loadSlidesForProject('proj_b');

      expect(a.length, 1);
      expect(a[0].title, 'A');
      expect(b.length, 2);
      expect(b[0].title, 'B');
      expect(b[1].title, 'B2');
    });

    test('overwriting project slides replaces all (no append)', () async {
      await StorageService.saveSlidesForProject('p1', [Slide(title: 'X'), Slide(title: 'Y')]);
      await StorageService.saveSlidesForProject('p1', [Slide(title: 'Z')]);

      final slides = StorageService.loadSlidesForProject('p1');
      expect(slides.length, 1);
      expect(slides[0].title, 'Z');
    });
  });

  group('Schema version reset', () {
    test('changing schema version clears all data', () async {
      await StorageService.saveProjectList([{'id': 'p1', 'title': 'Old'}]);
      await StorageService.saveSlidesForProject('p1', [Slide(title: 'Old slide')]);
      expect(StorageService.loadProjectList().length, 1);

      // Manually corrupt schema version to trigger reset on re-init
      final box = Hive.box('docucraft_db');
      await box.put('schema_version', 99); // wrong version

      // Re-init StorageService (will clear all and set version to current)
      await StorageService.init();

      final afterList = StorageService.loadProjectList();
      expect(afterList, isEmpty);
    });
  });

  group('Box stats', () {
    test('stats returns non-empty string', () async {
      await StorageService.saveProjectList([{'id': 'x', 'title': 'X'}]);
      final stats = StorageService.stats;
      expect(stats, contains('keys'));
      expect(stats, contains('KB'));
    });
  });
}
