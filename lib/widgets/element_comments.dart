// DocuCraft — Element Comments (long-press → input komentar mengambang)
// Floating comment input di atas element + badge hijau untuk element yang sudah dikomen

import 'package:flutter/material.dart';
import '../themes/app_theme.dart';

class ElementCommentBadge extends StatelessWidget {
  final int commentCount;
  const ElementCommentBadge({super.key, required this.commentCount});

  @override
  Widget build(BuildContext context) {
    if (commentCount == 0) return const SizedBox.shrink();
    return Positioned(
      top: -6,
      left: -6,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: AppTheme.success,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(color: AppTheme.success.withValues(alpha: 0.5), blurRadius: 4),
          ],
        ),
        child: Center(
          child: Text(
            '$commentCount',
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class FloatingCommentInput extends StatelessWidget {
  final String elementId;
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  /// Optional AI Sketch-to-Design action — shown as a button beside "Batal"
  final VoidCallback? onAISketch;

  const FloatingCommentInput({
    super.key,
    required this.elementId,
    required this.controller,
    required this.onSend,
    required this.onCancel,
    this.onAISketch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withAlpha(50)),
        boxShadow: [
          BoxShadow(color: AppTheme.success.withValues(alpha: 0.15), blurRadius: 12),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.comment, size: 14, color: AppTheme.success),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Komentar di elemen...',
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withAlpha(20)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withAlpha(20)),
                    ),
                    filled: true,
                    fillColor: AppTheme.surface3,
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // AI Sketch-to-Design button (only shown if onAISketch provided)
              if (onAISketch != null)
                GestureDetector(
                  onTap: onAISketch,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppTheme.primary, const Color(0xFFA855F7)]),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(children: [
                      Icon(Icons.auto_awesome, size: 10, color: Colors.white),
                      SizedBox(width: 4),
                      Text('AI Desain', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              if (onAISketch != null) const SizedBox(width: 6),
              GestureDetector(
                onTap: onCancel,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: AppTheme.surface3, borderRadius: BorderRadius.circular(6)),
                  child: const Text('Batal', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onSend,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.success,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Kirim', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
