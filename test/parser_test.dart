import 'dart:io';
import '../lib/services/html_template_parser.dart';
import '../lib/models/slide.dart';

void main() {
  final html = File('assets/templates/intro-slide.html').readAsStringSync();
  final slide = HtmlTemplateParser.parse(html, {
    'TITLE': 'Strategi Pemasaran Digital 2026',
    'PARAGRAPH': 'Membangun brand awareness dan meningkatkan konversi.',
    'COMPANY_NAME': 'Acme Corp',
    'WEBSITE': 'www.acme.com',
    'CARD_NAME': 'Kemal A.',
    'CARD_DATE': 'Jan 2026',
    'IMAGE_URL': 'https://example.com/img.jpg',
    'IMAGE_PROMPT': 'abstract',
  });
  if (slide == null) {
    print('PARSE FAILED');
    return;
  }
  print('backgroundGradient=${slide.backgroundGradient}');
  print('elements=${slide.elements.length}');
  for (final el in slide.elements) {
    final c = (el.content ?? '');
    final short = c.length > 40 ? c.substring(0, 40) : c;
    print('  type=${el.type.name} x=${el.x.round()} y=${el.y.round()} w=${el.width.round()} h=${el.height.round()} "$short"');
  }
}
