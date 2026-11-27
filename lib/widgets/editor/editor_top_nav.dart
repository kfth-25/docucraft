// DocuCraft — Editor Top Navigation Bar
// Diekstrak dari slide_editor_screen.dart demi modularitas

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/slide_provider.dart';
import '../../models/slide.dart';
import '../../services/web_download_selector.dart';
import '../../themes/app_theme.dart';
import '../../main.dart'; // CollabManager
import '../../widgets/search_panel.dart';
import '../../widgets/color_picker_dialog.dart';
import '../../widgets/text_editor_bottom_sheet.dart';

class EditorTopNav extends StatelessWidget {
  final Slide slide;
  final SlideProvider provider;
  final TextEditingController titleController;
  final String? selectedElementId;
  final VoidCallback onBackPressed;
  final VoidCallback onSharePressed;
  final VoidCallback onExportPressed;
  final VoidCallback onSearchPressed;
  final VoidCallback? onEditTextPressed;

  const EditorTopNav({
    super.key,
    required this.slide,
    required this.provider,
    required this.titleController,
    required this.selectedElementId,
    required this.onBackPressed,
    required this.onSharePressed,
    required this.onExportPressed,
    required this.onSearchPressed,
    this.onEditTextPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18, color: AppTheme.textSecondary),
            onPressed: onBackPressed,
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.success.withAlpha(38),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 6, color: AppTheme.success),
                SizedBox(width: 4),
                Text('OK', style: TextStyle(fontSize: 10, color: AppTheme.success)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: titleController,
              onChanged: (v) => provider.updateSlideTitle(v),
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Judul',
                hintStyle: TextStyle(color: AppTheme.textMuted),
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
                isDense: true,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.undo, size: 18, color: provider.canUndo ? AppTheme.textSecondary : AppTheme.textMuted.withAlpha(80)),
            onPressed: provider.canUndo ? () => provider.undo() : null,
          ),
          IconButton(
            icon: Icon(Icons.redo, size: 18, color: provider.canRedo ? AppTheme.textSecondary : AppTheme.textMuted.withAlpha(80)),
            onPressed: provider.canRedo ? () => provider.redo() : null,
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 18, color: AppTheme.textSecondary),
            onPressed: onSearchPressed,
          ),
          IconButton(
            icon: const Icon(Icons.share, size: 18, color: AppTheme.textSecondary),
            onPressed: onSharePressed,
          ),
          IconButton(
            icon: const Icon(Icons.download, size: 18, color: AppTheme.primary),
            onPressed: onExportPressed,
          ),
          if (selectedElementId != null)
            IconButton(
              icon: const Icon(Icons.edit_note, size: 18, color: AppTheme.primary),
              tooltip: 'Edit teks',
              onPressed: onEditTextPressed,
            ),
        ].map((w) => Flexible(child: w)).toList(),
      ),
    );
  }
}