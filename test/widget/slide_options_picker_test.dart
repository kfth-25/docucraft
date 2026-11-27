import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docucraft_app/services/api_client.dart';

void main() {
  group('SlideOption Model', () {
    test('should create from JSON', () {
      final option = SlideOption(
        index: 0,
        style: 'modern',
        svg: '<svg></svg>',
      );

      expect(option.index, 0);
      expect(option.style, 'modern');
      expect(option.svg, '<svg></svg>');
    });

    test('should parse from JSON correctly', () {
      final json = {
        'index': 1,
        'style': 'bold',
        'svg': '<svg width="1920" height="1080"></svg>',
      };

      final option = SlideOption.fromJson(json);

      expect(option.index, 1);
      expect(option.style, 'bold');
      expect(option.svg, '<svg width="1920" height="1080"></svg>');
    });

    test('should handle different styles', () {
      final styles = ['modern', 'minimal', 'bold', 'elegant'];

      for (final style in styles) {
        final option = SlideOption(
          index: 0,
          style: style,
          svg: '<svg></svg>',
        );

        expect(option.style, style);
      }
    });
  });

  group('SlideMultiResponse Model', () {
    test('should parse complete response', () {
      final json = {
        'ok': true,
        'topic': 'Digital Marketing',
        'title': 'Social Media Trends',
        'index': 0,
        'total': 5,
        'options': [
          {'index': 0, 'style': 'modern', 'svg': '<svg>1</svg>'},
          {'index': 1, 'style': 'minimal', 'svg': '<svg>2</svg>'},
          {'index': 2, 'style': 'bold', 'svg': '<svg>3</svg>'},
        ],
        'selected': 1,
      };

      final response = SlideMultiResponse.fromJson(json);

      expect(response.ok, true);
      expect(response.topic, 'Digital Marketing');
      expect(response.title, 'Social Media Trends');
      expect(response.index, 0);
      expect(response.total, 5);
      expect(response.options.length, 3);
      expect(response.options[0].style, 'modern');
      expect(response.options[1].style, 'minimal');
      expect(response.options[2].style, 'bold');
      expect(response.selected, 1);
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

    test('should handle error response', () {
      final json = {
        'ok': false,
        'topic': 'Test',
        'title': 'Test',
        'index': 0,
        'total': 1,
        'options': [],
        'selected': 0,
      };

      final response = SlideMultiResponse.fromJson(json);

      expect(response.ok, false);
    });
  });

  group('OutlineItem Model', () {
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

  group('OutlineResponse Model', () {
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

  group('StyleSkill Model', () {
    test('should parse from JSON correctly', () {
      final json = {
        'colors': {
          'primary': '#6366F1',
          'secondary': '#EC4899',
        },
        'fonts': {
          'title': 'Inter',
          'body': 'Roboto',
        },
        'layoutVariants': {
          'cover': ['centered', 'split'],
        },
        'overallStyle': 'Modern and clean',
      };

      final skill = StyleSkill.fromJson(json);

      expect(skill.colors['primary'], '#6366F1');
      expect(skill.fonts['title'], 'Inter');
      expect(skill.layoutVariants['cover'], ['centered', 'split']);
      expect(skill.overallStyle, 'Modern and clean');
    });
  });
}
