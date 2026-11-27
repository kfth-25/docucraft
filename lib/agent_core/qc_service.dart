// DocuCraft Flutter — QC Service (Sprint 23)
//
// Pass QC layout pasca-generasi. Iterasi halaman yang sudah di-land,
// menjalankan audit deterministik, dan mencoba perbaikan geometri via
// agent loop LLM.
//
// QC hanya deterministik (tanpa screenshot vision) — berjalan setelah semua
// halaman di-land, secara sekuensial. Halaman yang di-pin dilewati.

import 'dart:math' as math;
import '../models/slide.dart';
import '../services/quality_check.dart';
import '../services/settings_service.dart';

/// Result dari QC satu halaman.
class QcPageResult {
  final bool ok;
  final bool edited;
  final String reply;
  final int preIssues;
  final int postIssues;
  final String? error;

  const QcPageResult({
    required this.ok,
    required this.edited,
    required this.reply,
    required this.preIssues,
    required this.postIssues,
    this.error,
  });
}

/// Config for QC pass.
class QcConfig {
  /// Maximum pages to QC per run (cost ceiling).
  final int maxPages;

  /// Whether QC is enabled at all.
  final bool enabled;

  const QcConfig({this.maxPages = 20, this.enabled = true});

  /// Create a config from stored settings
  static Future<QcConfig> fromSettings() async {
    final settings = await SettingsService.getInstance();
    return QcConfig(
      maxPages: settings.qcMaxPages,
      enabled: settings.qcEnabled,
    );
  }
}

/// QC orchestrator — post-generation background pass.
///
/// Usage:
/// ```dart
/// final service = await QcService.create();
/// await for (final result in service.runQcPass(
///   pageIndexes: [0, 1, 2],
///   pinnedPages: {1}, // page 1 skipped
///   getPage: (i) => slideProvider.slides[i],
///   applyPage: (i, slide) => slideProvider.updateSlide(i, slide),
///   onProgress: (done, total) => runProvider.tickQcProgress(done: done + 1),
/// )) {
///   // log result per page
/// }
/// ```
class QcService {
  final QcConfig config;

  static const double _w = 1920.0, _h = 1080.0;
  static const double _edgeTol = 8.0, _overflowTol = 4.0;
  static const double _overlapRatio = 0.12, _overlapMinArea = 400.0;

  const QcService({this.config = const QcConfig()});

  /// Factory constructor that loads config from settings
  static Future<QcService> create() async {
    final config = await QcConfig.fromSettings();
    return QcService(config: config);
  }

  /// Run QC on a list of page indexes, skipping pinned pages.
  /// Yields results per page as they complete.
  Stream<QcPageResult> runQcPass({
    required List<int> pageIndexes,
    required Set<int> pinnedPages,
    required Slide Function(int idx) getPage,
    required void Function(int idx, Slide slide) applyPage,
    required void Function(int done, int total) onProgress,
  }) async* {
    if (!config.enabled) return;

    final toQc = pageIndexes.where((i) => !pinnedPages.contains(i)).toList();
    final total = toQc.length;

    for (int i = 0; i < toQc.length; i++) {
      final idx = toQc[i];
      onProgress(i, total);

      final result = await _qcSinglePage(
        idx: idx,
        getPage: getPage,
        applyPage: applyPage,
      );
      yield result;
    }
  }

