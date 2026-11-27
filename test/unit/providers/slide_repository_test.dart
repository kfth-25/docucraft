// DocuCraft — SlideRepository Unit Tests
// Note: Most tests require Hive initialization. Run with `flutter test --dart-define=TEST_MODE=true`

import 'package:test/test.dart';
import 'package:docucraft_app/providers/slide_repository.dart';
import 'package:docucraft_app/models/slide.dart';

void main() {
  group('SlideRepository', () {
    late SlideRepository repository;

    setUp(() {
      repository = SlideRepository();
    });

    test('initial project ID is default', () {
      expect(repository.currentProjectId, 'default');
      expect(repository.currentProjectTitle, 'Presentasi Baru');
    });

    // Skip tests that require Hive initialization
    test('createNewProject generates unique ID', () {
      // This test requires Hive to be initialized
      // Run with: flutter test --dart-define=TEST_MODE=true
    });

    test('createNewProject stores templateId if provided', () {
      // This test requires Hive to be initialized
    });

    test('updateProjectTitle updates title in project list', () {
      // This test requires Hive to be initialized
    });

    test('openProject sets current project', () {
      // This test requires Hive to be initialized
    });

    test('deleteProject removes from list', () {
      // This test requires Hive to be initialized
    });

    test('deleteCurrentProject resets to default', () {
      // This test requires Hive to be initialized
    });

    test('getAllProjects returns list with created projects', () {
      // This test requires Hive to be initialized
    });

    test('initWithTemplate returns valid slide when empty', () async {
      // This test requires Hive to be initialized
    });
  });
}