import 'package:flutter_test/flutter_test.dart';
import 'package:docucraft_app/services/svg_to_slide_elements.dart';
import 'package:docucraft_app/models/slide.dart';

void main() {
  group('SvgToSlideElements.parseEditableJson', () {
    const json = '''
{
  "width": 1280,
  "height": 720,
  "background": "#ffffff",
  "elements": [
    {"type":"shape","x":0,"y":0,"w":1280,"h":720,"fill":"#ffffff","shapeType":"rect"},
    {"type":"text","x":100,"y":80,"w":1080,"h":60,"text":"Judul Slide","fontSize":32,"color":"#1a1a1a","bold":true,"italic":false,"align":"center"},
    {"type":"shape","x":100,"y":200,"w":1080,"h":80,"fill":"#6366F1","borderRadius":8,"shapeType":"roundRect"},
    {"type":"shape","x":300,"y":400,"w":200,"h":200,"fill":"#22c55e","shapeType":"ellipse"},
    {"type":"image","x":100,"y":300,"w":200,"h":150,"src":"data:image/png;base64,AAAA"}
  ]
}
''';

    test('parses all element types with 1280→1920 scaling', () {
      final elements = SvgToSlideElements.parseEditableJson(json);

      expect(elements.length, 5);

      // background shape (full bleed)
      final bg = elements[0];
      expect(bg.type, ElementType.shape);
      expect(bg.x, 0);
      expect(bg.y, 0);
      expect(bg.width, 1920);
      expect(bg.height, 1080);

      // text: 100*1.5=150, 80*1.5=120, 1080*1.5=1620, 60*1.5=90, fontSize 32*1.5=48
      final text = elements[1];
      expect(text.type, ElementType.text);
      expect(text.content, 'Judul Slide');
      expect(text.x, 150);
      expect(text.y, 120);
      expect(text.width, 1620);
      expect(text.height, 90);
      expect(text.textStyle!.fontSize, 48);
      expect(text.textStyle!.fontWeight, 'bold');
      expect(text.textStyle!.fontStyle, 'normal');
      expect(text.textStyle!.textAlign, 'center');
      expect(text.textStyle!.colorValue, 0xFF1A1A1A);

      // rounded rect → 'rect' shapeType with borderRadius 8*1.5=12
      final rr = elements[2];
      expect(rr.type, ElementType.shape);
      expect(rr.shapeStyle!.shapeType, 'rect');
      expect(rr.shapeStyle!.borderRadius, 12);
      expect(rr.shapeStyle!.fillColorValue, 0xFF6366F1);

      // ellipse → 'circle' approximation
      final ellipse = elements[3];
      expect(ellipse.shapeStyle!.shapeType, 'circle');

      // image: 100*1.5=150, 300*1.5=450, 200*1.5=300, 150*1.5=225
      final img = elements[4];
      expect(img.type, ElementType.image);
      expect(img.x, 150);
      expect(img.y, 450);
      expect(img.width, 300);
      expect(img.height, 225);
      expect(img.imageStyle!.src, 'data:image/png;base64,AAAA');
    });

    test('returns empty on malformed JSON', () {
      expect(SvgToSlideElements.parseEditableJson('not json'), isEmpty);
    });

    test('returns empty when elements is empty', () {
      expect(
        SvgToSlideElements.parseEditableJson('{"width":1280,"height":720,"elements":[]}'),
        isEmpty,
      );
    });
  });

  test('_parseColor handles rgb() and hex', () {
    // rgb(26,26,26) → 0xFF1A1A1A
    expect(
      SvgToSlideElements.parseEditableJson(
        '{"width":1280,"height":720,"elements":[{"type":"text","text":"x","x":0,"y":0,"w":10,"h":10,"color":"rgb(26, 26, 26)"}]}',
      ).first.textStyle!.colorValue,
      0xFF1A1A1A,
    );
  });

  test('_parseColor reorders CSS 8-digit hex #RRGGBBAA → 0xAARRGGBB', () {
    // #2E7DFF14 = rgb(46,125,255) at alpha 0x14 (GenOffice render-tree format)
    // → Flutter 0x142E7DFF (alpha FIRST). The old code read the alpha as red.
    expect(
      SvgToSlideElements.parseEditableJson(
        '{"width":1280,"height":720,"elements":[{"type":"shape","x":0,"y":0,"w":10,"h":10,"fill":"#2E7DFF14","shapeType":"rect"}]}',
      ).first.shapeStyle!.fillColorValue,
      0x142E7DFF,
    );
  });

  group('SvgToSlideElements.parseEditableJson vertical runs', () {
    test('parses laid-out vertical runs (bodyPr vert) with rotation + scaling', () {
      const json = '''
{
  "width": 1280,
  "height": 720,
  "background": "#0D1424",
  "elements": [
    {"type":"text","x":1134,"y":304,"w":52,"h":66.88,"vert":"eaVert","runs":[
      {"text":"Inferensi","x":48,"y":-1.3,"rotate":90,"fontSize":25.33,"color":"#F5F8FF","bold":true,"italic":false,"fontFamily":"Calibri"},
      {"text":"n","x":49,"y":30,"rotate":90,"fontSize":25.33,"color":"#F5F8FF","bold":false,"italic":false,"fontFamily":"Calibri"}
    ]}
  ]
}
''';
      final elements = SvgToSlideElements.parseEditableJson(json);
      expect(elements.length, 1);
      final text = elements.first;
      expect(text.type, ElementType.text);
      expect(text.verticalRuns, isNotNull);
      expect(text.verticalRuns!.length, 2);

      final run = text.verticalRuns!.first;
      expect(run.text, 'Inferensi');
      expect(run.rotate, 90);
      expect(run.x, closeTo(48 * 1.5, 0.001));
      expect(run.y, closeTo(-1.3 * 1.5, 0.001));
      expect(run.fontSize, closeTo(25.33 * 1.5, 0.001));
      expect(run.colorValue, 0xFFF5F8FF);
      expect(run.fontWeight, 'bold');
      expect(run.fontStyle, 'normal');
      expect(run.fontFamily, 'Carlito'); // Calibri → Carlito mapping
    });

    test('ignores runs when absent', () {
      final elements = SvgToSlideElements.parseEditableJson(
        '{"width":1280,"height":720,"elements":[{"type":"text","x":0,"y":0,"w":10,"h":10,"text":"hi"}]}',
      );
      expect(elements.first.verticalRuns, isNull);
    });
  });

  group('SvgToSlideElements.parseEditableJson rich runs', () {
    test('parses mixed-style horizontal runs (stat card) at own size + color', () {
      const json = '''
{
  "width": 1280,
  "height": 720,
  "background": "#0A1628",
  "elements": [
    {"type":"text","x":160,"y":350,"w":310,"h":239,"text":"97M\\nnew jobs\\nby 2025","fontSize":96,"color":"#00D4FF","bold":true,"lineHeight":1.44,"anchor":"middle",
     "richRuns":[
       {"text":"97M","fontSize":96,"color":"#00D4FF","bold":true,"italic":false,"fontFamily":"Calibri"},
       {"text":"\\nnew jobs","fontSize":28,"color":"#FFFFFF","bold":false,"italic":false,"fontFamily":"Calibri"},
       {"text":"\\nby 2025","fontSize":24,"color":"#94A3B8","bold":false,"italic":false,"fontFamily":"Calibri"}
     ]}
  ]
}
''';
      final elements = SvgToSlideElements.parseEditableJson(json);
      expect(elements.length, 1);
      final text = elements.first;
      expect(text.richRuns, isNotNull);
      expect(text.richRuns!.length, 3);

      final first = text.richRuns![0];
      expect(first.text, '97M');
      expect(first.fontSize, closeTo(96 * 1.5, 0.001));
      expect(first.colorValue, 0xFF00D4FF);
      expect(first.fontWeight, 'bold');
      expect(first.fontFamily, 'Carlito'); // Calibri → Carlito

      final third = text.richRuns![2];
      expect(third.text, '\nby 2025');
      expect(third.fontSize, closeTo(24 * 1.5, 0.001));
      expect(third.colorValue, 0xFF94A3B8);
      expect(third.fontWeight, 'normal');
    });

    test('ignores richRuns when absent', () {
      final elements = SvgToSlideElements.parseEditableJson(
        '{"width":1280,"height":720,"elements":[{"type":"text","x":0,"y":0,"w":10,"h":10,"text":"hi"}]}',
      );
      expect(elements.first.richRuns, isNull);
    });
  });

  group('SvgToSlideElements.parseEditableJson polygon/path shapes', () {
    test('polygon preset carries flat point list scaled into design space', () {
      const json = '''
{
  "width": 1280,
  "height": 720,
  "background": "#ffffff",
  "elements": [
    {"type":"shape","x":100,"y":100,"w":200,"h":200,"fill":"#6366F1","shapeType":"polygon",
     "polygonPoints":[50,0,150,0,200,100,150,200,50,200,0,100]}
  ]
}
''';
      final elements = SvgToSlideElements.parseEditableJson(json);
      final shape = elements.first;
      expect(shape.type, ElementType.shape);
      expect(shape.shapeStyle!.shapeType, 'polygon');
      expect(shape.shapeStyle!.polygonPoints, isNotNull);
      expect(shape.shapeStyle!.polygonPoints!.length, 12);
      // 50*1.5=75, 0*1.5=0, 150*1.5=225, 200*1.5=300 …
      expect(shape.shapeStyle!.polygonPoints![0], closeTo(75, 0.001));
      expect(shape.shapeStyle!.polygonPoints![1], closeTo(0, 0.001));
      expect(shape.shapeStyle!.polygonPoints![2], closeTo(225, 0.001));
      expect(shape.shapeStyle!.polygonPoints![4], closeTo(300, 0.001));
      expect(shape.shapeStyle!.polygonPoints![5], closeTo(150, 0.001));
      expect(shape.shapeStyle!.pathData, isNull);
    });

    test('path preset (donut/ring) preserves the SVG path string', () {
      const json = '''
{
  "width": 1280,
  "height": 720,
  "background": "#ffffff",
  "elements": [
    {"type":"shape","x":100,"y":100,"w":200,"h":200,"fill":"#6366F1","shapeType":"path",
     "pathData":"M 100 100 C 100 44.77 155.23 0 200 0 L 100 0 Z"}
  ]
}
''';
      final elements = SvgToSlideElements.parseEditableJson(json);
      final shape = elements.first;
      expect(shape.shapeStyle!.shapeType, 'path');
      expect(shape.shapeStyle!.pathData, 'M 100 100 C 100 44.77 155.23 0 200 0 L 100 0 Z');
      expect(shape.shapeStyle!.polygonPoints, isNull);
    });
  });

  group('SvgToSlideElements.parseBackgroundGradient', () {
    test('solid hex → custom_<hex>,<hex>', () {
      expect(
        SvgToSlideElements.parseBackgroundGradient(
          '{"width":1280,"height":720,"background":"#0D1424","elements":[]}',
        ),
        'custom_0D1424,0D1424',
      );
    });

    test('8-digit solid hex strips alpha', () {
      expect(
        SvgToSlideElements.parseBackgroundGradient(
          '{"width":1280,"height":720,"background":"#0D1424FF","elements":[]}',
        ),
        'custom_0D1424,0D1424',
      );
    });

    test('gradient uses first and last stop colors', () {
      expect(
        SvgToSlideElements.parseBackgroundGradient(
          '{"width":1280,"height":720,"background":{"kind":"gradient","stops":[{"pos":0,"color":"#111827"},{"pos":0.5,"color":"#334155"},{"pos":1,"color":"#0F172A"}],"angleDeg":90},"elements":[]}',
        ),
        'custom_111827,0F172A',
      );
    });

    test('missing background → null', () {
      expect(
        SvgToSlideElements.parseBackgroundGradient('{"width":1280,"height":720,"elements":[]}'),
        isNull,
      );
    });
  });
}
