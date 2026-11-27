// DocuCraft — Version History Panel (dengan timestamp)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/slide_provider.dart';
import '../themes/app_theme.dart';

class VersionHistoryPanel extends StatelessWidget {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VersionHistoryPanel(),
    );
  }

  const VersionHistoryPanel({super.key});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    return '${diff.inDays}h lalu';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Consumer<SlideProvider>(
        builder: (ctx, provider, _) {
          final canUndo = provider.canUndo;
          final canRedo = provider.canRedo;
          final undoTimestamps = provider.undoTimestamps;
          final redoTimestamps = provider.redoTimestamps;
          final undoCount = provider.undoCount;
          final redoCount = provider.redoCount;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.history, size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                const Text('Riwayat Versi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const Spacer(),
                GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary)),
              ]),
              const SizedBox(height: 4),
              const Text('Snapshot otomatis setiap perubahan', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              // Current version
              _versionCard('Versi Saat Ini', true, null, null),
              const SizedBox(height: 6),
              // Undo history list (up to 5 entries)
              if (undoCount > 0)
                ...List.generate(
                  undoCount > 5 ? 5 : undoCount,
                  (i) {
                    final idx = undoCount - 1 - i;
                    final ts = idx < undoTimestamps.length ? undoTimestamps[idx] : null;
                    final label = ts != null ? '${undoCount - i}. ${_timeAgo(ts)}' : '${undoCount - i}';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _versionCard(label, false, Icons.undo, () {
                        // Undo back to this version by popping stack
                        while (provider.canUndo && provider.undoCount > idx) {
                          provider.undo();
                        }
                        Navigator.pop(context);
                      }),
                    );
                  },
                ),
              if (undoCount > 5)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('...dan ${undoCount - 5} lagi', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ),
              // Redo history
              if (redoCount > 0)
                ...List.generate(
                  redoCount > 3 ? 3 : redoCount,
                  (i) {
                    final ts = i < redoTimestamps.length ? redoTimestamps[i] : null;
                    final label = ts != null ? 'Setelahnya ${_timeAgo(ts)}' : 'Setelahnya';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _versionCard(label, false, Icons.redo, () {
                        provider.redo();
                        Navigator.pop(context);
                      }),
                    );
                  },
                ),
              if (!canUndo && !canRedo)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('Belum ada riwayat versi', style: TextStyle(color: AppTheme.textMuted, fontSize: 11))),
                ),
              const SizedBox(height: 12),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: canUndo ? () { provider.undo(); Navigator.pop(context); } : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: canUndo ? AppTheme.primary : AppTheme.surface3,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text('Restore Versi Sebelumnya',
                              style: TextStyle(color: canUndo ? Colors.white : AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _versionCard(String title, bool isCurrent, IconData? icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrent ? AppTheme.primary.withAlpha(20) : AppTheme.surface3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isCurrent ? AppTheme.primary.withAlpha(30) : Colors.white.withAlpha(8)),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: isCurrent ? AppTheme.primary : AppTheme.textPrimary)),
            ),
            if (isCurrent) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(4)),
                child: const Text('Saat ini', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
