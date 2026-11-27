// DocuCraft — Slide Model Unit Tests

import 'package:test/test.dart';
import 'package:docucraft_app/models/slide.dart';

void main() {
  group('Slide', () {
    test('creates slide with default values', () {
      final slide = Slide();

      expect(slide.title, 'Slide Baru');
      expect(slide.subtitle, 'Subtitle');
      expect(slide.backgroundGradient, 'indigo');
      expect(slide.hidden, false);
      expect(slide.elements, isEmpty);
      expect(slide.version, 1);
      expect(slide.id, isNotEmpty);
    });

    test('creates slide with custom values', () {
      final slide = Slide(
        title: 'Custom Title',
        subtitle: 'Custom Subtitle',
        backgroundGradient: 'purple',
        hidden: true,
      );

      expect(slide.title, 'Custom Title');
      expect(slide.subtitle, 'Custom Subtitle');
      expect(slide.backgroundGradient, 'purple');
      expect(slide.hidden, true);
    });

    test('copyWith updates only specified fields', () {
      final original = Slide(title: 'Original', backgroundGradient: 'blue');
      final updated = original.copyWith(title: 'Updated');

      expect(updated.title, 'Updated');
      expect(updated.backgroundGradient, 'blue');
      expect(updated.id, original.id);
      expect(updated.version, 2); // version bumped
    });

    test('bumpVersion increments version and updates timestamp', () {
      final slide = Slide();
      final originalVersion = slide.version;
      final originalTime = DateTime.now().subtract(Duration(seconds: 1)); // before bump

      slide.bumpVersion();

      expect(slide.version, originalVersion + 1);
      expect(slide.lastModifiedAt, isNotNull);
      expect(slide.lastModifiedAt!.isAfter(originalTime), true);
    });

    test('toJson and fromJson roundtrip', () {
      final original = Slide(
        title: 'Test Slide',
        subtitle: 'Test Subtitle',
        backgroundGradient: 'custom_FFFFFF,000000',
        elements: [
          SlideElement(
            type: ElementType.text,
            content: 'Hello World',
            x: 100, y: 200, width: 400, height: 100,
            textStyle: TextStyleData(fontSize: 24, colorValue: 0xFFFFFFFF),
          ),
        ],
      );

      final json = original.toJson();
      final restored = Slide.fromJson(json);

      expect(restored.title, original.title);
      expect(restored.subtitle, original.subtitle);
      expect(restored.backgroundGradient, original.backgroundGradient);
      expect(restored.elements.length, 1);
      expect(restored.elements.first.content, 'Hello World');
    });

    test('V1 backward compatibility - converts percentage to pixels', () {
      // V1 format: positions as percentages (0-100)
      final v1Json = {
        'id': '1234567890', // timestamp ID
        'title': 'V1 Slide',
        'subtitle': 'V1 Subtitle',
        'backgroundGradient': 'indigo',
        'hidden': false,
        'elements': [
          {
            'id': '1234567891',
            'type': 'text',
            'x': 50,      // 50%
            'y': 25,      // 25%
            'width': 30,  // 30%
            'height': 10, // 10%
            'content': 'V1 Text',
            'fontSize': 18,
            'color': '#FF0000',
            'bold': true,
            'italic': false,
          },
        ],
      };

      final slide = Slide.fromJson(v1Json);

      // 1920 * 50% = 960, 1080 * 25% = 270
      expect(slide.elements.first.x, closeTo(960, 1));
      expect(slide.elements.first.y, closeTo(270, 1));
      expect(slide.elements.first.width, closeTo(576, 1)); // 1920 * 30%
      expect(slide.elements.first.height, closeTo(108, 1)); // 1080 * 10%
      expect(slide.elements.first.textStyle?.fontSize, 18);
      expect(slide.elements.first.textStyle?.colorValue, 0xFFFF0000);
      expect(slide.elements.first.textStyle?.fontWeight, 'bold');
    });
  });

  group('SlideElement', () {
    test('creates element with defaults', () {
      final element = SlideElement(type: ElementType.text);

      expect(element.type, ElementType.text);
      expect(element.x, 0);
      expect(element.y, 0);
      expect(element.width, 400);
      expect(element.height, 80);
      expect(element.rotation, 0);
      expect(element.zIndex, 0);
      expect(element.id, isNotEmpty);
    });

    test('toJson and fromJson roundtrip preserves all fields', () {
      final original = SlideElement(
        type: ElementType.shape,
        x: 100, y: 200, width: 300, height: 200,
        rotation: 0.5,
        zIndex: 5,
        content: 'Shape content',
        shapeStyle: ShapeStyleData(
          fillColorValue: 0xFF6366F1,
          strokeColorValue: 0xFF000000,
          strokeWidth: 2,
          borderRadius: 12,
          opacity: 0.8,
          shapeType: 'circle',
        ),
        version: 3,
      );

      final json = original.toJson();
      final restored = SlideElement.fromJson(json);

      expect(restored.type, ElementType.shape);
      expect(restored.x, 100);
      expect(restored.y, 200);
      expect(restored.width, 300);
      expect(restored.height, 200);
      expect(restored.rotation, 0.5);
      expect(restored.zIndex, 5);
      expect(restored.shapeStyle?.fillColorValue, 0xFF6366F1);
      expect(restored.shapeStyle?.shapeType, 'circle');
      expect(restored.version, 3);
    });

    test('convenience getters/setters work correctly', () {
      final element = SlideElement(type: ElementType.text);

      element.bold = true;
      expect(element.textStyle?.fontWeight, 'bold');
      expect(element.bold, true);

      element.italic = true;
      expect(element.textStyle?.fontStyle, 'italic');
      expect(element.italic, true);

      element.fontSize = 32;
      expect(element.textStyle?.fontSize, 32);

      element.color = '#6366F1';
      expect(element.textStyle?.colorValue, 0xFF6366F1);
    });
  });

  group('StyleData classes', () {
    test('TextStyleData serialization', () {
       final style = TextStyleData(
        fontSize: 24,
        colorValue: 0xFFFFFFFF,
        fontWeight: 'semibold',
        fontStyle: 'italic',
        textAlign: 'center',
        fontFamily: 'Roboto',
        letterSpacing: 0.5,
        lineHeight: 1.5,
        wordSpacing: 1.0,
        textDecoration: 'underline',
      );

      final json = style.toJson();
      final restored = TextStyleData.fromJson(json);

      expect(restored.fontSize, 24);
      expect(restored.colorValue, 0xFFFFFFFF);
      expect(restored.fontWeight, 'semibold');
      expect(restored.fontStyle, 'italic');
      expect(restored.textAlign, 'center');
      expect(restored.fontFamily, 'Roboto');
      expect(restored.letterSpacing, 0.5);
      expect(restored.lineHeight, 1.5);
      expect(restored.wordSpacing, 1.0);
      expect(restored.textDecoration, 'underline');
    });

    test('ShapeStyleData serialization', () {
       final style = ShapeStyleData(
        fillColorValue: 0xFF6366F1,
        strokeColorValue: 0xFF000000,
        strokeWidth: 2,
        borderRadius: 8,
        opacity: 0.9,
        shapeType: 'diamond',
      );

      final json = style.toJson();
      final restored = ShapeStyleData.fromJson(json);

      expect(restored.fillColorValue, 0xFF6366F1);
      expect(restored.strokeColorValue, 0xFF000000);
      expect(restored.strokeWidth, 2);
      expect(restored.borderRadius, 8);
      expect(restored.opacity, 0.9);
      expect(restored.shapeType, 'diamond');
    });

    test('ChartData serialization', () {
       final chartData = ChartData(
        chartType: 'line',
        dataSets: [
          ChartDataSet(values: [1.0, 2.0, 3.0], label: 'Series A', colorValue: 0xFF6366F1),
          ChartDataSet(values: [3.0, 2.0, 1.0], label: 'Series B', colorValue: 0xFFEC4899),
        ],
        labels: ['Jan', 'Feb', 'Mar'],
      );

      final json = chartData.toJson();
      final restored = ChartData.fromJson(json);

      expect(restored.chartType, 'line');
      expect(restored.dataSets.length, 2);
      expect(restored.dataSets[0].label, 'Series A');
      expect(restored.dataSets[0].values, [1.0, 2.0, 3.0]);
      expect(restored.labels, ['Jan', 'Feb', 'Mar']);
    });

    test('TableData serialization', () {
       final tableData = TableData(
        rows: 2,
        cols: 3,
        cells: [
          ['Header 1', 'Header 2', 'Header 3'],
          ['Cell 1', 'Cell 2', 'Cell 3'],
        ],
        hasHeader: true,
      );

      final json = tableData.toJson();
      final restored = TableData.fromJson(json);

      expect(restored.rows, 2);
      expect(restored.cols, 3);
      expect(restored.hasHeader, true);
      expect(restored.cells, [
        ['Header 1', 'Header 2', 'Header 3'],
        ['Cell 1', 'Cell 2', 'Cell 3'],
      ]);
    });

    test('DrawData serialization', () {
       final drawData = DrawData(strokes: [
        DrawStroke(
          colorValue: 0xFF000000,
          size: 3,
          points: [[0.0, 0.0], [100.0, 100.0]],
          label: 'line',
        ),
      ]);

      final json = drawData.toJson();
      final restored = DrawData.fromJson(json);

      expect(restored.strokes.length, 1);
      expect(restored.strokes.first.colorValue, 0xFF000000);
      expect(restored.strokes.first.size, 3);
      expect(restored.strokes.first.points, [[0.0, 0.0], [100.0, 100.0]]);
      expect(restored.strokes.first.label, 'line');
    });
  });
}