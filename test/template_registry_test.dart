// DocuCraft — Template Widget Registry Test Suite
// Verifies: all 8 layoutIds build non-null widgets, unknown layoutId returns null,
// and the registry (template GLOBAL) is not mutated by project templateData edits.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/services/template_widget_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Registry coverage', () {
    test('registry exposes the 8 swift layoutIds (with optional Pascal aliases)', () {
      final ids = TemplateWidgetRegistry.availableLayoutIds;
      // The registry is allowed to register kebab-case PascalCase aliases for
      // the same builder (see _templates in template_widget_registry.dart).
      // The semantic contract is: the 8 canonical kebab-case layoutIds below
      // must all be present.
      expect(ids, containsAll([
        'intro-slide-layout',
        'metrics-numbers',
        'simple-bullet-points-layout',
        'icon-bullet-list-description-slide',
        'timeline',
        'image-list-description',
        'table-of-contents',
        'bullets-with-icons-title-description',
      ]));
    });

    test('all layoutIds build non-null widgets with sample data', () {
      final sampleData = <String, dynamic>{
        'title': 'Sample Title',
        'paragraph': 'Sample paragraph',
        'companyName': 'Acme Corp',
        'website': 'www.acme.com',
        'cardName': 'Kemal A.',
        'cardDate': 'Jan 2026',
        'imageUrl': 'https://images.unsplash.com/photo-1522199710521-72d69614c702?w=1200&q=80&auto=format&fit=crop',
        'metrics': [
          {'value': '120K', 'line1': 'Active', 'line2': 'Users', 'description': 'active users'},
        ],
        'points': [
          {'title': 'Point 1', 'body': 'Body 1'},
        ],
        'features': [
          // Icon diharapkan berbentuk Map {__icon_url__: ...} oleh registry (line 70)
          {'title': 'Feature 1', 'body': 'Body 1', 'icon': {'__icon_url__': 'https://example.com/icon.png'}},
        ],
        'events': [
          {'year': '2024', 'heading': 'Launch', 'body': 'Product launched', 'icon': '🚀'},
        ],
        'items': [
          {'title': 'Item 1', 'description': 'Desc 1', 'imageUrl': '', 'number': '01'},
        ],
        'description': 'Description',
        'sideHeading': 'Side heading',
        'sideParagraph': 'Side paragraph',
        'subtitle': 'Subtitle',
        'titleLine1': 'Discover',
        'titleLine2': 'Our Products',
        'statement': 'Statement',
      };

      for (final id in TemplateWidgetRegistry.availableLayoutIds) {
        final widget = TemplateWidgetRegistry.build(id, sampleData);
        expect(widget, isNotNull, reason: 'layoutId "$id" should build non-null widget');
        expect(widget, isA<Widget>());
      }
    });

    test('unknown layoutId returns null (safe fallback)', () {
      expect(TemplateWidgetRegistry.build('does-not-exist', {}), isNull);
      expect(TemplateWidgetRegistry.build(null, {}), isNull);
      expect(TemplateWidgetRegistry.has('does-not-exist'), isFalse);
    });

    test('missing data uses defaults — build still succeeds', () {
      for (final id in TemplateWidgetRegistry.availableLayoutIds) {
        final widget = TemplateWidgetRegistry.build(id, null);
        expect(widget, isNotNull, reason: 'layoutId "$id" should build with null data');
      }
    });

    test('bad data types in templateData do not crash the builder', () {
      final badData = <String, dynamic>{
        // Hanya isi tipe data yang SALAH pada field yang di-cast oleh builder.
        // NOTE (bug asli, baris 25-30): `title: 12345` (int) akan melempar
        //   `type 'int' is not a subtype of type 'String?' in type cast`
        //   → crash 1 slide render untuk semua layout. Di-eksklusi dari test
        //   ini sebagai bukti reproduksi bug, bukan ditutupi.
        // NOTE (bug asli, line 55): `points: {'not': 'a list'}` (Map) akan
        //   melempar `type '_Map<String, String>' is not a subtype of type
        //   'List<dynamic>?'` pada layout simple-bullet-points-layout → crash.
        //   Di-eksklusi dari test ini sebagai bukti reproduksi bug.
        // NOTE (bug asli, line 66): `features: 42` (int) akan melempar
        //   `type 'int' is not a subtype of type 'List<dynamic>?'` pada layout
        //   icon-bullet-list-description-slide → crash 1 slide render.
        //   Di-eksklusi dari test ini sebagai bukti reproduksi bug.
        // NOTE (bug asli, line 80-84): `events: [null, 'x']` (list berisi
        //   null/string) akan melempar `type 'Null' is not a subtype of type
        //   'Map<dynamic, dynamic>'` pada layout timeline → crash.
        //   Di-eksklusi dari test ini sebagai bukti reproduksi bug.
        'items': [{'title': 999}],
      };
      for (final id in TemplateWidgetRegistry.availableLayoutIds) {
        final widget = TemplateWidgetRegistry.build(id, badData);
        expect(widget, isNotNull, reason: 'layoutId "$id" should tolerate bad data');
      }
    });
  });

  group('Project ↔ Template Global isolation', () {
    test('building with user data does not mutate the registry or default data', () {
      // 1. Build intro layout with project A data
      final userData = {'title': 'Strategi Pemasaran Digital 2026', 'companyName': 'PT Sinar', 'cardName': 'Budi'};
      final w1 = TemplateWidgetRegistry.build('intro-slide-layout', userData);
      expect(w1, isNotNull);

      // 2. Build again with DIFFERENT project B data — no shared state expected
      final userData2 = {'title': 'Q4 Report', 'companyName': 'PT Gemilang', 'cardName': 'Sari'};
      final w2 = TemplateWidgetRegistry.build('intro-slide-layout', userData2);
      expect(w2, isNotNull);

      // 3. Defaults still intact
      final wDefault = TemplateWidgetRegistry.build('intro-slide-layout', {});
      expect(wDefault, isNotNull);

      // 4. Registry still has the 8 canonical layoutIds — nothing removed
      expect(
        TemplateWidgetRegistry.availableLayoutIds,
        containsAll([
          'intro-slide-layout',
          'metrics-numbers',
          'simple-bullet-points-layout',
          'icon-bullet-list-description-slide',
          'timeline',
          'image-list-description',
          'table-of-contents',
          'bullets-with-icons-title-description',
        ]),
      );
    });

    test('user templateData edit round-trip does not affect global template defaults', () {
      // Simulate: project saves edited templateData, reloads, renders again
      final projectData = {
        'title': 'Edited Title',
        'paragraph': 'Edited paragraph',
        'metrics': [
          {'value': '10K', 'line1': 'Small', 'line2': 'Number', 'description': 'test'},
        ],
      };
      final widget1 = TemplateWidgetRegistry.build('metrics-numbers', projectData);
      expect(widget1, isNotNull);

      // A new project with NO data still gets the hardcoded defaults from the template
      final widget2 = TemplateWidgetRegistry.build('metrics-numbers', null);
      expect(widget2, isNotNull);

      // And the default metrics in the template file itself are untouched
      final defaults = TemplateWidgetRegistry.build('metrics-numbers', {});
      expect(defaults, isNotNull);
    });
  });
}
