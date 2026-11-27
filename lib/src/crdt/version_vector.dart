// DocuCraft CRDT — Version Vector & Frontiers
// Port dari loro-js: version-vector.ts, version-vector.ts

import 'dart:collection';
import 'dart:convert';
import 'id.dart';

/// Deep collection equality helper
class _DeepCollectionEquality {
  const _DeepCollectionEquality();

  bool equals(Map<PeerID, Lamport> a, Map<PeerID, Lamport> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final bValue = b[entry.key];
      if (bValue == null) return false;
      if (entry.value != bValue) return false;
    }
    return true;
  }
}

/// Version Vector — maps PeerID -> Lamport counter
/// Represents the "frontier" of known operations per peer
class VersionVector {
  final Map<PeerID, Lamport> _map;

  VersionVector._(this._map);

  factory VersionVector.empty() => VersionVector._(<PeerID, Lamport>{});

  factory VersionVector.fromMap(Map<PeerID, Lamport> map) =>
      VersionVector._(Map.unmodifiable(Map.from(map)));

  factory VersionVector.fromJson(Map<String, dynamic> json) {
    final map = <PeerID, Lamport>{};
    for (final entry in json.entries) {
      map[PeerID.fromInt(int.parse(entry.key))] = Lamport(entry.value as int);
    }
    return VersionVector._(map);
  }

  /// Get the Lamport for a peer (0 if not present)
  Lamport get(PeerID peer) => _map[peer] ?? Lamport.zero();

  /// Set the Lamport for a peer
  VersionVector set(PeerID peer, Lamport lamport) {
    final newMap = Map<PeerID, Lamport>.from(_map);
    if (lamport.value == 0) {
      newMap.remove(peer);
    } else {
      newMap[peer] = lamport;
    }
    return VersionVector._(newMap);
  }

  /// Increment the counter for a peer
  VersionVector increment(PeerID peer) {
    return set(peer, get(peer).next());
  }

  /// Merge two version vectors (take max per peer)
  VersionVector merge(VersionVector other) {
    final allPeers = <PeerID>{..._map.keys, ...other._map.keys};
    final merged = <PeerID, Lamport>{};
    for (final peer in allPeers) {
      final a = get(peer);
      final b = other.get(peer);
      merged[peer] = a.value >= b.value ? a : b;
    }
    return VersionVector._(merged);
  }

  /// Check if this vector dominates another (>= for all peers)
  bool dominates(VersionVector other) {
    for (final entry in other._map.entries) {
      if (get(entry.key) < entry.value) return false;
    }
    return true;
  }

  /// Check if this vector is strictly less than another
  bool isStrictlyLessThan(VersionVector other) {
    if (dominates(other)) return false; // equal or greater
    return other.dominates(this);
  }

  /// Check if two version vectors are concurrent (neither dominates)
  bool isConcurrentWith(VersionVector other) {
    return !dominates(other) && !other.dominates(this);
  }

  /// Get all peers in this vector
  Iterable<PeerID> get peers => _map.keys;

  /// Get number of peers
  int get length => _map.length;

  bool get isEmpty => _map.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is VersionVector && _DeepCollectionEquality().equals(_map, other._map);

  @override
  int get hashCode => Object.hashAll(_map.entries.map((e) => Object.hash(e.key, e.value)));

  @override
  String toString() => 'VV{${_map.entries.map((e) => '${e.key.value}@${e.value.value}').join(', ')}}';

  Map<String, dynamic> toJson() {
    return _map.map((k, v) => MapEntry(k.value.toString(), v.value));
  }

  Map<String, dynamic> toJsonStringKeys() => toJson();
}

/// Frontiers — compressed version vector for efficient storage/sync
/// Only stores peers that have non-zero counters
class Frontiers {
  final Map<PeerID, Lamport> _map;

  Frontiers._(this._map);

  factory Frontiers.empty() => Frontiers._(<PeerID, Lamport>{});

