// DocuCraft CRDT — Sequence Index (RLE-based)
// Struktur data inti untuk List dan Text CRDT
// Port dari loro-js: sequence-index.ts, sequence-deletion-index.ts

import 'dart:collection';
import 'dart:typed_data';
import 'id.dart';

/// Represents an item in the sequence (character for text, element for list)
class SequenceItem {
  final OpID id;
  final dynamic value; // String for text, any for list
  final Map<String, dynamic>? attributes; // For rich text marks
  bool _deleted = false;

  SequenceItem({required this.id, required this.value, this.attributes});

  bool get deleted => _deleted;

  void delete() => _deleted = true;

  void undelete() => _deleted = false;

  SequenceItem copyWith({dynamic value, Map<String, dynamic>? attributes}) {
    return SequenceItem(
      id: id,
      value: value ?? this.value,
      attributes: attributes ?? this.attributes,
    );
  }

  @override
  String toString() => 'Item(${id}, ${deleted ? 'DEL' : value})';
}

/// RLE (Run-Length Encoding) block for efficient storage
/// Stores consecutive items with same "deleted" status
class RLEBlock {
  final int startIndex; // Index in the flat item list
  final int length;
  final bool deleted;

  RLEBlock({required this.startIndex, required this.length, required this.deleted});

  bool get isDeleted => deleted;

  RLEBlock copyWith({int? startIndex, int? length, bool? deleted}) {
    return RLEBlock(
      startIndex: startIndex ?? this.startIndex,
      length: length ?? this.length,
      deleted: deleted ?? this.deleted,
    );
  }

  @override
  String toString() => 'RLEBlock(start=$startIndex, len=$length, del=$deleted)';
}

/// Sequence Index — RLE-based ordered sequence CRDT
/// Supports: insert, delete, get, iterate, move (for movable list)
class SequenceIndex {
  final List<SequenceItem> _items = [];
  final List<RLEBlock> _blocks = []; // RLE compression of deleted/alive runs
  final Map<OpID, int> _idToIndex = {}; // OpID -> item index
  final List<int> _deletedIndices = []; // Indices of deleted items (for GC)

  // For movable list: fractional index support
  final Map<OpID, String> _fractionalIndices = {};

  // Public getters/setters for serialization (used by containers)
  List<SequenceItem> get itemsValue => _items;
  set itemsValue(List<SequenceItem> value) {
    _items.clear();
    _items.addAll(value);
  }

  List<RLEBlock> get blocksValue => _blocks;
  set blocksValue(List<RLEBlock> value) {
    _blocks.clear();
    _blocks.addAll(value);
  }

  Map<OpID, int> get idToIndexValue => _idToIndex;
  set idToIndexValue(Map<OpID, int> value) {
    _idToIndex.clear();
    _idToIndex.addAll(value);
  }

  List<int> get deletedIndicesValue => _deletedIndices;
  set deletedIndicesValue(List<int> value) {
    _deletedIndices.clear();
    _deletedIndices.addAll(value);
  }

  Map<OpID, String> get fractionalIndicesValue => _fractionalIndices;
  set fractionalIndicesValue(Map<OpID, String> value) {
    _fractionalIndices.clear();
    _fractionalIndices.addAll(value);
  }

  int get length => _items.length;
  int get aliveLength => _items.where((item) => !item.deleted).length;
  bool get isEmpty => _items.isEmpty;

  /// Get item by index (includes deleted)
  SequenceItem? get(int index) {
    if (index < 0 || index >= _items.length) return null;
    return _items[index];
  }

  /// Get item by OpID
  SequenceItem? getById(OpID id) {
    final index = _idToIndex[id];
    if (index == null) return null;
    return _items[index];
  }

  /// Get index of item by OpID
  int? indexOf(OpID id) => _idToIndex[id];

  /// Get all alive items in order
  List<SequenceItem> getAliveItems() {
    return _items.where((item) => !item.deleted).toList();
  }

