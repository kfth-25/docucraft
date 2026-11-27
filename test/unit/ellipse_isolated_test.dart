import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('isolated faint ellipse', (tester) async {
    tester.view.physicalSize = const Size(400, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final baseColor = Color(0x0D7B68EE);
    final color = baseColor.withValues(alpha: (baseColor.a * 1.0).clamp(0.0, 1.0));

    await tester.pumpWidget(MaterialApp(home: RepaintBoundary(
      key: const Key('b'),
      child: Container(
        color: const Color(0xFF0F1029),
        child: Stack(children: [
          Positioned(left: 100, top: 50, width: 200, height: 200,
            child: ClipOval(child: Container(color: color))),
        ]),
      ),
    )));
    await tester.pumpAndSettle();
    final b = tester.renderObject(find.byKey(const Key('b'))) as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 1.0);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    int sample(int x, int y) {
      final i = (y * 400 + x) * 4;
      return bytes!.getUint8(i) << 16 | bytes.getUint8(i+1) << 8 | bytes.getUint8(i+2);
    }
    final c = sample(200, 150); // ellipse center
    final edge = sample(50, 150); // outside ellipse (navy bg)
    print('RESULT center=#${c.toRadixString(16).padLeft(6,"0")} edge=#${edge.toRadixString(16).padLeft(6,"0")}');
  });
}
