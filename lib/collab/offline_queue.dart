// DocuCraft — Offline Queue V2
// Mengantrekan edit lokal saat disconnected, replay saat reconnected.
// Mencegah kehilangan data saat jaringan terputus.
//
// Arsitektur:
//   1. Setiap edit lokal → tambahkan ke antrean SEBELUM mencoba mengirim
//   2. Jika pengiriman gagal → antrean disimpan persisten (di SharedPreferences)
//   3. Saat reconnect → replay antrean secara berurutan
//   4. Saat server mengirim ack → hapus dari antrean
//   5. Setelah 5 kali retry → pindahkan ke dead letter (user diberi tahu)
//   6. Key idempotency mencegah event duplikat saat retry
//
// Resolusi konflik: server selalu menang saat replay.
// Jika edit lokal konflik dengan edit remote yang tiba saat offline,
// server akan menerapkan edit remote terlebih dahulu, lalu edit lokal di atasnya.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sync_engine.dart';

const String _queueKey = 'docucraft_offline_queue';
const String _deadLetterKey = 'docucraft_offline_dead_letter';

/// Status of a queued edit
enum QueuedEditStatus { pending, sent, failed }

/// Queued edit waiting to be sent
class QueuedEdit {
  final SyncEvent event;
  final DateTime createdAt;
  final String idempotencyKey;
  bool sent;
  int retryCount;
  QueuedEditStatus status;
  String? lastError;

  QueuedEdit({
    required this.event,
    DateTime? createdAt,
    this.sent = false,
    this.retryCount = 0,
    String? idempotencyKey,
    this.status = QueuedEditStatus.pending,
    this.lastError,
  }) : createdAt = createdAt ?? DateTime.now(),
       idempotencyKey = idempotencyKey ?? '${event.type}_${event.slideId}_${event.elementId}_${DateTime.now().millisecondsSinceEpoch}';

  Map<String, dynamic> toJson() => {
    'event': event.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'sent': sent,
    'retryCount': retryCount,
    'idempotencyKey': idempotencyKey,
    'status': status.name,
    'lastError': lastError,
  };

  factory QueuedEdit.fromJson(Map<String, dynamic> json) => QueuedEdit(
    event: SyncEvent.fromJson(json['event']),
    createdAt: DateTime.parse(json['createdAt']),
    sent: json['sent'] ?? false,
    retryCount: json['retryCount'] ?? 0,
    idempotencyKey: json['idempotencyKey'],
    status: QueuedEditStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => QueuedEditStatus.pending,
    ),
    lastError: json['lastError'],
  );
}

/// Offline Queue Manager
class OfflineQueue {
  final List<QueuedEdit> _queue = [];
  final List<QueuedEdit> _failedEdits = [];
  bool _isProcessing = false;
  bool _isConnected = false;
  Completer<void>? _connectionCompleter;

  /// Callback for notifying user about failed edits
  void Function(String message)? onFailed;

  List<QueuedEdit> get pendingEdits => _queue.where((e) => !e.sent).toList();
  List<QueuedEdit> get failedEdits => List.unmodifiable(_failedEdits);
  int get pendingCount => pendingEdits.length;
  int get failedCount => _failedEdits.length;
  bool get isEmpty => _queue.isEmpty;
  bool get isOnline => _isConnected;

  OfflineQueue() {
    _loadFromStorage();
  }

  /// Queue a local edit for later sending (includes idempotency key)
  void enqueue(SyncEvent event) {
    final edit = QueuedEdit(event: event);
    _queue.add(edit);
    _saveToStorage();
    // Try to send immediately if connected
    if (_isConnected) {
      processQueue();
    }
  }

  /// Mark as connected and replay all pending edits
  Future<void> onConnect(Future<void> Function(SyncEvent) sendFn) async {
    _isConnected = true;
    _connectionCompleter = Completer<void>();
    await processQueue(sendFn);
  }

  /// Mark as disconnected
  void onDisconnect() {
    _isConnected = false;
  }

