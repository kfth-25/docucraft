import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Project Context API', () {
    test('should parse project init response', () {
      final json = <String, dynamic>{
        'ok': true,
        'project': <String, dynamic>{
          'id': 'test-123',
          'topic': 'Digital Marketing',
          'slides': <dynamic>[],
          'styleSkill': null,
          'outline': <dynamic>[],
          'currentSlideIndex': 0,
          'createdAt': '2026-09-13T00:00:00Z',
          'updatedAt': '2026-09-13T00:00:00Z',
        },
      };

      final project = json['project'] as Map<String, dynamic>;
      expect(json['ok'], true);
      expect(project['id'], 'test-123');
      expect(project['topic'], 'Digital Marketing');
      expect(project['slides'], []);
    });

    test('should parse project with slides', () {
      final json = <String, dynamic>{
        'ok': true,
        'project': <String, dynamic>{
          'id': 'test-123',
          'topic': 'Digital Marketing',
          'slides': <Map<String, dynamic>>[
            <String, dynamic>{
              'index': 0,
              'title': 'Introduction',
              'svg': '<svg></svg>',
              'style': 'modern',
            },
            <String, dynamic>{
              'index': 1,
              'title': 'Main Content',
              'svg': '<svg></svg>',
              'style': 'minimal',
            },
          ],
          'styleSkill': <String, dynamic>{
            'colors': <String, dynamic>{'primary': '#6366F1'},
          },
          'outline': <Map<String, dynamic>>[
            <String, dynamic>{'index': 0, 'title': 'Introduction', 'brief': 'Overview'},
            <String, dynamic>{'index': 1, 'title': 'Main Content', 'brief': 'Details'},
          ],
          'currentSlideIndex': 1,
          'createdAt': '2026-09-13T00:00:00Z',
          'updatedAt': '2026-09-13T00:05:00Z',
        },
      };

      final project = json['project'] as Map<String, dynamic>;
      final slides = project['slides'] as List;
      final styleSkill = project['styleSkill'] as Map<String, dynamic>;
      final outline = project['outline'] as List;

      expect(slides.length, 2);
      expect((slides[0] as Map<String, dynamic>)['title'], 'Introduction');
      expect((slides[1] as Map<String, dynamic>)['title'], 'Main Content');
      expect((styleSkill['colors'] as Map<String, dynamic>)['primary'], '#6366F1');
      expect(outline.length, 2);
      expect(project['currentSlideIndex'], 1);
    });

    test('should parse AI refine response', () {
      final json = <String, dynamic>{
        'ok': true,
        'svg': '<svg width="1920" height="1080"><text>Updated</text></svg>',
        'projectId': 'test-123',
        'slideIndex': 0,
      };

      expect(json['ok'], true);
      expect(json['svg'], contains('Updated'));
      expect(json['projectId'], 'test-123');
      expect(json['slideIndex'], 0);
    });

    test('should parse AI regenerate response', () {
      final json = <String, dynamic>{
        'ok': true,
        'svg': '<svg width="1920" height="1080"><text>Regenerated</text></svg>',
        'projectId': 'test-123',
        'slideIndex': 1,
        'title': 'Slide 2',
      };

      expect(json['ok'], true);
      expect(json['svg'], contains('Regenerated'));
      expect(json['title'], 'Slide 2');
    });
  });
}
