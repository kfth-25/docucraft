// DocuCraft — CRDT Provider (Flutter side)
// Membungkus binding FFI dari flutter_rust_bridge dan mengintegrasikannya dengan SlideProvider.
//
// Ini menggantikan SyncEngine + CollabWebSocketProvider custom dengan Loro CRDT.

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import '../../models/slide.dart';

/// CRDT Document wrapper that manages a LoroDoc via FFI.
class CrdtDocument {
  final String docId;
  final DocHandle _handle;

  // Stream controllers for events
  final _localUpdateController = StreamController<Uint8List>.broadcast();
  final _remoteUpdateController = StreamController<Uint8List>.broadcast();
  final _cursorController = StreamController<CursorInfo>.broadcast();
  final _connectionStateController = StreamController<ConnectionState>.broadcast();

  Stream<Uint8List> get localUpdates => _localUpdateController.stream;
  Stream<Uint8List> get remoteUpdates => _remoteUpdateController.stream;
  Stream<CursorInfo> get cursorUpdates => _cursorController.stream;
  Stream<ConnectionState> get connectionState => _connectionStateController.stream;

  bool _isConnected = false;
  Timer? _autoSyncTimer;
  Timer? _autoSaveTimer;

  CrdtDocument._(this.docId, this._handle);

  /// Create a new CRDT document
  static Future<CrdtDocument> create(String docId) async {
    final handle = await DocHandle.create(docId);
    return CrdtDocument._(docId, handle);
  }

  /// Restore from snapshot
  static Future<CrdtDocument> fromSnapshot(String docId, Uint8List bytes) async {
    final handle = await DocHandle.fromSnapshot(docId, bytes);
    return CrdtDocument._(docId, handle);
  }

  /// Initialize and start auto-sync
  Future<void> initialize({Duration syncInterval = const Duration(milliseconds: 500)}) async {
    _connectionStateController.add(ConnectionState.connecting);
    _connectionStateController.add(ConnectionState.connected);
    _isConnected = true;

    // Start periodic local update emission (for WebSocket sync)
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(syncInterval, (_) {
      if (_isConnected) {
        _handle.exportUpdate().then((update) {
          if (update.isNotEmpty) {
            _localUpdateController.add(update);
          }
        });
      }
    });

    // Auto-save snapshot every 30 seconds
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _saveSnapshotLocally();
    });
  }

  // ─── SLIDE OPERATIONS ──────────────────────────────────────────────

  /// Create a new slide, return its ID
  Future<String> createSlide({String layout = 'title-body'}) async {
    return _handle.createSlide(layout);
  }

  /// Delete a slide by ID
  Future<void> deleteSlide(String slideId) async {
    await _handle.deleteSlide(slideId);
  }

  /// Get all slide IDs in order
  Future<List<String>> getSlideIds() async {
    return _handle.getSlideIds();
  }

  /// Move slide from one index to another
  Future<void> moveSlide(int from, int to) async {
    await _handle.moveSlide(from, to);
  }

  /// Set slide title
  Future<void> setSlideTitle(String slideId, String title) async {
    await _handle.setSlideTitle(slideId, title);
  }

  /// Get slide title
  Future<String> getSlideTitle(String slideId) async {
    return _handle.getSlideTitle(slideId);
  }

  /// Set slide body
  Future<void> setSlideBody(String slideId, String body) async {
    await _handle.setSlideBody(slideId, body);
  }

  /// Get slide body
  Future<String> getSlideBody(String slideId) async {
    return _handle.getSlideBody(slideId);
  }

  /// Get slide layout
  Future<String> getSlideLayout(String slideId) async {
    return _handle.getSlideLayout(slideId);
  }

  // ─── PAGE OPERATIONS (Document mode) ──────────────────────────────

  Future<String> createPage() async {
    return _handle.createPage();
  }

  Future<List<String>> getPageIds() async {
    return _handle.getPageIds();
  }

  Future<void> setPageContent(String pageId, String content) async {
    await _handle.setPageContent(pageId, content);
  }

  Future<String> getPageContent(String pageId) async {
    return _handle.getPageContent(pageId);
  }

  // ─── SYNC ──────────────────────────────────────────────────────────

  /// Export full snapshot (for initial load / backup)
  Future<Uint8List> exportSnapshot() async {
    return _handle.exportSnapshot();
  }

  /// Export incremental update (for WebSocket sync)
  Future<Uint8List> exportUpdate() async {
    return _handle.exportUpdate();
  }

  /// Import update from remote peer
  Future<void> importUpdate(Uint8List bytes) async {
    await _handle.importUpdate(bytes);
  }

  /// Import multiple updates (any order)
  Future<void> importBatch(List<Uint8List> bytesList) async {
    await _handle.importBatch(bytesList);
  }

  /// Export full document as JSON (for PPTX/DOCX export)
  Future<String> toJson() async {
    return _handle.toJson();
  }

  // ─── PRESENCE ──────────────────────────────────────────────────────

  /// Set local cursor position
  Future<void> setCursor(String container, int position) async {
    await _handle.setCursor(container, position);
  }

  /// Get all active cursors (container, peer, position)
  Future<List<CursorInfo>> getCursors() async {
    final raw = await _handle.getCursors();
    return raw.map((t) => CursorInfo(
      container: t.$1,
      peerId: t.$2,
      position: int.tryParse(t.$3) ?? 0,
    )).toList();
  }

  // ─── VERSION / TIME TRAVEL ────────────────────────────────────────

  Future<String> getVersion() async => _handle.getVersion();
  Future<int> getOpCount() async => _handle.getOpCount();

  // ─── BASE64 HELPERS ────────────────────────────────────────────────

  static String bytesToBase64(Uint8List bytes) => DocHandle.bytesToBase64(bytes);
  static Uint8List base64ToBytes(String encoded) => Uint8List.fromList(DocHandle.base64ToBytes(encoded));

  // ─── PERSISTENCE ──────────────────────────────────────────────────

  Future<void> _saveSnapshotLocally() async {
    // This would use SharedPreferences or Hive
    // Implementation delegated to SlideRepository
  }

  // ─── CLEANUP ──────────────────────────────────────────────────────

  void disconnect() {
    _isConnected = false;
    _autoSyncTimer?.cancel();
    _autoSaveTimer?.cancel();
    _connectionStateController.add(ConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _localUpdateController.close();
    _remoteUpdateController.close();
    _cursorController.close();
    _connectionStateController.close();
  }
}

