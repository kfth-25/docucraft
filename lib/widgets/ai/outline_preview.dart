// DocuCraft Flutter — Outline Preview Widget (Sprint 12)
//
// Ditampilkan ketika AI run berada di state `RunAwaitingOutlineReview`. User
// bisa mengedit judul + brief tiap halaman sebelum generate dimulai.
// Confirm → memanggil onConfirm(editedPages). Cancel → memanggil onCancel().

import 'package:flutter/material.dart';
import '../../ai/run_state_machine.dart';

class OutlinePreview extends StatefulWidget {
  final String topic;
  final List<OutlinePage> pages;
  final void Function(List<OutlinePage> pages) onConfirm;
  final VoidCallback onCancel;

  const OutlinePreview({
    super.key,
    required this.topic,
    required this.pages,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<OutlinePreview> createState() => _OutlinePreviewState();
}

class _OutlinePreviewState extends State<OutlinePreview> {
  late List<_PageEdit> _edits;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _edits = widget.pages.map((p) => _PageEdit(page: p)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt_outlined, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Review outline',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.topic,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _edits.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final e = _edits[i];
                  return _PageRow(
                    index: e.page.index,
                    title: e.title,
                    brief: e.brief,
                    onTitleChanged: (v) => setState(() => e.title = v),
                    onBriefChanged: (v) => setState(() => e.brief = v),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _confirming ? null : widget.onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _confirming ? null : _confirm,
                  child: _confirming
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Generate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirm() {
    setState(() => _confirming = true);
    final pages = _edits
        .map((e) => e.page.copyWith(title: e.title.trim(), brief: e.brief.trim()))
        .toList();
    widget.onConfirm(pages);
  }
}

class _PageEdit {
  final OutlinePage page;
  String title;
  String brief;
  _PageEdit({required this.page})
      : title = page.title,
        brief = page.brief;
}

class _PageRow extends StatelessWidget {
  final int index;
  final String title;
  final String brief;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onBriefChanged;
  const _PageRow({
    required this.index,
    required this.title,
    required this.brief,
    required this.onTitleChanged,
    required this.onBriefChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 6, right: 8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: TextEditingController(text: title)
                    ..selection = TextSelection.collapsed(offset: title.length),
                  onChanged: onTitleChanged,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Page title',
                  ),
                ),
                const SizedBox(height: 2),
                TextField(
                  controller: TextEditingController(text: brief)
                    ..selection = TextSelection.collapsed(offset: brief.length),
                  onChanged: onBriefChanged,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Brief',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
