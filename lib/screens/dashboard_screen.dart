// DocuCraft — Dashboard Screen (Project List)
// List semua presentasi project, create/delete/open

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../themes/app_theme.dart';
import '../services/storage_service.dart';
import '../services/api_client.dart';
import '../models/template_layout.dart';
import '../models/template_registry.dart';
import '../services/template_renderer.dart';
import '../services/template_converter.dart';
import 'profile_screen.dart';
import 'templates_storage_screen.dart';
import '../services/template_widget_registry.dart';
import '../providers/slide_provider.dart';
import '../providers/document_provider.dart';
import 'document_editor_screen.dart';
import 'slide_editor_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'spreadsheet_viewer_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Controller hidup di State — dulu dibuat baru tiap build, bikin TextField
  // kehilangan fokus + controller bocor setiap rebuild.
  late final TextEditingController _promptCtrl;

  @override
  void initState() {
    super.initState();
    _promptCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 14),
              _searchBar(),
              const SizedBox(height: 12),
              _suggestionChips(),
              const SizedBox(height: 18),
              _quickActionsSection(),
              const SizedBox(height: 20),
              _featuredTemplatesSection(),
              const SizedBox(height: 18),
              _projectList(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: AppTheme.textSecondary),
            onPressed: () {},
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting(),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                const SizedBox(height: 2),
                Text('Good morning, Designer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryLight]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 10)],
            ),
            child: const Center(
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    // TextField untuk input prompt AI
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 60,
        padding: const EdgeInsets.only(left: 16, right: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _promptCtrl,
                style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'What do you want to create today?',
                  hintStyle: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                  isDense: true,
                ),
                onSubmitted: (v) => _generateWithAI(context, prompt: v),
              ),
            ),
            GestureDetector(
              onTap: () => _generateWithAI(context, prompt: _promptCtrl.text),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('Generate',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Generate dengan AI: buka editor + AI Chat panel langsung dengan prompt
  Future<void> _generateWithAI(BuildContext ctx, {String? prompt}) async {
    final provider = ctx.read<SlideProvider>();
    final title = prompt != null && prompt.isNotEmpty ? prompt : 'AI Presentation';
    final id = provider.createNewProject(title: title);
    await provider.openProject(id, title);

    // Open GenOffice workspace for this project (fire-and-forget)
    _openGenOfficeWorkspace(title);

    if (ctx.mounted) {
      Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => SlideEditorScreen(autoOpenAi: true, initialPrompt: prompt),
      ));
    }
  }

  /// Import PPT — buka file picker lalu buka editor
  void _importPPT(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('📥 Import PPTX — pilih file .pptx')),
    );
    // TODO: wire ke file picker + PptxImporter
  }

  /// Open AI Document editor — choose new or existing, then navigate
  Future<void> _openAIDocument(BuildContext ctx) async {
    final docProvider = ctx.read<DocumentProvider>();

    // Show choice dialog: New Document or Existing Document
    final choice = await showDialog<String>(
      context: ctx,
      builder: (dialogCtx) => SimpleDialog(
        title: const Text('AI Document'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogCtx, 'new'),
            child: const Row(
              children: [
                Icon(Icons.add_circle_outline, size: 20),
                SizedBox(width: 12),
                Text('Dokumen Baru'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogCtx, 'existing'),
            child: const Row(
              children: [
                Icon(Icons.folder_open, size: 20),
                SizedBox(width: 12),
                Text('Dokumen Existing'),
              ],
            ),
          ),
        ],
      ),
    );

    if (choice == null) return; // dismissed

    String documentId;

    if (choice == 'new') {
      final doc = await docProvider.createDocument(title: 'Dokumen Tanpa Judul');
      documentId = doc.id;
    } else {
      // Pick from existing documents
      final docs = docProvider.getAllDocuments();
      if (docs.isEmpty) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('⚠️ Belum ada dokumen tersimpan')),
          );
        }
        return;
      }
      final picked = await showDialog<String>(
        context: ctx,
        builder: (dialogCtx) => SimpleDialog(
          title: const Text('Pilih Dokumen'),
          children: docs.map((d) => SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogCtx, d.id),
            child: Text(d.title.isEmpty ? 'Tanpa Judul' : d.title),
          )).toList(),
        ),
      );
      if (picked == null) return;
      documentId = picked;
    }

    // Open a document workspace in GenOffice UI
    String? workspaceId;
    try {
      final api = GenOfficeClient();
      final result = await api.openDocumentWorkspace();
      if (result['ok'] == true) {
        workspaceId = result['workspaceId'] as String?;
      }
    } catch (_) {
      // Non-critical: GenOffice may not be running; Flutter still works standalone
    }

    if (ctx.mounted) {
      Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => DocumentEditorScreen(documentId: documentId, workspaceId: workspaceId),
      ));
    }
  }

  /// Open AI Excel spreadsheet viewer — pick an .xlsx file first
  /// Open AI Excel spreadsheet viewer
  void _openAIExcel(BuildContext ctx) {
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => const SpreadsheetViewerScreen(title: 'AI Excel'),
    ));
  }

  /// AI Remaster — pilih project lalu remaster dengan AI
  Future<void> _aiRemaster(BuildContext ctx) async {
    final provider = ctx.read<SlideProvider>();
    final projects = provider.getAllProjects();
    if (projects.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('⚠️ Belum ada project untuk di-remaster')));
      return;
    }
    // Tampilkan dialog pilih project
    final result = await showDialog<String>(
      context: ctx,
      builder: (dialogCtx) => SimpleDialog(
        title: const Text('Pilih Project'),
        children: projects.map((p) {
          final id = p['id'] as String;
          final title = (p['title'] as String?) ?? 'Untitled';
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogCtx, id),
            child: Row(
              children: [
                const Icon(Icons.slideshow, size: 18, color: AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(title, overflow: TextOverflow.ellipsis)),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (result == null || !ctx.mounted) return;
    // Buka project tersebut lalu remaster
    final title = projects.firstWhere((p) => p['id'] == result)['title'] as String? ?? '';
    await provider.openProject(result, title);
    if (ctx.mounted) {
      Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => const SlideEditorScreen(autoOpenAi: true, initialPrompt: 'Remaster presentasi ini dengan desain yang lebih baik'),
      ));
    }
  }

  /// Translate — pilih project lalu terjemahkan dengan AI
  Future<void> _translateSlide(BuildContext ctx) async {
    final provider = ctx.read<SlideProvider>();
    final projects = provider.getAllProjects();
    if (projects.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('⚠️ Belum ada project untuk diterjemahkan')));
      return;
    }
    final result = await showDialog<String>(
      context: ctx,
      builder: (dialogCtx) => SimpleDialog(
        title: const Text('Pilih Project'),
        children: projects.map((p) {
          final id = p['id'] as String;
          final title = (p['title'] as String?) ?? 'Untitled';
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogCtx, id),
            child: Row(
              children: [
                const Icon(Icons.translate, size: 18, color: AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(title, overflow: TextOverflow.ellipsis)),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (result == null || !ctx.mounted) return;
    final title = projects.firstWhere((p) => p['id'] == result)['title'] as String? ?? '';
    await provider.openProject(result, title);
    if (ctx.mounted) {
      Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => const SlideEditorScreen(autoOpenAi: true, initialPrompt: 'Terjemahkan presentasi ini ke bahasa Indonesia'),
      ));
    }
  }

  /// More — tampilkan menu tambahan (termasuk Templates)
  void _showMoreActions(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppTheme.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.dashboard_customize, color: AppTheme.primary),
              title: const Text('Templates'),
              subtitle: const Text('Browse all templates'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx, MaterialPageRoute(builder: (_) => const TemplatesStorageScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open, color: AppTheme.textSecondary),
              title: const Text('File Manager'),
              subtitle: const Text('Manage local files'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: AppTheme.textSecondary),
              title: const Text('Settings'),
              subtitle: const Text('App configuration'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx, MaterialPageRoute(builder: (_) => const ProfileScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _chip(Icons.lightbulb, 'Summarize notes', prompt: 'Buat presentasi 5 slide yang merangkum catatan meeting ini secara profesional'),
          const SizedBox(width: 8),
          _chip(Icons.auto_stories, 'Create pitch deck', prompt: 'Buat pitch deck 8 slide untuk startup teknologi yang menarik'),
          const SizedBox(width: 8),
          _chip(Icons.edit_note, 'Polish spec', prompt: 'Buat presentasi teknis 6 slide menjelaskan spesifikasi produk baru'),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, {String? prompt}) {
    return Expanded(
      child: GestureDetector(
      onTap: () => _generateWithAI(context, prompt: prompt),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.secondaryDark.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: AppTheme.secondaryDark),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  style: const TextStyle(fontSize: 10, color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _quickActionsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Actions',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _actionTile(Icons.upload_file, 'Import', () => _importPPT(context),
                  bg: const Color(0xFFbac3ff), iconColor: AppTheme.textPrimary),
              _actionTile(Icons.auto_fix_high, 'AI Remaster', () => _aiRemaster(context),
                  bg: const Color(0xFFcae6ff), iconColor: AppTheme.textPrimary),
              _actionTile(Icons.translate, 'Translate', () => _translateSlide(context),
                  bg: const Color(0xFFdee1ff), iconColor: AppTheme.textPrimary),
              _actionTile(Icons.auto_awesome, 'AI Doc', () => _openAIDocument(context),
                  bg: const Color(0xFFdbe1ff), iconColor: AppTheme.primary),
              _actionTile(Icons.table_chart, 'AI Excel', () => _openAIExcel(context),
                  bg: const Color(0xFFDCFCE7), iconColor: const Color(0xFF16A34A)),
              _actionTile(Icons.more_horiz, 'More', () => _showMoreActions(context),
                  bg: const Color(0xFFe1e3e4), iconColor: AppTheme.textPrimary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featuredTemplatesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Featured Templates',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              Text('See all',
                  style: TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 160,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _featuredCard('Corporate Pitch', '12 Slides · Modern', AppTheme.primary, 'POPULAR'),
                const SizedBox(width: 12),
                _featuredCard('Annual Report 2024', '8 Pages · Minimal', AppTheme.secondaryDark, null),
                const SizedBox(width: 12),
                _featuredCard('Tech Startup Deck', '15 Slides · Bold', AppTheme.tertiary, null),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _featuredCard(String title, String subtitle, Color accentColor, String? badge) {
    // Cari template preview dari registry berdasarkan nama
    final layoutData = _findLayoutData(title);
    return Container(
      width: 200,
      height: 160,
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Stack(
        children: [
          // Area preview — render template nyata atau gradient
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 100,
              width: double.infinity,
              child: ClipRect(
                child: layoutData != null
                    ? TemplateRenderer(layout: layoutData, width: 200)
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [accentColor, accentColor.withValues(alpha: 0.6)]),
                        ),
                        child: Center(
                          child: Icon(Icons.slideshow, size: 36, color: Colors.white.withValues(alpha: 0.8)),
                        ),
                      ),
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(6)),
                child: Text(badge, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          Positioned(
            bottom: 0, left: 10, right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Cari layout data berdasarkan judul yang mirip
  TemplateLayoutData? _findLayoutData(String title) {
    final allData = TemplateRegistry.instance.layoutData;
    for (final entry in allData.entries) {
      if (entry.value.name.toLowerCase().contains(title.toLowerCase()) ||
          title.toLowerCase().contains(entry.value.name.toLowerCase().split(' ').first)) {
        return entry.value;
      }
    }
    // Fallback: ambil template pertama
    if (allData.isNotEmpty) return allData.values.first;
    return null;
  }

  /// Cari layout data untuk pilihan template di dialog "Buat Baru"
  /// ('blank' → null, 'corporate' → template cover dari kategori business, dll)
  TemplateLayoutData? _findLayoutDataForTemplate(String template) {
    if (template == 'blank' || template.isEmpty) return null;
    final allData = TemplateRegistry.instance.layoutData;
    if (allData.isEmpty) return null;

    // Cari berdasarkan keyword yang cocok dengan pilihan
    const keywords = <String, List<String>>{
      'corporate': ['cover', 'corporate', 'business'],
      'creative': ['cover', 'creative', 'bold'],
      'modern': ['cover', 'modern', 'intro'],
    };
    final keys = keywords[template] ?? ['cover'];
    for (final key in keys) {
      for (final entry in allData.entries) {
        if (entry.value.name.toLowerCase().contains(key) ||
            entry.key.toLowerCase().contains(key)) {
          return entry.value;
        }
      }
    }
    // Fallback: template pertama
    return allData.values.first;
  }

  Widget _actionTile(IconData icon, String label, VoidCallback onTap, {Color? bg, Color? iconColor}) {
    // NOTE: dipakai di dalam Wrap — Wrap tidak boleh punya anak Expanded
    // (ParentDataWidget error tiap layout). Wrap lepas: ukur sendiri.
    return SizedBox(
      width: 72,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: bg ?? AppTheme.surface2,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(child: Icon(icon, size: 24, color: iconColor ?? AppTheme.primary)),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _projectList(BuildContext context) {
    // Watch provider — rebuild otomatis setelah deleteProject
    return Consumer<SlideProvider>(
      builder: (ctx, provider, _) {
    final projects = StorageService.loadProjectList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Recent Projects',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const Spacer(),
              GestureDetector(
                onTap: () => _createNewProject(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(children: [
                    Icon(Icons.add, size: 14, color: AppTheme.textOnPrimary),
                    SizedBox(width: 4),
                    Text('Buat Baru', style: TextStyle(fontSize: 11, color: AppTheme.textOnPrimary, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (projects.isEmpty)
            _emptyState(context)
          else
            ...projects.map((p) => _projectCard(context, p)),
        ],
      ),
    );
      },
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppTheme.surface3,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.outline),
            ),
            child: const Icon(Icons.slideshow_outlined, size: 32, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          const Text('Belum ada presentasi',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          const Text('Tap "Buat Baru" untuk mulai',
              style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _projectCard(BuildContext ctx, Map<String, dynamic> project) {
    final id = project['id'] as String;
    final title = (project['title'] as String?) ?? 'Presentasi';
    final slideCount = (project['slideCount'] as int?) ?? 0;
    final updatedAt = project['updatedAt'] as String?;
    final created = project['createdAt'] as String?;
    final dateStr = updatedAt ?? created ?? '';

    // Load slide pertama untuk thumbnail
    final firstSlide = StorageService.loadSlidesForProject(id).firstOrNull;

    return GestureDetector(
      onTap: () => _openProject(ctx, id, title),
      onLongPress: () => _projectActions(ctx, id, title),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            // Thumbnail slide pertama (template widget atau gradient icon)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 44,
                child: firstSlide != null && TemplateWidgetRegistry.has(firstSlide.layoutId)
                    ? TemplateWidgetRegistry.build(firstSlide.layoutId, firstSlide.templateData)
                    : Container(
                        width: 64,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: firstSlide != null
                                ? AppTheme.gradientFor(firstSlide.backgroundGradient)
                                : const [AppTheme.primary, AppTheme.primaryLight],
                          ),
                        ),
                        child: const Center(child: Icon(Icons.slideshow, color: Colors.white70, size: 20)),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('$slideCount slide',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
            ),
            // Tombol menu ⋯ — buka aksi (hapus proyek)
            IconButton(
              icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.textMuted),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => _projectActions(ctx, id, title),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _createNewProject(BuildContext context) async {
    final nameCtrl = TextEditingController();
    String? selectedTemplate;

    // Show dialog with name input + template picker
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Buat Presentasi Baru', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nama', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Contoh: Strategi Marketing 2026',
                    hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.6)),
                    filled: true, fillColor: AppTheme.surface3,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Template', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _templateOption(ctx, 'blank', 'Blank', Icons.grid_off, selectedTemplate == 'blank', setDialogState, (v) => selectedTemplate = v),
                    const SizedBox(width: 6),
                    _templateOption(ctx, 'corporate', 'Corporate', Icons.business, selectedTemplate == 'corporate', setDialogState, (v) => selectedTemplate = v),
                    const SizedBox(width: 6),
                    _templateOption(ctx, 'creative', 'Kreatif', Icons.palette, selectedTemplate == 'creative', setDialogState, (v) => selectedTemplate = v),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, {'name': nameCtrl.text.trim(), 'template': selectedTemplate ?? 'blank'}),
                child: const Text('Buat', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    if (result == null || !context.mounted) return;
    final name = result['name'] ?? '';
    final template = result['template'] ?? 'blank';
    final provider = context.read<SlideProvider>();
    final id = provider.createNewProject(title: name.isEmpty ? 'Presentasi Baru' : name);
    await provider.openProject(id, name.isEmpty ? 'Presentasi Baru' : name);

    // Open GenOffice workspace for this project (fire-and-forget)
    _openGenOfficeWorkspace(name.isEmpty ? 'Presentasi Baru' : name);

    // Intro template (Flutter-native) sudah di-apply oleh initWithHtmlTemplate()
    // melalui openProject → initFromStorage. Tidak perlu override dari sini.

    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SlideEditorScreen(autoOpenAi: true)));
    }
  }

  /// Open GenOffice workspace when creating a new project (fire-and-forget)
  void _openGenOfficeWorkspace(String topic) {
    final client = GenOfficeClient();
    client.healthCheck().then((healthy) {
      if (!healthy) return;
      final projectId = 'docucraft-${DateTime.now().millisecondsSinceEpoch}';
      client.initProject(projectId: projectId, topic: topic).then((_) {
        client.openWorkspace(projectId: projectId).then((wsResult) {
          final wsId = wsResult['workspaceId'] as String?;
          final tabId = wsResult['tabId'] as String?;
          debugPrint('🖥️ [Dashboard] GenOffice tab opened: $tabId (workspace: $wsId)');
        });
      });
    }).catchError((e) {
      debugPrint('🖥️ [Dashboard] GenOffice not available: $e');
    });
  }

  Widget _templateOption(BuildContext ctx, String id, String label, IconData icon, bool isActive, StateSetter setDialogState, Function(String) onTap) {
    return GestureDetector(
      onTap: () => setDialogState(() => onTap(id)),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary.withAlpha(20) : AppTheme.surface3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppTheme.primary : Colors.white.withAlpha(15),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isActive ? AppTheme.primary : AppTheme.textMuted),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: isActive ? AppTheme.primary : AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  Future<void> _openProject(BuildContext ctx, String id, String title) async {
    final provider = ctx.read<SlideProvider>();
    await provider.openProject(id, title);
    if (ctx.mounted) {
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => const SlideEditorScreen()));
    }
  }

  Future<void> _projectActions(BuildContext ctx, String id, String title) async {
    final action = await showModalBottomSheet<String>(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: AppTheme.outline, borderRadius: BorderRadius.circular(2)))),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppTheme.error),
            title: const Text('Hapus Proyek', style: TextStyle(color: AppTheme.error, fontSize: 13)),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
          ListTile(
            leading: const Icon(Icons.close, color: AppTheme.textMuted),
            title: const Text('Batal', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
            onTap: () => Navigator.pop(ctx),
          ),
        ]),
      ),
    );

    if (action == 'delete' && ctx.mounted) {
      final confirmed = await showDialog<bool>(
        context: ctx,
        builder: (dctx) => AlertDialog(
          backgroundColor: AppTheme.surface2,
          title: const Text('Hapus proyek?', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          content: Text('"$title" akan dihapus permanen.', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary))),
            TextButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('Hapus', style: TextStyle(color: AppTheme.error))),
          ],
        ),
      );
      if (confirmed == true && ctx.mounted) {
        await ctx.read<SlideProvider>().deleteProject(id);
      }
    }
  }

  String _timeAgoFrom(String iso) {
    if (iso.isEmpty) return 'baru saja';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'baru saja';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${diff.inDays ~/ 7} minggu lalu';
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat pagi';
    if (hour < 17) return 'Selamat siang';
    return 'Selamat malam';
  }
}
