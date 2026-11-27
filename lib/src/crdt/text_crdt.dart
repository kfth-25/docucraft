// DocuCraft CRDT — Text CRDT (Fugue-inspired RGA)
// Dukungan rich text dengan marks/attributes
// Port dari loro-js: text handling logic

import 'dart:collection';
import 'id.dart';
import 'sequence_index.dart';

/// Text operation types
enum TextOpType { insert, delete, retain }

/// Text operation for rich text
class TextOp {
  final TextOpType type;
  final String? text; // For insert
  final int? count; // For retain/delete
  final Map<String, dynamic>? attributes; // For insert with marks

  TextOp.insert(this.text, {this.attributes})
      : type = TextOpType.insert,
        count = null;

  TextOp.delete(this.count)
      : type = TextOpType.delete,
        text = null,
        attributes = null;

  TextOp.retain(this.count)
      : type = TextOpType.retain,
        text = null,
        attributes = null;

  @override
  String toString() {
    switch (type) {
      case TextOpType.insert:
        return 'Insert("$text"${attributes != null ? ' @$attributes' : ''})';
      case TextOpType.delete:
        return 'Delete($count)';
      case TextOpType.retain:
        return 'Retain($count)';
    }
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'text': text,
    'count': count,
    'attributes': attributes,
  };

  static TextOp fromJson(Map<String, dynamic> json) {
    switch (json['type'] as String) {
      case 'insert':
        return TextOp.insert(
          json['text'] as String,
          attributes: json['attributes'] != null
              ? Map<String, dynamic>.from(json['attributes'] as Map)
              : null,
        );
      case 'delete':
        return TextOp.delete(json['count'] as int);
      case 'retain':
        return TextOp.retain(json['count'] as int);
      default:
        throw ArgumentError('Unknown TextOp type: ${json['type']}');
    }
  }
}

/// Rich text delta — sequence of operations
class TextDelta {
  final List<TextOp> ops;

  TextDelta(this.ops);

  /// Compose two deltas (apply delta2 after delta1)
  static TextDelta compose(TextDelta delta1, TextDelta delta2) {
    // Simplified composition - real implementation is more complex
    return TextDelta([...delta1.ops, ...delta2.ops]);
  }

  /// Invert a delta (for undo)
  TextDelta invert(String originalText) {
    final invertedOps = <TextOp>[];
    int pos = 0;

    for (final op in ops) {
      switch (op.type) {
        case TextOpType.insert:
          invertedOps.add(TextOp.delete(op.text!.length));
          pos += op.text!.length;
          break;
        case TextOpType.delete:
          // Need original text to know what was deleted
          final deleted = originalText.substring(pos, pos + op.count!);
          invertedOps.add(TextOp.insert(deleted));
          break;
        case TextOpType.retain:
          invertedOps.add(TextOp.retain(op.count!));
          pos += op.count!;
          break;
      }
    }
    return TextDelta(invertedOps);
  }

  Map<String, dynamic> toJson() => {'ops': ops.map((o) => o.toJson()).toList()};

  static TextDelta fromJson(Map<String, dynamic> json) {
    return TextDelta(
      (json['ops'] as List).map((o) => TextOp.fromJson(o as Map<String, dynamic>)).toList(),
    );
  }

  @override
  String toString() => 'TextDelta{${ops.map((o) => o.toString()).join(', ')}}';
}

/// Text CRDT — Fugue-style with RGA fallback
/// Uses SequenceIndex for underlying storage
class TextCRDT {
  SequenceIndex _sequence;
  final PeerID _peerId;
  Lamport _lamport = Lamport.zero();

  TextCRDT(this._peerId) : _sequence = SequenceIndex();

  /// Create TextCRDT from existing sequence (for deserialization)
  TextCRDT._internal(this._peerId, this._sequence);

  // Public accessors for encoding/decoding
  SequenceIndex get sequenceValue => _sequence;
  set sequenceValue(SequenceIndex value) => _sequence = value;

  /// Get current text content
  String get text {
    return _sequence.getAliveItems()
        .map((item) => item.value as String)
        .join('');
  }

  /// Get length (Unicode characters)
  int get length => text.length;

  /// Get length in UTF-16 code units
  int get lengthUtf16 {
    return text.codeUnits.length;
  }

  /// Get length in UTF-8 bytes
  int get lengthUtf8 {
    return text.codeUnits.fold(0, (sum, c) => sum + (c < 0x80 ? 1 : (c < 0x800 ? 2 : 3)));
  }

  /// Insert text at Unicode position
  void insert(int pos, String str, {Map<String, dynamic>? attributes}) {
    if (str.isEmpty) return;

    _lamport = _lamport.next();
    var aliveIndex = _unicodeToAliveIndex(pos);

    for (int i = 0; i < str.length; i++) {
      final char = str[i];
      final opId = OpID.create(_peerId, _lamport.next());
      final item = SequenceItem(id: opId, value: char, attributes: attributes);
      _sequence.insert(aliveIndex + i, item);
    }
  }

