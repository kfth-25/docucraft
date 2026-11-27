// DocuCraft CRDT — Diff, Checkout, Time Travel
// Port dari loro-js: diff logic

import 'dart:typed_data';
import 'id.dart';
import 'version_vector.dart';
import 'container.dart';
import 'sequence_index.dart';
import 'doc.dart';

/// Diff operation types
enum DiffOpType { insert, delete, update, move, retain }

/// Diff operation for containers
class DiffOp {
  final DiffOpType type;
  final ContainerID containerId;
  final int? index;
  final int? fromIndex;
  final int? toIndex;
  final dynamic value;
  final dynamic oldValue;
  final Map<String, dynamic>? attributes;
  final OpID? opId;

  DiffOp.insert(this.containerId, this.index, this.value, {this.attributes, this.opId})
      : type = DiffOpType.insert,
        fromIndex = null,
        toIndex = null,
        oldValue = null;

  DiffOp.delete(this.containerId, this.index, this.oldValue, {this.opId})
      : type = DiffOpType.delete,
        fromIndex = null,
        toIndex = null,
        value = null,
        attributes = null;

  DiffOp.update(this.containerId, this.index, this.value, this.oldValue, {this.attributes, this.opId})
      : type = DiffOpType.update,
        fromIndex = null,
        toIndex = null;

  DiffOp.move(this.containerId, this.fromIndex, this.toIndex, {this.opId})
      : type = DiffOpType.move,
        index = null,
        value = null,
        oldValue = null,
        attributes = null;

  @override
  String toString() {
    switch (type) {
      case DiffOpType.insert:
        return 'Insert($containerId[$index] = $value)';
      case DiffOpType.delete:
        return 'Delete($containerId[$index])';
      case DiffOpType.update:
        return 'Update($containerId[$index]: $oldValue -> $value)';
      case DiffOpType.move:
        return 'Move($containerId[$fromIndex] -> $toIndex)';
      case DiffOpType.retain:
        return 'Retain';
    }
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'containerId': containerId.toJson(),
    'index': index,
    'fromIndex': fromIndex,
    'toIndex': toIndex,
    'value': value?.toString(),
    'oldValue': oldValue?.toString(),
    'attributes': attributes,
    'opId': opId?.toJson(),
  };
}

/// Diff result between two versions
class DiffResult {
  final List<DiffOp> ops;
  final VersionVector fromVersion;
  final VersionVector toVersion;

  DiffResult({required this.ops, required this.fromVersion, required this.toVersion});

  bool get isEmpty => ops.isEmpty;

  Map<String, dynamic> toJson() => {
    'ops': ops.map((o) => o.toJson()).toList(),
    'fromVersion': fromVersion.toJson(),
    'toVersion': toVersion.toJson(),
  };
}

/// Diff Calculator — computes diff between two document versions
class DiffCalculator {
  final CRDTDocument _doc;

  DiffCalculator(this._doc);

  /// Compute diff between two version vectors
  DiffResult diff(VersionVector from, VersionVector to) {
    final ops = <DiffOp>[];

    // For each container, compute diff
    for (final cid in _doc.getRootContainerIds()) {
      final container = _doc.getContainer(cid);
      if (container == null) continue;

      final containerOps = _diffContainer(container, from, to);
      ops.addAll(containerOps);
    }

    return DiffResult(ops: ops, fromVersion: from, toVersion: to);
  }

  List<DiffOp> _diffContainer(CRDTContainer container, VersionVector from, VersionVector to) {
    // Simplified: in real implementation, track per-container version vectors
    // and compare operation logs
    return [];
  }

  /// Compute diff between two sequence indices
  List<DiffOp> _diffSequence(SequenceIndex oldSeq, SequenceIndex newSeq, ContainerID cid) {
    final ops = <DiffOp>[];

    // Use Myers diff algorithm or simple LCS
    final oldItems = oldSeq.getAliveItems();
    final newItems = newSeq.getAliveItems();

    // Simple approach: find common items, detect insert/delete/move
    // Real implementation uses proper diff algorithm

    return [];
  }
}

/// Checkout / Time Travel Manager
class CheckoutManager {
  final CRDTDocument _doc;
  final Map<Frontiers, DocumentState> _stateCache = {};

  CheckoutManager(this._doc);

  /// Checkout to a specific version (frontiers)
  void checkout(Frontiers frontiers) {
    if (_doc.isDetached && _doc.checkoutFrontiers == frontiers) return;

    // Save current state if not already detached
    if (!_doc.isDetached) {
      _saveCurrentState();
    }

    // Restore state at frontiers
    _restoreState(frontiers);
    _doc.checkoutFrontiers = frontiers;
    _doc.detached = true;
  }

  /// Return to latest version
  void checkoutToLatest() {
    if (!_doc.isDetached) return;

    _restoreLatestState();
    _doc.checkoutFrontiers = null;
    _doc.detached = false;
  }

  /// Revert to a previous version (create new ops to undo changes)
  void revertTo(Frontiers target) {
    // Create inverse operations to revert to target
    // This is different from checkout - it creates new history
    throw UnimplementedError('revertTo not implemented');
  }

  void _saveCurrentState() {
    // Save current document state for potential return
    // In real impl: snapshot all containers
  }

  void _restoreState(Frontiers frontiers) {
    // Restore document to state at frontiers
    // In real impl: replay operations up to frontiers
  }

  void _restoreLatestState() {
    // Restore to latest (tip of history)
  }

  /// Get available versions for time travel UI
  List<VersionInfo> getAvailableVersions() {
    // Return list of checkpoints with timestamps, authors, messages
    return [];
  }
}

/// Version info for time travel UI
class VersionInfo {
  final Frontiers frontiers;
  final DateTime timestamp;
  final String author;
  final String? message;
  final int opCount;

  VersionInfo({
    required this.frontiers,
    required this.timestamp,
    required this.author,
    this.message,
    required this.opCount,
  });
}

/// Document state at a specific version
class DocumentState {
  final Frontiers frontiers;
  final Map<ContainerID, dynamic> containerStates;
  final DateTime timestamp;

  DocumentState({
    required this.frontiers,
    required this.containerStates,
    required this.timestamp,
  });
}

/// Shallow Snapshot support (like git shallow clone)
class ShallowSnapshotManager {
  final CRDTDocument _doc;

  ShallowSnapshotManager(this._doc);

  /// Create a shallow snapshot starting from frontiers
  Uint8List createShallowSnapshot(Frontiers from) {
    // Only include operations from 'from' onwards
    // History before 'from' is discarded
    throw UnimplementedError('Shallow snapshot not implemented');
  }

  /// Load shallow snapshot
  void loadShallowSnapshot(Uint8List bytes, Frontiers from) {
    // Load state from 'from' onwards
    throw UnimplementedError('Load shallow snapshot not implemented');
  }
}