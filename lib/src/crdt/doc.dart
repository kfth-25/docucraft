// DocuCraft CRDT — Document (LoroDoc equivalent)
// Titik masuk utama untuk dokumen CRDT
// Port dari loro-js: document.ts

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'id.dart';
import 'version_vector.dart';
import 'container.dart';
import 'sequence_index.dart';
import 'lww_map.dart';
import 'text_crdt.dart';
import 'undo.dart';

/// Export mode for document serialization
enum ExportMode {
  snapshot,           // Full state + history
  allUpdates,         // All operations
  updates,            // Incremental from version
  shallowSnapshot,    // GC'd snapshot
}

class ExportModeConfig {
  final ExportMode mode;
  final VersionVector? fromVersion;
  final Frontiers? fromFrontiers;

  const ExportModeConfig._(this.mode, this.fromVersion, this.fromFrontiers);

  factory ExportModeConfig.snapshot() => ExportModeConfig._(ExportMode.snapshot, null, null);
  factory ExportModeConfig.allUpdates() => ExportModeConfig._(ExportMode.allUpdates, null, null);
  factory ExportModeConfig.updates(VersionVector from) => ExportModeConfig._(ExportMode.updates, from, null);
  factory ExportModeConfig.updatesFromFrontiers(Frontiers from) => ExportModeConfig._(ExportMode.updates, null, from);
  factory ExportModeConfig.shallowSnapshot(Frontiers from) => ExportModeConfig._(ExportMode.shallowSnapshot, null, from);
}

/// Import status result
class ImportStatus {
  final List<IdSpan>? pending;
  final int importedOps;

  ImportStatus({this.pending, this.importedOps = 0});

  bool get hasPending => pending != null && pending!.isNotEmpty;
}

/// Document event for subscriptions
class DocEvent {
  final String containerId;
  final String eventType; // 'insert', 'delete', 'update', 'move', etc.
  final dynamic data;
  final bool isLocal;

  DocEvent({required this.containerId, required this.eventType, required this.data, required this.isLocal});
}

/// Subscription handle
class Subscription {
  final String id;
  final void Function(DocEvent) callback;
  bool _cancelled = false;

  Subscription(this.id, this.callback);

  void cancel() => _cancelled = true;
  bool get isCancelled => _cancelled;
}

/// Main CRDT Document — equivalent to LoroDoc
class CRDTDocument {
  final String docId;
  final PeerID peerId;
  Lamport _lamport = Lamport.zero();
  final Map<ContainerID, CRDTContainer> _containers = {};
  final Map<String, StreamController<DocEvent>> _subscriptions = {};
  bool _detached = false;
  Frontiers? _checkoutFrontiers; // For time travel

  CRDTDocument({required this.docId, PeerID? peerId}) : peerId = peerId ?? PeerID.random();

  // Public accessors for encoding/decoding
  Lamport get lamport => _lamport;
  set lamport(Lamport value) => _lamport = value;

  Map<ContainerID, CRDTContainer> get containers => Map.unmodifiable(_containers);
  int get containerCount => _containers.length;

  /// Add a pre-created container (for example_usage)
  void addContainer(CRDTContainer container) {
    _containers[container.id] = container;
  }

  // Public getters/setters for external access (encoding, diff, etc.)
  Lamport get lamportValue => _lamport;
  set lamportValue(Lamport value) => _lamport = value;

  Map<ContainerID, CRDTContainer> get containersMap => _containers;
  set containersMap(Map<ContainerID, CRDTContainer> value) {
    _containers.clear();
    _containers.addAll(value);
  }

  bool get detached => _detached;
  set detached(bool value) => _detached = value;

  Frontiers? get checkoutFrontiers => _checkoutFrontiers;
  set checkoutFrontiers(Frontiers? value) => _checkoutFrontiers = value;

  // ─── Container Access ───

  CRDTList getList(String name) {
    final cid = ContainerID.root(ContainerType.list, name: name);
    return _getOrCreateContainer(cid, () => ContainerFactory.createList(id: cid)) as CRDTList;
  }