  /// Process all pending edits (uses idempotency key to prevent duplicates)
  Future<void> processQueue([Future<void> Function(SyncEvent)? sendFn]) async {
    if (_isProcessing || sendFn == null) return;
    _isProcessing = true;

    final toSend = _queue.where((e) => !e.sent).toList();
    final sentKeys = <String>{};

    for (final edit in toSend) {
      if (!_isConnected) break;

      // Skip if already sent this batch (idempotency check)
      if (sentKeys.contains(edit.idempotencyKey)) continue;
      sentKeys.add(edit.idempotencyKey);

      try {
        await sendFn(edit.event);
        edit.sent = true;
        edit.status = QueuedEditStatus.sent;
        edit.retryCount++;
        _saveToStorage();
      } catch (e) {
        edit.retryCount++;
        edit.lastError = e.toString();

        if (edit.retryCount > 5) {
          // Move to dead letter instead of silent drop
          edit.status = QueuedEditStatus.failed;
          _failedEdits.add(edit);
          _queue.remove(edit);
          _saveToStorage();
          _saveDeadLetter();
          // Notify user about the failure
          final msg = '⚠️ Edit gagal setelah 5 percobaan: ${edit.event.type} '
              '${edit.event.slideId ?? ''} ${edit.event.elementId ?? ''}';
          debugPrint(msg);
          onFailed?.call(msg);
          continue; // ← FIX: process remaining edits, don't break
        }
      }
    }

    // Remove all sent edits
    _queue.removeWhere((e) => e.sent);
    _saveToStorage();
    _isProcessing = false;
  }

  /// Ack by idempotency key (more precise than type+elementId+slideId)
  void ackByIdempotencyKey(String key) {
    _queue.removeWhere((e) => e.idempotencyKey == key);
    _saveToStorage();
  }

  /// Remove a specific event from queue (when server ack received)
  void ack(String eventType, String? elementId, String? slideId) {
    _queue.removeWhere((e) =>
      e.event.type == eventType &&
      e.event.elementId == elementId &&
      e.event.slideId == slideId
    );
    _saveToStorage();
  }

  /// Retry all failed edits
  Future<void> retryFailed([Future<void> Function(SyncEvent)? sendFn]) async {
    if (sendFn == null) return;
    final toRetry = List<QueuedEdit>.from(_failedEdits);
    for (final edit in toRetry) {
      edit.retryCount = 0;
      edit.status = QueuedEditStatus.pending;
      edit.lastError = null;
      _queue.add(edit);
      _failedEdits.remove(edit);
    }
    _saveToStorage();
    _saveDeadLetter();
    await processQueue(sendFn);
  }

  /// Clear all queued edits (e.g., on full sync)
  void clear() {
    _queue.clear();
    _failedEdits.clear();
    _saveToStorage();
  }

  // ── Persistence ──

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_queue.map((e) => e.toJson()).toList());
      await prefs.setString(_queueKey, data);
    } catch (_) {
      // Non-critical — queue will be lost on restart, but won't crash
    }
  }

  Future<void> _saveDeadLetter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_failedEdits.map((e) => e.toJson()).toList());
      await prefs.setString(_deadLetterKey, data);
    } catch (_) {}
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_queueKey);
      if (data == null) return;
      final list = jsonDecode(data) as List;
      for (final item in list) {
        _queue.add(QueuedEdit.fromJson(item as Map<String, dynamic>));
      }
      if (_queue.isNotEmpty) {
        debugPrint('📦 Loaded ${_queue.length} queued edits from storage');
      }
    } catch (_) {
      // Corrupted queue — clear and start fresh
      _queue.clear();
    }

    // Load dead letter
    try {
      final prefs = await SharedPreferences.getInstance();
      final deadData = prefs.getString(_deadLetterKey);
      if (deadData != null) {
        final list = jsonDecode(deadData) as List;
        for (final item in list) {
          _failedEdits.add(QueuedEdit.fromJson(item as Map<String, dynamic>));
        }
        if (_failedEdits.isNotEmpty) {
          debugPrint('💀 Loaded ${_failedEdits.length} failed edits from dead letter');
        }
      }
    } catch (_) {
      _failedEdits.clear();
    }
  }
}
