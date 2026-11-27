// DocuCraft — minimal SVG path parser
//
// Layer ekspor GenOffice (export-render.tsx → PathB di pptx-render) selalu
// meng-emit `M`/`L`/`Q`/`C`/`Z` dengan koordinat ABSOLUTE (elliptical arcs
// sudah di-split di awal menjadi cubic segments), sehingga parser ini hanya
// menangani command tersebut dan tidak lain — tanpa arc `A`, tanpa shorthand
// relatif/`H`/`V`/`S`/`T`.

import 'package:flutter/widgets.dart';

/// Parse a GenOffice SVG path `d` string into a Flutter [Path].
///
/// The returned path uses the default [PathFillType.nonZero], matching the SVG
/// nonzero rule GenOffice renders with. Donut/ring shapes encode their hole as a
/// reverse-wound inner subpath, which nonzero fill punches automatically.
Path parseSvgPath(String d) {
  final path = Path();
  final tokens = RegExp(r'[a-zA-Z]|[-+]?(?:\d+\.?\d*|\.\d+)')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  if (tokens.isEmpty) return path;

  String cmd = '';
  int ti = 0;

  double nextNum() => double.tryParse(tokens[ti++]) ?? 0;

  bool isCmd(String t) => RegExp(r'^[a-zA-Z]$').hasMatch(t);

  while (ti < tokens.length) {
    final tok = tokens[ti];
    if (isCmd(tok)) {
      cmd = tok;
      ti++;
      if (cmd == 'Z' || cmd == 'z') path.close();
      continue;
    }
    // A number token under the current command. All coordinates are absolute
    // (GenOffice never emits relative coords), so no current-point tracking needed.
    switch (cmd) {
      case 'M':
        path.moveTo(nextNum(), nextNum());
        break;
      case 'L':
        path.lineTo(nextNum(), nextNum());
        break;
      case 'Q':
        final qx1 = nextNum();
        final qy1 = nextNum();
        path.quadraticBezierTo(qx1, qy1, nextNum(), nextNum());
        break;
      case 'C':
        final cx1 = nextNum();
        final cy1 = nextNum();
        final cx2 = nextNum();
        final cy2 = nextNum();
        path.cubicTo(cx1, cy1, cx2, cy2, nextNum(), nextNum());
        break;
      default:
        // Unknown command — skip the number (defensive; shouldn't happen).
        ti++;
    }
  }
  return path;
}
