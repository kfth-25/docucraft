// DocuCraft — Template Browser
// Menjelajah dan memilih dari 231+ template yang diorganisir per kategori

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/template_registry.dart';
import '../models/slide.dart';
import '../providers/slide_provider.dart';
import '../services/template_converter.dart';
import '../services/template_widget_registry.dart';
import '../themes/app_theme.dart';
import '../widgets/html_template_preview.dart';

class TemplateBrowser extends StatelessWidget {
  const TemplateBrowser({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => const TemplateBrowser(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = TemplateRegistry.instance.groups;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        // Handle
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppTheme.outline, borderRadius: BorderRadius.circular(2))),
        ),
        const SizedBox(height: 12),
        const Text('Templates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        Text('${groups.length} categories • ${TemplateRegistry.instance.groups.expand((g) => g.layouts).length} layouts',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        const SizedBox(height: 12),

        // Template categories
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: groups.length,
          itemBuilder: (ctx, i) => _CategoryTile(group: groups[i]),
        )),
        const SizedBox(height: 16),
      ]),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final TemplateGroup group;
  const _CategoryTile({required this.group});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(group.label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text('${group.layouts.length} layouts', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        trailing: Icon(Icons.expand_more, color: AppTheme.textMuted),
        children: group.layouts.map((layout) => _TemplateTile(layout: layout)).toList(),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  final TemplateLayout layout;
  const _TemplateTile({required this.layout});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => _TemplateDetailPage(layout: layout),
        ));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(children: [
          Container(width: 4, height: 36,
            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(layout.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(layout.description, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          )),
          Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
        ]),
      ),
    );
  }
}

// ══ TEMPLATE DETAIL — EDIT WITH AI ══
class _TemplateDetailPage extends StatefulWidget {
  final TemplateLayout layout;
  const _TemplateDetailPage({required this.layout});
  @override
  State<_TemplateDetailPage> createState() => _TemplateDetailPageState();
}

class _TemplateDetailPageState extends State<_TemplateDetailPage> {
  late Map<String, dynamic> _data;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _data = Map.from(widget.layout.sampleData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface2,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary), onPressed: () => Navigator.pop(context)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.layout.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          Text(widget.layout.description, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ]),
        actions: [
          GestureDetector(
            onTap: _useTemplate,
            child: Container(
              margin: const EdgeInsets.only(right: 16, top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8)),
              child: const Text('Use Template', style: TextStyle(color: AppTheme.textOnPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Preview mockup
          _buildPreview(),

          const SizedBox(height: 20),
          const Text('Template Fields', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),

          // Editable fields
          ...widget.layout.fields.map((field) => _buildField(field)),

          const SizedBox(height: 20),

          // AI Generate Button
          GestureDetector(
            onTap: _isGenerating ? null : _generateContent,
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: _isGenerating ? null : const LinearGradient(colors: [AppTheme.primary, AppTheme.secondary]),
                color: _isGenerating ? AppTheme.surface3 : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (_isGenerating) ...[
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2)),
                  const SizedBox(width: 8),
                ] else ...[
                  Icon(Icons.auto_awesome, color: AppTheme.textOnPrimary, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(_isGenerating ? 'Generating...' : 'AI Generate Content',
                    style: const TextStyle(color: AppTheme.textOnPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),

          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _buildPreview() {
    // HTML preview (web) — 1:1 dengan Presenton
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: HtmlTemplatePreview(
          layout: widget.layout,
          width: MediaQuery.of(context).size.width - 32,
          height: 180,
        ),
      ),
    );
  }

  Widget _buildField(SchemaField field) {
    final currentValue = _data[field.name] ?? field.defaultValue ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(field.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
        const SizedBox(height: 6),
        TextField(
          controller: TextEditingController(text: '$currentValue'),
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Enter ${field.name}...', hintStyle: const TextStyle(color: AppTheme.textMuted),
            filled: true, fillColor: AppTheme.surface3,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.primary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: (v) => _data[field.name] = v,
        ),
        if (field.description != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(field.description!, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ),
      ]),
    );
  }

  void _useTemplate() {
    final provider = context.read<SlideProvider>();
    // Ambil layout data dari registry (dari JSON assets)
    final layoutData = TemplateRegistry.instance.layoutData[widget.layout.layoutId];

    // Model Presenton: layoutId + templateData → widget render template penuh
    final slide = Slide(
      title: _data['title'] ?? widget.layout.name,
      subtitle: _data['subtitle'] ?? widget.layout.description,
      backgroundGradient: layoutData != null
          ? TemplateConverter.fromLayoutData(layoutData).backgroundGradient
          : 'indigo',
      layoutId: widget.layout.layoutId,
      templateData: {
        'title': _data['title'] ?? widget.layout.name,
        'paragraph': _data['subtitle'] ?? widget.layout.description,
      },
      templateId: widget.layout.layoutId,
    );

    // Fallback: kalau layoutId belum ada widget di registry → parse elements
    if (layoutData != null && !TemplateWidgetRegistry.has(widget.layout.layoutId)) {
      final result = TemplateConverter.fromLayoutData(layoutData);
      slide.elements.addAll(result.elements);
    }

    provider.addNewSlide(slide, null);
    // Note: saveToStorage() not available on SlideProvider, persistence is handled internally
    Navigator.pop(context);
  }

  void _generateContent() async {
    setState(() => _isGenerating = true);
    // Simulate AI content generation
    await Future.delayed(const Duration(seconds: 2));
    // In real implementation: POST to AI endpoint with schema
    // For now: fill with random realistic content
    _data = {
      'title': '${widget.layout.name} - Generated',
      'subtitle': 'AI-generated content for ${widget.layout.name}',
    };
    setState(() => _isGenerating = false);
  }
}
