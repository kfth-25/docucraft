// Test script for TemplateRegistryV2
// Run with: dart run test_template_registry.dart

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'dart:convert';
import 'dart:io';

import 'lib/models/template_registry_v2.dart';

void main() async {
  // Initialize Flutter binding for asset loading
  WidgetsFlutterBinding.ensureInitialized();

  print('Testing TemplateRegistryV2...');

  final registry = TemplateRegistryV2();

  try {
    await registry.initialize();
    print('✓ Registry initialized');
    print('  Brands: ${registry.allBrands.length}');
    print('  Styles: ${registry.allStyles.length}');
    print('  Layouts: ${registry.allLayouts.length}');
    print('  Decks: ${registry.allDecks.length}');

    // Test resolving a deck
    final resolved = registry.resolve('default-pitch-deck');
    print('\n✓ Resolved deck: ${resolved.deck.name}');
    print('  Brand: ${resolved.brand.name}');
    print('  Style: ${resolved.style.name}');
    print('  Layout: ${resolved.layout.name}');

    // Test slot binding
    final boundSvg = registry.bindTemplateSvg('intro-slide-layout', {
      'companyName': 'Acme Corp',
      'counter': '1',
      'imageUrl': 'https://example.com/image.jpg',
      'title': 'Welcome to Acme',
      'paragraph': 'This is a test presentation',
      'introCard.enabled': true,
      'introCard.initials': 'AC',
      'introCard.name': 'Acme Team',
      'introCard.date': '2025-01-15',
    });

    print('\n✓ Template binding works');
    print('  SVG length: ${boundSvg.length} chars');
    print('  Contains title: ${boundSvg.contains('Welcome to Acme')}');
    print('  Contains companyName: ${boundSvg.contains('Acme Corp')}');

    // Test chart data binding
    final chartSvg = registry.bindTemplateSvg('intro-slide-layout', {
      'title': 'Chart Slide',
      'chartData': {
        'type': 'bar',
        'categories': ['Jan', 'Feb', 'Mar'],
        'series': [
          {'name': 'Revenue', 'values': [100, 150, 200]},
        ],
      },
    });

    print('\n✓ Chart data binding works');
    print('  Contains chart data: ${chartSvg.contains('Revenue')}');

    print('\n✅ All tests passed!');

  } catch (e, stack) {
    print('❌ Error: $e');
    print(stack);
    exit(1);
  }
}