import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docucraft_app/models/slide.dart';
import 'package:docucraft_app/widgets/slide_canvas.dart';

void main() {
  testWidgets('full pipeline single ellipse', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final el = SlideElement(
      id: 'e0', zIndex: 0, type: ElementType.shape,
      x: 450, y: 150, width: 1020, height: 630,
      shapeStyle: ShapeStyleData(fillColorValue: 0x0D7B68EE, opacity: 1, shapeType: 'circle', borderRadius: 0),
    );
    final slide = Slide(id: 's', title: 't', backgroundGradient: 'custom_0F1029,0F1029', elements: [el]);

    await tester.pumpWidget(MaterialApp(home: RepaintBoundary(
      key: const Key('b'),
      child: SlideCanvas(slide: slide, fitScale: 1280/1920, onElementTap: (_){}, onElementDragEnd: (_, __, ___) {}),
    )));
    await tester.pump();
    await tester.pump();

    final b = tester.renderObject(find.byKey(const Key('b'))) as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 1.0);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    int sample(int x, int y) { final i=(y*1280+x)*4; return bytes!.getUint8(i)<<16 | bytes.getUint8(i+1)<<8 | bytes.getUint8(i+2); }
    print('FULLPIPE center(640,310)=#${sample(640,310).toRadixString(16).padLeft(6,"0")} bg(50,50)=#${sample(50,50).toRadixString(16).padLeft(6,"0")}');
  });
}
