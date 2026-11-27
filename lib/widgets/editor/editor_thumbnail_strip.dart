// DocuCraft — Editor Thumbnail Strip
// Diekstrak dari slide_editor_screen.dart demi modularitas

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/slide_provider.dart';
import '../../widgets/slide_thumbnail_strip.dart';
import '../../themes/app_theme.dart';

class EditorThumbnailStrip extends StatelessWidget {
  final SlideProvider provider;

  const EditorThumbnailStrip({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return SlideThumbnailStrip(
      slides: provider.slides,
      currentIndex: provider.currentSlideIndex,
      onTap: provider.switchSlide,
    );
  }
}