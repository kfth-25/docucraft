// DocuCraft CRDT — Binary Encoding/Decoding
// Port dari loro-js: encoding logic

import 'dart:typed_data';
import 'dart:convert';
import 'id.dart';
import 'version_vector.dart';
import 'container.dart';
import 'sequence_index.dart';
import 'doc.dart';
import 'lww_map.dart';

/// Binary format constants
class BinaryConstants {
  static const int MAGIC = 0x44435244; // 'DCRD'
  static const int VERSION = 1;

  // Container type tags
  static const int TAG_CONTAINER_LIST = 0x01;
  static const int TAG_CONTAINER_MOVABLE_LIST = 0x02;
  static const int TAG_CONTAINER_MAP = 0x03;
  static const int TAG_CONTAINER_TEXT = 0x04;
  static const int TAG_CONTAINER_TREE = 0x05;
  static const int TAG_CONTAINER_COUNTER = 0x06;

  // Operation tags
  static const int TAG_OP_INSERT = 0x10;
  static const int TAG_OP_DELETE = 0x11;
  static const int TAG_OP_SET = 0x12;
  static const int TAG_OP_MOVE = 0x13;

  // Value type tags
  static const int TAG_VAL_NULL = 0x20;
  static const int TAG_VAL_BOOL = 0x21;
  static const int TAG_VAL_INT = 0x22;
  static const int TAG_VAL_FLOAT = 0x23;
  static const int TAG_VAL_STRING = 0x24;
  static const int TAG_VAL_BYTES = 0x25;
  static const int TAG_VAL_CONTAINER = 0x26;
  static const int TAG_VAL_MAP = 0x27;
  static const int TAG_VAL_LIST = 0x28;
}

/// Binary Encoder — encodes CRDT operations to bytes
class BinaryEncoder {
  final ByteData _buffer;
  int _offset = 0;

  BinaryEncoder({int initialCapacity = 1024}) : _buffer = ByteData(initialCapacity);

  /// Ensure buffer has capacity
  void _ensureCapacity(int needed) {
    if (_offset + needed > _buffer.lengthInBytes) {
      final newSize = (_buffer.lengthInBytes * 2).clamp(_offset + needed, 16 * 1024 * 1024);
      final newBuffer = ByteData(newSize);
      for (int i = 0; i < _offset; i++) {
        newBuffer.setUint8(i, _buffer.getUint8(i));
      }
      // Can't easily replace _buffer, so we'll just grow list instead
      throw StateError('Buffer overflow - use List<int> approach instead');
    }
  }

  // Use List<int> for dynamic growth
  final List<int> _bytes = [];

  void _writeByte(int value) => _bytes.add(value & 0xFF);
  void _writeUint16(int value) {
    _bytes.add((value >> 8) & 0xFF);
    _bytes.add(value & 0xFF);
  }
  void _writeUint32(int value) {
    _bytes.add((value >> 24) & 0xFF);
    _bytes.add((value >> 16) & 0xFF);
    _bytes.add((value >> 8) & 0xFF);
    _bytes.add(value & 0xFF);
  }
  void _writeUint64(int value) {
    _bytes.add((value >> 56) & 0xFF);
    _bytes.add((value >> 48) & 0xFF);
    _bytes.add((value >> 40) & 0xFF);
    _bytes.add((value >> 32) & 0xFF);
    _bytes.add((value >> 24) & 0xFF);
    _bytes.add((value >> 16) & 0xFF);
    _bytes.add((value >> 8) & 0xFF);
    _bytes.add(value & 0xFF);
  }
  void _writeVarint(int value) {
    while (value >= 0x80) {
      _writeByte((value & 0x7F) | 0x80);
      value >>= 7;
    }
    _writeByte(value & 0x7F);
  }

  void writeMagic() {
    _writeUint32(BinaryConstants.MAGIC);
  }

  void writeVersion() {
    _writeByte(BinaryConstants.VERSION);
  }

