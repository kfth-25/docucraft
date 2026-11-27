// DocuCraft — Editor Slide Actions
// Diekstrak dari slide_editor_screen.dart demi modularitas

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/slide.dart';
import '../../providers/slide_provider.dart';
import '../../widgets/presentation_mode.dart';
import '../../themes/app_theme.dart';

class EditorSlideActions extends StatelessWidget {
  final SlideProvider provider;
  final TextEditingController notesCtrl;
  final int lastNotesSlideIndex;
  final ValueChanged<int> onSlideChanged;
  final VoidCallback onAddSlide;
  final VoidCallback onDuplicateSlide;
  final VoidCallback onDeleteSlide;
  final VoidCallback onToggleHideSlide;
  final VoidCallback onPresent;

  const EditorSlideActions({
    super.key,
    required this.provider,
    required this.notesCtrl,
    required this.lastNotesSlideIndex,
    required this.onSlideChanged,
    required this.onAddSlide,
    required this.onDuplicateSlide,
    required this.onDeleteSlide,
    required this.onToggleHideSlide,
    required this.onPresent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // Presenter notes input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface3,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Text('📝', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Expanded(
                  child: _NotesField(
                    provider: provider,
                    notesCtrl: notesCtrl,
                    lastSlideIndex: lastNotesSlideIndex,
                    onSlideChanged: onSlideChanged,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _actionBtn(Icons.add, 'Slide Baru', onAddSlide),
                const SizedBox(width: 8),
                _actionBtn(Icons.copy, 'Duplikat', onDuplicateSlide),
                const SizedBox(width: 8),
                _actionBtn(Icons.delete_outline, 'Hapus', onDeleteSlide),
                const SizedBox(width: 8),
                _actionBtn(
                  provider.currentSlide?.hidden == true ? Icons.visibility : Icons.visibility_off,
                  provider.currentSlide?.hidden == true ? 'Tampil' : 'Sembunyi',
                  onToggleHideSlide,
                ),
                const SizedBox(width: 8),
                _actionBtn(Icons.slideshow, 'Present', onPresent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// Presenter Notes Field (StatefulWidget — persistent controller, no cursor jump)
class _NotesField extends StatefulWidget {
  final SlideProvider provider;
  final TextEditingController notesCtrl;
  final int lastSlideIndex;
  final ValueChanged<int> onSlideChanged;

  const _NotesField({
    required this.provider,
    required this.notesCtrl,
    required this.lastSlideIndex,
    required this.onSlideChanged,
  });

  @override
  State<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends State<_NotesField> {
  @override
  void initState() {
    super.initState();
    widget.notesCtrl.text = widget.provider.getPresenterNotes() ?? '';
    widget.onSlideChanged(widget.provider.currentSlideIndex);
  }

  @override
  void didUpdateWidget(_NotesField old) {
    super.didUpdateWidget(old);
    if (widget.provider.currentSlideIndex != widget.lastSlideIndex) {
      widget.notesCtrl.text = widget.provider.getPresenterNotes() ?? '';
      widget.onSlideChanged(widget.provider.currentSlideIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.notesCtrl,
      onChanged: (v) => widget.provider.setPresenterNotes(v),
      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
      decoration: const InputDecoration(
        border: InputBorder.none, isDense: true,
        hintText: 'Catatan presenter per slide...',
        hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 10),
      ),
    );
  }
}