import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docucraft_app/models/slide.dart';
import 'package:docucraft_app/services/svg_to_slide_elements.dart';
import 'package:docucraft_app/widgets/slide_canvas.dart';

void main() {
  testWidgets('inspect rendered widget styles', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;

    final wsDir = 'C:/Users/Pongo/AppData/Roaming/GenOffice Dev/docucraft-workspaces';
    final dirs = Directory(wsDir).listSync().whereType<Directory>()
        .where((d) => File('${d.path}/presentation.json').existsSync()).toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    final deck = jsonDecode(File('${dirs.first.path}/presentation.json').readAsStringSync()) as Map<String, dynamic>;
    final editable = (deck['slides'][0] as Map)['editable'] as String;
    final all = SvgToSlideElements.parseEditableJson(editable);
    final slide = Slide(id: 's', title: 't', backgroundGradient: 'custom_0F1029,0F1029', elements: all);

    await tester.pumpWidget(MaterialApp(home: SlideCanvas(slide: slide, fitScale: 1280/1920, onElementTap: (_){}, onElementDragEnd: (_, __, ___) {})));
    await tester.pump();

    // Inspect all Text widgets' styles
    final texts = tester.widgetList<Text>(find.byType(Text)).toList();
    print('TOTAL Text widgets: ${texts.length}');
    for (final t in texts) {
      final data = t.textSpan?.toPlainText() ?? t.data ?? '?';
      final style = t.style;
      print('TEXT "$data" fontSize=${style?.fontSize} color=${style?.color?.toARGB32().toRadixString(16)} fam=${style?.fontFamily} bg=${style?.backgroundColor}');
    }

    // Inspect all ClipOval/Container colors for shapes
    final clips = tester.widgetList<ClipOval>(find.byType(ClipOval)).toList();
    print('TOTAL ClipOval: ${clips.length}');
    for (final c in clips) {
      final cont = c.clipper;
      print('ClipOval child=${c.child.runtimeType}');
    }
    // Find Containers that are direct ClipOval children with a color
    for (final c in clips) {
      if (c.child is Container) {
        final cont = c.child as Container;
        print('ELLIPSE Container color=${cont.color?.toARGB32().toRadixString(16)}');
      }
    }
  });
}