  void writePeerId(PeerID peer) => _writeVarint(peer.value);
  void writeLamport(Lamport lamport) => _writeVarint(lamport.value);
  void writeOpId(OpID opId) {
    writePeerId(opId.peer);
    writeLamport(opId.lamport);
  }

  void writeContainerId(ContainerID cid) {
    final str = cid.value;
    final bytes = utf8.encode(str);
    _writeVarint(bytes.length);
    _bytes.addAll(bytes);
  }

  void writeString(String str) {
    final bytes = utf8.encode(str);
    _writeVarint(bytes.length);
    _bytes.addAll(bytes);
  }

  void writeBytes(List<int> bytes) {
    _writeVarint(bytes.length);
    _bytes.addAll(bytes);
  }

  void writeValue(dynamic value) {
    if (value == null) {
      _writeByte(BinaryConstants.TAG_VAL_NULL);
    } else if (value is bool) {
      _writeByte(BinaryConstants.TAG_VAL_BOOL);
      _writeByte(value ? 1 : 0);
    } else if (value is int) {
      _writeByte(BinaryConstants.TAG_VAL_INT);
      _writeVarint(value);
    } else if (value is double) {
      _writeByte(BinaryConstants.TAG_VAL_FLOAT);
      _writeUint64(value.toInt()); // Simplified
    } else if (value is String) {
      _writeByte(BinaryConstants.TAG_VAL_STRING);
      writeString(value);
    } else if (value is List) {
      _writeByte(BinaryConstants.TAG_VAL_LIST);
      _writeVarint(value.length);
      for (final v in value) writeValue(v);
    } else if (value is Map) {
      _writeByte(BinaryConstants.TAG_VAL_MAP);
      _writeVarint(value.length);
      for (final entry in value.entries) {
        writeString(entry.key.toString());
        writeValue(entry.value);
      }
    } else {
      throw ArgumentError('Unsupported value type: ${value.runtimeType}');
    }
  }

  Uint8List toBytes() => Uint8List.fromList(_bytes);
}

/// Binary Decoder — decodes CRDT operations from bytes
class BinaryDecoder {
  final Uint8List _bytes;
  int _offset = 0;

  BinaryDecoder(this._bytes);

  int get remaining => _bytes.length - _offset;
  bool get isEmpty => _offset >= _bytes.length;

  int _readByte() => _bytes[_offset++];
  int _readUint16() => (_readByte() << 8) | _readByte();
  int _readUint32() => (_readByte() << 24) | (_readByte() << 16) | (_readByte() << 8) | _readByte();
  int _readUint64() => (_readUint32() << 32) | _readUint32();

  int _readVarint() {
    int result = 0;
    int shift = 0;
    while (true) {
      final b = _readByte();
      result |= (b & 0x7F) << shift;
      if ((b & 0x80) == 0) break;
      shift += 7;
    }
    return result;
  }

  bool checkMagic() {
    if (remaining < 4) return false;
    final magic = _readUint32();
    _offset -= 4; // Rewind
    return magic == BinaryConstants.MAGIC;
  }

  int readVersion() => _readByte();

  PeerID readPeerId() => PeerID.fromInt(_readVarint());
  Lamport readLamport() => Lamport(_readVarint());
  OpID readOpId() => OpID(readPeerId(), readLamport());

  ContainerID readContainerId() {
    final len = _readVarint();
    final bytes = _bytes.sublist(_offset, _offset + len);
    _offset += len;
    return ContainerID.parse(utf8.decode(bytes));
  }

  String readString() {
    final len = _readVarint();
    final bytes = _bytes.sublist(_offset, _offset + len);
    _offset += len;
    return utf8.decode(bytes);
  }

  List<int> readBytes() {
    final len = _readVarint();
    final bytes = _bytes.sublist(_offset, _offset + len);
    _offset += len;
    return bytes;
  }