  /// Delete range at Unicode position
  bool delete(int pos, int len) {
    if (len <= 0) return false;

    _lamport = _lamport.next();
    var aliveIndex = _unicodeToAliveIndex(pos);
    var deleted = false;

    for (int i = 0; i < len; i++) {
      final item = _sequence.getAliveWithIndices().elementAtOrNull(aliveIndex);
      if (item == null) break;
      _sequence.deleteById(item.$2.id);
      deleted = true;
    }
    return deleted;
  }

  /// Get substring at Unicode range
  String slice(int start, int end) {
    final aliveIndex = _unicodeToAliveIndex(start);
    final items = _sequence.getAliveWithIndices();
    final result = StringBuffer();

    for (int i = 0; i < end - start && aliveIndex + i < items.length; i++) {
      result.write(items[aliveIndex + i].$2.value);
    }
    return result.toString();
  }

  /// Get character at Unicode position
  String? charAt(int pos) {
    final aliveIndex = _unicodeToAliveIndex(pos);
    final item = _sequence.getAliveWithIndices().elementAtOrNull(aliveIndex);
    return item?.$2.value as String?;
  }

  /// Mark range with attributes (bold, italic, link, etc.)
  void mark(int start, int end, String key, dynamic value) {
    final aliveIndex = _unicodeToAliveIndex(start);
    final items = _sequence.getAliveWithIndices();

    for (int i = 0; i < end - start && aliveIndex + i < items.length; i++) {
      final item = items[aliveIndex + i].$2;
      final attrs = Map<String, dynamic>.from(item.attributes ?? {});
      attrs[key] = value;
      // Create new item with updated attributes (immutable approach)
      final newItem = item.copyWith(attributes: attrs);
      _sequence.set(aliveIndex + i, newItem);
    }
  }

  /// Remove mark from range
  void unmark(int start, int end, String key) {
    final aliveIndex = _unicodeToAliveIndex(start);
    final items = _sequence.getAliveWithIndices();

    for (int i = 0; i < end - start && aliveIndex + i < items.length; i++) {
      final item = items[aliveIndex + i].$2;
      if (item.attributes == null) continue;
      final attrs = Map<String, dynamic>.from(item.attributes!);
      attrs.remove(key);
      final newItem = item.copyWith(attributes: attrs.isEmpty ? null : attrs);
      _sequence.set(aliveIndex + i, newItem);
    }
  }

  /// Get delta representation (for Quill/ProseMirror compatibility)
  TextDelta toDelta() {
    final ops = <TextOp>[];
    String currentText = '';
    Map<String, dynamic>? currentAttrs;

    for (final item in _sequence.getAliveItems()) {
      final char = item.value as String;
      final attrs = item.attributes;

      if (currentAttrs == null && attrs == null) {
        // Plain text run
        currentText += char;
      } else if (mapEquals(currentAttrs, attrs)) {
        // Same attributes, continue run
        currentText += char;
      } else {
        // Attribute change - flush current run
        if (currentText.isNotEmpty) {
          ops.add(TextOp.insert(currentText, attributes: currentAttrs));
          currentText = '';
        }
        currentText = char;
        currentAttrs = attrs;
      }
    }

    if (currentText.isNotEmpty) {
      ops.add(TextOp.insert(currentText, attributes: currentAttrs));
    }

    return TextDelta(ops);
  }

  /// Apply delta (for remote sync)
  void applyDelta(TextDelta delta) {
    int pos = 0;
    for (final op in delta.ops) {
      switch (op.type) {
        case TextOpType.insert:
          if (op.text != null) {
            insert(pos, op.text!, attributes: op.attributes);
            pos += op.text!.length;
          }
          break;
        case TextOpType.delete:
          if (op.count != null) {
            delete(pos, op.count!);
          }
          break;
        case TextOpType.retain:
          if (op.count != null) {
            pos += op.count!;
          }
          break;
      }
    }
  }

  /// Get iterator over text chunks with attributes
  Iterable<(String, Map<String, dynamic>?)> iterChunks() sync* {
    String currentText = '';
    Map<String, dynamic>? currentAttrs;

    for (final item in _sequence.getAliveItems()) {
      final char = item.value as String;
      final attrs = item.attributes;

      if (currentAttrs == null && attrs == null) {
        // Plain text run
        currentText += char;
      } else if (mapEquals(currentAttrs, attrs)) {
        // Same attributes, continue run
        currentText += char;
      } else {
        // Attribute change - flush current run
        if (currentText.isNotEmpty) {
          yield (currentText, currentAttrs);
        }
        currentText = char;
        currentAttrs = attrs;
      }
    }

    if (currentText.isNotEmpty) {
      yield (currentText, currentAttrs);
    }
  }

  // ─── Serialization ───

  Map<String, dynamic> toJson() => _sequence.toJson();

  static TextCRDT fromJson(PeerID peerId, Map<String, dynamic> json) {
    return TextCRDT._internal(peerId, SequenceIndex.fromJson(json));
  }

  // ─── Helpers ───

  int _unicodeToAliveIndex(int unicodePos) {
    int count = 0;
    for (int i = 0; i < _sequence.length; i++) {
      final item = _sequence.get(i);
      if (item != null && !item.deleted) {
        if (count == unicodePos) return count;
        count++;
      }
    }
    return count.clamp(0, _sequence.aliveLength);
  }

  static bool mapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Extension for safe element access
extension ListExtensions<T> on List<T> {
  T? elementAtOrNull(int index) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }
}