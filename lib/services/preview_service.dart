// DocuCraft — Preview Service (Langkah 6: Executor Live Preview)
// Tangani live preview sebelum ekspor final

import '../models/slide.dart';
import 'quality_check.dart';

/// Preview state
enum PreviewState {
  idle,
  rendering,
  ready,
  error,
}

/// Preview result with diagnostics
class PreviewResult {
  final PreviewState state;
  final List<Slide> slides;
  final List<QualityCheckResult> qualityResults;
  final String? error;

  PreviewResult({
    required this.state,
    required this.slides,
    required this.qualityResults,
    this.error,
  });

  bool get hasIssues => qualityResults.any((q) => !q.passed);
  int get totalIssues => qualityResults.fold(0, (sum, q) => sum + q.issues.length);
}

class PreviewService {
  /// Render slides for preview
  static Future<PreviewResult> renderPreview(List<Slide> slides) async {
    try {
      final qualityResults = <QualityCheckResult>[];

      // Check each slide quality
      for (final slide in slides) {
        final qc = QualityChecker.check(slide.elements);
        qualityResults.add(qc);
      }

      return PreviewResult(
        state: PreviewState.ready,
        slides: slides,
        qualityResults: qualityResults,
      );
    } catch (e) {
      return PreviewResult(
        state: PreviewState.error,
        slides: slides,
        qualityResults: [],
        error: e.toString(),
      );
    }
  }

  /// Auto-fix all slides
  static List<Slide> autoFixAll(List<Slide> slides) {
    return slides.map((slide) {
      final qc = QualityChecker.check(slide.elements);
      if (!qc.passed) {
        final fixedElements = QualityChecker.autoFix(slide.elements, qc);
        return Slide(
          id: slide.id,
          title: slide.title,
          subtitle: slide.subtitle,
          backgroundGradient: slide.backgroundGradient,
          elements: fixedElements,
        );
      }
      return slide;
    }).toList();
  }

  /// Get preview summary
  static String getPreviewSummary(PreviewResult result) {
    if (result.state == PreviewState.error) {
      return 'Error: ${result.error}';
    }

    final sb = StringBuffer();
    sb.writeln('📊 Preview Summary:');
    sb.writeln('• Total slides: ${result.slides.length}');
    sb.writeln('• Slides with issues: ${result.qualityResults.where((q) => !q.passed).length}');

    if (result.hasIssues) {
      sb.writeln('\n⚠️ Issues found:');
      for (int i = 0; i < result.qualityResults.length; i++) {
        final qc = result.qualityResults[i];
        if (!qc.passed) {
          sb.writeln('  Slide ${i + 1}: ${qc.issues.length} issues');
          for (final issue in qc.issues) {
            sb.writeln('    - $issue');
          }
        }
      }
    } else {
      sb.writeln('\n✅ All slides passed quality check!');
    }

    return sb.toString();
  }
}