  dynamic readValue() {
    final tag = _readByte();
    switch (tag) {
      case BinaryConstants.TAG_VAL_NULL:
        return null;
      case BinaryConstants.TAG_VAL_BOOL:
        return _readByte() == 1;
      case BinaryConstants.TAG_VAL_INT:
        return _readVarint();
      case BinaryConstants.TAG_VAL_FLOAT:
        return _readUint64().toDouble(); // Simplified
      case BinaryConstants.TAG_VAL_STRING:
        return readString();
      case BinaryConstants.TAG_VAL_LIST:
        final len = _readVarint();
        return List.generate(len, (_) => readValue());
      case BinaryConstants.TAG_VAL_MAP:
        final len = _readVarint();
        final map = <String, dynamic>{};
        for (int i = 0; i < len; i++) {
          final key = readString();
          final value = readValue();
          map[key] = value;
        }
        return map;
      default:
        throw FormatException('Unknown value tag: $tag');
    }
  }
}

/// Encode document operations to binary format
class OperationEncoder {
  final BinaryEncoder _encoder = BinaryEncoder();

  OperationEncoder() {
    _encoder.writeMagic();
    _encoder.writeVersion();
  }

  void encodeInsert(ContainerID container, int index, dynamic value, OpID opId) {
    _encoder._writeByte(BinaryConstants.TAG_OP_INSERT);
    _encoder.writeContainerId(container);
    _encoder._writeVarint(index);
    _encoder.writeValue(value);
    _encoder.writeOpId(opId);
  }

  void encodeDelete(ContainerID container, int index, OpID opId) {
    _encoder._writeByte(BinaryConstants.TAG_OP_DELETE);
    _encoder.writeContainerId(container);
    _encoder._writeVarint(index);
    _encoder.writeOpId(opId);
  }

  void encodeSet(ContainerID container, int index, dynamic value, OpID opId) {
    _encoder._writeByte(BinaryConstants.TAG_OP_SET);
    _encoder.writeContainerId(container);
    _encoder._writeVarint(index);
    _encoder.writeValue(value);
    _encoder.writeOpId(opId);
  }

  void encodeMove(ContainerID container, int from, int to, OpID opId) {
    _encoder._writeByte(BinaryConstants.TAG_OP_MOVE);
    _encoder.writeContainerId(container);
    _encoder._writeVarint(from);
    _encoder._writeVarint(to);
    _encoder.writeOpId(opId);
  }

  Uint8List finish() => _encoder.toBytes();
}

/// Decode binary operations
class OperationDecoder {
  final BinaryDecoder _decoder;

  OperationDecoder(Uint8List bytes) : _decoder = BinaryDecoder(bytes);

  bool get hasMore => !_decoder.isEmpty;

  Map<String, dynamic>? decodeNext() {
    if (!hasMore) return null;
    final tag = _decoder._readByte();
    switch (tag) {
      case BinaryConstants.TAG_OP_INSERT:
        return {
          'type': 'insert',
          'container': _decoder.readContainerId(),
          'index': _decoder._readVarint(),
          'value': _decoder.readValue(),
          'opId': _decoder.readOpId(),
        };
      case BinaryConstants.TAG_OP_DELETE:
        return {
          'type': 'delete',
          'container': _decoder.readContainerId(),
          'index': _decoder._readVarint(),
          'opId': _decoder.readOpId(),
        };
      case BinaryConstants.TAG_OP_SET:
        return {
          'type': 'set',
          'container': _decoder.readContainerId(),
          'index': _decoder._readVarint(),
          'value': _decoder.readValue(),
          'opId': _decoder.readOpId(),
        };
      case BinaryConstants.TAG_OP_MOVE:
        return {
          'type': 'move',
          'container': _decoder.readContainerId(),
          'from': _decoder._readVarint(),
          'to': _decoder._readVarint(),
          'opId': _decoder.readOpId(),
        };
      default:
        throw FormatException('Unknown operation tag: $tag');
    }
  }
}

