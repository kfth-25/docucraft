// Docucraft — Templates & Storage Screen (KEKO Intelligence Light Design)
// Sesuai desain Stitch: Tab Templates + Storage, Grid cards, Folder, Recent Files
// Templates diambil real dari TemplateRegistry (presenton-templates/).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/template_layout.dart';
import '../models/template_registry.dart';
import '../models/slide.dart';
import '../services/template_renderer.dart';
import '../services/template_widget_registry.dart';
import '../services/template_converter.dart';
import '../themes/app_theme.dart';
import '../providers/slide_provider.dart';
import 'slide_editor_screen.dart';

class TemplatesStorageScreen extends StatefulWidget {
  const TemplatesStorageScreen({super.key});

  @override
  State<TemplatesStorageScreen> createState() => _TemplatesStorageScreenState();
}

class _TemplatesStorageScreenState extends State<TemplatesStorageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface2,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppTheme.primary, size: 22),
          onPressed: () {},
        ),
        title: const Text(
          'KEKO',
          style: TextStyle(
            color: AppTheme.primary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.cloud_done, size: 14, color: AppTheme.success),
                SizedBox(width: 4),
                Text('Synced', style: TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Icon(Icons.notifications_outlined, size: 22, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // ── Search Bar ──
          _buildSearchBar(),
          // ── Tab Bar ──
          _buildTabBar(),
          // ── Tab Content ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTemplatesView(),
                _buildStorageView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.outline),
        ),
        child: const Row(
          children: [
            Icon(Icons.search, size: 18, color: AppTheme.textMuted),
            SizedBox(width: 10),
            Expanded(
              child: Text('Search documents & themes...',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(color: AppTheme.surface2),
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.textMuted,
        indicatorColor: AppTheme.primary,
        indicatorWeight: 2,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        tabs: const [
          Tab(text: 'Templates'),
          Tab(text: 'Storage'),
        ],
      ),
    );
  }

  // ── TEMPLATES VIEW (real data dari TemplateRegistry) ──
  static const _categoryColors = {
    'code': AppTheme.primary,
    'pitch-deck': Color(0xFFF43F5E),
    'modern': AppTheme.secondaryDark,
    'education': AppTheme.success,
    'standard': AppTheme.tertiary,
    'neo-modern': Color(0xFF8B5CF6),
    'neo-standard': Color(0xFF0EA5E9),
    'neo-general': Color(0xFFD97706),
    'neo-swift': Color(0xFF10B981),
    'general': AppTheme.textSecondary,
    'swift': Color(0xFFF97316),
    'product-overview': AppTheme.primaryDark,
    'report': Color(0xFF3B82F6),
  };

  static const _categoryIcons = {
    'code': Icons.code,
    'pitch-deck': Icons.slideshow,
    'modern': Icons.auto_awesome,
    'education': Icons.school,
    'standard': Icons.view_carousel,
    'neo-modern': Icons.bolt,
    'neo-standard': Icons.dashboard,
    'neo-general': Icons.language,
    'neo-swift': Icons.speed,
    'general': Icons.grid_view,
    'swift': Icons.flash_on,
    'product': Icons.shopping_bag,
    'report': Icons.assessment,
  };

  Widget _buildTemplatesView() {
    final groups = TemplateRegistry.instance.groups;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header — jumlah total
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${groups.length} Categories',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            Text('See all',
                style: TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 14),

        // Setiap group jadi section dengan grid templates di dalamnya
        ...groups.map((g) => _categorySection(g)),

        const SizedBox(height: 24),

        // AI Recommendation
        _buildAIRecommendation(),
      ],
    );
  }

  Widget _categorySection(TemplateGroup group) {
    final color = _categoryColors[group.name] ?? AppTheme.primary;
    final icon = _categoryIcons[group.name] ?? Icons.category;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.label,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    Text('${group.layouts.length} layouts',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: AppTheme.textMuted),
            ],
          ),
          const SizedBox(height: 10),

          // 1 cover card per kategori — clean preview
          SizedBox(
            height: 140,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _templateCard(_getCoverLayout(group), color),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Pick cover/first layout of a group — 1 per category
  TemplateLayout _getCoverLayout(TemplateGroup group) {
    return group.layouts.firstWhere(
      (l) => l.layoutId.toLowerCase().contains('cover') || l.layoutId.toLowerCase().contains('intro'),
      orElse: () => group.layouts.first,
    );
  }

  Widget _templateCard(TemplateLayout layout, Color accentColor) {
    final layoutData = TemplateRegistry.instance.layoutData[layout.layoutId];
    return GestureDetector(
      onTap: () {
        if (layoutData != null) {
          showDialog(
            context: context,
            builder: (dialogCtx) => Dialog(
              backgroundColor: AppTheme.surface2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(layout.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    Text(layout.description, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    const SizedBox(height: 12),
                    // Preview pakai TemplateWidgetRegistry (sama dengan workspace)
                    if (TemplateWidgetRegistry.has(layout.layoutId))
                      SizedBox(
                        width: double.infinity,
                        height: 220,
                        child: TemplateWidgetRegistry.build(layout.layoutId, {
                          'title': layout.name,
                          'subtitle': layout.description,
                        }),
                      )
                    else
                      TemplateRenderer(layout: layoutData, width: MediaQuery.of(context).size.width * 0.85),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('Tutup', style: TextStyle(color: AppTheme.textSecondary)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            _useTemplate(context, layout, layoutData);
                          },
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('Gunakan Template', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: AppTheme.surface3,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Template preview — render layout asli dari JSON
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: layoutData != null
                    ? (TemplateWidgetRegistry.has(layout.layoutId)
                        ? SizedBox(
                            width: double.infinity,
                            height: double.infinity,
                            child: TemplateWidgetRegistry.build(layout.layoutId, {
                              'title': layout.name,
                              'subtitle': layout.description,
                            }),
                          )
                        : TemplateRenderer(layout: layoutData, width: 160))
                    : Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accentColor, accentColor.withValues(alpha: 0.6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            layout.name.substring(0, layout.name.length.clamp(0, 2)).toUpperCase(),
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.7)),
                          ),
                        ),
                      ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(layout.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(layout.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Apply template: buat project baru → set layoutId + templateData → buka editor
  /// Model Presenton: layoutId → widget render penuh, bukan parse elements
  Future<void> _useTemplate(BuildContext ctx, TemplateLayout layout, TemplateLayoutData data) async {
    final provider = context.read<SlideProvider>();
    final id = provider.createNewProject(title: layout.name);
    await provider.openProject(id, layout.name);

    // Cari semua layout dalam grup yang sama → buat deck lengkap
    final group = TemplateRegistry.instance.groups
        .where((g) => g.layouts.any((l) => l.layoutId == layout.layoutId))
        .firstOrNull;

    if (group != null && group.layouts.length > 1) {
      // ── MULTI-SLIDE DECK: buat slide dari semua layout dalam grup ──
      final slides = <Slide>[];
      for (final gLayout in group.layouts) {
        final gData = TemplateRegistry.instance.layoutData[gLayout.layoutId];
        if (gData == null) continue;
        final bgHex = gData.canvas.backgroundColor ?? '#FFFFFF';
        final hex = bgHex.replaceFirst('#', '');
        slides.add(Slide(
          title: gLayout.name,
          subtitle: gLayout.description,
          backgroundGradient: 'custom_$hex,$hex',
          layoutId: gLayout.layoutId,
          templateData: {
            'title': gLayout.name,
            'paragraph': gLayout.description,
          },
          templateId: gLayout.layoutId,
        ));
      }
      if (slides.isNotEmpty) {
        provider.applyAiResult(slides, replaceAll: true);
        await provider.saveToStorage();
        if (ctx.mounted) {
          Navigator.push(ctx, MaterialPageRoute(builder: (_) => const SlideEditorScreen()));
        }
        return;
      }
    }

    // ── SINGLE SLIDE: hanya 1 layout yang tersedia ──
    final slide = provider.currentSlide;
    if (slide != null) {
      slide.elements.clear(); // jangan parse — widget yang render
      slide.layoutId = layout.layoutId;
      slide.templateData = {
        'title': layout.name,
        'paragraph': layout.description,
      };
      // Background: simpan hex canvas sebagai custom gradient
      final bgHex = data.canvas.backgroundColor ?? '#FFFFFF';
      final hex = bgHex.replaceFirst('#', '');
      slide.backgroundGradient = 'custom_$hex,$hex';
      provider.notifyListeners();
      // Note: saveToStorage() is not available on SlideProvider, persistence is handled internally
    }

    if (ctx.mounted) {
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => const SlideEditorScreen()));
    }
  }

  Widget _buildAIRecommendation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.secondaryDark.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.secondaryDark.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome, color: AppTheme.secondaryDark, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Recommendation',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                    children: [
                      TextSpan(text: 'Based on your recent "Project Nebula" documents, we suggest the '),
                      TextSpan(text: 'Future Tech', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                      TextSpan(text: ' template for your next report.'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('View Template',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textOnPrimary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── STORAGE VIEW ──
  Widget _buildStorageView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Cloud Storage indicator
        _buildStorageIndicator(),
        const SizedBox(height: 24),

        // Folders
        _buildFoldersSection(),
        const SizedBox(height: 24),

        // Recent Files
        _buildRecentFiles(),
      ],
    );
  }

  Widget _buildStorageIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cloud Storage',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const Text('24% Used',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.24,
              minHeight: 8,
              backgroundColor: AppTheme.surface3,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          const Text('12.4 GB of 50 GB used',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildFoldersSection() {
    final folders = [
      _FolderData(Icons.folder, 'Presentations', '48 files', AppTheme.warning),
      _FolderData(Icons.folder, 'Documents', '124 files', AppTheme.primary),
      _FolderData(Icons.group, 'Shared', '12 folders', AppTheme.secondaryDark),
      _FolderData(Icons.star_outline, 'Starred', '15 files', AppTheme.tertiary),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Folders',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
          ),
          itemCount: folders.length,
          itemBuilder: (ctx, i) => _folderCard(folders[i]),
        ),
      ],
    );
  }

  Widget _folderCard(_FolderData data) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface3,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(data.icon, size: 24, color: data.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                Text(data.count,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentFiles() {
    final files = [
      _FileData(Icons.slideshow, 'Quarterly_Report_Q4.pptx', 'Modified Oct 24 • 14.2 MB', AppTheme.warning),
      _FileData(Icons.description, 'Brand_Guidelines_v2.docx', 'Modified yesterday • 5.1 MB', AppTheme.primary),
      _FileData(Icons.picture_as_pdf, 'Contract_Project_Nebula.pdf', 'Modified 2h ago • 1.8 MB', AppTheme.error),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Files',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        ...files.map((f) => _fileTile(f)),
      ],
    );
  }

  Widget _fileTile(_FileData data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(data.icon, size: 28, color: data.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                Text(data.meta,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
          ),
          const Icon(Icons.more_vert, size: 18, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}

class _FolderData {
  final IconData icon;
  final String name, count;
  final Color color;
  const _FolderData(this.icon, this.name, this.count, this.color);
}

class _FileData {
  final IconData icon;
  final String name, meta;
  final Color color;
  const _FileData(this.icon, this.name, this.meta, this.color);
}
