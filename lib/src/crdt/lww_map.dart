// DocuCraft CRDT — Last-Write-Wins Map
// Port dari loro-js: map handling logic

import 'dart:collection';
import 'id.dart';

/// LWW (Last-Write-Wins) Map Entry
/// Each key stores value + timestamp (Lamport) + origin OpID for tie-breaking
class LWWEntry<V> {
  final V value;
  final Lamport lamport;
  final OpID opId;
  final bool deleted;

  LWWEntry({required this.value, required this.lamport, required this.opId, this.deleted = false});

  LWWEntry<V> copyWith({V? value, Lamport? lamport, OpID? opId, bool? deleted}) {
    return LWWEntry<V>(
      value: value ?? this.value,
      lamport: lamport ?? this.lamport,
      opId: opId ?? this.opId,
      deleted: deleted ?? this.deleted,
    );
  }

  @override
  String toString() => 'LWWEntry(${deleted ? 'DEL' : value} @$lamport)';
}

/// LWW Map CRDT — Last-Write-Wins per key
/// Concurrent writes to same key: highest Lamport wins, tie-break by OpID
class LWWMap<K, V> {
  final Map<K, LWWEntry<V>> map = {};

  // Public accessors for encoding/decoding
  Map<K, LWWEntry<V>> get mapValue => map;
  set mapValue(Map<K, LWWEntry<V>> value) {
    map.clear();
    map.addAll(value);
  }

  /// Get value for key (null if not exists or deleted)
  V? get(K key) {
    final entry = map[key];
    if (entry == null || entry.deleted) return null;
    return entry.value;
  }

  /// Check if key exists and not deleted
  bool containsKey(K key) {
    final entry = map[key];
    return entry != null && !entry.deleted;
  }

  /// Get all alive keys
  Iterable<K> get keys => map.keys.where((k) => !map[k]!.deleted);

  /// Get all alive entries
  Iterable<MapEntry<K, V>> get entries =>
      map.entries.where((e) => !e.value.deleted).map((e) => MapEntry(e.key, e.value.value));

  int get length => map.values.where((e) => !e.deleted).length;
  bool get isEmpty => length == 0;

  /// Set value with timestamp (caller provides Lamport + OpID)
  void set(K key, V value, Lamport lamport, OpID opId) {
    final existing = map[key];
    if (existing != null) {
      // Compare timestamps
      if (lamport > existing.lamport ||
          (lamport == existing.lamport && opId.compareTo(existing.opId) > 0)) {
        map[key] = existing.copyWith(value: value, lamport: lamport, opId: opId, deleted: false);
      }
    } else {
      map[key] = LWWEntry<V>(value: value, lamport: lamport, opId: opId);
    }
  }

  /// Delete key (tombstone with timestamp)
  void delete(K key, Lamport lamport, OpID opId) {
    final existing = map[key];
    if (existing != null) {
      if (lamport > existing.lamport ||
          (lamport == existing.lamport && opId.compareTo(existing.opId) > 0)) {
        map[key] = existing.copyWith(lamport: lamport, opId: opId, deleted: true);
      }
    } else {
      // Delete non-existent key — create tombstone
      map[key] = LWWEntry<V>(
        value: null as V,
        lamport: lamport,
        opId: opId,
        deleted: true,
      );
    }
  }

  /// Merge another LWWMap into this one
  void merge(LWWMap<K, V> other) {
    for (final entry in other.map.entries) {
      final key = entry.key;
      final otherEntry = entry.value;
      final existing = map[key];

      if (existing == null) {
        map[key] = otherEntry;
      } else {
        // Compare timestamps
        if (otherEntry.lamport > existing.lamport ||
            (otherEntry.lamport == existing.lamport &&
                otherEntry.opId.compareTo(existing.opId) > 0)) {
          map[key] = otherEntry;
        }
      }
    }
  }

  /// Get all entries including tombstones (for serialization)
  Map<K, LWWEntry<V>> getAllEntries() => Map.unmodifiable(map);

  /// Clear all entries
  void clear() => map.clear();

  /// Serialize to JSON
  Map<String, dynamic> toJson({
    required String Function(K) keyToString,
    required String Function(V) valueToString,
  }) {
    return map.map((k, v) => MapEntry(
      keyToString(k),
      {
        'value': valueToString(v.value),
        'lamport': v.lamport.value,
        'opId': v.opId.toJson(),
        'deleted': v.deleted,
      },
    ));
  }

  /// Deserialize from JSON
  static LWWMap<K, V> fromJson<K, V>(
    Map<String, dynamic> json, {
    required K Function(String) keyFromString,
    required V Function(String) valueFromString,
  }) {
    final map = LWWMap<K, V>();
    for (final entry in json.entries) {
      final entryMap = entry.value as Map<String, dynamic>;
      map.map[keyFromString(entry.key)] = LWWEntry<V>(
        value: valueFromString(entryMap['value'] as String),
        lamport: Lamport(entryMap['lamport'] as int),
        opId: OpID.fromJson(entryMap['opId'] as Map<String, dynamic>),
        deleted: entryMap['deleted'] as bool? ?? false,
      );
    }
    return map;
  }

  @override
  String toString() => 'LWWMap{$length entries}';
}

/// Mergeable Map Key — for nested containers in map values
/// Tracks which keys activate mergeable child containers
class MergeableKeyTracker {
  final Map<String, ContainerType> _mergeableKeys = {};

  // Public accessors for encoding/decoding
  Map<String, ContainerType> get mergeableKeysValue => _mergeableKeys;
  set mergeableKeysValue(Map<String, ContainerType> value) {
    _mergeableKeys.clear();
    _mergeableKeys.addAll(value);
  }

  /// Mark a key as holding a mergeable container of given type
  void setMergeable(String key, ContainerType type) {
    _mergeableKeys[key] = type;
  }

  /// Get the mergeable container type for a key
  ContainerType? getMergeableType(String key) => _mergeableKeys[key];

  /// Check if key is a mergeable container
  bool isMergeable(String key) => _mergeableKeys.containsKey(key);

  /// Remove mergeable marker (but keep child state)
  void removeMergeable(String key) => _mergeableKeys.remove(key);

  /// Get all mergeable keys
  Iterable<String> get mergeableKeys => _mergeableKeys.keys;

  Map<String, ContainerType> toJson() => Map.from(_mergeableKeys);

  static MergeableKeyTracker fromJson(Map<String, dynamic> json) {
    final tracker = MergeableKeyTracker();
    json.forEach((k, v) {
      tracker._mergeableKeys[k] = ContainerType.values.firstWhere(
        (t) => t.name == v,
        orElse: () => ContainerType.unknown,
      );
    });
    return tracker;
  }
}