/// Snapshot format for full document serialization
class SnapshotCodec {
  static Uint8List encode(CRDTDocument doc) {
    final encoder = BinaryEncoder();
    encoder.writeMagic();
    encoder.writeVersion();

    // Doc metadata
    encoder.writeString(doc.docId);
    encoder.writePeerId(doc.peerId);
    encoder._writeVarint(doc.lamportValue.value);

    // Containers
    encoder._writeVarint(doc.containersMap.length);
    for (final entry in doc.containersMap.entries) {
      encoder.writeContainerId(entry.key);
      encoder._writeByte(_containerTypeToTag(entry.value.type));
      _encodeContainer(encoder, entry.value);
    }

    return encoder.toBytes();
  }

  static CRDTDocument decode(Uint8List bytes) {
    final decoder = BinaryDecoder(bytes);

    if (!decoder.checkMagic()) {
      throw FormatException('Invalid snapshot magic');
    }
    decoder.readVersion();

    final docId = decoder.readString();
    final peerId = decoder.readPeerId();
    final lamport = decoder.readLamport();

    final doc = CRDTDocument(docId: docId, peerId: peerId);
    doc.lamportValue = lamport;

    final containerCount = decoder._readVarint();
    for (int i = 0; i < containerCount; i++) {
      final cid = decoder.readContainerId();
      final typeTag = decoder._readByte();
      final container = _decodeContainer(decoder, cid, typeTag);
      if (container != null) {
        doc.containersMap[cid] = container;
      }
    }

    return doc;
  }

  static int _containerTypeToTag(ContainerType type) {
    switch (type) {
      case ContainerType.list: return BinaryConstants.TAG_CONTAINER_LIST;
      case ContainerType.movableList: return BinaryConstants.TAG_CONTAINER_MOVABLE_LIST;
      case ContainerType.map: return BinaryConstants.TAG_CONTAINER_MAP;
      case ContainerType.text: return BinaryConstants.TAG_CONTAINER_TEXT;
      case ContainerType.tree: return BinaryConstants.TAG_CONTAINER_TREE;
      case ContainerType.counter: return BinaryConstants.TAG_CONTAINER_COUNTER;
      default: return 0;
    }
  }

  static ContainerType _tagToContainerType(int tag) {
    switch (tag) {
      case BinaryConstants.TAG_CONTAINER_LIST: return ContainerType.list;
      case BinaryConstants.TAG_CONTAINER_MOVABLE_LIST: return ContainerType.movableList;
      case BinaryConstants.TAG_CONTAINER_MAP: return ContainerType.map;
      case BinaryConstants.TAG_CONTAINER_TEXT: return ContainerType.text;
      case BinaryConstants.TAG_CONTAINER_TREE: return ContainerType.tree;
      case BinaryConstants.TAG_CONTAINER_COUNTER: return ContainerType.counter;
      default: return ContainerType.unknown;
    }
  }

  static void _encodeContainer(BinaryEncoder encoder, CRDTContainer container) {
    if (container is CRDTList) {
      _encodeSequence(encoder, container.sequenceValue);
    } else if (container is CRDTMovableList) {
      _encodeSequence(encoder, container.sequenceValue);
    } else if (container is CRDTMap) {
      _encodeMap(encoder, container.mapValue);
    } else if (container is CRDTText) {
      _encodeSequence(encoder, container.textValue.sequenceValue);
    } else if (container is CRDTTree) {
      _encodeTree(encoder, container);
    } else if (container is CRDTCounter) {
      _encodeCounter(encoder, container);
    }
  }

  static CRDTContainer? _decodeContainer(BinaryDecoder decoder, ContainerID cid, int typeTag) {
    final type = _tagToContainerType(typeTag);
    switch (type) {
      case ContainerType.list:
        return CRDTList(id: cid)..sequenceValue = _decodeSequence(decoder);
      case ContainerType.movableList:
        return CRDTMovableList(id: cid)..sequenceValue = _decodeSequence(decoder);
      case ContainerType.map:
        return CRDTMap(id: cid)..mapValue = _decodeMap(decoder);
      case ContainerType.text:
        final text = CRDTText(id: cid, peerId: PeerID.random());
        text.textValue.sequenceValue = _decodeSequence(decoder);
        return text;
      case ContainerType.tree:
        return CRDTTree(id: cid);
      case ContainerType.counter:
        return CRDTCounter(id: cid);
      default:
        return null;
    }
  }

