// DocuCraft — Grid View (Fullscreen dialog, semua slide)
// Tap → ganti slide, X → delete, + → tambah slide

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/slide.dart';
import '../providers/slide_provider.dart';
import '../themes/app_theme.dart';

class SlideGridView extends StatelessWidget {
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _GridViewDialog(),
    );
  }

  const SlideGridView({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // Use static show() instead
  }
}

class _GridViewDialog extends StatelessWidget {
  const _GridViewDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: AppTheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Top bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withAlpha(12))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.grid_view_rounded, size: 20, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  const Text('Semua Slide',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const Spacer(),
                  Consumer<SlideProvider>(
                    builder: (_, p, __) => Text(
                      '${p.visibleSlides.length} slide',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.surface3,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            // Grid
            Expanded(
              child: Consumer<SlideProvider>(
                builder: (ctx, provider, _) {
                  if (provider.slides.isEmpty) {
                    return const Center(child: Text('Belum ada slide', style: TextStyle(color: AppTheme.textMuted)));
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 16 / 10,
                    ),
                    itemCount: provider.slides.length,
                    itemBuilder: (ctx, index) {
                      final slide = provider.slides[index];
                      final isActive = index == provider.currentSlideIndex;
                      return _SlideCard(
                        slide: slide,
                        index: index,
                        isActive: isActive,
                        onTap: () {
                          provider.switchSlide(index);
                          Navigator.pop(context);
                        },
                        onDelete: () => _confirmDelete(context, provider, index),
                      );
                    },
                  );
                },
              ),
            ),
            // Add button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: GestureDetector(
                onTap: () {
                  context.read<SlideProvider>().addSlide();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('➕ Slide baru ditambahkan'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(20),
                    border: Border.all(color: AppTheme.primary.withAlpha(40)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 18, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Text('Tambah Slide Baru',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, SlideProvider provider, int index) {
    if (provider.slides.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Minimal harus ada 1 slide'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface2,
        title: const Text('Hapus slide?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text('"${provider.slides[index].title}"',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(onPressed: () { provider.deleteSlide(index); Navigator.pop(ctx); },
              child: const Text('Hapus', style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
  }
}

class _SlideCard extends StatelessWidget {
  final Slide slide;
  final int index;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SlideCard({
    required this.slide,
    required this.index,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = AppTheme.gradientFor(slide.backgroundGradient);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Gradient preview
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? AppTheme.primary : Colors.white.withAlpha(15),
                width: isActive ? 2.5 : 1,
              ),
              boxShadow: isActive
                  ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 10)]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Slide number badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('#${index + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  // Title
                  Text(slide.title,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(slide.subtitle,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 9),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
          // Hidden badge
          if (slide.hidden)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Icon(Icons.visibility_off, color: Colors.white54, size: 24)),
              ),
            ),
          // Delete button (X) — top right
          Positioned(
            top: 6, right: 6,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: AppTheme.error,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
          // Active badge
          if (isActive)
            Positioned(
              bottom: 6, left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Aktif', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}
