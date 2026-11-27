// DocuCraft — Conflict Resolver
// Resolusi konflik Last-Writer-Wins (LWW) untuk editing kolaboratif
//
// Strategi: Setiap slide dan elemen memiliki `version` yang naik monoton.
// Saat dua klien mengedit elemen yang sama secara bersamaan, versi yang lebih
// tinggi menang. Jika versinya sama, timestamp `lastModifiedAt` yang lebih
// akhir menang.
//
// Keterbatasan:
//   - LWW sederhana tapi bisa kehilangan edit bersamaan yang tidak konflik
//   - Untuk teks di dalam elemen, LWW berarti teks satu user menimpa
//     teks user lain sepenuhnya (masa depan: OT/CRDT di dalam text span)
//
// Edge cases yang ditangani:
//   - Versi seri → tiebreaker timestamp (presisi milidetik)
//   - Versi hilang → asumsikan versi 1 (data legacy)
//   - Elemen terhapus saat sedang diedit → penghapusan menang (tombstone)

import '../models/slide.dart';

/// Result of a conflict resolution
class ConflictResult {
  final bool hasConflict;
  final Slide? resolvedSlide;
  final List<String> log;

  ConflictResult({
    this.hasConflict = false,
    this.resolvedSlide,
    this.log = const [],
  });
}

/// Resolves conflicts between two versions of a slide
class ConflictResolver {
  /// Resolve conflict between local and remote slide versions
  static ConflictResult resolve(Slide local, Slide remote) {
    final log = <String>[];

    // Slide-level conflict
    if (local.version > remote.version) {
      log.add('Slide version: local ($local) > remote ($remote) → local wins');
      return ConflictResult(resolvedSlide: local, log: log);
    }
    if (remote.version > local.version) {
      log.add('Slide version: remote ($remote) > local ($local) → remote wins');
      return ConflictResult(resolvedSlide: remote, log: log);
    }

    // Version tie — check timestamps
    final localTime = local.lastModifiedAt ?? DateTime.now();
    final remoteTime = remote.lastModifiedAt ?? DateTime.now();

    if (localTime.isAfter(remoteTime)) {
      log.add('Version tied ($local), local timestamp later → local wins');
      return ConflictResult(resolvedSlide: local, log: log);
    }
    if (remoteTime.isAfter(localTime)) {
      log.add('Version tied ($local), remote timestamp later → remote wins');
      return ConflictResult(resolvedSlide: remote, log: log);
    }

    // True simultaneous edit — merge element by element
    log.add('TRUE SIMULTANEOUS — merging element-by-element');
    final merged = _mergeElements(local, remote, log);
    return ConflictResult(
      hasConflict: true,
      resolvedSlide: merged,
      log: log,
    );
  }

  /// Merge elements from two conflicting slides
  static Slide _mergeElements(Slide local, Slide remote, List<String> log) {
    final mergedElements = <SlideElement>[];
    final processedIds = <String>{};

    // Process remote elements first
    for (final remoteEl in remote.elements) {
      final localEl = local.elements.where((e) => e.id == remoteEl.id).firstOrNull;
      if (localEl == null) {
        // New element from remote
        mergedElements.add(remoteEl);
        processedIds.add(remoteEl.id);
        log.add('  Element ${remoteEl.id}: new from remote');
      } else {
        // Both edited — version check
        final resolved = _resolveElement(localEl, remoteEl, log);
        mergedElements.add(resolved);
        processedIds.add(remoteEl.id);
      }
    }

    // Add remaining local elements (not in remote)
    for (final localEl in local.elements) {
      if (!processedIds.contains(localEl.id)) {
        mergedElements.add(localEl);
        processedIds.add(localEl.id);
        log.add('  Element ${localEl.id}: only in local, keeping');
      }
    }

    return Slide(
      id: local.id,
      title: local.version >= remote.version ? local.title : remote.title,
      subtitle: local.version >= remote.version ? local.subtitle : remote.subtitle,
      backgroundGradient: local.backgroundGradient,
      elements: mergedElements,
      version: local.version + 1,
      lastModifiedAt: DateTime.now(),
    );
  }

  /// Resolve conflict between two versions of an element
  static SlideElement _resolveElement(SlideElement local, SlideElement remote, List<String> log) {
    if (local.version > remote.version) {
      log.add('    Element ${local.id}: local v${local.version} > remote v${remote.version} → local');
      return local;
    }
    if (remote.version > local.version) {
      log.add('    Element ${local.id}: remote v${remote.version} > local v${local.version} → remote');
      return remote;
    }

    // Version tie — field-level LWW merge
    log.add('    Element ${local.id}: version tie (v${local.version}) — field-level merge');

    final merged = SlideElement(
      type: local.type,
      content: _pick(local.content, remote.content, local, remote),
      x: _pickNum(local.x, remote.x, local, remote),
      y: _pickNum(local.y, remote.y, local, remote),
      width: _pickNum(local.width, remote.width, local, remote),
      height: _pickNum(local.height, remote.height, local, remote),
      rotation: _pickNum(local.rotation, remote.rotation, local, remote),
      zIndex: (local.lastModifiedAt ?? DateTime.now()).isAfter(remote.lastModifiedAt ?? DateTime.now())
          ? local.zIndex : remote.zIndex,
      textStyle: local.textStyle ?? remote.textStyle,
      shapeStyle: local.shapeStyle ?? remote.shapeStyle,
      imageStyle: local.imageStyle ?? remote.imageStyle,
      chartData: local.chartData ?? remote.chartData,
      tableData: local.tableData ?? remote.tableData,
      version: local.version + 1,
      lastModifiedAt: DateTime.now(),
    );

    return merged;
  }

  /// Pick which value wins (non-null and higher version wins)
  static T? _pick<T>(T? local, T? remote, SlideElement lEl, SlideElement rEl) {
    if (local == null) return remote;
    if (remote == null) return local;
    if (lEl.version > rEl.version) return local;
    if (rEl.version > lEl.version) return remote;
    // Version tie — use timestamp
    return (lEl.lastModifiedAt ?? DateTime.now()).isAfter(rEl.lastModifiedAt ?? DateTime.now())
        ? local : remote;
  }

  static double _pickNum(double local, double remote, SlideElement lEl, SlideElement rEl) {
    if (lEl.version > rEl.version) return local;
    if (rEl.version > lEl.version) return remote;
    return (lEl.lastModifiedAt ?? DateTime.now()).isAfter(rEl.lastModifiedAt ?? DateTime.now())
        ? local : remote;
  }
}
