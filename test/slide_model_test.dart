// DocuCraft — Slide Model Test Suite
// Verifies: JSON round-trip, V1→V2 migration, style serialization, template linkage

import 'package:flutter_test/flutter_test.dart';
import '../lib/models/slide.dart';

void main() {
  group('Slide JSON round-trip', () {
    test('full slide with elements survives toJson → fromJson', () {
      final original = Slide(
        title: 'Judul Test',
        subtitle: 'Subtitle Test',
        backgroundGradient: 'purple',
        elements: [
          SlideElement(
            type: ElementType.text,
            content: 'Konten teks',
            x: 100, y: 200, width: 600, height: 80,
            textStyle: TextStyleData(
              fontSize: 28, fontWeight: 'bold', colorValue: 0xFF112233, textAlign: 'center',
            ),
          ),
          SlideElement(
            type: ElementType.shape,
            x: 50, y: 50, width: 100, height: 100,
            shapeStyle: ShapeStyleData(
              fillColorValue: 0xFF6366F1, borderRadius: 16, opacity: 0.5, shapeType: 'circle',
            ),
          ),
          SlideElement(
            type: ElementType.chart,
            chartData: ChartData(
              chartType: 'bar',
              labels: ['A', 'B', 'C'],
              dataSets: [ChartDataSet(values: [1.5, 2.5, 3.5], label: 'S1')],
            ),
          ),
          SlideElement(
            type: ElementType.image,
            imageStyle: ImageStyleData(src: 'https://img.example.com/x.png', borderRadius: 12),
          ),
        ],
        templateId: 'tpl_intro',
        layoutId: 'intro-slide-layout',
        templateData: {'title': 'Strategi', 'companyName': 'Acme'},
        version: 3,
        lastModifiedBy: 'tester',
        lastModifiedAt: DateTime.utc(2026, 8, 10, 12, 30),
      );

      final json = original.toJson();
      final restored = Slide.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.title, 'Judul Test');
      expect(restored.subtitle, 'Subtitle Test');
      expect(restored.backgroundGradient, 'purple');
      expect(restored.elements.length, 4);
      expect(restored.templateId, 'tpl_intro');
      expect(restored.layoutId, 'intro-slide-layout');
      expect(restored.templateData?['title'], 'Strategi');
      expect(restored.templateData?['companyName'], 'Acme');
      expect(restored.version, 3);
      expect(restored.lastModifiedBy, 'tester');
      expect(restored.lastModifiedAt, DateTime.utc(2026, 8, 10, 12, 30));
    });

    test('templateData survives round-trip with nested lists/maps', () {
      final slide = Slide(
        title: 'T',
        templateData: {
          'title': 'Performance',
          'metrics': [
            {'value': '120K', 'line1': 'Active', 'line2': 'Users'},
            {'value': '150%', 'line1': 'Revenue', 'line2': 'Growth'},
          ],
        },
      );
      final restored = Slide.fromJson(slide.toJson());
      final metrics = restored.templateData?['metrics'] as List?;
      expect(metrics, isNotNull);
      expect(metrics!.length, 2);
      expect((metrics[0] as Map)['value'], '120K');
    });

    test('text style fields survive round-trip', () {
      final el = SlideElement(
        type: ElementType.text,
        content: 'x',
        textStyle: TextStyleData(
          fontSize: 36.5,
          colorValue: 0xFFAABBCC,
          fontWeight: 'semibold',
          fontStyle: 'italic',
          textAlign: 'right',
          fontFamily: 'Inter',
          letterSpacing: 1.5,
          lineHeight: 1.4,
          wordSpacing: 2.0,
          textDecoration: 'underline',
        ),
      );
      final restored = SlideElement.fromJson(el.toJson());
      final s = restored.textStyle!;
      expect(s.fontSize, 36.5);
      expect(s.colorValue, 0xFFAABBCC);
      expect(s.fontWeight, 'semibold');
      expect(s.fontStyle, 'italic');
      expect(s.textAlign, 'right');
      expect(s.fontFamily, 'Inter');
      expect(s.letterSpacing, 1.5);
      expect(s.lineHeight, 1.4);
      expect(s.wordSpacing, 2.0);
      expect(s.textDecoration, 'underline');
    });
  });

  group('V1 → V2 migration', () {
    test('percentage positions convert to 1920x1080 pixels', () {
      // V1 format: no version field, positions in 0-100%
      final v1Json = {
        'id': '1234567890123', // timestamp-like id → must be replaced with UUID v7
        'title': 'V1 Slide',
        'subtitle': '',
        'backgroundGradient': 'indigo',
        'elements': [
          {
            'type': 'text',
            'content': 'V1 text',
            'x': 50, 'y': 50, 'width': 50, 'height': 10,
            'fontSize': 20,
            'color': '#FF0000',
            'bold': true,
          },
        ],
      };

      final slide = Slide.fromJson(v1Json);
      // Not a timestamp id anymore
      expect(slide.id, isNot('1234567890123'));
      expect(RegExp(r'^\d{10,}$').hasMatch(slide.id), isFalse);

      final el = slide.elements.single;
      expect(el.type, ElementType.text);
      expect(el.x, closeTo(960, 0.001));   // 50% of 1920
      expect(el.y, closeTo(540, 0.001));   // 50% of 1080
      expect(el.width, closeTo(960, 0.001)); // 50% of 1920
      expect(el.height, closeTo(108, 0.001)); // 10% of 1080
      expect(el.textStyle!.fontSize, 20);
      expect(el.textStyle!.colorValue, 0xFFFF0000);
      expect(el.textStyle!.fontWeight, 'bold');
    });

    test('V1 loose color/align fields migrate to structured styles', () {
      final v1Json = {
        'title': 'T',
        'elements': [
          {
            'type': 'text',
            'content': 'hello',
            'x': 0, 'y': 0, 'width': 100, 'height': 50,
            'italic': true,
            'extra': {'align': 'center'},
          },
        ],
      };
      final slide = Slide.fromJson(v1Json);
      final el = slide.elements.single;
      expect(el.textStyle!.fontStyle, 'italic');
      expect(el.textStyle!.textAlign, 'center');
    });

    test('V1 chart with content string becomes ChartData', () {
      final v1Json = {
        'title': 'T',
        'elements': [
          {'type': 'chart', 'content': 'pie', 'x': 0, 'y': 0, 'width': 400, 'height': 300},
        ],
      };
      final slide = Slide.fromJson(v1Json);
      final el = slide.elements.single;
      expect(el.chartData, isNotNull);
      expect(el.chartData!.chartType, 'pie');
    });
  });

  group('Element type safety', () {
    test('unknown element type falls back to text', () {
      final el = SlideElement.fromJson({
        'type': 'hologram',
        'content': 'x',
        'x': 0, 'y': 0, 'width': 100, 'height': 50,
      });
      expect(el.type, ElementType.text);
    });

    test('null/invalid numeric fields use defaults without crash', () {
      final el = SlideElement.fromJson({
        'type': 'text',
        'x': 'not-a-number',
        'width': null,
        'height': null,
      });
      expect(el.x, 0);
      expect(el.width, 400);
      expect(el.height, 80);
    });
  });

  group('CRDT metadata', () {
    test('bumpVersion increments and updates timestamp', () {
      final slide = Slide();
      final v0 = slide.version;
      slide.bumpVersion();
      expect(slide.version, v0 + 1);
      expect(slide.lastModifiedAt, isNotNull);
    });

    test('UUID v7 ids are unique across instances', () {
      final a = Slide();
      final b = Slide();
      expect(a.id, isNot(b.id));
      expect(a.id.length, 36); // standard UUID format
    });
  });
}
