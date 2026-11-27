// DocuCraft Flutter — Blueprint Picker Provider (Sprint 12)
//
// ChangeNotifier yang memegang state picker: daftar blueprint,
// query pencarian, filter tag aktif (All / Forked / Recent), dan
// getter turunan `visibleBlueprints`.

import 'package:flutter/foundation.dart';
import '../models/deck_blueprint.dart';
import '../services/deck_blueprint_storage.dart';

enum BlueprintTag { all, forked, recent }

class BlueprintPickerProvider extends ChangeNotifier {
  final DeckBlueprintStorage storage;
  static const int recentLimit = 5;

  List<DeckBlueprint> _blueprints = [];
  bool _loading = false;
  String? _error;
  String _query = '';
  BlueprintTag _tag = BlueprintTag.all;

  BlueprintPickerProvider({required this.storage});

  List<DeckBlueprint> get blueprints => List.unmodifiable(_blueprints);
  bool get loading => _loading;
  String? get error => _error;
  String get query => _query;
  BlueprintTag get tag => _tag;

  int get forkedCount => _blueprints.where((b) => b.forkedFrom != null).length;

  /// The filtered list the UI renders. Server already returns newest-first
  /// (storage.listAll sorts), so "Recent" is just take(5).
  List<DeckBlueprint> get visibleBlueprints {
    Iterable<DeckBlueprint> out = _blueprints;
    if (_tag == BlueprintTag.forked) {
      out = out.where((b) => b.forkedFrom != null);
    } else if (_tag == BlueprintTag.recent) {
      out = out.take(recentLimit);
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((b) =>
          b.name.toLowerCase().contains(q) ||
          b.topic.toLowerCase().contains(q));
    }
    return out.toList(growable: false);
  }

  bool get hasBlueprints => _blueprints.isNotEmpty;
  bool get hasMatches => visibleBlueprints.isNotEmpty;
  bool get isFiltering => _query.trim().isNotEmpty || _tag != BlueprintTag.all;

  void setQuery(String q) {
    if (q == _query) return;
    _query = q;
    notifyListeners();
  }

  void setTag(BlueprintTag t) {
    if (t == _tag) return;
    _tag = t;
    notifyListeners();
  }

  void clearFilter() {
    _query = '';
    _tag = BlueprintTag.all;
    notifyListeners();
  }

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();
    final r = await storage.listAll();
    if (r.ok) {
      _blueprints = r.value ?? [];
    } else {
      _error = r.error;
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool> delete(String id) async {
    final r = await storage.delete(id);
    if (r.ok) {
      _blueprints.removeWhere((b) => b.id == id);
      notifyListeners();
      return true;
    }
    _error = r.error;
    notifyListeners();
    return false;
  }
}
