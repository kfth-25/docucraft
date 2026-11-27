// DocuCraft CRDT — Container Abstractions
// Interface terpadu untuk semua tipe container CRDT
// Port dari loro-js: container logic

import 'dart:collection';
import 'dart:math';
import 'id.dart';
import 'sequence_index.dart';
import 'lww_map.dart';
import 'text_crdt.dart';
import 'fractional_index.dart';

/// Base trait for all CRDT containers
abstract class CRDTContainer {
  ContainerID get id;
  ContainerType get type;
  bool get isDeleted;
  Map<String, dynamic> toJson();
  void merge(CRDTContainer other);
}

/// Container factory for creating detached containers
class ContainerFactory {
  static CRDTList createList({ContainerID? id}) => CRDTList(id: id ?? ContainerID.root(ContainerType.list));
  static CRDTMovableList createMovableList({ContainerID? id}) => CRDTMovableList(id: id ?? ContainerID.root(ContainerType.movableList));
  static CRDTMap createMap({ContainerID? id}) => CRDTMap(id: id ?? ContainerID.root(ContainerType.map));
  static CRDTText createText({ContainerID? id, required PeerID peerId}) => CRDTText(id: id ?? ContainerID.root(ContainerType.text), peerId: peerId);
  static CRDTTree createTree({ContainerID? id}) => CRDTTree(id: id ?? ContainerID.root(ContainerType.tree));
  static CRDTCounter createCounter({ContainerID? id}) => CRDTCounter(id: id ?? ContainerID.root(ContainerType.counter));
}

/// CRDT List — RGA-based (insert/delete only, no move)
class CRDTList implements CRDTContainer {
  @override
  final ContainerID id;
  final SequenceIndex _sequence = SequenceIndex();
  bool _deleted = false;

  CRDTList({required this.id});

  @override
  ContainerType get type => ContainerType.list;

  @override
  bool get isDeleted => _deleted;

  void delete() => _deleted = true;

  // Public accessors for encoding/decoding
  SequenceIndex get sequenceValue => _sequence;
  set sequenceValue(SequenceIndex value) => _sequence
    ..itemsValue = value.itemsValue
    ..blocksValue = value.blocksValue
    ..idToIndexValue = value.idToIndexValue
    ..deletedIndicesValue = value.deletedIndicesValue
    ..fractionalIndicesValue = value.fractionalIndicesValue;

  // ─── List Operations ───

  /// Insert value at position (among alive items)
  void insert(int index, dynamic value) {
    final opId = OpID.create(PeerID.random(), Lamport.zero()); // Will be set by doc
    final item = SequenceItem(id: opId, value: value);
    _sequence.insert(index, item);
  }

  /// Delete item at position
  bool deleteAt(int index) => _sequence.delete(index);

  /// Get value at position
  dynamic get(int index) => _sequence.get(index)?.value;

  /// Get all alive values
  List<dynamic> getValues() => _sequence.getAliveItems().map((item) => item.value).toList();

  /// Get length (alive items only)
  int get length => _sequence.aliveLength;

  bool get isEmpty => _sequence.aliveLength == 0;

  /// Find index of value (first occurrence)
  int? indexOf(dynamic value) {
    for (int i = 0; i < _sequence.length; i++) {
      final item = _sequence.get(i);
      if (item != null && !item.deleted && item.value == value) return i;
    }
    return null;
  }

  /// Iterate alive items
  Iterable<dynamic> get aliveValues => _sequence.getAliveItems().map((item) => item.value);

  @override
  Map<String, dynamic> toJson() => _sequence.toJson();

  @override
  void merge(CRDTContainer other) {
    if (other is CRDTList) {
      // Merge is handled at document level via OpIDs
    }
  }
}

/// CRDT Movable List — FractionalIndex-based (supports move/set)
class CRDTMovableList implements CRDTContainer {
  @override
  final ContainerID id;
  final SequenceIndex _sequence = SequenceIndex();
  bool _deleted = false;

  CRDTMovableList({required this.id});

  @override
  ContainerType get type => ContainerType.movableList;

  @override
  bool get isDeleted => _deleted;

  void delete() => _deleted = true;

  // Public accessors for encoding/decoding
  SequenceIndex get sequenceValue => _sequence;
  set sequenceValue(SequenceIndex value) => _sequence
    ..itemsValue = value.itemsValue
    ..blocksValue = value.blocksValue
    ..idToIndexValue = value.idToIndexValue
    ..deletedIndicesValue = value.deletedIndicesValue
    ..fractionalIndicesValue = value.fractionalIndicesValue;

