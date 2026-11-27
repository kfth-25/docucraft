// DocuCraft — Template Widget Registry
// Mirip getLayoutByLayoutId() di Presenton:
// map layoutId → Widget builder yang render template dari content data.
//
// Template = Widget Flutter yang TAHU cara render data.
// Content  = Plain data (JSON) yang tidak tahu bagaimana di-render.

import 'package:flutter/material.dart';
import '../templates/swift/bullets_with_icons_template.dart';
import '../templates/swift/icon_bullet_list_template.dart';
import '../templates/swift/image_list_template.dart';
import '../templates/swift/intro_slide_template.dart';
import '../templates/swift/metrics_template.dart';
import '../templates/swift/simple_bullet_points_template.dart';
import '../templates/swift/table_of_contents_template.dart';
import '../templates/swift/timeline_template.dart';
import '../templates/product_overview/table_of_content_slide_template.dart';
import '../templates/code/table_of_content_slide_template.dart';
import '../templates/code/table_slide_template.dart';
import '../templates/code/terminal_command_slide_template.dart';

/// Builder signature — terima content data, return widget
typedef TemplateWidgetBuilder = Widget Function(Map<String, dynamic> data);

class TemplateWidgetRegistry {
  /// Registri: layoutId → builder
  static final Map<String, TemplateWidgetBuilder> _templates = {
    // Alias: layoutId bisa 'IntroSlideLayout' (JSON) atau 'intro-slide-layout' (registry)
    'IntroSlideLayout': (data) => _buildIntroSlide(data),
    'intro-slide-layout': (data) => _buildIntroSlide(data),
    'metrics-numbers': (data) => MetricsTemplate(
          title: data['title'] as String? ?? 'Performance Highlights',
          leftTitle: data['leftTitle'] as String? ?? 'Performance\nOverview',
          leftBody: data['leftBody'] as String? ?? data['paragraph'] as String? ?? 'Key metrics across our business units, tracking growth and impact.',
          metrics: (data['metrics'] as List?)?.map((m) => {
                'value': m['value']?.toString() ?? '',
                'line1': m['line1']?.toString() ?? '',
                'line2': m['line2']?.toString() ?? '',
                'description': m['description']?.toString() ?? '',
              }).toList() ??
              const [
                {'value': '120K', 'line1': 'Active', 'line2': 'Users', 'description': 'active users across multiple industries'},
                {'value': '150%', 'line1': 'Revenue', 'line2': 'Growth', 'description': 'year-over-year revenue growth'},
                {'value': '95%', 'line1': 'Customer', 'line2': 'Satisfaction', 'description': 'retention rate with an average rating of 4.8/5'},
              ],
          website: data['website'] as String? ?? '',
          companyName: data['companyName'] as String? ?? '',
        ),
    'simple-bullet-points-layout': (data) => SimpleBulletPointsTemplate(
          title: data['title'] as String? ?? 'Our Commitment to Innovation',
          statement: data['statement'] as String? ?? '',
          points: (data['points'] as List?)?.map((p) => {
                'title': (p as Map)['title']?.toString() ?? '',
                'body': (p as Map)['body']?.toString() ?? '',
              }).toList() ??
              [],
          website: data['website'] as String? ?? '',
        ),
    'icon-bullet-list-description-slide': (data) => IconBulletListTemplate(
          title: data['title'] as String? ?? 'Key Product Features',
          description: data['description'] as String? ?? '',
          companyName: data['companyName'] as String? ?? '',
          features: (data['features'] as List?)?.map((f) => {
                'title': (f as Map)['title']?.toString() ?? '',
                'body': (f as Map)['body']?.toString() ?? '',
                'icon': (f as Map)['icon'] != null
                    ? ((f['icon'] as Map)['__icon_url__']?.toString() ?? '')
                    : '',
              }).toList() ??
              [],
          website: data['website'] as String? ?? '',
        ),
    'timeline': (data) => TimelineTemplate(
          title: data['title'] as String? ?? 'Timeline',
          subtitle: data['subtitle'] as String? ?? '',
          events: (data['events'] as List?)?.map((e) => {
                'year': (e as Map)['year']?.toString() ?? '',
                'heading': (e as Map)['heading']?.toString() ?? '',
                'body': (e as Map)['body']?.toString() ?? '',
                'icon': (e as Map)['icon']?.toString() ?? '✨',
              }).toList() ??
              [
                {'year': '2024', 'heading': 'Launch', 'body': 'Product launched globally', 'icon': '🚀'},
                {'year': '2025', 'heading': 'Growth', 'body': '100K+ users reached', 'icon': '📈'},
                {'year': '2026', 'heading': 'Scale', 'body': 'Enterprise expansion', 'icon': '🏢'},
                {'year': '2027', 'heading': 'Future', 'body': 'Global AI integration', 'icon': '⚡'},
              ],
          website: data['website'] as String? ?? '',
          companyName: data['companyName'] as String? ?? '',
        ),
    'image-list-description': (data) => ImageListTemplate(
          titleLine1: data['titleLine1'] as String? ?? 'Discover',
          titleLine2: data['titleLine2'] as String? ?? 'Our Products',
          description: data['description'] as String? ?? '',
          items: (data['items'] as List?)?.map((it) => {
                'title': (it as Map)['title']?.toString() ?? '',
                'description': (it as Map)['description']?.toString() ?? '',
                'imageUrl': (it as Map)['imageUrl']?.toString() ?? '',
              }).toList() ??
              [],
          website: data['website'] as String? ?? '',
        ),
    'table-of-contents': (data) => TableOfContentsTemplate(
          title: data['title'] as String? ?? 'Table of Contents',
          subtitle: data['subtitle'] as String? ?? '',
          companyName: data['companyName'] as String? ?? '',
          items: (data['items'] as List?)?.map((it) => {
                'number': (it as Map)['number']?.toString() ?? '',
                'title': (it as Map)['title']?.toString() ?? '',
                'description': (it as Map)['description']?.toString() ?? '',
              }).toList() ??
              [],
          website: data['website'] as String? ?? '',
        ),
    'bullets-with-icons-title-description': (data) => BulletsWithIconsTemplate(
          title: data['title'] as String? ?? 'Our Infographic',
          sideHeading: data['sideHeading'] as String? ?? '',
          sideParagraph: data['sideParagraph'] as String? ?? '',
          points: (data['points'] as List?)?.map((p) => {
                'icon': (p as Map)['icon']?.toString() ?? '✨',
                'title': (p as Map)['title']?.toString() ?? '',
                'description': (p as Map)['description']?.toString() ?? '',
              }).toList() ??
              [],
          website: data['website'] as String? ?? '',
        ),
        // Code theme (layoutId: table-of-content-slide from code/TableOfContentSlide.json)
        'code-table-of-content-slide': (data) => CodeTableOfContentSlideTemplate(
          title: data['title'] as String? ?? 'Table of Content',
          items: (data['items'] as List?)?.map((it) => {
                'number': (it as Map)['number']?.toString() ?? '',
                'label': (it as Map)['label']?.toString() ?? '',
                'description': (it as Map)['description']?.toString() ?? '',
              }).toList() ??
              [],
        ),
        // Code theme — Table Slide (layoutId: table-slide from code/TableSlide.json)
        'code-table-slide': (data) => CodeTableSlideTemplate(
          title: data['title'] as String? ?? 'Comparison',
          tableColumns: (data['tableColumns'] as List?)?.map((c) => c.toString()).toList() ??
              ['Feature', 'Column 1', 'Column 2', 'Column 3'],
          rows: (data['rows'] as List?)?.map((r) => (r as List).map((c) => c.toString()).toList()).toList() ??
              [
                ['Component-based', 'check', 'check', 'check'],
                ['TypeScript Support', 'check', 'check', 'check'],
                ['Learning Curve', 'Medium', 'Easy', 'Steep'],
                ['Bundle Size', '40KB', '34KB', '167KB'],
                ['Performance', 'Excellent', 'Excellent', 'Good'],
                ['Community Size', 'Huge', 'Large', 'Large'],
              ],
        ),
        // Code theme — Terminal Command Slide (layoutId: terminal-command-slide from code/TerminalCommandSlide.json)
        'code-terminal-command-slide': (data) => CodeTerminalCommandSlideTemplate(
          title: data['title'] as String? ?? 'Local Development Setup',
          description: data['description'] as String? ?? 'Run these commands to start the application locally with Docker.',
          terminalLabel: (data['terminal'] as Map?)?['label'] as String? ?? 'Terminal',
          terminalCommands: (data['terminal'] as Map?)?['commands'] as String? ?? 'pnpm install\npnpm dev',
          note: data['note'] as String? ?? 'The application should be available after the containers finish booting.',
        ),
        // Product Overview (layoutId: table-of-content-slide from product-overview/TableOfContentSlide.json)
        'product-table-of-content-slide': (data) => TableOfContentSlideTemplate(
          title: data['title'] as String? ?? 'Table Of Content',
          description: data['description'] as String? ?? 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore.',
          sections: (data['sections'] as List?)?.map((s) => {
                'title': (s as Map)['title']?.toString() ?? '',
                'number': (s as Map)['number']?.toString() ?? '',
                'description': (s as Map)['description']?.toString() ?? '',
              }).toList() ??
              [],
        ),
  };

