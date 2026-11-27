// DocuCraft — Code Block Fitting (Dart port)
// Port dari codeBlockFitting.ts (Presenton Code theme)
// Fungsi: normalize, format, fit code ke area yang tersedia.
//
// Tidak pakai PrismJS (Dart tidak punya Prism).
// Fokus: JSON format, line wrapping, perhitungan ukuran font.

import 'dart:convert';

/// Default font family untuk code
const kCodeFontFamily = 'monospace'; // 'Liberation Mono' atau 'Fira Code' untuk prod

/// Constants dari TSX
const _defaultCharWidthRatio = 0.66;
const _defaultLineHeightRatio = 1.25;
const _hardMinFontSize = 4.0;
const _minCodeLineChars = 34;
const _maxCodeLineChars = 96;

/// Output dari fitCodeBlock
class FittedCodeBlock {
  final String text;
  final String highlightedHtml; // plain text (tanpa syntax highlighting di Flutter)
  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final String? prismLanguage;

  const FittedCodeBlock({
    required this.text,
    required this.highlightedHtml,
    required this.fontFamily,
    required this.fontSize,
    required this.lineHeight,
    this.prismLanguage,
  });
}

/// Opsi untuk fitCodeBlock
class FitCodeBlockOptions {
  final String? language;
  final String? content;
  final double maxWidth;
  final double maxHeight;
  final double maxFontSize;
  final double minFontSize;
  final double charWidthRatio;
  final double lineHeightRatio;

  const FitCodeBlockOptions({
    this.language,
    this.content,
    required this.maxWidth,
    required this.maxHeight,
    this.maxFontSize = 16,
    this.minFontSize = 8,
    this.charWidthRatio = _defaultCharWidthRatio,
    this.lineHeightRatio = _defaultLineHeightRatio,
  });
}

/// Normalize JSON content — format & repair
String tryFormatJson(String content) {
  final trimmed = content.replaceFirst(RegExp(r'^﻿'), '').trim();
  if (trimmed.isEmpty) return '';

  // Coba parse langsung
  try {
    final parsed = _parseJsonSafe(trimmed);
    if (parsed != null) {
      return const JsonEncoder.withIndent('  ').convert(parsed);
    }
  } catch (_) {}

  // Coba repair: ganti / → , di JSON
  final normalized = trimmed
      .replaceAll(RegExp(r'^\s*/\s*$', multiLine: true), ',')
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'\n\s*:\s*'), ': ')
      .replaceAll(RegExp(r'\n\s*,\s*'), ', ');

  try {
    final parsed = _parseJsonSafe(normalized);
    if (parsed != null) {
      return const JsonEncoder.withIndent('  ').convert(parsed);
    }
  } catch (_) {}

  // Fallback: format manual
  return _manualFormatJson(normalized);
}

/// Parse JSON aman
dynamic _parseJsonSafe(String content) {
  try {
    return jsonDecode(content);
  } catch (_) {
    return null;
  }
}

/// Format JSON manual (tanpa parser) — fix common issues
String _manualFormatJson(String content) {
  var result = content
      .replaceAll(RegExp(r'\n\s*:\s*\n\s*'), ': ')
      .replaceAll(RegExp(r'\n\s*/\s*\n'), ',\n')
      .replaceAll(RegExp(r',\s*([}\]])'), r'$1')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trimRight();
  return result;
}

