// DocuCraft — WebSocket Service for Loro CRDT Sync
//
// Menggantikan CollabWebSocketProvider dengan binary sync yang kompatibel Loro.
// Memakai protokol collab server yang sudah ada tapi mengirim Loro binary update.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

/// WebSocket service that syncs Loro CRDT binary updates.
///
/// Protocol:
/// - Client → Server: binary Loro update (Uint8List) or JSON control messages
/// - Server → Client: binary Loro update or JSON control messages
/// - Control messages: join, leave, snapshot_req, ack, ping/pong
class CrdtWebSocketSync {
  final String documentId;
  final String userId;
  final String userName;
  final String serverUrl;

  WebSocketChannel? _channel;
  StreamController<Uint8List>? _updateController;
  StreamController<SyncEvent>? _eventController;
  StreamController<ConnectionState>? _stateController;

  bool _isConnected = false;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  static const int _maxReconnectAttempts = 10;
  static const Duration _pingInterval = Duration(seconds: 30);

  CrdtWebSocketSync({
    required this.documentId,
    required this.userId,
    required this.userName,
    this.serverUrl = 'ws://127.0.0.1:9101',
  });

  /// Initialize and connect
  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;

    _isConnecting = true;
    _updateController = StreamController<Uint8List>.broadcast();
    _eventController = StreamController<SyncEvent>.broadcast();
    _stateController = StreamController<ConnectionState>.broadcast();

    _stateController!.add(ConnectionState.connecting);

    try {
      final uri = Uri.parse('$serverUrl/ws/$documentId');
      _channel = WebSocketChannel.connect(uri);

      _channel!.ready.then((_) {
        _isConnecting = false;
        _isConnected = true;
        _reconnectAttempts = 0;
        _stateController!.add(ConnectionState.connected);

        // Send join message
        _sendJoin();

        // Start ping timer
        _startPingTimer();
      }).catchError((e) {
        _isConnecting = false;
        _handleError('Connection failed: $e');
      });

      // Listen for messages
      _channel!.stream.listen(
        _onMessage,
        onDone: _onDisconnected,
        onError: (error) => _handleError('WebSocket error: $error'),
      );
    } catch (e) {
      _isConnecting = false;
      _handleError('Connect error: $e');
    }
  }

  void _sendJoin() {
    _channel?.sink.add(jsonEncode({
      'type': 'join',
      'clientId': userId,
      'documentId': documentId,
      'userName': userName,
    }));
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_isConnected) {
        _channel?.sink.add(jsonEncode({'type': 'ping'}));
      }
    });
  }

  void _onMessage(dynamic message) {
    if (message is Uint8List) {
      // Binary Loro update from another peer
      _updateController?.add(Uint8List.fromList(message));
    } else if (message is String) {
      try {
        final data = jsonDecode(message) as Map<String, dynamic>;
        final type = data['type'] as String?;

        switch (type) {
          case 'ack':
            // Server acknowledged our update
            break;
          case 'snapshot':
            // Full snapshot from server
            final slidesData = data['slides'] as List?;
            if (slidesData != null) {
              _eventController?.add(SyncEvent(
                type: 'snapshot',
                data: {'slides': slidesData},
                userId: 'server',
              ));
            }
            break;
          case 'error':
            _handleError(data['message'] as String? ?? 'Server error');
            break;
          case 'pong':
            break;
        }
      } catch (e) {
        debugPrint('Parse error: $e');
      }
    }
  }

  void _onDisconnected() {
    _isConnected = false;
    _pingTimer?.cancel();
    _stateController?.add(ConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _handleError('Max reconnect attempts reached');
      return;
    }

    _reconnectAttempts++;
    _stateController?.add(ConnectionState.reconnecting);

    final delay = Duration(seconds: (1 << _reconnectAttempts).clamp(1, 30));
    _reconnectTimer = Timer(delay, () {
      if (!_isConnected) {
        connect();
      }
    });
  }

  void _handleError(String error) {
    debugPrint('❌ CRDT WebSocket: $error');
    _eventController?.add(SyncEvent(
      type: 'error',
      data: {'message': error},
      userId: 'system',
    ));
  }

  /// Send a Loro binary update to the server
  void sendUpdate(Uint8List update) {
    if (!_isConnected) return;
    _channel?.sink.add(update);
  }

  /// Request full snapshot from server
  void requestSnapshot() {
    if (!_isConnected) return;
    _channel?.sink.add(jsonEncode({'type': 'snapshot_req'}));
  }

  /// Get stream of binary updates from other peers
  Stream<Uint8List> get updates => _updateController!.stream;

  /// Get stream of control events (snapshot, error, etc.)
  Stream<SyncEvent> get events => _eventController!.stream;

  /// Get connection state stream
  Stream<ConnectionState> get connectionState => _stateController!.stream;

  bool get isConnected => _isConnected;

  /// Disconnect cleanly
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _isConnected = false;
    _channel?.sink.close();
    _channel = null;

    await _updateController?.close();
    await _eventController?.close();
    await _stateController?.close();
  }

  void dispose() {
    disconnect();
  }
}

/// Connection state
enum ConnectionState { disconnected, connecting, connected, reconnecting }

/// Sync event for control messages
class SyncEvent {
  final String type;
  final Map<String, dynamic>? data;
  final String userId;
  final DateTime timestamp;

  SyncEvent({
    required this.type,
    this.data,
    required this.userId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'type': type,
    'data': data,
    'userId': userId,
    'timestamp': timestamp.toIso8601String(),
  };
}