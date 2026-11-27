// DocuCraft — AI Error Classification (terinspirasi GenOffice)
//
// Mengklasifikasikan kegagalan ke dalam kategori yang menentukan perilaku retry:
// - timeout: silence watchdog fired (giliran mati), jangan retry dengan model berbeda
// - empty: model mengembalikan output kosong, jangan retry dengan model berbeda
// - stopped: user membatalkan, jangan retry
// - api: error request/HTTP, BISA retry dengan model fallback

import 'dart:async' show TimeoutException;

/// Error classification that determines retry behavior.
/// Mirrors GenOffice's `errKind` in AiPanel.tsx.
enum AiErrKind {
  /// Silence watchdog fired — no chunks received within timeout.
  /// Switching models won't help (likely network/stall issue).
  timeout,

  /// Model returned empty output (no content in response).
  /// Switching models won't help (likely prompt/model issue).
  empty,

  /// User explicitly stopped the generation.
  stopped,

  /// API/HTTP error (4xx, 5xx, network failure).
  /// CAN retry with fallback model (transient or model-specific).
  api,
}

/// Classified error result from an LLM call.
/// Mirrors GenOffice's `LlmResult` type.
class AiLlmResult {
  final bool ok;
  final String? text;
  final String? error;
  final AiErrKind? errKind;

  const AiLlmResult({
    required this.ok,
    this.text,
    this.error,
    this.errKind,
  });

  /// Whether this error should NOT trigger a model fallback retry.
  bool get shouldNotRetry => errKind != null && errKind != AiErrKind.api;

  /// Human-readable error message for UI display.
  String get displayMessage {
    if (error != null) return error!;
    switch (errKind) {
      case AiErrKind.timeout:
        return 'AI timeout — no response received';
      case AiErrKind.empty:
        return 'AI returned empty output';
      case AiErrKind.stopped:
        return 'Generation stopped by user';
      case AiErrKind.api:
        return 'API error — try again';
      case null:
        return 'Unknown error';
    }
  }

  /// Create a timeout error result.
  factory AiLlmResult.timeout({String? error}) => AiLlmResult(
    ok: false,
    error: error ?? 'AI timeout — no response received',
    errKind: AiErrKind.timeout,
  );

  /// Create an empty output error result.
  factory AiLlmResult.empty({String? error}) => AiLlmResult(
    ok: false,
    error: error ?? 'AI returned empty output',
    errKind: AiErrKind.empty,
  );

  /// Create a user-stopped error result.
  factory AiLlmResult.stopped() => const AiLlmResult(
    ok: false,
    error: 'Generation stopped by user',
    errKind: AiErrKind.stopped,
  );

  /// Create an API error result (can retry with fallback).
  factory AiLlmResult.apiError(String error) => AiLlmResult(
    ok: false,
    error: error,
    errKind: AiErrKind.api,
  );

  /// Create a success result.
  factory AiLlmResult.success(String text) => AiLlmResult(
    ok: true,
    text: text,
  );

  @override
  String toString() => 'AiLlmResult(ok=$ok, errKind=$errKind, error=$error)';
}

/// Classify an exception into an AiErrKind.
AiErrKind classifyException(Object e) {
  final msg = e.toString().toLowerCase();

  // Timeout detection
  if (e is TimeoutException) return AiErrKind.timeout;
  if (msg.contains('timeout') || msg.contains('timed out')) return AiErrKind.timeout;

  // Empty stream detection
  if (msg.contains('empty stream') || msg.contains('empty output')) return AiErrKind.empty;

  // User abort detection
  if (msg.contains('abort') || msg.contains('cancel') || msg.contains('stop')) {
    return AiErrKind.stopped;
  }

  // Everything else is API error (can retry with fallback)
  return AiErrKind.api;
}
