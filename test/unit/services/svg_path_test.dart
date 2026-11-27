import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docucraft_app/services/svg_path.dart';

void main() {
  group('parseSvgPath', () {
    test('parses a simple closed rect (M/L/Z)', () {
      final path = parseSvgPath('M 0 0 L 100 0 L 100 100 L 0 100 Z');
      expect(path.contains(const Offset(50, 50)), isTrue);
      expect(path.contains(const Offset(-10, 50)), isFalse);
    });

    test('parses cubic + quadratic commands', () {
      // A diamond-ish shape via Q, and a smoothed blob via C — just assert no throw
      // and that the bounding region is filled.
      final path = parseSvgPath(
        'M 50 0 Q 100 50 50 100 Q 0 50 50 0 Z',
      );
      expect(path.contains(const Offset(50, 50)), isTrue);
      expect(path.contains(const Offset(0, 0)), isFalse);

      final cubic = parseSvgPath(
        'M 0 50 C 25 0 75 0 100 50 C 75 100 25 100 0 50 Z',
      );
      expect(cubic.contains(const Offset(50, 50)), isTrue);
    });

    test('donut/ring: reverse-wound inner subpath punches a hole (nonzero fill)', () {
      // Outer square clockwise (y-down: right→down→left→up), inner square
      // counter-clockwise — the same winding relationship GenOffice emits for a
      // donut (outer ellipse CW, inner ellipse CCW). Nonzero fill must leave the
      // center empty and fill the ring band.
      final path = parseSvgPath(
        'M 0 0 L 100 0 L 100 100 L 0 100 Z M 25 25 L 25 75 L 75 75 L 75 25 Z',
      );
      // Ring band (inside outer, outside inner) → filled.
      expect(path.contains(const Offset(10, 50)), isTrue);
      expect(path.contains(const Offset(50, 10)), isTrue);
      // Hole center (inside inner) → punched out.
      expect(path.contains(const Offset(50, 50)), isFalse);
    });

    test('empty / malformed input returns an empty path', () {
      expect(parseSvgPath('').getBounds(), const Rect.fromLTRB(0, 0, 0, 0));
      expect(parseSvgPath('not a path'), isEmptyPath);
    });
  });
}

/// Matcher: an empty Path has a zero-size bounding box.
const isEmptyPath = _EmptyPathMatcher();

class _EmptyPathMatcher extends Matcher {
  const _EmptyPathMatcher();
  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    if (item is! Path) return false;
    final b = item.getBounds();
    return b.isEmpty;
  }

  @override
  Description describe(Description description) => description.add('empty path');
}
