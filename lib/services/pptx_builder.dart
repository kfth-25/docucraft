// DocuCraft — PPTX Builder (GenOffice-style)
// Service level tinggi yang menghasilkan file .pptx sungguhan dari model Slide
// Mencerminkan landGeneratedPages() GenOffice + generasi PPTX main process
//
// Alur:
//   AI menghasilkan slide (SVG → SlideElements) → PptxBuilder.build() → File .pptx sungguhan
//   Juga memperbarui state in-memory lewat SlideProvider

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/slide.dart';
import 'pptx_export.dart';

/// Result of landing generated pages (mirrors GenOffice's landGeneratedPages return)
class LandResult {
  final bool ok;
  final String? path;
  final int pages;
  final String? error;
  final String? fallbackReason;
  final List<ImageFailure>? imageFailures;
  /// Index in the deck where new pages were appended/inserted (GenOffice uses this for insert_at mode)
  final int? appendedFrom;

  const LandResult({
    required this.ok,
    this.path,
    this.pages = 0,
    this.error,
    this.fallbackReason,
    this.imageFailures,
    this.appendedFrom,
  });
}

class ImageFailure {
  final int page;
  final String url;
  const ImageFailure({required this.page, required this.url});
}

/// PptxBuilder — GenOffice-style PPTX generation
/// Generates real .pptx files from Slide model, saves to disk,
/// and returns metadata for state updates.
class PptxBuilder {
  /// Generate and save a complete presentation deck
  ///
  /// [slides] - The slides to include in the deck
  /// [deckName] - Optional filename (without .pptx extension)
  /// [replaceAll] - If true, replaces entire deck; if false, appends
  ///
  /// Returns LandResult with:
  /// - ok: success/failure
  /// - path: absolute path to the saved .pptx file
  /// - pages: total page count
  /// - error: error message if failed
  static Future<LandResult> build({
    required List<Slide> slides,
    String? deckName,
    bool replaceAll = true,
  }) async {
    if (slides.isEmpty) {
      return const LandResult(
        ok: false,
        error: 'No slides to generate',
      );
    }

    try {
      // 1. Generate PPTX bytes using existing PptxExporter
      final exporter = PptxExporter(slides: slides, title: deckName);
      final bytes = exporter.exportAsBytes();

      if (bytes.isEmpty) {
        return const LandResult(
          ok: false,
          error: 'Failed to generate PPTX bytes',
        );
      }

      // 2. Determine output path
      final outputPath = await _getOutputPath(deckName ?? 'presentation');

      // 3. Write to file
      final file = File(outputPath);
      await file.writeAsBytes(bytes);

      // 4. Verify file was written
      if (!await file.exists()) {
        return const LandResult(
          ok: false,
          error: 'File was not written to disk',
        );
      }

      final fileSize = await file.length();
      print('✅ PptxBuilder: Generated ${slides.length} slides, ${fileSize} bytes → $outputPath');

      return LandResult(
        ok: true,
        path: outputPath,
        pages: slides.length,
      );
    } catch (e) {
      print('❌ PptxBuilder error: $e');
      return LandResult(
        ok: false,
        error: e.toString(),
      );
    }
  }

  /// Land generated pages into the existing deck (append mode)
  /// Used when adding new pages to an existing presentation
  static Future<LandResult> landAppend({
    required List<Slide> newSlides,
    required List<Slide> existingSlides,
    String? deckName,
  }) async {
    final allSlides = [...existingSlides, ...newSlides];
    return build(
      slides: allSlides,
      deckName: deckName,
      replaceAll: false,
    );
  }

  /// Land generated pages at a specific index (insert mode)
  /// Used for re-inserting failed pages at their original position
  static Future<LandResult> landInsertAt({
    required List<Slide> newSlides,
    required List<Slide> existingSlides,
    required int insertIndex,
    String? deckName,
  }) async {
    final allSlides = [
      ...existingSlides.sublist(0, insertIndex),
      ...newSlides,
      ...existingSlides.sublist(insertIndex),
    ];
    return build(
      slides: allSlides,
      deckName: deckName,
      replaceAll: false,
    );
  }

  /// Replace a single slide in the deck
  static Future<LandResult> replaceSlide({
    required int slideIndex,
    required Slide newSlide,
    required List<Slide> existingSlides,
    String? deckName,
  }) async {
    if (slideIndex < 0 || slideIndex >= existingSlides.length) {
      return LandResult(
        ok: false,
        error: 'Invalid slide index: $slideIndex',
      );
    }

    final updatedSlides = List<Slide>.from(existingSlides);
    updatedSlides[slideIndex] = newSlide;

    return build(
      slides: updatedSlides,
      deckName: deckName,
      replaceAll: false,
    );
  }

  /// Share the generated PPTX file
  static Future<void> share(String filePath) async {
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'DocuCraft Presentation',
    );
  }

  /// Get the output directory for generated presentations
  static Future<String> _getOutputPath(String baseName) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = baseName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    return '${directory.path}/${safeName}_$timestamp.pptx';
  }

  /// Get a persistent path for auto-save (same file, overwritten each time)
  static Future<String> getAutoSavePath(String projectId) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/autosave_$projectId.pptx';
  }

  /// Auto-save the deck to a persistent path (overwrites previous)
  static Future<LandResult> autoSave({
    required List<Slide> slides,
    required String projectId,
    String? deckName,
  }) async {
    try {
      final outputPath = await getAutoSavePath(projectId);

      final exporter = PptxExporter(slides: slides, title: deckName);
      final bytes = exporter.exportAsBytes();

      if (bytes.isEmpty) {
        return LandResult(
          ok: false,
          error: 'Failed to generate PPTX bytes',
        );
      }

      final file = File(outputPath);
      await file.writeAsBytes(bytes);

      return LandResult(
        ok: true,
        path: outputPath,
        pages: slides.length,
      );
    } catch (e) {
      return LandResult(
        ok: false,
        error: e.toString(),
      );
    }
  }
}
