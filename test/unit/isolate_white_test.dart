import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docucraft_app/models/slide.dart';
import 'package:docucraft_app/services/svg_to_slide_elements.dart';
import 'package:docucraft_app/widgets/slide_canvas.dart';

void main() {
  testWidgets('isolate white source', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;

    // Parse the real deck
    final wsDir = 'C:/Users/Pongo/AppData/Roaming/GenOffice Dev/docucraft-workspaces';
    final dirs = Directory(wsDir).listSync().whereType<Directory>()
        .where((d) => File('${d.path}/presentation.json').existsSync()).toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    final deck = jsonDecode(File('${dirs.first.path}/presentation.json').readAsStringSync()) as Map<String, dynamic>;
    final editable = (deck['slides'][0] as Map)['editable'] as String;
    final all = SvgToSlideElements.parseEditableJson(editable);

    Future<int> renderAndSample(List<SlideElement> els, int x, int y) async {
      final slide = Slide(id: 's${els.hashCode}', title: 't', backgroundGradient: 'custom_0F1029,0F1029', elements: els);
      await tester.pumpWidget(MaterialApp(home: RepaintBoundary(
        key: const Key('b'), child: SlideCanvas(slide: slide, fitScale: 1280/1920, onElementTap: (_){}, onElementDragEnd: (_, __, ___) {}),
      )));
      await tester.pump(); await tester.pump();
      final b = tester.renderObject(find.byKey(const Key('b'))) as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1.0);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      final i = (y*1280+x)*4;
      return bytes!.getUint8(i)<<16 | bytes.getUint8(i+1)<<8 | bytes.getUint8(i+2);
    }

    // Only the 2 ellipses
    final ellipses = all.where((e) => e.type == ElementType.shape && e.shapeStyle!.shapeType == 'circle').toList();
    final c1 = await renderAndSample(ellipses, 640, 310);
    print('ELLIPSES-ONLY center=#${c1.toRadixString(16).padLeft(6,"0")}');

    // Ellipses + title + subtitle (the text elements)
    final withText = all.where((e) => e.type == ElementType.shape || e.type == ElementType.text).toList();
    final c2 = await renderAndSample(withText, 640, 310);
    print('SHAPES+TEXT center=#${c2.toRadixString(16).padLeft(6,"0")}');

    // Just the title text element alone
    final title = all.where((e) => e.content == 'Keajaiban Alam Semesta').toList();
    final c3 = await renderAndSample(title, 640, 230);
    print('TITLE-ONLY (640,230)=#${c3.toRadixString(16).padLeft(6,"0")}');
  });
}