  CRDTMovableList getMovableList(String name) {
    final cid = ContainerID.root(ContainerType.movableList, name: name);
    return _getOrCreateContainer(cid, () => ContainerFactory.createMovableList(id: cid)) as CRDTMovableList;
  }

  CRDTMap getMap(String name) {
    final cid = ContainerID.root(ContainerType.map, name: name);
    return _getOrCreateContainer(cid, () => ContainerFactory.createMap(id: cid)) as CRDTMap;
  }

  CRDTText getText(String name) {
    final cid = ContainerID.root(ContainerType.text, name: name);
    return _getOrCreateContainer(cid, () => ContainerFactory.createText(id: cid, peerId: peerId)) as CRDTText;
  }

  CRDTTree getTree(String name) {
    final cid = ContainerID.root(ContainerType.tree, name: name);
    return _getOrCreateContainer(cid, () => ContainerFactory.createTree(id: cid)) as CRDTTree;
  }

  CRDTCounter getCounter(String name) {
    final cid = ContainerID.root(ContainerType.counter, name: name);
    return _getOrCreateContainer(cid, () => ContainerFactory.createCounter(id: cid)) as CRDTCounter;
  }

  T _getOrCreateContainer<T extends CRDTContainer>(ContainerID cid, T Function() creator) {
    if (_containers.containsKey(cid)) {
      return _containers[cid]! as T;
    }
    final container = creator();
    _containers[cid] = container;
    return container;
  }

  /// Get container by ID (for nested containers)
  CRDTContainer? getContainer(ContainerID cid) => _containers[cid];

  /// Get all root container IDs
  List<ContainerID> getRootContainerIds() => _containers.keys.where((c) => c.isRoot).toList();

  /// Get container count (for debugging)
  int _getContainerCount() => _containers.length;

  // ─── Transaction / Commit ───

  /// Commit current transaction (increment lamport, emit events)
  void commit() {
    _lamport = _lamport.next();
    // In real implementation, emit events for all pending changes
  }

  /// Auto-commit mode (commit after each operation)
  void startAutoCommit() {
    // In this simplified version, each operation auto-commits
  }

  // ─── Version / Sync ───

  VersionVector get oplogVersion => _computeVersionVector();
  VersionVector get stateVersion => _computeVersionVector(); // Same in this impl

  Frontiers get oplogFrontiers => Frontiers.fromVersionVector(oplogVersion);
  Frontiers get stateFrontiers => Frontiers.fromVersionVector(stateVersion);

  VersionVector _computeVersionVector() {
    // In real implementation, track per-container versions
    // Simplified: use peer's lamport as single-counter version
    return VersionVector.fromMap({peerId: _lamport});
  }

  /// Export document in given mode
  Uint8List export(ExportModeConfig config) {
    final encoder = DocumentEncoder(this);
    switch (config.mode) {
      case ExportMode.snapshot:
        return encoder.encodeSnapshot();
      case ExportMode.allUpdates:
        return encoder.encodeAllUpdates();
      case ExportMode.updates:
        return encoder.encodeUpdates(config.fromVersion!);
      case ExportMode.shallowSnapshot:
        return encoder.encodeShallowSnapshot(config.fromFrontiers!);
    }
  }

  /// Import binary data
  ImportStatus import(Uint8List bytes) {
    final decoder = DocumentDecoder(this);
    return decoder.decode(bytes);
  }

  /// Import multiple updates (any order)
  ImportStatus importBatch(List<Uint8List> batches) {
    var totalImported = 0;
    List<IdSpan>? allPending;
    for (final batch in batches) {
      final status = import(batch);
      totalImported += status.importedOps;
      if (status.hasPending) {
        allPending ??= [];
        allPending!.addAll(status.pending!);
      }
    }
    return ImportStatus(pending: allPending, importedOps: totalImported);
  }

  // ─── Time Travel / Checkout ───

  /// Checkout to a specific version (time travel)
  void checkout(Frontiers frontiers) {
    _checkoutFrontiers = frontiers;
    _detached = true;
    // In real impl: replay history up to frontiers
  }

  /// Return to latest version
  void checkoutToLatest() {
    _checkoutFrontiers = null;
    _detached = false;
  }

