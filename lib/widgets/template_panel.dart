// DocuCraft — Template Panel V2
// 13 theme × preview cover × terapkan background

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/template_layout.dart';
import '../models/template_registry.dart';
import '../providers/slide_provider.dart';
// TemplateWidgetRegistry sudah tidak dipakai langsung di sini
import '../themes/app_theme.dart';
import '../services/template_renderer.dart';

class TemplatePanel extends StatefulWidget {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TemplatePanel(),
    );
  }
  const TemplatePanel({super.key});

  @override
  State<TemplatePanel> createState() => _TemplatePanelState();
}

class _TemplatePanelState extends State<TemplatePanel> {
  String _selectedGroup = 'Semua';
  late List<String> _groups;

  @override
  void initState() {
    super.initState();
    final registry = TemplateRegistry.instance;
    _groups = ['Semua'];
    for (final g in registry.groups) {
      if (!_groups.contains(g.label)) _groups.add(g.label);
    }
  }

  /// Group by theme folder — deduplicate by label
  List<_ThemeGroup> _getThemes() {
    final registry = TemplateRegistry.instance;
    final Map<String, _ThemeGroup> themeMap = {};

    for (final group in registry.groups) {
      if (_selectedGroup != 'Semua' && group.label != _selectedGroup) continue;
      if (group.layouts.isEmpty) continue;
      if (themeMap.containsKey(group.label)) continue; // ← dedup

      // Find the "cover" or first layout for preview
      final coverLayout = group.layouts.firstWhere(
        (l) => l.layoutId.toLowerCase().contains('cover') || l.layoutId.toLowerCase().contains('intro'),
        orElse: () => group.layouts.first,
      );

      themeMap[group.label] = _ThemeGroup(
        label: group.label,
        folder: group.name,
        layoutCount: group.layouts.length,
        coverLayoutId: coverLayout.layoutId,
        coverLayout: coverLayout,
      );
    }
    return themeMap.values.toList();
  }

  void _applyTheme(_ThemeGroup theme) {
    final provider = context.read<SlideProvider>();
    final slide = provider.currentSlide;
    if (slide == null) return;

    provider.captureUndo();

    // Model Presenton: set layoutId + templateData → widget render penuh
    final layoutData = TemplateRegistry.instance.layoutData[theme.coverLayoutId];
    slide.layoutId = theme.coverLayoutId;
    slide.templateData = {
      'title': slide.title,
      'paragraph': slide.subtitle,
      // Image URL dari layout JSON (elemen type=image) supaya foto tampil
      if (layoutData != null) 'imageUrl': _findImageUrl(layoutData),
    };

    // Fallback: kalau template widget belum ada di registry → render static via TemplateRenderer
    // (bukan parse elements — supaya tidak berantakan)
    slide.elements.clear();

    slide.bumpVersion();
    provider.notify();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎨 Tema "${theme.label}" diterapkan'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Cari URL gambar dari layout JSON (elemen type=image)
  String _findImageUrl(TemplateLayoutData layout) {
    for (final el in layout.elements) {
      if (el.type == TemplateElementType.image && el.content is String) {
        final url = el.content as String;
        if (url.startsWith('http')) return url;
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final themes = _getThemes();
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Center(child: Container(width: 40, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(2)))),
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withAlpha(12)))),
                child: Row(children: [
                  const Icon(Icons.palette, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  const Text('Tema Presentasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const Spacer(),
                  Text('${themes.length} tema', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                  ),
                ]),
              ),
              // Group chips
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _groups.length,
                  itemBuilder: (ctx, i) {
                    final g = _groups[i];
                    final active = g == _selectedGroup;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedGroup = g),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8, top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: active ? AppTheme.primary : AppTheme.surface3,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: active ? AppTheme.primary : Colors.white.withAlpha(20)),
                        ),
                        child: Text(g, style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: active ? Colors.white : AppTheme.textSecondary,
                        )),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              // Theme grid (1 per theme folder)
              Expanded(
                child: themes.isEmpty
                    ? const Center(child: Text('Tidak ada tema', style: TextStyle(color: AppTheme.textMuted)))
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        itemCount: themes.length,
                        itemBuilder: (ctx, i) => _themeCard(ctx, themes[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _themeCard(BuildContext ctx, _ThemeGroup theme) {
    final layoutData = TemplateRegistry.instance.layoutData[theme.coverLayoutId];
    return GestureDetector(
      onTap: () => _applyTheme(theme),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview: render cover layout
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: layoutData != null
                    ? TemplateRenderer(layout: layoutData, width: 380)
                    : Container(
                        color: AppTheme.surface3,
                        child: Center(
                          child: Text(theme.label, style: const TextStyle(color: Colors.white38, fontSize: 14)),
                        ),
                      ),
              ),
            ),
            // Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppTheme.surface3,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${theme.layoutCount} layouts', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(theme.label,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                ),
                const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.textMuted),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeGroup {
  final String label;
  final String folder;
  final int layoutCount;
  final String coverLayoutId;
  final TemplateLayout coverLayout;

  _ThemeGroup({
    required this.label,
    required this.folder,
    required this.layoutCount,
    required this.coverLayoutId,
    required this.coverLayout,
  });
}
