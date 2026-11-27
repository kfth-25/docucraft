import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docucraft_app/models/slide.dart';

void main() {
  testWidgets('single faint ellipse renders', (tester) async {
    tester.view.physicalSize = const Size(400, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Directly build the same color math _shapeWidget uses.
    final baseColor = Color(0x0D7B68EE);
    final color = baseColor.withValues(alpha: (baseColor.a * 1.0).clamp(0.0, 1.0));
    print('baseColor.a=${baseColor.a} composed alpha=${color.a} color=${color.toARGB32().toRadixString(16)}');

    await tester.pumpWidget(MaterialApp(home: RepaintBoundary(
      key: const Key('b'),
      child: Container(
        color: const Color(0xFF0F1029),
        child: ClipOval(child: Container(width: double.infinity, height: double.infinity, color: color)),
      ),
    )));
    await tester.pumpAndSettle();
    final b = tester.renderObject(find.byKey(const Key('b'))) as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 1.0);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    // sample center
    final i = (150 * 400 + 200) * 4;
    final r = bytes!.getUint8(i), g = bytes.getUint8(i+1), bl = bytes.getUint8(i+2), a = bytes.getUint8(i+3);
    print('center pixel = ($r,$g,$bl,$a)');
  });
}
