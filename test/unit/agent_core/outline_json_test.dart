// DocuCraft Flutter — OutlineJson parser tests (Sprint 13)

import 'dart:convert' show jsonDecode;
import 'package:flutter_test/flutter_test.dart';
import 'package:docucraft_app/agent_core/outline_json.dart';

void main() {
  group('extractJsonObject', () {
    test('strips markdown fences', () {
      expect(extractJsonObject('```json\n{"a":1}\n```'), '{"a":1}');
    });

    test('slices between first and last brace when prose surrounds', () {
      expect(
        extractJsonObject('here you go: {"pages":[]}, thanks!'),
        '{"pages":[]}',
      );
    });

    test('returns trimmed input when no braces', () {
      expect(extractJsonObject('hello'), 'hello');
    });
  });

  group('stripTrailingCommas', () {
    test('removes trailing commas in objects and arrays', () {
      expect(stripTrailingCommas('{"a":1,}'), '{"a":1}');
      expect(stripTrailingCommas('[1,2,]'), '[1,2]');
    });
  });

  group('normalizeSmartQuotes', () {
    test('replaces curly double quotes with straight', () {
      const curly = '“hi”';
      expect(normalizeSmartQuotes(curly), '"hi"');
    });
  });

  group('escapeBrokenStringLiterals', () {
    test('escapes embedded double quote that does not terminate the string', () {
      // "title":"He said "hi" today" — the inner " are not string terminators.
      const input = '{"title":"He said "hi" today"}';
      final out = escapeBrokenStringLiterals(input);
      expect(jsonDecode(out), {'title': 'He said "hi" today'});
    });
  });

  group('parseOutlineJson', () {
    test('parses clean JSON', () {
      final obj = parseOutlineJson('{"pages":[{"title":"A"}]}');
      expect(obj, isNotNull);
      expect(obj!['pages'], isA<List>());
    });

    test('recovers JSON with trailing commas', () {
      final obj = parseOutlineJson('{"pages":[{"title":"A",},]}');
      expect(obj, isNotNull);
      expect((obj!['pages'] as List).length, 1);
    });

    test('recovers JSON surrounded by prose', () {
      final obj = parseOutlineJson('Here is your outline: {"pages":[]}. Cheers!');
      expect(obj, isNotNull);
      expect(obj!['pages'], isA<List>());
    });

    test('recovers JSON with smart quotes at the string boundary', () {
      // Smart quotes used AS the JSON string delimiters: the first
      // normalizeSmartQuotes pass replaces them with straight quotes, then
      // the JSON parses cleanly.
      final obj = parseOutlineJson('{“title”: “smart”}');
      expect(obj, isNotNull);
      expect(obj!['title'], 'smart');
    });

    test('returns null on totally invalid input', () {
      expect(parseOutlineJson(''), isNull);
      expect(parseOutlineJson('not json at all'), isNull);
    });
  });

  group('extractOutlinePages', () {
    test('parses pages array of {title, brief}', () {
      final obj = parseOutlineJson('{"pages":[{"title":"Intro","brief":"Why"},{"title":"Body"}]}')!;
      final pages = extractOutlinePages(obj);
      expect(pages.length, 2);
      expect(pages[0].title, 'Intro');
      expect(pages[0].brief, 'Why');
      expect(pages[1].title, 'Body');
      expect(pages[1].brief, '');
      expect(pages[0].index, 1);
      expect(pages[1].index, 2);
    });

    test('accepts string entries', () {
      final obj = parseOutlineJson('{"pages":["Intro","Body"]}')!;
      final pages = extractOutlinePages(obj);
      expect(pages.length, 2);
      expect(pages[0].title, 'Intro');
    });

    test('returns empty on null/empty input', () {
      expect(extractOutlinePages(null), isEmpty);
      final obj = parseOutlineJson('{"pages":[]}')!;
      expect(extractOutlinePages(obj), isEmpty);
    });

    test('falls back to defaultCount when pages empty', () {
      final obj = parseOutlineJson('{"topic":"x","pages":[]}')!;
      final pages = extractOutlinePages(obj, defaultCount: 3);
      expect(pages.length, 3);
      expect(pages.map((p) => p.title).toList(), ['Page 1', 'Page 2', 'Page 3']);
    });

    test('reads layout field when present', () {
      final obj = parseOutlineJson('{"pages":[{"title":"Hero","layout":"cover"}]}')!;
      final pages = extractOutlinePages(obj);
      expect(pages.first.layout, 'cover');
    });
  });
}
