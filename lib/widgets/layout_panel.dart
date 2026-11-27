// DocuCraft — Layout Panel (5 layout preset)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/slide_provider.dart';
import '../themes/app_theme.dart';

class LayoutPanel extends StatelessWidget {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const LayoutPanel(),
    );
  }

  const LayoutPanel({super.key});

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
            const Icon(Icons.dashboard, size: 18, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            const Text('Layout Slide', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const Spacer(),
            GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary)),
          ]),
          const SizedBox(height: 4),
          const Align(alignment: Alignment.centerLeft,
            child: Text('Pilih tata letak — elemen akan disusun ulang', style: TextStyle(fontSize: 10, color: AppTheme.textMuted))),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: [
              _layoutCard(context, 'blank', 'Blank', Icons.grid_off, null),
              _layoutCard(context, 'title', 'Title', Icons.title, 'title'),
              _layoutCard(context, 'content', 'Content', Icons.text_snippet, 'content'),
              _layoutCard(context, 'two-column', 'Two Column', Icons.view_column, 'two-column'),
              _layoutCard(context, 'image-text', 'Image+Text', Icons.image, 'image-text'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _layoutCard(BuildContext ctx, String type, String label, IconData icon, String? layoutType) {
    return GestureDetector(
      onTap: () {
        final provider = ctx.read<SlideProvider>();
        provider.applyLayout(type);
        Navigator.pop(ctx);
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('📐 Layout: $label'), behavior: SnackBarBehavior.floating),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.surface3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(12)),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 36,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: _layoutPreview(type),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _layoutPreview(String type) {
    return Stack(
      children: [
        if (type == 'blank') const SizedBox.shrink(),
        if (type == 'title')
          Center(child: Container(width: 24, height: 4, color: Colors.white.withValues(alpha: 0.5), margin: const EdgeInsets.only(bottom: 8))),
        if (type == 'content')
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 20, height: 3, color: Colors.white.withValues(alpha: 0.5)),
              const SizedBox(height: 4),
              Container(width: 20, height: 8, color: Colors.white.withValues(alpha: 0.2)),
            ],
          ),
        if (type == 'two-column')
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 10, height: 16, color: Colors.white.withValues(alpha: 0.4)),
              const SizedBox(width: 2),
              Container(width: 10, height: 16, color: Colors.white.withValues(alpha: 0.2)),
            ],
          ),
        if (type == 'image-text')
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 12, height: 16, color: Colors.white.withValues(alpha: 0.4)),
              const SizedBox(width: 2),
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 8, height: 3, color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(height: 2),
                Container(width: 8, height: 6, color: Colors.white.withValues(alpha: 0.15)),
              ]),
            ],
          ),
      ],
    );
  }
}
