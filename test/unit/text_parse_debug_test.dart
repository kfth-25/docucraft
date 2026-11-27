import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:docucraft_app/services/svg_to_slide_elements.dart';

void main() {
  test('dump parsed text styles', () {
    final wsDir = 'C:/Users/Pongo/AppData/Roaming/GenOffice Dev/docucraft-workspaces';
    final dirs = Directory(wsDir).listSync().whereType<Directory>()
        .where((d) => File('${d.path}/presentation.json').existsSync()).toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    final deck = jsonDecode(File('${dirs.first.path}/presentation.json').readAsStringSync()) as Map<String, dynamic>;
    final editable = (deck['slides'][0] as Map)['editable'] as String;
    final elements = SvgToSlideElements.parseEditableJson(editable);
    for (final e in elements) {
      if (e.type.toString() == 'ElementType.text') {
        final ts = e.textStyle!;
        print('TEXT "${e.content}" fontSize=${ts.fontSize} color=0x${ts.colorValue.toRadixString(16).padLeft(8,"0")} fam=${ts.fontFamily} bold=${ts.fontWeight} lh=${ts.lineHeight} anchor=${ts.anchor} insetL=${ts.insetL} insetT=${ts.insetT} rich=${e.richRuns?.length ?? 0}');
      }
    }
  });
}
