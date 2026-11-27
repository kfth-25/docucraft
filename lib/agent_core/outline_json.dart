// DocuCraft Flutter — OutlineJson parser (Sprint 13)
//
// Parsing fallback berlapis-lapis untuk outline JSON dari LLM. Model sering
// mengeluarkan kutip yang tak-escape, trailing comma, smart quote, atau teks
// prosa di sekitar JSON. Modul ini menerapkan serangkaian normalisasi yang
// makin agresif secara bertahap sampai ada yang berhasil di-parse.
//
// Mencerminkan GenOffice `apps/slides/src/renderer/ai/outline-json.ts`.

import 'dart:convert';
import '../ai/run_state_machine.dart';

/// Strip markdown fences and slice the object between the first and last
/// braces.
String extractJsonObject(String text) {
  var s = text.trim();
  s = s.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '').replaceFirst(RegExp(r'```\s*$'), '').trim();
  final st = s.indexOf('{');
  final en = s.lastIndexOf('}');
  if (st >= 0 && en > st) s = s.substring(st, en + 1);
  return s;
}

/// Remove trailing commas in objects/arrays: `{"a":1,}` / `[1,]`.
String stripTrailingCommas(String s) {
  return s.replaceAllMapped(
    RegExp(r',(\s*[}\]])'),
    (m) => m.group(1)!,
  );
}

/// Curly quotes (CJK and Western) → straight quotes, so parse doesn't blow up.
String normalizeSmartQuotes(String s) {
  final sb = StringBuffer();
  for (final c in s.runes) {
    if (c == 0x201C || c == 0x201D || c == 0x201E || c == 0x201F || c == 0x2033 || c == 0x2036) {
      sb.write('"');
    } else if (c == 0x2018 || c == 0x2019 || c == 0x201A || c == 0x201B || c == 0x2032 || c == 0x2035) {
      sb.write("'");
    } else {
      sb.writeCharCode(c);
    }
  }
  return sb.toString();
}

/// Escape unescaped `"` inside string values, and write bare newlines/tabs
/// as JSON escapes.
String escapeBrokenStringLiterals(String json) {
  final out = StringBuffer();
  var i = 0;
  var inString = false;
  while (i < json.length) {
    final c = json[i];
    if (!inString) {
      out.write(c);
      if (c == '"') inString = true;
      i++;
      continue;
    }
    if (c == r'\') {
      out.write(c);
      if (i + 1 < json.length) {
        out.write(json[i + 1]);
        i += 2;
      } else {
        i++;
      }
      continue;
    }
    if (c == '"') {
      var j = i + 1;
      while (j < json.length && _isWhitespace(json[j])) j++;
      final next = j < json.length ? json[j] : '';
      if (next == '' || next == ',' || next == '}' || next == ']' || next == ':') {
        out.write('"');
        inString = false;
      } else {
        out.write(r'\"');
      }
      i++;
      continue;
    }
    if (c == '\n') { out.write(r'\n'); i++; continue; }
    if (c == '\r') { out.write(r'\r'); i++; continue; }
    if (c == '\t') { out.write(r'\t'); i++; continue; }
    out.write(c);
    i++;
  }
  return out.toString();
}

bool _isWhitespace(String s) {
  if (s.isEmpty) return false;
  final c = s.codeUnitAt(0);
  return c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;
}

Map<String, dynamic>? _tryParse(String s) {
  try {
    final v = jsonDecode(s);
    return v is Map<String, dynamic> ? v : null;
  } catch (_) {
    return null;
  }
}

/// Multi-layer fallback parsing of outline JSON. Returns the object on
/// success; null on failure.
Map<String, dynamic>? parseOutlineJson(String text) {
  final raw = extractJsonObject(text);
  if (raw.isEmpty) return null;

  final candidates = <String>[
    raw,
    stripTrailingCommas(raw),
    normalizeSmartQuotes(raw),
    stripTrailingCommas(normalizeSmartQuotes(raw)),
    escapeBrokenStringLiterals(raw),
    escapeBrokenStringLiterals(normalizeSmartQuotes(raw)),
    stripTrailingCommas(escapeBrokenStringLiterals(normalizeSmartQuotes(raw))),
  ];

  final seen = <String>{};
  for (final c in candidates) {
    if (seen.contains(c)) continue;
    seen.add(c);
    final obj = _tryParse(c);
    if (obj != null) return obj;
  }
  return null;
}

/// Parse the `pages` field of an outline JSON object into a list of
/// `OutlinePage`. Tolerant: missing fields default to empty, malformed
/// entries are dropped, indices are renumbered 1..N.
List<OutlinePage> extractOutlinePages(Map<String, dynamic>? obj, {int? defaultCount}) {
  if (obj == null) return const [];
  final pages = obj['pages'];
  if (pages is! List) return const [];

  final result = <OutlinePage>[];
  var i = 1;
  for (final entry in pages) {
    if (entry is Map) {
      final title = _stringField(entry, 'title') ?? _stringField(entry, 'name') ?? 'Page $i';
      final brief = _stringField(entry, 'brief') ?? _stringField(entry, 'description') ?? '';
      final layout = _stringField(entry, 'layout');
      result.add(OutlinePage(index: i, title: title, brief: brief, layout: layout));
    } else if (entry is String && entry.trim().isNotEmpty) {
      result.add(OutlinePage(index: i, title: entry.trim(), brief: ''));
    }
    i++;
  }
  if (result.isEmpty && defaultCount != null && defaultCount > 0) {
    return List.generate(
      defaultCount,
      (k) => OutlinePage(index: k + 1, title: 'Page ${k + 1}', brief: ''),
    );
  }
  return result;
}

String? _stringField(Map entry, String key) {
  final v = entry[key];
  return v is String ? v : null;
}
