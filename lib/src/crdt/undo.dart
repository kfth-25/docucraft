// DocuCraft CRDT — Undo Manager
// Port dari loro-js: undo.ts

import 'dart:collection';
import 'id.dart';
import 'doc.dart';

/// Undo/Redo action types
enum UndoAction { undo, redo }

/// Undo/Redo item metadata
class UndoItemMeta {
  final String? origin;
  final String? message;
  final DateTime timestamp;
  final List<ContainerID> affectedContainers;

  UndoItemMeta({
    this.origin,
    this.message,
    required this.timestamp,
    required this.affectedContainers,
  });
}

/// Undo Manager — manages local undo/redo stack per peer
class UndoManager {
  final CRDTDocument _doc;
  final PeerID _peerId;

  final List<UndoItem> _undoStack = [];
  final List<UndoItem> _redoStack = [];
  int _maxUndoSteps = 100;
  int _mergeIntervalMs = 0; // 0 = no merge
  final Set<String> _excludeOriginPrefixes = {};

  // Callbacks
  void Function(UndoAction, UndoItemMeta)? onPush;
  void Function(UndoAction, UndoItemMeta)? onPop;

  UndoManager(this._doc, {PeerID? peerId}) : _peerId = peerId ?? PeerID.random();

  // ─── Configuration ───

  void setMaxUndoSteps(int steps) => _maxUndoSteps = steps < 1 ? 1 : steps;

  void setMergeInterval(int ms) => _mergeIntervalMs = ms;

  void addExcludeOriginPrefix(String prefix) => _excludeOriginPrefixes.add(prefix);

  void setOnPush(void Function(UndoAction, UndoItemMeta) callback) => onPush = callback;
  void setOnPop(void Function(UndoAction, UndoItemMeta) callback) => onPop = callback;

  // ─── State ───

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  int get undoCount => _undoStack.length;
  int get redoCount => _redoStack.length;

  UndoItemMeta? get topUndoMeta => _undoStack.isNotEmpty ? _undoStack.last.meta : null;
  UndoItemMeta? get topRedoMeta => _redoStack.isNotEmpty ? _redoStack.last.meta : null;

  // ─── Core Operations ───

  /// Record a change for undo tracking
  void recordChange({
    required List<ContainerID> affectedContainers,
    String? origin,
    String? message,
  }) {
    // Check if origin should be excluded
    if (origin != null) {
      for (final prefix in _excludeOriginPrefixes) {
        if (origin.startsWith(prefix)) return;
      }
    }

    final now = DateTime.now();
    final meta = UndoItemMeta(
      origin: origin,
      message: message,
      timestamp: now,
      affectedContainers: affectedContainers,
    );

    // Check if we should merge with previous item
    if (_mergeIntervalMs > 0 && _undoStack.isNotEmpty) {
      final last = _undoStack.last;
      final timeDiff = now.difference(last.meta.timestamp).inMilliseconds;
      final sameOrigin = last.meta.origin == origin;

      if (timeDiff <= _mergeIntervalMs && sameOrigin) {
        // Merge: replace the last item with a new one with updated metadata
        _undoStack.removeLast();
        final mergedItem = UndoItem(meta: meta);
        _undoStack.add(mergedItem);
        return;
      }
    }

    // Create new undo item
    final item = UndoItem(meta: meta);
    _undoStack.add(item);

    // Trim stack
    if (_undoStack.length > _maxUndoSteps) {
      _undoStack.removeAt(0);
    }

    // Clear redo stack on new change
    _redoStack.clear();

    onPush?.call(UndoAction.undo, meta);
  }

  /// Perform undo
  bool undo() {
    if (!canUndo) return false;

    final item = _undoStack.removeLast();
    _redoStack.add(item);

    // Apply inverse operations
    _applyInverse(item);

    onPop?.call(UndoAction.undo, item.meta);
    return true;
  }

  /// Perform redo
  bool redo() {
    if (!canRedo) return false;

    final item = _redoStack.removeLast();
    _undoStack.add(item);

    // Apply forward operations
    _applyForward(item);

    onPop?.call(UndoAction.redo, item.meta);
    return true;
  }

  /// Start a group for batching multiple changes
  UndoGroup startGroup() => UndoGroup(this);

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }

  // ─── Internal ───

  void _applyInverse(UndoItem item) {
    // In real implementation: apply inverse operations to document
  }

  void _applyForward(UndoItem item) {
    // In real implementation: reapply operations
  }
}

/// Group multiple changes into a single undo item
class UndoGroup {
  final UndoManager _manager;
  final List<ContainerID> _affectedContainers = [];
  String? _origin;
  String? _message;

  UndoGroup(this._manager);

  void addContainer(ContainerID cid) => _affectedContainers.add(cid);
  void setOrigin(String origin) => _origin = origin;
  void setMessage(String message) => _message = message;

  void close() {
    if (_affectedContainers.isNotEmpty) {
      _manager.recordChange(
        affectedContainers: _affectedContainers,
        origin: _origin,
        message: _message,
      );
    }
  }
}

/// Single undo/redo item
class UndoItem {
  final UndoItemMeta meta;
  final List<RecordedOp> ops = [];

  UndoItem({required this.meta});
}

/// Recorded operation for undo/redo
class RecordedOp {
  final String type; // 'insert', 'delete', 'update', 'move'
  final ContainerID containerId;
  final int? index;
  final int? fromIndex;
  final int? toIndex;
  final dynamic value;
  final dynamic oldValue;
  final OpID? opId;

  RecordedOp({
    required this.type,
    required this.containerId,
    this.index,
    this.fromIndex,
    this.toIndex,
    this.value,
    this.oldValue,
    this.opId,
  });
}

/// Origin tracker for grouping
class OriginTracker {
  String? _currentOrigin;
  String? _currentMessage;

  void setOrigin(String? origin) => _currentOrigin = origin;
  void setMessage(String? message) => _currentMessage = message;
  void clear() { _currentOrigin = null; _currentMessage = null; }

  String? get origin => _currentOrigin;
  String? get message => _currentMessage;
}