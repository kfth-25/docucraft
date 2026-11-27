// DocuCraft — Sync Engine
// Menjembatani SlideProvider lokal dengan CollabWebSocketProvider remote
// Menangani: edit outbound → broadcast, update inbound → terapkan ke state lokal
//
// Arsitektur:
//   SlideProvider (state lokal)
//       ↕ SyncEngine
//   CollabWebSocketProvider (state remote via WebSocket)
//       ↕ WebSocket
//   Klien lain

import 'dart:async';

import '../models/slide.dart';
import '../providers/slide_provider.dart';
import 'collab_web_socket_provider.dart';
import 'presence.dart';

/// Sync direction
enum SyncDirection { outbound, inbound, conflict }

/// A sync event — unit of change between clients
class SyncEvent {
  final String type; // 'slide_add', 'slide_delete', 'element_update', 'element_add', etc.
  final String? slideId;
  final String? elementId;
  final Map<String, dynamic>? data;
  final String userId;
  final DateTime timestamp;

  SyncEvent({
    required this.type,
    this.slideId,
    this.elementId,
    this.data,
    required this.userId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'type': type,
    'slideId': slideId,
    'elementId': elementId,
    'data': data,
    'userId': userId,
    'timestamp': timestamp.toIso8601String(),
  };

  factory SyncEvent.fromJson(Map<String, dynamic> json) => SyncEvent(
    type: json['type'],
    slideId: json['slideId'],
    elementId: json['elementId'],
    data: json['data'] as Map<String, dynamic>?,
    userId: json['userId'],
    timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
  );
}

/// Sync Engine — manages bidirectional sync between local and remote state
class SyncEngine {
  final SlideProvider provider;
  final CollabWebSocketProvider yjsProvider;
  final String userId;
  String? _currentDocumentId;

  // Lock to prevent echo (applying remote update that came from us)
  bool _applyingRemoteUpdate = false;
  bool _isInitialized = false;

  // Local event log (for conflict resolution)
  final List<SyncEvent> _localEvents = [];
  final List<SyncEvent> _remoteEvents = [];
  static const int _maxEventLog = 500;

  // Streams
  final _syncStatusController = StreamController<CollabStatus>.broadcast();
  final _eventController = StreamController<SyncEvent>.broadcast();

  Stream<CollabStatus> get syncStatus => _syncStatusController.stream;
  Stream<SyncEvent> get events => _eventController.stream;
  bool get isConnected => yjsProvider.status == CollabStatus.connected;
  List<SyncEvent> get recentEvents => List.unmodifiable(_localEvents);
  List<PresenceUser> get awarenessUsers => yjsProvider.users;

  SyncEngine({
    required this.provider,
    required this.yjsProvider,
    required this.userId,
  });

  /// Initialize sync with a document
  Future<void> init(String documentId) async {
    if (_isInitialized) return;
    _currentDocumentId = documentId;

    // Listen for remote doc updates
    yjsProvider.docUpdateStream.listen(_onRemoteDocUpdate);

    // Listen for awareness updates (presence)
    yjsProvider.awarenessStream.listen(_onAwarenessUpdate);

    // Listen for status changes
    yjsProvider.statusStream.listen((status) {
      _syncStatusController.add(status);
    });

    // Connect
    await yjsProvider.connect();
    _isInitialized = true;
  }

  /// Disconnect from sync
  Future<void> disconnect() async {
    _isInitialized = false;
    await yjsProvider.disconnect();
  }

  // ── Outbound: local changes → broadcast ──

  /// Call this after every local edit in SlideProvider
  void onLocalEdit(String changeType, {String? slideId, String? elementId, Map<String, dynamic>? data}) {
    if (_applyingRemoteUpdate) return; // Don't echo remote updates

    final event = SyncEvent(
      type: changeType,
      slideId: slideId,
      elementId: elementId,
      data: data ?? _snapshotData(),
      userId: userId,
    );

    _addLocalEvent(event);
    _broadcastUpdate(event);
  }

  void _broadcastUpdate(SyncEvent event) {
    if (!isConnected) return;
    yjsProvider.sendUpdate(event.toJson());
  }

  // ── Inbound: remote changes → apply locally ──

  void _onRemoteDocUpdate(Map<String, dynamic> delta) {
    try {
      final event = SyncEvent.fromJson(delta);

      // Ignore our own updates (already applied locally)
      if (event.userId == userId) return;

      _applyingRemoteUpdate = true;
      _applyRemoteEvent(event);
      _applyingRemoteUpdate = false;
    } catch (e) {
      _applyingRemoteUpdate = false;
      print('⚠️ Sync engine: failed to apply remote update: $e');
    }
  }