  // ─── Movable List Operations ───

  void insert(int index, dynamic value, {OpID? opId}) {
    final item = SequenceItem(id: opId ?? OpID.create(PeerID.random(), Lamport.zero()), value: value);
    _sequence.insert(index, item);
  }

  bool deleteAt(int index) => _sequence.delete(index);

  dynamic get(int index) => _sequence.get(index)?.value;

  void set(int index, dynamic value) => _sequence.set(index, _sequence.get(index)!.copyWith(value: value));

  /// Move item from one position to another
  void move(int fromIndex, int toIndex) => _sequence.move(fromIndex, toIndex);

  List<dynamic> getValues() => _sequence.getAliveItems().map((item) => item.value).toList();

  int get length => _sequence.aliveLength;

  bool get isEmpty => _sequence.aliveLength == 0;

  @override
  Map<String, dynamic> toJson() => _sequence.toJson();

  @override
  void merge(CRDTContainer other) {}
}

/// CRDT Map — LWW per key with mergeable children support
class CRDTMap implements CRDTContainer {
  @override
  final ContainerID id;
  final LWWMap<String, dynamic> _map = LWWMap();
  final MergeableKeyTracker _mergeableKeys = MergeableKeyTracker();
  bool _deleted = false;

  CRDTMap({required this.id});

  @override
  ContainerType get type => ContainerType.map;

  @override
  bool get isDeleted => _deleted;

  void delete() => _deleted = true;

  // Public accessors for encoding/decoding
  LWWMap<String, dynamic> get mapValue => _map;
  set mapValue(LWWMap<String, dynamic> value) => _map
    ..mapValue = value.mapValue;

  MergeableKeyTracker get mergeableKeysValue => _mergeableKeys;
  set mergeableKeysValue(MergeableKeyTracker value) => _mergeableKeys
    ..mergeableKeysValue = value.mergeableKeysValue;

  // ─── Map Operations ───

  void set(String key, dynamic value, {required Lamport lamport, required OpID opId}) {
    _map.set(key, value, lamport, opId);
  }

  dynamic get(String key) => _map.get(key);

  bool containsKey(String key) => _map.containsKey(key);

  void deleteKey(String key, {required Lamport lamport, required OpID opId}) {
    _map.delete(key, lamport, opId);
  }

  Iterable<String> get keys => _map.keys;

  Iterable<MapEntry<String, dynamic>> get entries => _map.entries;

  int get length => _map.length;

  bool get isEmpty => _map.isEmpty;

  // ─── Mergeable Children ───

  /// Mark a key as holding a mergeable child container
  void setMergeableChild(String key, ContainerType type) {
    _mergeableKeys.setMergeable(key, type);
  }

  ContainerType? getMergeableChildType(String key) => _mergeableKeys.getMergeableType(key);

  bool isMergeableChild(String key) => _mergeableKeys.isMergeable(key);

  Iterable<String> get mergeableKeys => _mergeableKeys.mergeableKeys;

  @override
  Map<String, dynamic> toJson() => {
    'map': _map.toJson(
      keyToString: (k) => k,
      valueToString: (v) => v.toString(),
    ),
    'mergeableKeys': _mergeableKeys.toJson(),
  };

  @override
  void merge(CRDTContainer other) {
    if (other is CRDTMap) {
      _map.merge(other._map);
      // Mergeable keys: union
      for (final key in other._mergeableKeys.mergeableKeys) {
        if (!_mergeableKeys.isMergeable(key)) {
          _mergeableKeys.setMergeable(key, other._mergeableKeys.getMergeableType(key)!);
        }
      }
    }
  }
}

/// CRDT Text — Rich text with marks
class CRDTText implements CRDTContainer {
  @override
  final ContainerID id;
  final TextCRDT _text;
  bool _deleted = false;

  CRDTText({required this.id, required PeerID peerId}) : _text = TextCRDT(peerId);

  @override
  ContainerType get type => ContainerType.text;

  @override
  bool get isDeleted => _deleted;

  void delete() => _deleted = true;

  // Public accessors for encoding/decoding
  TextCRDT get textValue => _text;
  set textValue(TextCRDT value) => _text.sequenceValue = value.sequenceValue;

  // ─── Text Operations ───

  String get text => _text.text;

  int get length => _text.length;

