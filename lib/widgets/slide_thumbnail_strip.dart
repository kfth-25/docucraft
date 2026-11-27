// DocuCraft — Slide Thumbnail Strip Widget (dengan drag-to-reorder)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/slide.dart';
import '../providers/slide_provider.dart';
import '../themes/app_theme.dart';

class SlideThumbnailStrip extends StatelessWidget {
  final List<Slide> slides;
  final int currentIndex;
  final Function(int) onTap;

  const SlideThumbnailStrip({
    super.key,
    required this.slides,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final visibleSlides = slides.where((s) => !s.hidden).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Thumbnail strip with drag-reorder
        SizedBox(
          height: 70,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: slides.length + 1,
            itemBuilder: (context, index) {
              if (index == slides.length) {
                return _addButton(context);
              }
              final slide = slides[index];
              final isActive = index == currentIndex;
              return _DraggableThumbnail(
                slide: slide,
                index: index,
                isActive: isActive,
                slidesLength: slides.length,
                onTap: () => onTap(index),
              );
            },
          ),
        ),
        // Slide dots
        SizedBox(
          height: 16,
          child: Center(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: visibleSlides.length,
              itemBuilder: (ctx, index) {
                int actualIdx = 0;
                int found = -1;
                for (var i = 0; i < slides.length; i++) {
                  if (!slides[i].hidden) {
                    if (actualIdx == index) { found = i; break; }
                    actualIdx++;
                  }
                }
                final isActive = found == currentIndex;
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primary : AppTheme.textMuted.withAlpha(100),
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _addButton(BuildContext ctx) {
    return GestureDetector(
      onTap: () {
        final provider = ctx.read<SlideProvider>();
        provider.addSlide();
        provider.switchSlide(provider.slides.length - 1);
      },
      child: Container(
        width: 70,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: const Center(
          child: Icon(Icons.add, color: AppTheme.primary, size: 20),
        ),
      ),
    );
  }
}

/// Draggable thumbnail — long-press to drag-reorder
class _DraggableThumbnail extends StatelessWidget {
  final Slide slide;
  final int index;
  final bool isActive;
  final int slidesLength;
  final VoidCallback onTap;

  const _DraggableThumbnail({
    required this.slide,
    required this.index,
    required this.isActive,
    required this.slidesLength,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = AppTheme.gradientFor(slide.backgroundGradient);
    return LongPressDraggable<_DragData>(
      data: _DragData(index: index),
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: _buildThumb(gradient, 80),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildThumb(gradient, 70)),
      onDragEnd: (details) {
        // Check if dropped near another thumbnail
        final provider = context.read<SlideProvider>();
        provider.reorderSlide(index, index); // Reset if no target
      },
      child: DragTarget<_DragData>(
        onAcceptWithDetails: (details) {
          if (details.data.index != index) {
            final provider = context.read<SlideProvider>();
            provider.reorderSlide(details.data.index, index);
          }
        },
        builder: (ctx, candidates, rejected) {
          return GestureDetector(
            onTap: onTap,
            child: _buildThumb(gradient, 70),
          );
        },
      ),
    );
  }

  Widget _buildThumb(List<Color> gradient, double width) {
    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? AppTheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          '${index + 1}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Drag data for drag-reorder
class _DragData {
  final int index;
  const _DragData({required this.index});
}