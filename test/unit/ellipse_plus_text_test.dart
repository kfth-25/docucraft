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
  testWidgets('ellipse + title text compositing', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final wsDir = 'C:/Users/Pongo/AppData/Roaming/GenOffice Dev/docucraft-workspaces';
    final dirs = Directory(wsDir).listSync().whereType<Directory>()
        .where((d) => File('${d.path}/presentation.json').existsSync()).toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    final deck = jsonDecode(File('${dirs.first.path}/presentation.json').readAsStringSync()) as Map<String, dynamic>;
    final editable = (deck['slides'][0] as Map)['editable'] as String;
    final all = SvgToSlideElements.parseEditableJson(editable);

    final ellipses = all.where((e) => e.type == ElementType.shape && e.shapeStyle!.shapeType == 'circle').toList();
    final title = all.where((e) => e.content == 'Keajaiban Alam Semesta').toList();
    final subtitle = all.where((e) => e.content != null && e.content!.startsWith('Kita terbuat')).toList();

    Future<void> renderAndLog(String label, List<SlideElement> els, List<(int,int)> pts) async {
      final slide = Slide(id: 's_$label', title: 't', backgroundGradient: 'custom_0F1029,0F1029', elements: els);
      await tester.pumpWidget(MaterialApp(home: RepaintBoundary(
        key: const Key('b'), child: SlideCanvas(slide: slide, fitScale: 1280/1920, onElementTap: (_){}, onElementDragEnd: (_, __, ___) {}),
      )));
      await tester.pumpAndSettle();
      final b = tester.renderObject(find.byKey(const Key('b'))) as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1.0);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      final parts = <String>[];
      for (final (x, y) in pts) {
        final i = (y*1280+x)*4;
        parts.add('($x,$y)=#${bytes!.getUint8(i).toRadixString(16).padLeft(2,"0")}${bytes.getUint8(i+1).toRadixString(16).padLeft(2,"0")}${bytes.getUint8(i+2).toRadixString(16).padLeft(2,"0")}');
      }
      print('$label: ${parts.join(" ")}');
    }

    await renderAndLog('ELLIPSES', ellipses, [(640,310),(640,230)]);
    await renderAndLog('ELL+TITLE', [...ellipses, ...title], [(640,310),(640,230)]);
    await renderAndLog('ELL+SUB', [...ellipses, ...subtitle], [(640,310),(640,230)]);
  });
}