  bool get isDetached => _detached;

  // ─── Undo Manager ───

  UndoManager createUndoManager() => UndoManager(this);

  // ─── Subscriptions ───

  Subscription subscribe(String containerId, void Function(DocEvent) callback) {
    final subId = 'sub_${_subscriptions.length}';
    _subscriptions[containerId] = StreamController<DocEvent>.broadcast();
    _subscriptions[containerId]!.stream.listen(callback);
    return Subscription(subId, callback);
  }

  Subscription subscribeRoot(void Function(DocEvent) callback) {
    return subscribe('*', callback);
  }

  void _emitEvent(DocEvent event) {
    final sub = _subscriptions[event.containerId];
    sub?.add(event);
    final rootSub = _subscriptions['*'];
    rootSub?.add(event);
  }

  // ─── Serialization ───

  Map<String, dynamic> toJson() {
    return {
      'docId': docId,
      'peerId': peerId.value,
      'lamport': _lamport.value,
      'containers': _containers.map((k, v) => MapEntry(k.toJson(), v.toJson())),
    };
  }

  static CRDTDocument fromJson(String docId, Map<String, dynamic> json) {
    final doc = CRDTDocument(docId: docId, peerId: PeerID.fromInt(json['peerId'] as int));
    // Restore containers would happen here
    return doc;
  }

  // ─── Deep Value (for export) ───

  Map<String, dynamic> getDeepValue() {
    final result = <String, dynamic>{};
    for (final entry in _containers.entries) {
      if (entry.key.isRoot) {
        result[entry.key.value] = _containerToValue(entry.value);
      }
    }
    return result;
  }

  dynamic _containerToValue(CRDTContainer container) {
    if (container is CRDTList) {
      return container.getValues();
    } else if (container is CRDTMovableList) {
      return container.getValues();
    } else if (container is CRDTMap) {
      return Map.fromEntries(container.entries);
    } else if (container is CRDTText) {
      return container.text;
    } else if (container is CRDTTree) {
      return {'nodes': container.getAllNodes().length};
    } else if (container is CRDTCounter) {
      return container.value;
    }
    return null;
  }
}

/// Document Encoder — binary serialization
class DocumentEncoder {
  final CRDTDocument _doc;

  DocumentEncoder(this._doc);

  Uint8List encodeSnapshot() {
    // Simplified: JSON + magic bytes
    final json = utf8.encode(jsonEncode(_doc.toJson()));
    return Uint8List.fromList([0x44, 0x43, 0x52, 0x44] + json); // 'DCRD' magic
  }

  Uint8List encodeAllUpdates() {
    // Simplified: same as snapshot for now
    return encodeSnapshot();
  }

  Uint8List encodeUpdates(VersionVector from) {
    // Simplified: incremental not implemented
    return encodeSnapshot();
  }

  Uint8List encodeShallowSnapshot(Frontiers from) {
    // Simplified: same as snapshot
    return encodeSnapshot();
  }
}

/// Document Decoder — binary deserialization
class DocumentDecoder {
  final CRDTDocument _doc;

  DocumentDecoder(this._doc);

  ImportStatus decode(Uint8List bytes) {
    // Check magic
    if (bytes.length < 4 || bytes[0] != 0x44 || bytes[1] != 0x43 || bytes[2] != 0x52 || bytes[3] != 0x44) {
      throw FormatException('Invalid document format');
    }

    try {
      final json = utf8.decode(bytes.sublist(4));
      final map = jsonDecode(json) as Map<String, dynamic>;
      // In real impl: apply operations to document
      return ImportStatus(importedOps: 1);
    } catch (e) {
      throw FormatException('Failed to decode document: $e');
    }
  }
}

/// Export mode constants for API compatibility
class ExportModeConstants {
  static const Map<String, dynamic> snapshot = {'mode': 'snapshot'};
  static const Map<String, dynamic> allUpdates = {'mode': 'update'};
  static Map<String, dynamic> updates(VersionVector from) => {'mode': 'update', 'from': from.toJson()};
  static Map<String, dynamic> shallowSnapshot(Frontiers from) => {'mode': 'shallow', 'from': from.toJson()};
}