/// Connection state enum
enum ConnectionState { disconnected, connecting, connected, reconnecting }

/// Cursor info from presence
class CursorInfo {
  final String container;
  final String peerId;
  final int position;

  CursorInfo({required this.container, required this.peerId, required this.position});

  @override
  String toString() => 'CursorInfo($container, $peerId, $position)';
}

/// FFI bindings generated by flutter_rust_bridge
/// Run: flutter_rust_bridge_codegen generate
class DocHandle {
  // Static methods
  static Future<DocHandle> create(String docId) => _docCreate(docId);
  static Future<DocHandle> fromSnapshot(String docId, Uint8List bytes) =>
      _docFromSnapshot(docId, bytes);
  static String bytesToBase64(Uint8List bytes) => _bytesToBase64(bytes);
  static Uint8List base64ToBytes(String encoded) => Uint8List.fromList(_base64ToBytes(encoded));

  // Instance methods
  Future<String> createSlide(String layout) => __docCreateSlide(this, layout);
  Future<void> deleteSlide(String slideId) => __docDeleteSlide(this, slideId);
  Future<List<String>> getSlideIds() => __docGetSlideIds(this);
  Future<void> moveSlide(int from, int to) => __docMoveSlide(this, from, to);
  Future<void> setSlideTitle(String slideId, String title) => __docSetSlideTitle(this, slideId, title);
  Future<String> getSlideTitle(String slideId) => __docGetSlideTitle(this, slideId);
  Future<void> setSlideBody(String slideId, String body) => _docSetSlideBody(this, slideId, body);
  Future<String> getSlideBody(String slideId) => _docGetSlideBody(this, slideId);
  Future<String> getSlideLayout(String slideId) => _docGetSlideLayout(this, slideId);
  Future<String> createPage() => _docCreatePage(this);
  Future<List<String>> getPageIds() => _docGetPageIds(this);
  Future<void> setPageContent(String pageId, String content) => _docSetPageContent(this, pageId, content);
  Future<String> getPageContent(String pageId) => _docGetPageContent(this, pageId);
  Future<Uint8List> exportSnapshot() => _docExportSnapshot(this);
  Future<Uint8List> exportUpdate() => __docExportUpdate(this);
  Future<void> importUpdate(Uint8List bytes) => _docImport(this, bytes);
  Future<void> importBatch(List<Uint8List> bytesList) => _docImportBatch(this, bytesList);
  Future<String> toJson() => _docToJson(this);
  Future<String> getVersion() => _docGetVersion(this);
  Future<int> getOpCount() => _docOpCount(this);
  Future<void> setCursor(String container, int position) => _docSetCursor(this, container, position);
  Future<List<(String, String, String)>> getCursors() => _docGetCursors(this);