  int get lengthUtf16 => _text.lengthUtf16;

  int get lengthUtf8 => _text.lengthUtf8;

  void insert(int pos, String str, {Map<String, dynamic>? attributes}) {
    _text.insert(pos, str, attributes: attributes);
  }

  bool deleteText(int pos, int len) => _text.delete(pos, len);

  String slice(int start, int end) => _text.slice(start, end);

  String? charAt(int pos) => _text.charAt(pos);

  void mark(int start, int end, String key, dynamic value) => _text.mark(start, end, key, value);

  void unmark(int start, int end, String key) => _text.unmark(start, end, key);

  TextDelta toDelta() => _text.toDelta();

  void applyDelta(TextDelta delta) => _text.applyDelta(delta);

  Iterable<(String, Map<String, dynamic>?)> iterChunks() => _text.iterChunks();

  @override
  Map<String, dynamic> toJson() => _text.toJson();

  static CRDTText fromJson(ContainerID id, PeerID peerId, Map<String, dynamic> json) {
    return CRDTText(id: id, peerId: peerId); // TextCRDT.fromJson would be called
  }

  @override
  void merge(CRDTContainer other) {}
}

/// CRDT Tree — Hierarchical structure with fractional indexing
class CRDTTree implements CRDTContainer {
  @override
  final ContainerID id;
  final Map<TreeID, TreeNode> nodes = {};
  final Map<TreeID, String> _fractionalIndices = {}; // TreeID -> fractional index
  bool _deleted = false;

  CRDTTree({required this.id});

  @override
  ContainerType get type => ContainerType.tree;

  @override
  bool get isDeleted => _deleted;

  void delete() => _deleted = true;

  // Public accessors for encoding/decoding
  Map<TreeID, TreeNode> get nodesValue => nodes;
  set nodesValue(Map<TreeID, TreeNode> value) => nodes
    ..clear()
    ..addAll(value);

  Map<TreeID, String> get fractionalIndicesValue => _fractionalIndices;
  set fractionalIndicesValue(Map<TreeID, String> value) => _fractionalIndices
    ..clear()
    ..addAll(value);

  // ─── Tree Operations ───

  /// Create a new node, return its TreeID
  TreeID create({TreeParentId? parent}) {
    final treeId = TreeID.random();
    final parentId = parent is TreeParentNode ? parent.id : null;
    final fractionalIndex = parentId != null
        ? TreeFractionalIndex.childOf(_getFractionalIndex(parentId), afterSibling: null)
        : FractionalIndex.initial();

    nodes[treeId] = TreeNode(
      id: treeId,
      parent: parent ?? TreeParentRoot(),
      fractionalIndex: fractionalIndex,
      meta: LWWMap(),
    );
    _fractionalIndices[treeId] = fractionalIndex;
    return treeId;
  }

  TreeID? createAt(TreeParentId parent, int index) {
    // Find children of parent, insert at index
    final children = getChildren(parent);
    String? afterSibling;
    if (index > 0 && index <= children.length) {
      afterSibling = _fractionalIndices[children[index - 1]] ?? '';
    }
    final treeId = TreeID.random();
    final parentId = parent is TreeParentNode ? parent.id : null;
    final fractionalIndex = TreeFractionalIndex.childOf(
      _getFractionalIndex(parentId),
      afterSibling: afterSibling,
    );

    nodes[treeId] = TreeNode(
      id: treeId,
      parent: parent,
      fractionalIndex: fractionalIndex,
      meta: LWWMap(),
    );
    _fractionalIndices[treeId] = fractionalIndex;
    return treeId;
  }

  void move(TreeID target, TreeParentId newParent) {
    final node = nodes[target];
    if (node == null) return;
    node.parent = newParent;
    final parentId = newParent is TreeParentNode ? newParent.id : null;
    final newFracIdx = TreeFractionalIndex.childOf(_getFractionalIndex(parentId), afterSibling: null);
    node.fractionalIndex = newFracIdx;
    _fractionalIndices[target] = newFracIdx;
  }

  void moveTo(TreeID target, TreeParentId newParent, int index) {
    move(target, newParent); // Simplified
  }

  void moveAfter(TreeID target, TreeID after) {
    final node = nodes[target];
    if (node == null) return;
    node.fractionalIndex = TreeFractionalIndex.nextSibling(after.toString()) ?? node.fractionalIndex;
    _fractionalIndices[target] = node.fractionalIndex;
  }

