// DocuCraft — Outline Panel
// Langkah 1 alur presentasi AI: user memasukkan topik → AI membuat outline
// User menyetujui/menolak item → item yang disetujui menjadi slide

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_generation_adapter.dart';
import '../services/ai_generation.dart';
import '../providers/slide_provider.dart';
import '../themes/app_theme.dart';

class OutlinePanel extends StatefulWidget {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const OutlinePanel(),
    );
  }

  const OutlinePanel({super.key});

  @override
  State<OutlinePanel> createState() => _OutlinePanelState();
}

class _OutlinePanelState extends State<OutlinePanel> {
  final TextEditingController _topicCtrl = TextEditingController();
  List<_OutlineItem> _items = [];
  bool _isGeneratingOutline = false;
  bool _isGeneratingSlides = false;

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateOutline() async {
    final topic = _topicCtrl.text.trim();
    if (topic.isEmpty) return;
    setState(() {
      _isGeneratingOutline = true;
      _items = [];
    });

    final titles = await AiGenerationService.generateOutline(topic);
    if (mounted) {
      setState(() {
        _isGeneratingOutline = false;
        _items = titles.map((t) => _OutlineItem(title: t, approved: true)).toList();
      });
    }
  }

  Future<void> _generateSlides() async {
    final approved = _items.where((item) => item.approved).toList();
    if (approved.isEmpty) return;

    setState(() => _isGeneratingSlides = true);
    final provider = context.read<SlideProvider>();

    for (var i = 0; i < approved.length; i++) {
      final result = await AiGenerationService.generateSingleSlide(approved[i].title);
      if (result.success && mounted) {
        AiGenerationAdapter.applySlideResult(provider.currentSlide!, result);
      }
    }

    if (mounted) {
      setState(() => _isGeneratingSlides = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ ${approved.length} slide berhasil di-generate'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(2)))),
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withAlpha(12)))),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 10),
                    const Text('Buat Presentasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const Spacer(),
                    const Text('Step 1/2', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                    const SizedBox(width: 8),
                    GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              // Topic input
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _topicCtrl,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Topik presentasi...',
                          hintStyle: TextStyle(color: AppTheme.textMuted),
                          filled: true, fillColor: AppTheme.surface3,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onSubmitted: (_) => _generateOutline(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _isGeneratingOutline ? null : _generateOutline,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: _topicCtrl.text.trim().isEmpty ? AppTheme.surface3 : AppTheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _isGeneratingOutline
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Generate', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              // Outline list
              Expanded(
                child: _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lightbulb_outline, size: 40, color: AppTheme.textMuted.withAlpha(60)),
                          const SizedBox(height: 12),
                          Text('Masukkan topik, lalu tap Generate', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          Text('AI akan membuat outline slide untukmu', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: _items[i].approved ? AppTheme.surface3 : AppTheme.surface3.withAlpha(60),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _items[i].approved ? AppTheme.primary.withAlpha(40) : Colors.white.withAlpha(8),
                          ),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _items[i].approved = !_items[i].approved),
                              child: Container(
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  color: _items[i].approved ? AppTheme.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _items[i].approved ? Colors.transparent : Colors.white24),
                                ),
                                child: _items[i].approved
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${i + 1}. ${_items[i].title}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _items[i].approved ? AppTheme.textPrimary : AppTheme.textMuted,
                                  fontWeight: _items[i].approved ? FontWeight.w500 : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ),
              // Generate slides button
              if (_items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: _isGeneratingSlides ? null : _generateSlides,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFFA855F7)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: _isGeneratingSlides
                          ? const Row(mainAxisSize: MainAxisSize.min, children: [
                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                              SizedBox(width: 8),
                              Text('Mengenerate slide...', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            ])
                          : Text(
                              'Generate ${_items.where((i) => i.approved).length} Slide',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _OutlineItem {
  final String title;
  bool approved;
  _OutlineItem({required this.title, this.approved = true});
}
