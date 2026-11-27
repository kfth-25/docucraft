// DocuCraft CRDT — Core ID Types
// Port dari loro-js: ids.ts, version-vector.ts

import 'dart:typed_data';
import 'dart:math';
import 'package:collection/collection.dart';

/// Unique identifier for a peer (device/user session)
/// Uses 64-bit random integer (compatible with Loro's PeerID)
class PeerID {
  final int value;

  const PeerID(this.value);

  factory PeerID.random() {
    return PeerID(Random.secure().nextInt(1 << 30)); // 30 bits for compatibility
  }

  factory PeerID.fromInt(int value) => PeerID(value);

  @override
  bool operator ==(Object other) => other is PeerID && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'PeerID($value)';

  int toInt() => value;
}

/// Lamport timestamp — logical clock for causal ordering
class Lamport {
  final int value;

  const Lamport(this.value);

  factory Lamport.zero() => const Lamport(0);

  Lamport next() => Lamport(value + 1);

  Lamport max(Lamport other) => Lamport(value > other.value ? value : other.value);

  @override
  bool operator ==(Object other) => other is Lamport && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Lamport($value)';

  bool operator <(Lamport other) => value < other.value;
  bool operator <=(Lamport other) => value <= other.value;
  bool operator >(Lamport other) => value > other.value;
  bool operator >=(Lamport other) => value >= other.value;
}

/// Operation ID — uniquely identifies an operation in the CRDT
/// Combines peer ID + Lamport counter (similar to Loro's OpID)
class OpID implements Comparable<OpID> {
  final PeerID peer;
  final Lamport lamport;

  const OpID(this.peer, this.lamport);

  factory OpID.create(PeerID peer, Lamport lamport) => OpID(peer, lamport);

  @override
  int compareTo(OpID other) {
    final lamportCmp = lamport.value.compareTo(other.lamport.value);
    if (lamportCmp != 0) return lamportCmp;
    return peer.value.compareTo(other.peer.value);
  }

  @override
  bool operator ==(Object other) =>
      other is OpID && other.peer == peer && other.lamport == lamport;

  @override
  int get hashCode => Object.hash(peer, lamport);

  @override
  String toString() => 'OpID(${peer.value}@${lamport.value})';

  Map<String, dynamic> toJson() => {'peer': peer.value, 'lamport': lamport.value};

  static OpID fromJson(Map<String, dynamic> json) =>
      OpID(PeerID.fromInt(json['peer'] as int), Lamport(json['lamport'] as int));
}

/// Container ID — identifies a CRDT container (List, Map, Text, Tree, MovableList)
/// Format: "cid:<type>:<origin>" where origin can be root or op-based
class ContainerID {
  final String value;

  const ContainerID._(this.value);

  factory ContainerID.root(ContainerType type, {String name = 'root'}) {
    return ContainerID._('cid:root-$type:$name');
  }

  factory ContainerID.fromOp(ContainerType type, OpID opId) {
    return ContainerID._('cid:${opId.peer.value}@${opId.lamport.value}:$type');
  }

  factory ContainerID.mergeableChild(ContainerType type, String parentKey) {
    // Deterministic ID for mergeable children: hash(parent_container + key + type)
    final hash = parentKey.hashCode ^ type.index;
    return ContainerID._('cid:mergeable-$type:$hash');
  }

  factory ContainerID.parse(String str) => ContainerID._(str);

  ContainerType get type {
    final parts = value.split(':');
    if (parts.length < 2) return ContainerType.unknown;
    final typeStr = parts[1].split('-').first;
    return ContainerType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => ContainerType.unknown,
    );
  }

  bool get isRoot => value.startsWith('cid:root-');
  bool get isMergeable => value.startsWith('cid:mergeable-');

  @override
  bool operator ==(Object other) => other is ContainerID && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;

  String toJson() => value;

  static ContainerID fromJson(String json) => ContainerID.parse(json);
}

/// Types of CRDT containers
enum ContainerType {
  list,           // RGA List (insert/delete only)
  movableList,    // FractionalIndex List (move/set supported)
  map,            // LWW Map
  text,           // Fugue/RGA Text
  tree,           // FractionalIndex Tree
  counter,        // PN-Counter
  unknown,
}

/// Unique ID for tree nodes
class TreeID {
  final int value;

  const TreeID(this.value);

  factory TreeID.random() => TreeID(Random.secure().nextInt(1 << 30));

  @override
  bool operator ==(Object other) => other is TreeID && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'TreeID($value)';
}

/// Parent reference for tree nodes
abstract class TreeParentId {
  const TreeParentId();
}

class TreeParentRoot extends TreeParentId {
  const TreeParentRoot() : super();
}

class TreeParentNode extends TreeParentId {
  final TreeID id;
  const TreeParentNode(this.id) : super();
}

class TreeParentDeleted extends TreeParentId {
  const TreeParentDeleted() : super();
}

class TreeParentUnexist extends TreeParentId {
  const TreeParentUnexist() : super();
}