  /// Get alive items with their indices
  List<(int, SequenceItem)> getAliveWithIndices() {
    final result = <(int, SequenceItem)>[];
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (!item.deleted) {
        result.add((i, item));
      }
    }
    return result;
  }

  /// Insert item at position (among alive items)
  void insert(int aliveIndex, SequenceItem item) {
    // Convert alive index to actual index
    int actualIndex = _aliveToActualIndex(aliveIndex);

    _items.insert(actualIndex, item);
    _idToIndex[item.id] = actualIndex;

    // Update indices after insertion point
    _shiftIndices(actualIndex + 1, 1);

    // Update RLE blocks
    _insertBlock(actualIndex, false);

    // Rebuild fractional indices if needed
    _rebuildFractionalIndices();
  }

  /// Delete item at alive index
  bool delete(int aliveIndex) {
    final actualIndex = _aliveToActualIndex(aliveIndex);
    if (actualIndex < 0 || actualIndex >= _items.length) return false;

    final item = _items[actualIndex];
    if (item.deleted) return false;

    item.delete();
    _markBlockDeleted(actualIndex);
    _deletedIndices.add(actualIndex);
    return true;
  }

  /// Delete item by OpID
  bool deleteById(OpID id) {
    final index = _idToIndex[id];
    if (index == null) return false;
    if (_items[index].deleted) return false;

    _items[index].delete();
    _markBlockDeleted(index);
    _deletedIndices.add(index);
    return true;
  }

  /// Undelete item by OpID (for undo)
  bool undeleteById(OpID id) {
    final index = _idToIndex[id];
    if (index == null) return false;
    if (!_items[index].deleted) return false;

    _items[index].undelete();
    _markBlockAlive(index);
    _deletedIndices.remove(index);
    return true;
  }

  /// Move item from one alive index to another (for movable list)
  void move(int fromAliveIndex, int toAliveIndex) {
    if (fromAliveIndex == toAliveIndex) return;

    final fromActual = _aliveToActualIndex(fromAliveIndex);
    final item = _items.removeAt(fromActual);

    final toActual = _aliveToActualIndex(toAliveIndex);
    _items.insert(toActual, item);

    rebuildIndices();
    rebuildBlocks();
    _rebuildFractionalIndices();
  }

  /// Set item at alive index (replace)
  void set(int aliveIndex, SequenceItem newItem) {
    final actualIndex = _aliveToActualIndex(aliveIndex);
    if (actualIndex < 0 || actualIndex >= _items.length) return;

    final oldItem = _items[actualIndex];
    _idToIndex.remove(oldItem.id);
    _items[actualIndex] = newItem;
    _idToIndex[newItem.id] = actualIndex;
  }

  /// Get fractional index for an item (for movable list ordering)
  String? getFractionalIndex(OpID id) => _fractionalIndices[id];

  /// Set fractional index for an item
  void setFractionalIndex(OpID id, String fracIdx) {
    _fractionalIndices[id] = fracIdx;
  }

  /// Get item at fractional index position
  int? indexByFractionalIndex(String fracIdx) {
    for (int i = 0; i < _items.length; i++) {
      if (_fractionalIndices[_items[i].id] == fracIdx) return i;
    }
    return null;
  }

  // ─── Internal Helpers ───

  int _aliveToActualIndex(int aliveIndex) {
    if (aliveIndex < 0) return 0;
    int count = 0;
    for (int i = 0; i < _items.length; i++) {
      if (!_items[i].deleted) {
        if (count == aliveIndex) return i;
        count++;
      }
    }
    return _items.length; // Append at end
  }

  void _shiftIndices(int from, int delta) {
    for (final entry in _idToIndex.entries) {
      if (entry.value >= from) {
        _idToIndex[entry.key] = entry.value + delta;
      }
    }
  }

  void rebuildIndices() {
    _idToIndex.clear();
    for (int i = 0; i < _items.length; i++) {
      _idToIndex[_items[i].id] = i;
    }
  }

  void _insertBlock(int index, bool deleted) {
    // Find block containing index
    int blockIndex = -1;
    int blockStart = 0;
    for (int i = 0; i < _blocks.length; i++) {
      final block = _blocks[i];
      final blockEnd = blockStart + block.length;
      if (index <= blockEnd) {
        blockIndex = i;
        break;
      }
      blockStart = blockEnd;
    }

    if (blockIndex == -1) {
      // Append new block at end
      _blocks.add(RLEBlock(startIndex: _items.length - 1, length: 1, deleted: deleted));
      return;
    }

    final block = _blocks[blockIndex];
    final offset = index - blockStart;

    if (block.deleted == deleted) {
      // Same type, just extend
      _blocks[blockIndex] = block.copyWith(length: block.length + 1);
    } else if (offset == 0) {
      // Insert at block start
      _blocks.insert(blockIndex, RLEBlock(startIndex: index, length: 1, deleted: deleted));
    } else if (offset == block.length) {
      // Insert at block end
      _blocks.insert(blockIndex + 1, RLEBlock(startIndex: index, length: 1, deleted: deleted));
    } else {
      // Split block
      _blocks[blockIndex] = block.copyWith(length: offset);
      _blocks.insert(blockIndex + 1, RLEBlock(startIndex: index, length: 1, deleted: deleted));
      _blocks.insert(blockIndex + 2, RLEBlock(startIndex: index + 1, length: block.length - offset, deleted: block.deleted));
    }

    // Merge adjacent blocks of same type
    _mergeAdjacentBlocks();
  }

  void _markBlockDeleted(int index) {
    _updateBlockAt(index, true);
  }

  void _markBlockAlive(int index) {
    _updateBlockAt(index, false);
  }

  void _updateBlockAt(int index, bool deleted) {
    int blockStart = 0;
    for (int i = 0; i < _blocks.length; i++) {
      final block = _blocks[i];
      final blockEnd = blockStart + block.length;
      if (index < blockEnd) {
        final offset = index - blockStart;
        if (block.deleted == deleted) return; // Already correct

        if (offset == 0) {
          // At start
          _blocks[i] = block.copyWith(length: block.length - 1, deleted: !deleted);
          _blocks.insert(i, RLEBlock(startIndex: index, length: 1, deleted: deleted));
        } else if (offset == block.length - 1) {
          // At end
          _blocks[i] = block.copyWith(length: block.length - 1);
          _blocks.insert(i + 1, RLEBlock(startIndex: index, length: 1, deleted: deleted));
        } else {
          // Middle - split into 3
          _blocks[i] = block.copyWith(length: offset);
          _blocks.insert(i + 1, RLEBlock(startIndex: index, length: 1, deleted: deleted));
          _blocks.insert(i + 2, RLEBlock(startIndex: index + 1, length: block.length - offset - 1, deleted: block.deleted));
        }
        _mergeAdjacentBlocks();
        return;
      }
      blockStart = blockEnd;
    }
  }

  void _mergeAdjacentBlocks() {
    for (int i = 0; i < _blocks.length - 1; i++) {
      if (_blocks[i].deleted == _blocks[i + 1].deleted) {
        _blocks[i] = _blocks[i].copyWith(length: _blocks[i].length + _blocks[i + 1].length);
        _blocks.removeAt(i + 1);
        i--;
      }
    }
    // Remove empty blocks
    _blocks.removeWhere((b) => b.length == 0);
  }

  void rebuildBlocks() {
    _blocks.clear();
    if (_items.isEmpty) return;

    bool currentDeleted = _items[0].deleted;
    int currentLength = 1;

    for (int i = 1; i < _items.length; i++) {
      if (_items[i].deleted == currentDeleted) {
        currentLength++;
      } else {
        _blocks.add(RLEBlock(
          startIndex: i - currentLength,
          length: currentLength,
          deleted: currentDeleted,
        ));
        currentDeleted = _items[i].deleted;
        currentLength = 1;
      }
    }
    _blocks.add(RLEBlock(
      startIndex: _items.length - currentLength,
      length: currentLength,
      deleted: currentDeleted,
    ));
  }

  void _rebuildFractionalIndices() {
    // Simple implementation: assign sequential fractional indices
    // Real implementation uses proper fractional indexing algorithm
    final aliveItems = getAliveWithIndices();
    for (int i = 0; i < aliveItems.length; i++) {
      final item = aliveItems[i].$2;
      _fractionalIndices[item.id] = _generateFractionalIndex(i, aliveItems.length);
    }
  }

  String _generateFractionalIndex(int index, int total) {
    // Simple base-36 encoding for fractional index
    // Real implementation uses proper algorithm from fractional_index.dart
    return index.toRadixString(36).padLeft(4, '0');
  }

  /// Serialize to JSON for transport
  Map<String, dynamic> toJson() {
    return {
      'items': _items.map((item) => {
        'id': item.id.toJson(),
        'value': item.value,
        'attributes': item.attributes,
        'deleted': item.deleted,
      }).toList(),
      'fractionalIndices': _fractionalIndices,
    };
  }

  /// Deserialize from JSON
  static SequenceIndex fromJson(Map<String, dynamic> json) {
    final seq = SequenceIndex();
    final itemsJson = json['items'] as List<dynamic>? ?? [];
    for (final itemJson in itemsJson) {
      final item = SequenceItem(
        id: OpID.fromJson(itemJson['id'] as Map<String, dynamic>),
        value: itemJson['value'],
        attributes: itemJson['attributes'] != null
            ? Map<String, dynamic>.from(itemJson['attributes'] as Map)
            : null,
      );
      if (itemJson['deleted'] == true) {
        item.delete();
      }
      seq._items.add(item);
    }
    seq.rebuildIndices();
    seq.rebuildBlocks();
    if (json['fractionalIndices'] != null) {
      final fracMap = json['fractionalIndices'] as Map<dynamic, dynamic>;
      seq._fractionalIndices.addAll(
        fracMap.map((k, v) => MapEntry(OpID.fromJson(k as Map<String, dynamic>), v as String))
      );
    }
    return seq;
  }
}

/// Iterator for alive items only
class AliveIterator {
  final SequenceIndex _sequence;
  int _index = 0;

  AliveIterator(this._sequence);

  bool moveNext() {
    while (_index < _sequence._items.length) {
      if (!_sequence._items[_index].deleted) return true;
      _index++;
    }
    return false;
  }

  SequenceItem get current => _sequence._items[_index]!;
}