  void moveBefore(TreeID target, TreeID before) {
    final node = nodes[target];
    if (node == null) return;
    node.fractionalIndex = TreeFractionalIndex.prevSibling(before.toString()) ?? node.fractionalIndex;
    _fractionalIndices[target] = node.fractionalIndex;
  }

  void deleteNode(TreeID target) {
    nodes.remove(target);
    _fractionalIndices.remove(target);
  }

  TreeNode? getNode(TreeID target) => nodes[target];

  TreeNode? getMeta(TreeID target) => nodes[target];

  TreeParentId? getParent(TreeID target) => nodes[target]?.parent;

  bool contains(TreeID target) => nodes.containsKey(target);

  bool isNodeDeleted(TreeID target) => !nodes.containsKey(target);

  List<TreeID> getAllNodes() => nodes.keys.toList();

  List<TreeID> getChildren(TreeParentId parent) {
    final parentId = parent is TreeParentNode ? parent.id : null;
    return nodes.entries
        .where((e) => _parentMatches(e.value.parent, parentId))
        .map((e) => e.key)
        .toList()
      ..sort((a, b) => TreeFractionalIndex.compare(
        _fractionalIndices[a] ?? '',
        _fractionalIndices[b] ?? '',
      ));
  }

  int? getChildrenCount(TreeParentId parent) => getChildren(parent).length;

  String? getFractionalIndex(TreeID target) => _fractionalIndices[target];

  void enableFractionalIndex(int jitter) {
    // Jitter not implemented in this simplified version
  }

  void disableFractionalIndex() {}

  bool get isFractionalIndexEnabled => true;

  bool get isEmpty => nodes.isEmpty;

  String _getFractionalIndex(TreeID? id) {
    if (id == null) return '';
    return _fractionalIndices[id] ?? '';
  }

  bool _parentMatches(TreeParentId? nodeParent, TreeID? expectedParent) {
    if (expectedParent == null) return nodeParent is TreeParentRoot;
    if (nodeParent is TreeParentNode) return nodeParent.id == expectedParent;
    return false;
  }

  @override
  Map<String, dynamic> toJson() => {
    'nodes': nodes.map((k, v) => MapEntry(k.value.toString(), {
      'parent': v.parent is TreeParentNode ? (v.parent as TreeParentNode).id.value.toString() : 'root',
      'fractionalIndex': v.fractionalIndex,
      'meta': v.meta.toJson(keyToString: (k) => k, valueToString: (v) => v.toString()),
    })),
  };

  @override
  void merge(CRDTContainer other) {}
}

/// Tree Node
class TreeNode {
  final TreeID id;
  TreeParentId parent;
  String fractionalIndex;
  final LWWMap<String, dynamic> meta;

  TreeNode({
    required this.id,
    required this.parent,
    required this.fractionalIndex,
    required this.meta,
  });
}

/// CRDT Counter — PN-Counter (Positive-Negative Counter)
class CRDTCounter implements CRDTContainer {
  @override
  final ContainerID id;
  final Map<PeerID, int> positive = {};
  final Map<PeerID, int> negative = {};
  bool _deleted = false;

  CRDTCounter({required this.id});

  @override
  ContainerType get type => ContainerType.counter;

  @override
  bool get isDeleted => _deleted;

  void delete() => _deleted = true;

  int get value {
    final pos = positive.values.fold(0, (a, b) => a + b);
    final neg = negative.values.fold(0, (a, b) => a + b);
    return pos - neg;
  }

  void increment(PeerID peer, [int delta = 1]) {
    positive[peer] = (positive[peer] ?? 0) + delta;
  }

  void decrement(PeerID peer, [int delta = 1]) {
    negative[peer] = (negative[peer] ?? 0) + delta;
  }

  void mergeCounter(CRDTCounter other) {
    for (final entry in other.positive.entries) {
      positive[entry.key] = _max(positive[entry.key] ?? 0, entry.value);
    }
    for (final entry in other.negative.entries) {
      negative[entry.key] = _max(negative[entry.key] ?? 0, entry.value);
    }
  }

  int _max(int a, int b) => a > b ? a : b;

  @override
  Map<String, dynamic> toJson() => {
    'positive': positive.map((k, v) => MapEntry(k.value.toString(), v)),
    'negative': negative.map((k, v) => MapEntry(k.value.toString(), v)),
  };

  @override
  void merge(CRDTContainer other) {
    if (other is CRDTCounter) mergeCounter(other);
  }
}