  void _applyRemoteEvent(SyncEvent event) {
    _addRemoteEvent(event);
    _eventController.add(event);

    switch (event.type) {
      case 'slide_add':
        _applySlideAdd(event);
        break;
      case 'slide_delete':
        _applySlideDelete(event);
        break;
      case 'slide_reorder':
        _applySlideReorder(event);
        break;
      case 'element_add':
        _applyElementAdd(event);
        break;
      case 'element_update':
        _applyElementUpdate(event);
        break;
      case 'element_delete':
        _applyElementDelete(event);
        break;
      case 'title_change':
        _applyTitleChange(event);
        break;
      case 'background_change':
        _applyBackgroundChange(event);
        break;
      default:
        print('⚠️ Sync engine: unknown event type: ${event.type}');
    }
  }

  void _applySlideAdd(SyncEvent event) {
    if (event.data == null) return;
    final slideData = event.data!['slide'];
    if (slideData != null) {
      final slide = Slide.fromJson(slideData as Map<String, dynamic>);
      provider.syncAddSlide(slide);
    }
  }

  void _applySlideDelete(SyncEvent event) {
    if (event.slideId == null) return;
    provider.syncRemoveSlide(event.slideId!);
  }

  void _applySlideReorder(SyncEvent event) {
    if (event.data == null) return;
    final oldIdx = event.data!['oldIndex'] as int?;
    final newIdx = event.data!['newIndex'] as int?;
    if (oldIdx != null && newIdx != null) {
      provider.reorderSlide(oldIdx, newIdx);
    }
  }

  void _applyElementAdd(SyncEvent event) {
    if (event.data == null || event.slideId == null) return;
    final elementData = event.data!['element'];
    if (elementData != null) {
      final element = SlideElement.fromJson(elementData as Map<String, dynamic>);
      provider.syncAddElementToSlide(event.slideId!, element);
    }
  }

  void _applyElementUpdate(SyncEvent event) {
    if (event.data == null || event.slideId == null || event.elementId == null) return;
    final content = event.data!['content'] as String?;
    if (content != null) {
      provider.syncUpdateElement(event.slideId!, event.elementId!, content);
    }
  }

  void _applyElementDelete(SyncEvent event) {
    if (event.slideId == null || event.elementId == null) return;
    provider.syncRemoveElement(event.slideId!, event.elementId!);
  }

  void _applyTitleChange(SyncEvent event) {
    if (event.data == null || event.slideId == null) return;
    provider.updateSlideTitleBySync(event.slideId!, event.data!['title'] as String? ?? '');
  }

  void _applyBackgroundChange(SyncEvent event) {
    if (event.data == null || event.slideId == null) return;
    provider.updateSlideBgBySync(event.slideId!, event.data!['gradient'] as String? ?? 'indigo');
  }

  void _patchElement(SlideElement element, Map<String, dynamic> data) {
    if (data.containsKey('x')) element.x = (data['x'] as num).toDouble();
    if (data.containsKey('y')) element.y = (data['y'] as num).toDouble();
    if (data.containsKey('width')) element.width = (data['width'] as num).toDouble();
    if (data.containsKey('height')) element.height = (data['height'] as num).toDouble();
    if (data.containsKey('content')) {
      element.content = data['content'] as String?;
      element.richRuns = null;
    }
    if (data.containsKey('rotation')) element.rotation = (data['rotation'] as num).toDouble();
    if (data.containsKey('zIndex')) element.zIndex = data['zIndex'] as int;
  }

  // ── Presence ──

  void _onAwarenessUpdate(List<PresenceUser> users) {
    // Update UI with user presence (handled by PresenceOverlay widget)
  }

  /// Broadcast cursor position for presence
  void updatePresence(CursorState cursor) {
    yjsProvider.sendPresenceUpdate(PresenceState(
      cursor: cursor,
      viewportSlideIndex: provider.currentSlideIndex,
    ));
  }

  // ── Helpers ──

  Map<String, dynamic> _snapshotData() {
    return {
      'slides': provider.slides.map((s) => s.toJson()).toList(),
      'currentIndex': provider.currentSlideIndex,
    };
  }

  void _addLocalEvent(SyncEvent event) {
    _localEvents.add(event);
    if (_localEvents.length > _maxEventLog) _localEvents.removeAt(0);
  }

  void _addRemoteEvent(SyncEvent event) {
    _remoteEvents.add(event);
    if (_remoteEvents.length > _maxEventLog) _remoteEvents.removeAt(0);
  }

  void dispose() {
    _syncStatusController.close();
    _eventController.close();
    disconnect();
  }
}