  Future<QcPageResult> _qcSinglePage({
    required int idx,
    required Slide Function(int idx) getPage,
    required void Function(int idx, Slide slide) applyPage,
  }) async {
    final slide = getPage(idx);

    // Pre-audit: deterministic geometry check
    final preIssues = _auditSlideLayout(slide);

    // Short-circuit: if geometry is clean, skip LLM round-trip
    if (preIssues == 0) {
      return QcPageResult(
        ok: true,
        edited: false,
        reply: 'OK',
        preIssues: 0,
        postIssues: 0,
      );
    }

    // Try auto-fix (deterministic repositioning)
    final checkResult = QualityChecker.check(slide.elements);
    List<SlideElement> fixedElements;
    if (!checkResult.passed) {
      fixedElements = QualityChecker.autoFix(slide.elements, checkResult);
    } else {
      fixedElements = slide.elements;
    }

    // Build updated slide with fixed elements (copy all fields from original)
    final fixedSlide = Slide(
      id: slide.id,
      elements: fixedElements,
      hidden: slide.hidden,
      title: slide.title,
      subtitle: slide.subtitle,
      backgroundGradient: slide.backgroundGradient,
      extra: slide.extra,
      version: slide.version,
      lastModifiedBy: slide.lastModifiedBy,
      lastModifiedAt: slide.lastModifiedAt,
      templateId: slide.templateId,
      layoutId: slide.layoutId,
      templateData: slide.templateData,
    );

    // Post-audit
    final postIssues = _auditSlideLayout(fixedSlide);

    // Revert if QC made things worse
    if (postIssues > preIssues) {
      return QcPageResult(
        ok: false,
        edited: false,
        reply: 'Reverted: QC found more issues',
        preIssues: preIssues,
        postIssues: postIssues,
      );
    }

    // Apply if better or same
    if (postIssues < preIssues) {
      applyPage(idx, fixedSlide);
    }

    return QcPageResult(
      ok: true,
      edited: postIssues < preIssues,
      reply: 'QC done: $postIssues issues remaining',
      preIssues: preIssues,
      postIssues: postIssues,
    );
  }

  /// Deterministic layout audit — zero LLM calls.
  /// Returns issue count (0 = clean). Caps at 12 for prompt size.
  static int _auditSlideLayout(Slide slide) {
    int issues = 0;

    for (final elem in slide.elements) {
      // 1. Out of bounds
      if (elem.x < -_edgeTol) issues++;
      if (elem.y < -_edgeTol) issues++;
      if (elem.x + elem.width > _w + _edgeTol) issues++;
      if (elem.y + elem.height > _h + _edgeTol) issues++;
      if (issues > 12) break;

      // 2. Text overflow (height)
      if (elem.type == ElementType.text) {
        final textElem = elem;
        // Use actual contentHeight from render layer if available, else fallback
        final contentH = _actualContentHeight(textElem);
        if (contentH - elem.height > _overflowTol) issues++;
        if (issues > 12) break;
      }
    }

    if (issues <= 12) {
      // 3. Pairwise overlap (content elements only)
      final contentElems = slide.elements.where(_isContentElement).toList();
      for (int i = 0; i < contentElems.length && issues <= 12; i++) {
        for (int j = i + 1; j < contentElems.length && issues <= 12; j++) {
          if (_overlaps(contentElems[i], contentElems[j])) issues++;
        }
      }
    }

    return issues.clamp(0, 12);
  }

  /// Actual content height from TextStyleData if available, else fallback estimate.
  /// Mirrors GenOffice's layout-audit.ts approach: uses the render layer's
  /// laid-out contentHeight for exact overflow detection.
  static double _actualContentHeight(SlideElement elem) {
    if (elem.type == ElementType.text && elem.textStyle?.contentHeight != null) {
      // Use actual laid-out content height when available
      return elem.textStyle!.contentHeight!;
    }
    // Fallback: estimate from font size (used for programmatic elements without layout)
    if (elem.textStyle != null) {
      final fs = elem.textStyle!.fontSize;
      final lines = (elem.height / (fs * 1.5)).ceil().clamp(1, 20);
      return (fs * lines * 1.5) + 8 + 8; // default padding
    }
    return elem.height;
  }

  static bool _isContentElement(SlideElement e) {
    return e.type == ElementType.text ||
        e.type == ElementType.image ||
        e.type == ElementType.shape;
  }

  static bool _overlaps(SlideElement a, SlideElement b) {
    // Axis-aligned bounding box intersection
    final ix = math.max(a.x, b.x);
    final iy = math.max(a.y, b.y);
    final ax2 = a.x + a.width, ay2 = a.y + a.height;
    final bx2 = b.x + b.width, by2 = b.y + b.height;
    final iw = ax2 - ix, ih = ay2 - iy;
    if (iw <= 0 || ih <= 0) return false;
    final interArea = iw * ih;
    final minArea = math.min(a.width * a.height, b.width * b.height);
    return interArea >= _overlapMinArea && interArea >= minArea * _overlapRatio;
  }
}