  /// Helper: build IntroSlideTemplate, baca imageUrl dari _schema ATAU elements[]
  static Widget _buildIntroSlide(Map<String, dynamic> data) {
    // Cari imageUrl dari _schema (data langsung)
    var imageUrl = data['imageUrl']?.toString() ??
        data['__image_url__']?.toString() ??
        data['media']?['image']?['__image_url__']?.toString() ??
        '';
    // Fallback: cari dari _schema dict
    if (imageUrl.isEmpty && data['_schema'] is Map) {
      final schema = data['_schema'] as Map;
      imageUrl = schema['__image_url__']?.toString() ?? '';
    }
    return IntroSlideTemplate(
      title: data['title'] as String? ?? 'Judul Presentasi',
      paragraph: data['paragraph'] as String? ?? '',
      companyName: data['companyName'] as String? ?? '',
      website: data['website'] as String? ?? '',
      cardName: data['cardName'] as String? ?? '',
      cardDate: data['cardDate'] as String? ?? '',
      imageUrl: imageUrl,
    );
  }

  /// Build widget untuk layoutId — return null kalau tidak dikenal
  static Widget? build(String? layoutId, Map<String, dynamic>? data) {
    if (layoutId == null) return null;
    final builder = _templates[layoutId];
    return builder != null ? builder(data ?? {}) : null;
  }

  /// Cek apakah layoutId dikenal
  static bool has(String? layoutId) =>
      layoutId != null && _templates.containsKey(layoutId);

  /// Daftar semua layoutId yang tersedia
  static List<String> get availableLayoutIds => _templates.keys.toList();
}