// DocuCraft Flutter — Deck Blueprint Storage (Sprint 12)
//
// Lapisan persistence untuk [DeckBlueprint] memakai Hive Box<Map> mentah.
// Tanpa codegen, tanpa typed adapter — hanya wrapper tipis yang mengelola
// siklus hidup box dan memvalidasi read/write.
//
// Semua method async karena box Hive bersifat async (box dibuka sekali
// saat app start dan disimpan di memori; sisi async ini jaring pengaman
// untuk pembukaan pertama).

import 'package:hive_flutter/hive_flutter.dart';
import '../models/deck_blueprint.dart';

/// Result envelope so callers can branch on ok/error without exceptions
/// for normal user-recoverable cases (id collision, missing key, etc).
class StorageResult<T> {
  final bool ok;
  final T? value;
  final String? error;
  const StorageResult.ok(this.value) : ok = true, error = null;
  const StorageResult.fail(this.error) : ok = false, value = null;
}

class DeckBlueprintStorage {
  /// Hive box name. Bumping the suffix invalidates the old box (useful
  /// if we ever change the JSON shape and want a clean migration).
  static const String boxName = 'deck_blueprints_v1';

  Box<Map>? _box;

  /// Open the box. Idempotent — safe to call from main() multiple times.
  Future<void> open() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<Map>(boxName);
  }

  Box<Map> get _requireBox {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError('DeckBlueprintStorage not open. Call open() first.');
    }
    return b;
  }

  /// Save a blueprint. Overwrites if [blueprint.id] already exists.
  Future<StorageResult<String>> save(DeckBlueprint blueprint) async {
    try {
      await _requireBox.put(blueprint.id, blueprint.toJson());
      return StorageResult.ok(blueprint.id);
    } catch (e) {
      return StorageResult.fail(e.toString());
    }
  }

  /// Load a blueprint by id. Returns null if not found.
  Future<StorageResult<DeckBlueprint?>> load(String id) async {
    try {
      final raw = _requireBox.get(id);
      if (raw == null) {
        return const StorageResult<DeckBlueprint?>.ok(null);
      }
      return StorageResult.ok(DeckBlueprint.fromJson(raw));
    } catch (e) {
      return StorageResult.fail(e.toString());
    }
  }

  /// List all blueprints, newest first (sorted by createdAt desc).
  Future<StorageResult<List<DeckBlueprint>>> listAll() async {
    try {
      final all = <DeckBlueprint>[];
      for (final raw in _requireBox.values) {
        final bp = DeckBlueprint.fromJson(raw);
        if (bp != null) all.add(bp);
      }
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return StorageResult.ok(all);
    } catch (e) {
      return StorageResult.fail(e.toString());
    }
  }

  /// Delete a blueprint by id. No-op if missing.
  Future<StorageResult<bool>> delete(String id) async {
    try {
      await _requireBox.delete(id);
      return const StorageResult.ok(true);
    } catch (e) {
      return StorageResult.fail(e.toString());
    }
  }

  /// Close the box (for tests / app shutdown).
  Future<void> close() async {
    await _box?.close();
    _box = null;
  }
}
