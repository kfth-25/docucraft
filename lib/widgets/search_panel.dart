// DocuCraft — Search & Replace Panel

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/slide_provider.dart';
import '../themes/app_theme.dart';

class SearchPanel extends StatefulWidget {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const SearchPanel(),
    );
  }

  const SearchPanel({super.key});

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _replaceCtrl = TextEditingController();
  int _matchCount = 0;
  List<_SearchResult> _results = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _replaceCtrl.dispose();
    super.dispose();
  }

  void _search() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() { _results = []; _matchCount = 0; });
      return;
    }
    final provider = context.read<SlideProvider>();
    final results = <_SearchResult>[];
    for (var si = 0; si < provider.slides.length; si++) {
      final slide = provider.slides[si];
      if (slide.hidden) continue;
      if (slide.title.toLowerCase().contains(q)) {
        results.add(_SearchResult(slideIndex: si, field: 'Judul', text: slide.title));
      }
      if (slide.subtitle.toLowerCase().contains(q)) {
        results.add(_SearchResult(slideIndex: si, field: 'Subtitle', text: slide.subtitle));
      }
      for (final el in slide.elements) {
        if (el.content != null && el.content!.toLowerCase().contains(q)) {
          results.add(_SearchResult(slideIndex: si, field: el.type.name, text: el.content!));
        }
      }
    }
    setState(() { _results = results; _matchCount = results.length; });
  }

  void _replaceOne() {
    final q = _searchCtrl.text.trim();
    final r = _replaceCtrl.text.trim();
    if (q.isEmpty || _results.isEmpty) return;
    final first = _results.first;
    final provider = context.read<SlideProvider>();
    final slide = provider.slides[first.slideIndex];
    provider.captureUndo();
    if (first.field == 'Judul') slide.title = slide.title.replaceFirst(q, r);
    else if (first.field == 'Subtitle') slide.subtitle = slide.subtitle.replaceFirst(q, r);
    else {
      for (final el in slide.elements) {
        if (el.content != null && el.content!.contains(q)) {
          el.content = el.content!.replaceFirst(q, r);
          el.richRuns = null;
          break;
        }
      }
    }
    provider.notify();
    _search();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🔁 1 item diganti'), behavior: SnackBarBehavior.floating),
    );
  }

  void _replaceAll() {
    final q = _searchCtrl.text.trim();
    final r = _replaceCtrl.text.trim();
    if (q.isEmpty) return;
    final provider = context.read<SlideProvider>();
    int count = 0;
    for (final slide in provider.slides) {
      if (slide.hidden) continue;
      if (slide.title.contains(q)) { slide.title = slide.title.replaceAll(q, r); count++; }
      if (slide.subtitle.contains(q)) { slide.subtitle = slide.subtitle.replaceAll(q, r); count++; }
      for (final el in slide.elements) {
        if (el.content != null && el.content!.contains(q)) {
          el.content = el.content!.replaceAll(q, r);
          el.richRuns = null;
          count++;
        }
      }
    }
    provider.notify();
    _search();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🔁 $count item diganti'), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppTheme.outline, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.search, size: 18, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            const Text('Search & Replace', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const Spacer(),
            Text('$_matchCount hasil', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            const SizedBox(width: 8),
            GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => _search(),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Cari teks di semua slide...',
              hintStyle: const TextStyle(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textMuted),
              filled: true, fillColor: AppTheme.surface3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replaceCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Ganti dengan...',
                    hintStyle: const TextStyle(color: AppTheme.textMuted),
                    filled: true, fillColor: AppTheme.surface3,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _replaceOne,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
                  child: const Text('Ganti', style: TextStyle(color: AppTheme.textOnPrimary, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _replaceAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(color: AppTheme.success, borderRadius: BorderRadius.circular(10)),
                  child: const Text('Semua', style: TextStyle(color: AppTheme.textOnPrimary, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(_searchCtrl.text.isEmpty ? 'Ketik kata kunci untuk mencari' : 'Tidak ditemukan',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length.clamp(0, 10),
                separatorBuilder: (_, __) => const Divider(height: 4, color: Colors.transparent),
                itemBuilder: (ctx, i) {
                  final r = _results[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppTheme.surface3, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: AppTheme.primary.withAlpha(30), borderRadius: BorderRadius.circular(3)),
                          child: Text('Slide ${r.slideIndex + 1}', style: TextStyle(fontSize: 8, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 4),
                        Text(': ${r.text.length > 24 ? '${r.text.substring(0, 24)}...' : r.text}',
                            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchResult {
  final int slideIndex;
  final String field;
  final String text;
  _SearchResult({required this.slideIndex, required this.field, required this.text});
}
