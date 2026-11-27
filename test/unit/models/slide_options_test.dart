import 'package:flutter_test/flutter_test.dart';
import 'package:docucraft_app/services/api_client.dart';

void main() {
  group('SlideOption', () {
    test('should parse from JSON correctly', () {
      final json = {
        'index': 0,
        'style': 'modern',
        'svg': '<svg width="1920" height="1080"></svg>',
      };

      final option = SlideOption.fromJson(json);

      expect(option.index, 0);
      expect(option.style, 'modern');
      expect(option.svg, '<svg width="1920" height="1080"></svg>');
    });

    test('should parse different styles', () {
      final styles = ['modern', 'minimal', 'bold', 'elegant'];

      for (final style in styles) {
        final json = {
          'index': 0,
          'style': style,
          'svg': '<svg></svg>',
        };

        final option = SlideOption.fromJson(json);
        expect(option.style, style);
      }
    });
  });

  group('SlideMultiResponse', () {
    test('should parse from JSON correctly', () {
      final json = {
        'ok': true,
        'topic': 'Digital Marketing',
        'title': 'Social Media Trends',
        'index': 2,
        'total': 10,
        'options': [
          {
            'index': 0,
            'style': 'modern',
            'svg': '<svg>modern</svg>',
          },
          {
            'index': 1,
            'style': 'minimal',
            'svg': '<svg>minimal</svg>',
          },
          {
            'index': 2,
            'style': 'bold',
            'svg': '<svg>bold</svg>',
          },
        ],
        'selected': 0,
      };

      final response = SlideMultiResponse.fromJson(json);

      expect(response.ok, true);
      expect(response.topic, 'Digital Marketing');
      expect(response.title, 'Social Media Trends');
      expect(response.index, 2);
      expect(response.total, 10);
      expect(response.options.length, 3);
      expect(response.selected, 0);
    });

    test('should handle empty options', () {
      final json = {
        'ok': true,
        'topic': 'Test',
        'title': 'Test',
        'index': 0,
        'total': 1,
        'options': [],
        'selected': 0,
      };

      final response = SlideMultiResponse.fromJson(json);

      expect(response.ok, true);
      expect(response.options.length, 0);
    });

    test('should handle multiple options with different styles', () {
      final json = {
        'ok': true,
        'topic': 'Test',
        'title': 'Test',
        'index': 0,
        'total': 1,
        'options': [
          {'index': 0, 'style': 'modern', 'svg': '<svg>1</svg>'},
          {'index': 1, 'style': 'minimal', 'svg': '<svg>2</svg>'},
          {'index': 2, 'style': 'bold', 'svg': '<svg>3</svg>'},
          {'index': 3, 'style': 'elegant', 'svg': '<svg>4</svg>'},
        ],
        'selected': 2,
      };

      final response = SlideMultiResponse.fromJson(json);

      expect(response.options.length, 4);
      expect(response.options[0].style, 'modern');
      expect(response.options[1].style, 'minimal');
      expect(response.options[2].style, 'bold');
      expect(response.options[3].style, 'elegant');
      expect(response.selected, 2);
    });
  });

  group('OutlineItem', () {
    test('should parse from JSON correctly', () {
      final json = {
        'index': 0,
        'title': 'Introduction',
        'brief': 'Overview of the topic',
      };

      final item = OutlineItem.fromJson(json);

      expect(item.index, 0);
      expect(item.title, 'Introduction');
      expect(item.brief, 'Overview of the topic');
    });
  });

  group('OutlineResponse', () {
    test('should parse from JSON correctly', () {
      final json = {
        'outline': [
          {'index': 0, 'title': 'Intro', 'brief': 'Brief 1'},
          {'index': 1, 'title': 'Content', 'brief': 'Brief 2'},
          {'index': 2, 'title': 'Conclusion', 'brief': 'Brief 3'},
        ],
      };

      final response = OutlineResponse.fromJson(json);

      expect(response.outline.length, 3);
      expect(response.outline[0].title, 'Intro');
      expect(response.outline[1].title, 'Content');
      expect(response.outline[2].title, 'Conclusion');
    });
  });
}
