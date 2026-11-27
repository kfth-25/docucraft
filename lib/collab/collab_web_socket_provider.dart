// DocuCraft — CollabWebSocketProvider V2 (Real WebSocket)
// Menghubungkan ke collab_server via WebSocket, mengelola doc sync + awareness.
//
// Catatan: Meskipun nama lamanya "YjsProvider", ini adalah WebSocket
// JSON sync provider biasa — TIDAK memakai library Yjs CRDT. Resolusi konflik
// ditangani oleh ConflictResolver (LWW) di modul terpisah.
//
// Fitur:
//   - Koneksi WebSocket nyata ke collab_server (port 9101)
//   - Reconnect otomatis dengan exponential backoff
//   - Offline queue: edit lokal disimpan saat disconnect, di-replay saat reconnect
//   - Resolusi konflik LWW via ConflictResolver
//   - Broadcasting awareness (presence)
//
// Penggunaan:
//   final collab = CollabWebSocketProvider(
//     documentId: 'doc-123',
//     userId: 'user-abc',
//     userName: 'Rina',
//   );
//   await collab.connect();
//   collab.docUpdateStream.listen((delta) { ... });

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'presence.dart';
import 'offline_queue.dart';
import 'conflict_resolver.dart';
import 'sync_engine.dart';

/// Connection status
enum CollabStatus { disconnected, connecting, connected, reconnecting }

/// CollabWebSocketProvider — manages WebSocket connection and collaboration state
class CollabWebSocketProvider {
  final String documentId;
  final String? serverUrl;
  final String userId;
  final String userName;
  final String? userColor;

  CollabWebSocketProvider({
    required this.documentId,
    this.serverUrl,
    required this.userId,
    required this.userName,
    this.userColor,
  }) {
    _serverUrl = serverUrl ?? 'ws://127.0.0.1:9101';
  }

  late String _serverUrl;
  WebSocketChannel? _wsChannel;
  CollabStatus _status = CollabStatus.disconnected;
  CollabStatus get status => _status;

  final List<PresenceUser> _users = [];
  List<PresenceUser> get users => List.unmodifiable(_users);

  int _serverVersion = 0;
  int get serverVersion => _serverVersion;

  final _offlineQueue = OfflineQueue();
  OfflineQueue get offlineQueue => _offlineQueue;

  // Reconnect state
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int MAX_RECONNECT_ATTEMPTS = 10;

  // Streams
  final _statusController = StreamController<CollabStatus>.broadcast();
  final _docUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _awarenessController = StreamController<List<PresenceUser>>.broadcast();
  final _connectionErrorController = StreamController<String>.broadcast();

  Stream<CollabStatus> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get docUpdateStream => _docUpdateController.stream;
  Stream<List<PresenceUser>> get awarenessStream => _awarenessController.stream;
  Stream<String> get connectionErrors => _connectionErrorController.stream;

  bool get isConnected => _status == CollabStatus.connected;

  // ── Connection lifecycle ──

  Future<void> connect() async {
    if (_status == CollabStatus.connected || _status == CollabStatus.connecting) return;

    _updateStatus(CollabStatus.connecting);

    try {
      final uri = Uri.parse('$_serverUrl');
      _wsChannel = WebSocketChannel.connect(uri);

      // Send join message after connection is established
      _wsChannel!.ready.then((_) {
        _wsChannel!.sink.add(jsonEncode({
          'type': 'join',
          'clientId': userId,
          'documentId': documentId,
        }));

        _updateStatus(CollabStatus.connected);
        _reconnectAttempts = 0;

        // Process any queued edits
        _offlineQueue.onConnect(_sendEvent);
      }).catchError((e) {
        _updateStatus(CollabStatus.disconnected);
        _connectionErrorController.add('Connection failed: $e');
        _scheduleReconnect();
      });

      // Listen for messages
      _wsChannel!.stream.listen(
        (message) => _onMessage(message),
        onDone: () {
          _updateStatus(CollabStatus.disconnected);
          _scheduleReconnect();
        },
        onError: (error) {
          _updateStatus(CollabStatus.disconnected);
          _connectionErrorController.add('WebSocket error: $error');
          _scheduleReconnect();
        },
      );
    } catch (e) {
      _updateStatus(CollabStatus.disconnected);
      _connectionErrorController.add('Connect error: $e');
      _scheduleReconnect();
    }
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _wsChannel?.sink.close();
    _wsChannel = null;
    _users.clear();
    _awarenessController.add(_users);
    _updateStatus(CollabStatus.disconnected);
  }

  // ── Outbound: send changes ──

