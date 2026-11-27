import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docucraft_app/models/slide.dart';
import 'package:docucraft_app/services/svg_to_slide_elements.dart';
import 'package:docucraft_app/widgets/slide_canvas.dart';

void main() {
  testWidgets('render GenOffice editable JSON to PNG for comparison',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // flutter_tester does NOT auto-load pubspec fonts — load Carlito explicitly
    // so text renders with real glyphs (not Ahem solid squares) and wraps at the
    // same metrics as the app / GenOffice.
    final fontLoader = FontLoader('Carlito')
      ..addFont(rootBundle.load('assets/fonts/Carlito-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Carlito-Bold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Carlito-Italic.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Carlito-BoldItalic.ttf'));
    await fontLoader.load();

    final wsDir =
        'C:/Users/Pongo/AppData/Roaming/GenOffice Dev/docucraft-workspaces';
    final dirs = Directory(wsDir)
        .listSync()
        .whereType<Directory>()
        .where((d) => File('${d.path}/presentation.json').existsSync())
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    final ws = dirs.first.path;
    final deck = jsonDecode(File('$ws/presentation.json').readAsStringSync())
        as Map<String, dynamic>;
    final slides = deck['slides'] as List;
    final editable = (slides[0] as Map)['editable'] as String;

    final elements = SvgToSlideElements.parseEditableJson(editable);
    final bg = SvgToSlideElements.parseBackgroundGradient(editable) ?? 'clean-white';
    final slide = Slide(
      id: 'dbg',
      title: 'Slide 1',
      backgroundGradient: bg,
      elements: elements,
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: const Key('boundary'),
          child: SlideCanvas(
            slide: slide,
            fitScale: 1280 / 1920, // design 1920 → 1280 surface
            onElementTap: (_) {},
            onElementDragEnd: (_, __, ___) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary = tester.renderObject(find.byKey(const Key('boundary')))
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('C:/Users/Pongo/genoffice/flutter_render.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
    debugPrint('WROTE flutter_render.png ($image) from $ws');
  });
}