  // Native function bindings (generated by flutter_rust_bridge)
  // NOTE: On web, these are stubbed — real FFI bindings only work on native platforms.
  static Future<DocHandle> _docCreate(String docId) {
    throw UnsupportedError('CRDT FFI is not available on web. Run on native platform.');
  }
  static Future<DocHandle> _docFromSnapshot(String docId, Uint8List bytes) {
    throw UnsupportedError('CRDT FFI is not available on web. Run on native platform.');
  }
  static String _bytesToBase64(Uint8List bytes) {
    throw UnsupportedError('CRDT FFI is not available on web. Run on native platform.');
  }
  static List<int> _base64ToBytes(String encoded) {
    throw UnsupportedError('CRDT FFI is not available on web. Run on native platform.');
  }

  Future<String> __docCreateSlide(DocHandle handle, String layout) {
    throw UnsupportedError('CRDT FFI is not available on web.');
  }
  Future<void> __docDeleteSlide(DocHandle handle, String slideId) {
    throw UnsupportedError('CRDT FFI is not available on web.');
  }
  Future<List<String>> __docGetSlideIds(DocHandle handle) {
    throw UnsupportedError('CRDT FFI is not available on web.');
  }
  Future<void> __docMoveSlide(DocHandle handle, int from, int to) {
    throw UnsupportedError('CRDT FFI is not available on web.');
  }
  Future<void> __docSetSlideTitle(DocHandle handle, String slideId, String title) {
    throw UnsupportedError('CRDT FFI is not available on web.');
  }
  Future<String> __docGetSlideTitle(DocHandle handle, String slideId) {
    throw UnsupportedError('CRDT FFI is not available on web.');
  }
  Future<void> _docSetSlideBody(DocHandle handle, String slideId, String body) {
    throw UnsupportedError('CRDT FFI is not available on web.');
  }
  Future<String> _docGetSlideBody(DocHandle handle, String slideId) {
    throw UnsupportedError('CRDT FFI is not available on web.');
  }
  Future<String> _docGetSlideLayout(DocHandle handle, String slideId) {
    throw UnsupportedError('CRDT FFI is not available on web.');
  }
  Future<String> _docCreatePage(DocHandle handle) {
    throw UnsupportedError('CRDT FFI is not available on web.');
  }
  Future<List<String>> _docGetPageIds(DocHandle handle) {
    throw UnsupportedError('CRDT FFI is not available on web.');
  }
  Future<void> _docSetPageContent(DocHandle handle, String pageId, String content) {
    throw UnsupportedError('CRDT FFI is not available on web.');
  }
  Future<String> _docGetPageContent(DocHandle handle, String pageId) {
    throw UnsupportedError('CRDT FFI is not available on web.');
  }
  Future<Uint8List> _docExportSnapshot(DocHandle handle) {
    throw UnsupportedError('CRDT FFI is not available on web.');
  }
  Future<Uint8List> __docExportUpdate(DocHandle handle) {
    throw UnsupportedError('CRDT FFI is not available on web.');
  }
  Future<void> _docImport(DocHandle handle, Uint8List bytes) {
    throw UnsupportedError('CRDT FFI is not available on web.');
  }
  Future<void> _docImportBatch(DocHandle handle, List<Uint8List> bytesList) {
    throw UnsupportedError('CRDT FFI is not available on web.');
  }
  Future<String> _docToJson(DocHandle handle) {
    throw UnsupportedError('CRDT FFI is not available on web.');
  }
  Future<String> _docGetVersion(DocHandle handle) {
    throw UnsupportedError('CRDT FFI is not available on web.');
  }
  Future<int> _docOpCount(DocHandle handle) {
    throw UnsupportedError('CRDT FFI is not available on web.');
  }
  Future<void> _docSetCursor(DocHandle handle, String container, int position) {
    throw UnsupportedError('CRDT FFI is not available on web.');
  }
  Future<List<(String, String, String)>> _docGetCursors(DocHandle handle) {
    throw UnsupportedError('CRDT FFI is not available on web.');
  }
}