// DocuCraft — OutlinePreview (Preview Outline yang Bisa Diedit)
// UI review outline yang muncul saat AI selesai menyusun rencana.
// User bisa mengedit judul/brief halaman, mengurutkan, menambah/menghapus
// halaman sebelum konfirmasi generate. Meniru `<OutlinePreview />` di GenOffice.

/// DocuCraft Flutter — OutlinePreview widget
///
/// Editable outline review UI shown when the AI completes planning.
/// Users can edit page titles/briefs, reorder, or add/remove pages
/// before confirming generation. Mirrors GenOffice's `<OutlinePreview />`.

import 'package:flutter/material.dart';
import '../ai/run_state_machine.dart';
import '../themes/app_theme.dart';

/// Result from outline review
class OutlineReviewResult {
  final List<OutlinePage> pages;
  final bool cancelled;
  const OutlineReviewResult({required this.pages, this.cancelled = false});
}

class OutlinePreview extends StatefulWidget {
  final List<OutlinePage> initialPages;
  final String topic;
  final String? planSummary;
  final ValueChanged<OutlineReviewResult> onConfirmed;
  final VoidCallback onCancelled;

  const OutlinePreview({
    super.key,
    required this.initialPages,
    required this.topic,
    this.planSummary,
    required this.onConfirmed,
    required this.onCancelled,
  });

  @override
  State<OutlinePreview> createState() => _OutlinePreviewState();
}

class _OutlinePreviewState extends State<OutlinePreview> {
  late List<_EditablePage> _pages;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _pages = widget.initialPages
        .map((p) => _EditablePage(
              index: p.index,
              titleController: TextEditingController(text: p.title),
              briefController: TextEditingController(text: p.brief),
            ))
        .toList();
  }

  @override
  void dispose() {
    for (final p in _pages) {
      p.titleController.dispose();
      p.briefController.dispose();
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _addPage() {
    setState(() {
      final newIdx = _pages.length + 1;
      _pages.add(_EditablePage(
        index: newIdx,
        titleController: TextEditingController(text: 'New Slide'),
        briefController: TextEditingController(text: ''),
      ));
    });
  }

  void _removePage(int index) {
    if (_pages.length <= 2) return; // Minimum 2 pages
    setState(() {
      _pages.removeAt(index);
      // Re-index
      for (int i = 0; i < _pages.length; i++) {
        _pages[i].index = i + 1;
      }
    });
  }

  void _movePage(int oldIndex, int newIndex) {
    setState(() {
      final item = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, item);
      // Re-index
      for (int i = 0; i < _pages.length; i++) {
        _pages[i].index = i + 1;
      }
    });
  }

  void _confirm() {
    final result = _pages
        .map((p) => OutlinePage(
              index: p.index,
              title: p.titleController.text.trim(),
              brief: p.briefController.text.trim(),
            ))
        .toList();
    widget.onConfirmed(OutlineReviewResult(pages: result));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.textMuted.withAlpha(40), width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(20),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.list_alt, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Outline — ${widget.topic}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '${_pages.length} slides',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),

          // Plan summary (if provided)
          if (widget.planSummary != null && widget.planSummary!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface2,
                border: Border(bottom: BorderSide(color: AppTheme.textMuted.withAlpha(40), width: 1)),
              ),
              child: Text(
                widget.planSummary!,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Pages list
          Flexible(
            child: ReorderableListView.builder(
              scrollController: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: _pages.length,
              onReorderItem: (oldIndex, newIndex) {
                _movePage(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final page = _pages[index];
                return _OutlinePageCard(
                  key: ValueKey('page_$index'),
                  page: page,
                  canRemove: _pages.length > 2,
                  onRemove: () => _removePage(index),
                );
              },
            ),
          ),

          // Add page button
          TextButton.icon(
            onPressed: _addPage,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Page'),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.textMuted.withAlpha(40), width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancelled,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _confirm,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Generate Deck'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditablePage {
  int index;
  final TextEditingController titleController;
  final TextEditingController briefController;

  _EditablePage({
    required this.index,
    required this.titleController,
    required this.briefController,
  });
}

class _OutlinePageCard extends StatelessWidget {
  final _EditablePage page;
  final bool canRemove;
  final VoidCallback onRemove;

  const _OutlinePageCard({
    super.key,
    required this.page,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      color: AppTheme.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppTheme.textMuted.withAlpha(40), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Icon(Icons.drag_handle, size: 16, color: AppTheme.textMuted),

            // Page number badge
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                '${page.index}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),

            // Title + Brief fields
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: page.titleController,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Slide title',
                      hintStyle: TextStyle(color: AppTheme.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 2),
                  TextField(
                    controller: page.briefController,
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    decoration: InputDecoration(
                      hintText: 'Brief description',
                      hintStyle: TextStyle(color: AppTheme.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),

            // Remove button
            if (canRemove)
              IconButton(
                icon: Icon(Icons.close, size: 14, color: AppTheme.textMuted),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
          ],
        ),
      ),
    );
  }
}
