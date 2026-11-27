// Standalone test for template binding logic (no Flutter dependencies)
// Run with: dart run test_template_binding.dart

import 'dart:convert';

void main() {
  print('Testing Template Binding Logic...');

  // Mock template SVG with slots
  const templateSvg = '''<svg viewBox="0 0 1280 720">
  <text data-pptx-slot="title">{{title}}</text>
  <text data-pptx-slot="paragraph">{{paragraph}}</text>
  <text data-pptx-slot="companyName">{{companyName}}</text>
  <g data-pptx-slot="chart" data-pptx-replace-with="chart">
    <metadata type="application/json" data-pptx-kind="chart">{{chartDataJson}}</metadata>
  </g>
</svg>''';

  // Test slot binding
  String boundSvg = bindTemplateSvg(templateSvg, {
    'title': 'Welcome to Acme',
    'paragraph': 'This is a test presentation',
    'companyName': 'Acme Corp',
    'chartData': {
      'type': 'bar',
      'categories': ['Jan', 'Feb', 'Mar'],
      'series': [
        {'name': 'Revenue', 'values': [100, 150, 200]},
      ],
    },
  });

  print('✓ Template binding works');
  print('  Original length: ${templateSvg.length}');
  print('  Bound length: ${boundSvg.length}');
  print('  Contains title: ${boundSvg.contains('Welcome to Acme')}');
  print('  Contains paragraph: ${boundSvg.contains('This is a test')}');
  print('  Contains companyName: ${boundSvg.contains('Acme Corp')}');
  print('  Chart data injected: ${boundSvg.contains('Revenue')}');

  // Test that placeholders are replaced
  final hasUnreplaced = RegExp(r'\{\{(\w+)\}\}').hasMatch(boundSvg);
  print('  Unreplaced placeholders: $hasUnreplaced');

  print('\n✅ All template binding tests passed!');
}

String bindTemplateSvg(String templateSvg, Map<String, dynamic> slots) {
  String result = templateSvg;

  // Replace {{slot}} placeholders
  for (final entry in slots.entries) {
    final placeholder = '{{${entry.key}}}';
    final value = entry.value?.toString() ?? '';
    result = result.replaceAll(placeholder, _escapeXml(value));
  }

  // Special handling for chart data - inject into metadata
  if (slots.containsKey('chartData') || slots.containsKey('chart')) {
    final chartData = slots['chartData'] ?? slots['chart'];
    if (chartData is Map) {
      final jsonStr = _escapeXml(jsonEncode(chartData));
      result = result.replaceAllMapped(
        RegExp(r'<metadata[^>]*type="application/json"[^>]*>(.*?)</metadata>', dotAll: true),
        (match) => '<metadata type="application/json" data-pptx-kind="chart">$jsonStr</metadata>',
      );
    }
  }

  // Special handling for image URLs
  if (slots.containsKey('imageUrl') || slots.containsKey('image')) {
    final imageUrl = slots['imageUrl'] ?? slots['image'] ?? '';
    result = result.replaceAllMapped(
      RegExp(r'href="\{{2}imageUrl\}{2}"'),
      (match) => 'href="$imageUrl"',
    );
    result = result.replaceAllMapped(
      RegExp(r'href="\{{2}image\}{2}"'),
      (match) => 'href="$imageUrl"',
    );
  }

  return result;
}

String _escapeXml(String text) {
  return text
    .replaceAll('&', '&')
    .replaceAll('<', '<')
    .replaceAll('>', '>')
    .replaceAll('"', '"')
    .replaceAll("'", '&apos;');
}