import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docucraft_app/services/svg_to_slide_elements.dart';

void main() {
  test('color math: does withValues blow low alpha to white?', () {
    final base = Color(0x0D7B68EE);
    print('base=0x${base.toARGB32().toRadixString(16)} a=${base.a} r=${base.r} g=${base.g} b=${base.b}');
    final composed = base.withValues(alpha: (base.a * 1.0).clamp(0.0, 1.0));
    print('composed=0x${composed.toARGB32().toRadixString(16)} a=${composed.a} r=${composed.r} g=${composed.g} b=${composed.b}');

    final base2 = Color(0x08FFD700);
    final composed2 = base2.withValues(alpha: (base2.a * 1.0).clamp(0.0, 1.0));
    print('gold composed=0x${composed2.toARGB32().toRadixString(16)} a=${composed2.a}');

    // What _shapeWidget actually does:
    final ssOpacity = 1.0;
    final c = Color(0x0D7B68EE).withValues(alpha: (Color(0x0D7B68EE).a * ssOpacity).clamp(0.0, 1.0));
    print('shapeWidget result=0x${c.toARGB32().toRadixString(16)} a=${c.a}');
  });
}