  factory Frontiers.fromVersionVector(VersionVector vv) {
    final map = <PeerID, Lamport>{};
    for (final entry in vv._map.entries) {
      if (entry.value.value > 0) {
        map[entry.key] = entry.value;
      }
    }
    return Frontiers._(map);
  }

  factory Frontiers.fromJson(Map<String, dynamic> json) {
    final map = <PeerID, Lamport>{};
    for (final entry in json.entries) {
      map[PeerID.fromInt(int.parse(entry.key))] = Lamport(entry.value as int);
    }
    return Frontiers._(map);
  }

  Lamport get(PeerID peer) => _map[peer] ?? Lamport.zero();

  VersionVector toVersionVector() => VersionVector.fromMap(_map);

  Frontiers merge(Frontiers other) {
    return Frontiers.fromVersionVector(toVersionVector().merge(other.toVersionVector()));
  }

  bool dominates(Frontiers other) => toVersionVector().dominates(other.toVersionVector());

  @override
  bool operator ==(Object other) =>
      other is Frontiers && _DeepCollectionEquality().equals(_map, other._map);

  @override
  int get hashCode => Object.hashAll(_map.entries.map((e) => Object.hash(e.key, e.value)));

  @override
  String toString() => 'Frontiers{${_map.entries.map((e) => '${e.key.value}@${e.value.value}').join(', ')}}';

  Map<String, dynamic> toJson() => _map.map((k, v) => MapEntry(k.value.toString(), v.value));

  int get length => _map.length;
  bool get isEmpty => _map.isEmpty;
}

/// ImVersionVector — immutable version vector for shallow snapshots
/// Represents the "since" version for shallow clones
class ImVersionVector {
  final Map<PeerID, Lamport> _map;

  ImVersionVector._(this._map);

  factory ImVersionVector.empty() => ImVersionVector._(<PeerID, Lamport>{});

  factory ImVersionVector.fromFrontiers(Frontiers f) => ImVersionVector._(Map.from(f._map));

  VersionVector toVersionVector() => VersionVector.fromMap(_map);

  @override
  String toString() => 'ImVV{${_map.entries.map((e) => '${e.key.value}@${e.value.value}').join(', ')}}';
}

/// Version Range — represents a range of versions for diff/export
class VersionRange {
  final Frontiers start;
  final Frontiers end;

  VersionRange({required this.start, required this.end});

  factory VersionRange.fromJson(Map<String, dynamic> json) {
    return VersionRange(
      start: Frontiers.fromJson(json['start'] as Map<String, dynamic>),
      end: Frontiers.fromJson(json['end'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
    'start': start.toJson(),
    'end': end.toJson(),
  };
}

/// Version Vector Diff — represents the difference between two versions
class VersionVectorDiff {
  final List<IdSpan> forward;
  final List<IdSpan> backward;

  VersionVectorDiff({required this.forward, required this.backward});

  bool get isEmpty => forward.isEmpty && backward.isEmpty;

  Map<String, dynamic> toJson() => {
    'forward': forward.map((s) => s.toJson()).toList(),
    'backward': backward.map((s) => s.toJson()).toList(),
  };
}

/// ID Span — a contiguous range of operation IDs from a single peer
class IdSpan {
  final PeerID peer;
  final int start; // inclusive
  final int end; // exclusive

  IdSpan({required this.peer, required this.start, required this.end});

  factory IdSpan.fromJson(Map<String, dynamic> json) {
    return IdSpan(
      peer: PeerID.fromInt(json['peer'] as int),
      start: json['start'] as int,
      end: json['end'] as int,
    );
  }

  int get length => end - start;

  bool get isEmpty => start >= end;

  bool contains(int lamport) => lamport >= start && lamport < end;

  Map<String, dynamic> toJson() => {
    'peer': peer.value,
    'start': start,
    'end': end,
  };

  @override
  String toString() => 'IdSpan(${peer.value}[$start, $end))';
}