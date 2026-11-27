// DocuCraft — Collab Sync Adapter
// Menjembatani SlideProvider dengan SyncEngine untuk kolaborasi real-time
// Diekstrak dari SlideProvider demi single responsibility

import 'dart:developer';
import '../collab/sync_engine.dart';
import '../collab/collab_web_socket_provider.dart';
import '../collab/presence.dart';
import 'slide_provider.dart';

class CollabSyncAdapter {
  SlideProvider? _provider;
  SyncEngine? _engine;
  bool _applyingRemoteUpdate = false;

  CollabSyncAdapter([SlideProvider? provider]) {
    _provider = provider;
  }

  void updateProvider(SlideProvider provider) {
    _provider = provider;
    if (_engine != null) {
      // Recreate engine with new provider reference
      // This is needed because SyncEngine holds a reference to provider
      // In practice, we'd need to dispose and recreate, but for now just update
    }
  }

  SlideProvider get _p => _provider!;

  /// Initialize collaboration for a document
  Future<void> init({
    required String documentId,
    required String userId,
    required String userName,
  }) async {
    // Dispose previous if any
    _engine?.dispose();

    final collabWs = CollabWebSocketProvider(
      documentId: documentId,
      userId: userId,
      userName: userName,
      userColor: '#6366F1',
    );

    _engine = SyncEngine(
      provider: _p,
      yjsProvider: collabWs,
      userId: userId,
    );

    await _engine!.init(documentId);
    _setupListeners();
  }

  void _setupListeners() {
    _engine?.events.listen(_onSyncEvent);
  }

  void _onSyncEvent(dynamic event) {
    log('📡 Collab event: ${event.type}');
  }

  /// Call after every local edit in SlideProvider
  void onLocalEdit(String changeType, {String? slideId, String? elementId, Map<String, dynamic>? data}) {
    if (_applyingRemoteUpdate) return; // Don't echo remote updates
    _engine?.onLocalEdit(changeType, slideId: slideId, elementId: elementId, data: data);
  }

  /// Apply remote update (called by SyncEngine internally)
  void setApplyingRemoteUpdate(bool value) {
    _applyingRemoteUpdate = value;
  }

  bool get isConnected => _engine?.isConnected ?? false;
  List<dynamic> get awarenessUsers => _engine?.awarenessUsers ?? [];

  /// Broadcast cursor position for presence
  void updatePresence(double x, double y, int viewportSlideIndex) {
    _engine?.updatePresence(CursorState(x: x, y: y, slideIndex: viewportSlideIndex));
  }

  void dispose() {
    _engine?.dispose();
    _engine = null;
  }
}