  static void _encodeSequence(BinaryEncoder encoder, SequenceIndex seq) {
    encoder._writeVarint(seq.itemsValue.length);
    for (final item in seq.itemsValue) {
      encoder.writeOpId(item.id);
      encoder.writeValue(item.value);
      if (item.attributes != null) {
        encoder._writeByte(1);
        encoder._writeVarint(item.attributes!.length);
        for (final entry in item.attributes!.entries) {
          encoder.writeString(entry.key);
          encoder.writeValue(entry.value);
        }
      } else {
        encoder._writeByte(0);
      }
      encoder._writeByte(item.deleted ? 1 : 0);
    }
  }

  static SequenceIndex _decodeSequence(BinaryDecoder decoder) {
    final seq = SequenceIndex();
    final count = decoder._readVarint();
    for (int i = 0; i < count; i++) {
      final opId = decoder.readOpId();
      final value = decoder.readValue();
      final hasAttrs = decoder._readByte() == 1;
      Map<String, dynamic>? attrs;
      if (hasAttrs) {
        final attrCount = decoder._readVarint();
        attrs = <String, dynamic>{};
        for (int j = 0; j < attrCount; j++) {
          attrs[decoder.readString()] = decoder.readValue();
        }
      }
      final deleted = decoder._readByte() == 1;
      final item = SequenceItem(id: opId, value: value, attributes: attrs);
      if (deleted) item.delete();
      seq.itemsValue.add(item);
    }
    seq.rebuildIndices();
    seq.rebuildBlocks();
    return seq;
  }

  static void _encodeMap(BinaryEncoder encoder, LWWMap<String, dynamic> map) {
    encoder._writeVarint(map.map.length);
    for (final entry in map.map.entries) {
      encoder.writeString(entry.key);
      encoder.writeValue(entry.value.value);
      encoder._writeVarint(entry.value.lamport.value);
      encoder.writeOpId(entry.value.opId);
      encoder._writeByte(entry.value.deleted ? 1 : 0);
    }
  }

  static LWWMap<String, dynamic> _decodeMap(BinaryDecoder decoder) {
    final map = LWWMap<String, dynamic>();
    final count = decoder._readVarint();
    for (int i = 0; i < count; i++) {
      final key = decoder.readString();
      final value = decoder.readValue();
      final lamport = Lamport(decoder._readVarint());
      final opId = decoder.readOpId();
      final deleted = decoder._readByte() == 1;
      map.map[key] = LWWEntry(value: value, lamport: lamport, opId: opId, deleted: deleted);
    }
    return map;
  }

  static void _encodeTree(BinaryEncoder encoder, CRDTTree tree) {
    encoder._writeVarint(tree.nodes.length);
    for (final entry in tree.nodes.entries) {
      encoder._writeVarint(entry.key.value);
      // Parent
      if (entry.value.parent is TreeParentNode) {
        encoder._writeByte(1);
        encoder._writeVarint((entry.value.parent as TreeParentNode).id.value);
      } else {
        encoder._writeByte(0);
      }
      encoder.writeString(entry.value.fractionalIndex);
      // Meta map
      _encodeMap(encoder, entry.value.meta);
    }
  }

  static void _encodeCounter(BinaryEncoder encoder, CRDTCounter counter) {
    encoder._writeVarint(counter.positive.length);
    for (final entry in counter.positive.entries) {
      encoder.writePeerId(entry.key);
      encoder._writeVarint(entry.value);
    }
    encoder._writeVarint(counter.negative.length);
    for (final entry in counter.negative.entries) {
      encoder.writePeerId(entry.key);
      encoder._writeVarint(entry.value);
    }
  }
}