/// Normalize Python code — expand collapsed imports, inline return
String normalizePythonCode(String content) {
  final lines = content.split('\n');
  final normalized = <String>[];

  for (final line in lines) {
    // Split collapsed imports
    final importSegments = line
        .split(RegExp(r'(?=\sfrom\s+[A-Za-z0-9_.]+\s+import\s+)'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    for (final segment in importSegments) {
      // Expand inline return
      final returnMatch = RegExp(
        r'^(\s*def\s+[^(]+\([^)]*\):)\s+return\s+(.+)$',
      ).firstMatch(segment);

      if (returnMatch != null) {
        normalized.add(returnMatch.group(1)!);
        normalized.add('return ${returnMatch.group(2)!}');
      } else {
        normalized.add(segment);
      }
    }
  }

  return normalized.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n');
}

/// Normalize content berdasarkan language
String normalizeCodeContent(String? language, String? content) {
  var result = (content ?? '')
      .replaceAll('\r\n', '\n')
      .replaceAll(r'\[', '[')
      .replaceAll(r'\]', ']');

  // Unwrap markdown code fence
  final fenceMatch = RegExp(r'^```([^\n`]*)\n([\s\S]*?)\n```$').firstMatch(result.trim());
  var fenceLanguage = language;
  if (fenceMatch != null) {
    result = fenceMatch.group(2)!;
    fenceLanguage = fenceMatch.group(1)?.trim().toLowerCase() ?? language;
  }

  final normalized = (fenceLanguage ?? '').toLowerCase().trim();

  if (normalized == 'python') {
    result = normalizePythonCode(result);
  } else if (normalized.contains('json') || normalized.isEmpty) {
    result = tryFormatJson(result);
  }

  return result;
}

/// Wrap long lines
String wrapLongCodeLines(String content, int maxCharsPerLine) {
  if (maxCharsPerLine <= 0) return content;
  return content
      .split('\n')
      .expand((line) => _wrapLongLine(line, maxCharsPerLine))
      .join('\n');
}

List<String> _wrapLongLine(String line, int maxChars) {
  if (line.length <= maxChars) return [line];

  final indent = RegExp(r'^\s*').firstMatch(line)?.group(0) ?? '';
  final contIndent = '$indent  ';
  final wrapped = <String>[];
  var remaining = line.trimLeft();
  var currentIndent = indent;

  while ('$currentIndent$remaining'.length > maxChars) {
    final available = (maxChars - currentIndent.length).clamp(1, maxChars);
    final breakIdx = _findSoftBreak(remaining, available);
    final chunk = remaining.substring(0, breakIdx).trimRight();
    wrapped.add('$currentIndent$chunk');
    remaining = remaining.substring(breakIdx).trimLeft();
    currentIndent = contIndent;
    if (remaining.isEmpty) break;
  }
  wrapped.add('$currentIndent$remaining');
  return wrapped;
}

int _findSoftBreak(String text, int maxChars) {
  final limit = maxChars.clamp(0, text.length);
  final minUseful = (limit * 0.55).floor().clamp(1, limit);
  const breakAfter = {',', ';', ')', '}', '{', ']'};

  // Cari break point setelah karakter khusus
  for (var i = limit - 1; i >= minUseful; i--) {
    if (breakAfter.contains(text[i])) return i + 1;
  }
  // Cari whitespace
  for (var i = limit - 1; i >= minUseful; i--) {
    if (text[i] == ' ' || text[i] == '\t') return i;
  }
  return limit;
}

/// Prepare code untuk display
String prepareCodeForDisplay(String content, String? language, int maxCharsPerLine) {
  return wrapLongCodeLines(content, maxCharsPerLine)
      .replaceAll(RegExp(r'[ \t]+$'), '')
      .replaceAll(RegExp(r'\n{4,}'), '\n\n\n');
}

/// FittedCodeBlock — hitung ukuran font & line height
FittedCodeBlock fitCodeBlock(FitCodeBlockOptions opts) {
  final maxChars = _maxCodeLineChars.clamp(
    _minCodeLineChars,
    (opts.maxWidth / (opts.maxFontSize * opts.charWidthRatio)).floor(),
  );

  final displayContent = prepareCodeForDisplay(
    normalizeCodeContent(opts.language, opts.content),
    opts.language,
    maxChars,
  );

  final lines = displayContent.split('\n');
  final lineCount = lines.length;
  final longestLine = lines.isEmpty
      ? 0
      : lines.map((l) => l.length).reduce((a, b) => a > b ? a : b);

  // Hitung font size pas
  double fontSize = opts.maxFontSize;
  while (fontSize >= opts.minFontSize) {
    final lineHeight = (fontSize * opts.lineHeightRatio).roundToDouble();
    final charsPerLine = (opts.maxWidth / (fontSize * opts.charWidthRatio)).floor();
    if (longestLine <= charsPerLine && lineCount * lineHeight <= opts.maxHeight) {
      break;
    }
    fontSize -= 0.5;
  }

  fontSize = fontSize.clamp(_hardMinFontSize, opts.maxFontSize);
  final lineHeight = (fontSize * opts.lineHeightRatio).roundToDouble();

  // Escape HTML untuk rendering
  final escaped = displayContent
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  return FittedCodeBlock(
    text: displayContent,
    highlightedHtml: escaped,
    fontFamily: kCodeFontFamily,
    fontSize: fontSize,
    lineHeight: lineHeight,
    prismLanguage: _resolvePrismLanguage(opts.language),
  );
}

/// Resolve Prism language dari input
String _resolvePrismLanguage(String? language) {
  final normalized = language?.toLowerCase().trim() ?? '';
  if (normalized.contains('json')) return 'json';
  if (normalized.contains('python')) return 'python';
  if (normalized == 'js') return 'javascript';
  if (normalized == 'ts') return 'typescript';
  if (normalized == 'sh' || normalized == 'shell') return 'bash';
  if (normalized == 'yml') return 'yaml';
  return 'clike';
}