  void sendUpdate(Map<String, dynamic> delta) {
    if (!isConnected) {
      // Queue for later
      final event = SyncEvent(
        type: delta['eventType'] ?? 'unknown',
        data: delta,
        userId: userId,
      );
      _offlineQueue.enqueue(event);
      return;
    }

    _wsChannel!.sink.add(jsonEncode({
      'type': 'update',
      'eventType': delta['eventType'],
      'data': delta['data'],
      'userId': userId,
    }));
  }

  void sendPresenceUpdate(PresenceState state) {
    if (!isConnected) return;

    _wsChannel!.sink.add(jsonEncode({
      'type': 'awareness',
      'userId': userId,
      'data': state.toJson(),
    }));
  }

  /// Request full snapshot from server
  void requestSnapshot() {
    if (!isConnected) return;
    _wsChannel!.sink.add(jsonEncode({'type': 'snapshot_req'}));
  }

  // ── Inbound: handle messages ──

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'joined':
          _onJoined(data);
          break;
        case 'update':
          _onRemoteUpdate(data);
          break;
        case 'awareness':
          _onRemoteAwareness(data);
          break;
        case 'snapshot':
          _onSnapshot(data);
          break;
        case 'ack':
          _onAck(data);
          break;
        case 'ping':
          _wsChannel?.sink.add(jsonEncode({'type': 'ping'}));
          break;
        case 'pong':
          // Server acknowledged our ping
          break;
        case 'error':
          _connectionErrorController.add(data['message'] as String);
          break;
      }
    } catch (e) {
      _connectionErrorController.add('Parse error: $e');
    }
  }

  void _onJoined(Map<String, dynamic> data) {
    final users = data['onlineUsers'] as List?;
    // TODO: parse users
  }

  void _onRemoteUpdate(Map<String, dynamic> data) {
    final delta = data['data'] as Map<String, dynamic>?;
    final eventType = data['eventType'] as String?;
    final serverVersion = data['serverVersion'] as int? ?? 0;

    if (delta == null) return;

    _serverVersion = serverVersion;
    _docUpdateController.add({
      'eventType': eventType,
      'data': delta,
      'serverVersion': serverVersion,
    });
  }

  void _onRemoteAwareness(Map<String, dynamic> data) {
    final userId = data['userId'] as String?;
    final action = data['action'] as String?;
    final presenceData = data['data'] as Map<String, dynamic>?;

    if (userId == null) return;

    if (action == 'offline') {
      _users.removeWhere((u) => u.userId == userId);
    } else if (action == 'online' || presenceData != null) {
      final existing = _users.where((u) => u.userId == userId).firstOrNull;
      if (existing != null) {
        if (presenceData != null) {
          existing.cursor = CursorState.fromJson(presenceData);
        }
      } else {
        final name = presenceData?['name'] as String? ?? 'User';
        _users.add(PresenceUser(
          userId: userId,
          name: name,
          color: userColor,
        ));
      }
    }
    _awarenessController.add(_users);
  }

  void _onSnapshot(Map<String, dynamic> data) {
    final slidesData = data['slides'] as List?;
    final version = data['version'] as int? ?? 0;

    if (slidesData != null) {
      _serverVersion = version;
      _docUpdateController.add({
        'eventType': 'snapshot',
        'data': {'slides': slidesData, 'version': version},
      });
    }
  }

  void _onAck(Map<String, dynamic> data) {
    final serverVersion = data['serverVersion'] as int?;
    if (serverVersion != null) {
      _serverVersion = serverVersion;
    }
  }

  // ── Private helpers ──

  Future<void> _sendEvent(SyncEvent event) async {
    if (!isConnected) return;
    _wsChannel!.sink.add(jsonEncode({
      'type': 'update',
      'eventType': event.type,
      'data': event.data,
      'userId': userId,
      // Include idempotency key for server-side deduplication
      'idempotencyKey': event.data?['idempotencyKey'] ?? event.type,
    }));
  }

  void _updateStatus(CollabStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
      _connectionErrorController.add('Max reconnect attempts reached. Please check your connection.');
      return;
    }

    _reconnectAttempts++;
    _updateStatus(CollabStatus.reconnecting);

    final delay = Duration(seconds: (1 << _reconnectAttempts).clamp(1, 30).toInt());
    _reconnectTimer = Timer(delay, () => connect());
  }

  /// Convert remote data to a local-compatible format (simplified)
  dynamic _snapToLocal(Map<String, dynamic> data) {
    return data;
  }

  void dispose() {
    _statusController.close();
    _docUpdateController.close();
    _awarenessController.close();
    _connectionErrorController.close();
    _reconnectTimer?.cancel();
    _wsChannel?.sink.close();
  }
}
