// DocuCraft Flutter — AI Run Provider (Sprint 12)
//
// ChangeNotifier pembungkus mesin RunState murni. Host (AiChatPanel)
// mendengarkan provider ini dan memanggil method aksinya dari callback
// AgentLoop (onText, onTool*, onDone, onError).
//
// Side effects yang dipegang provider ini:
//   - Menjaga Timer yang berdetak tiap 5 detik selama streaming untuk
//     mendeteksi keheningan (silence).
//   - Menjaga RunSnapshot mutable yang dibaca host di tengah jalan.
//   - Memberi tahu listener pada setiap transisi state.
//
// Callback run-loop host dipasang SEKALI (saat loop dibuat) dan membaca
// runProvider.getSnapshot() untuk mendapatkan nilai terbaru. Ini
// mencerminkan bentuk useRunStateMachine milik GenOffice.
//
// Kenapa ChangeNotifier (Provider) dan bukan ValueNotifier:
//   - Proyek Keqo sudah memakai Provider + ChangeNotifier (slide_provider).
//   - ChangeNotifier bisa menggabungkan banyak perubahan state lewat
//     panggilan notifyListeners() selektif. Untuk panel chat dengan stream
//     teks yang sering, kami hanya notifyListeners() saat phase berubah
//     (bukan di setiap chunk teks — itu akan membanjiri render).

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../ai/run_state_machine.dart';

/// Provider-side facade for the run state machine. One instance per chat
/// panel (or singleton for the whole app — both are fine; we recommend
/// singleton for a multi-panel app).
class AiRunProvider extends ChangeNotifier {
  RunState _state = const RunIdle();
  final RunSnapshot _snapshot = RunSnapshot();

  Timer? _silenceTimer;
  bool _silenceFlag = false;
  /// 45s silence threshold — well below IPC_STREAM_SILENCE_TIMEOUT_MS (240s)
  /// but above any normal tool call.
  static const Duration silenceThreshold = Duration(seconds: 45);
  static const Duration silenceTick = Duration(seconds: 5);

  /// Resolver for an outstanding outline review promise. Set on
  /// `enterOutlineReview`, consumed by `resolveOutlineReview` or
  /// `newChat` (drain as cancelled).
  void Function(List<OutlinePage>? pages, bool cancelled)? _outlineResolver;

  // ── Read API ──────────────────────────────────────────────────────

  RunState get state => _state;
  RunSnapshot get snapshot => _snapshot;

  /// Convenience: same as `state.isBusy`.
  bool get isBusy => _state.isBusy;

  /// True iff the stream is idle > silenceThreshold ms. Reset on every
  /// text/tool event. UI shows a "Thinking deeper…" label when this is
  /// true. (Sprint 5 silence watchdog.)
  bool get isSilent => _silenceFlag;

  // ── Lifecycle ─────────────────────────────────────────────────────

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _drainOutlineReview(cancelled: true);
    super.dispose();
  }

  // ── Action API ────────────────────────────────────────────────────

  /// Begin a new run. No-op if a run is already in flight.
  void start({required String instruction, String? displayText}) {
    if (_state.isBusy) return;
    _snapshot.instruction = instruction;
    _snapshot.displayText = displayText;
    _snapshot.lastInstruction = instruction;
    _snapshot.lastDisplayText = displayText;
    _snapshot.streamedText = '';
    _snapshot.qcPages = <int>[];
    _snapshot.runTools = <ToolActivity>[];
    _snapshot.docucraftMeta = null;
    _transition(StartRun(now: DateTime.now(), instruction: instruction, displayText: displayText));
  }

  /// User-cancelled the run. Waits for onDone({cancelled:true}) to settle.
  void cancel({String reason = 'user'}) {
    if (_state is! RunStreaming) return;
    _transition(CancelRun(now: DateTime.now(), reason: reason));
  }

  /// Reset everything. Cancels any pending outline review as cancelled.
  void newChat() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _silenceFlag = false;
    _drainOutlineReview(cancelled: true);
    _snapshot.reset();
    _transition(NewChat(now: DateTime.now()));
  }

  /// Streamed a chunk of text.
  void onText(String text) {
    _snapshot.streamedText += text;
    _bumpActivity();
    _transition(TextChunk(now: DateTime.now(), text: text));
  }

  /// A tool call started.
  void onToolStart(String toolName, {String? summary}) {
    _snapshot.runTools.add(ToolActivity(
      name: toolName,
      summary: summary ?? toolName.replaceAll('_', ' '),
      running: true,
    ));
    _bumpActivity();
    _transition(ToolStart(now: DateTime.now(), toolName: toolName));
  }

  /// A tool call finished. Captures blueprint meta when the tool is
  /// `generate_deck` (Sprint 3 + Sprint 10).
  void onToolExecuted(String toolName, {Map<String, dynamic>? result, bool isError = false, String? summary, String? output}) {
    // Mark the tool as not running in the snapshot.
    final idx = _snapshot.runTools.lastIndexWhere((t) => t.name == toolName && t.running);
    if (idx >= 0) {
      _snapshot.runTools[idx] = ToolActivity(
        name: toolName,
        summary: summary ?? toolName.replaceAll('_', ' '),
        running: false,
        isError: isError,
        output: output,
      );
    }

    // Capture blueprint meta from generate_deck.
    if (toolName == 'generate_deck' && result != null) {
      final current = _snapshot.docucraftMeta;
      final meta = DeckBlueprintMeta(
        topic: result['topic'] as String? ?? current?.topic,
        styleSkill: result['styleSkill'] as String? ?? current?.styleSkill,
        outlineJson: result['outlineJson'] as String? ?? current?.outlineJson,
        pageCount: (result['pageCount'] as num?)?.toInt() ?? current?.pageCount,
        style: current?.style,
        plan: current?.plan,
        images: current?.images,
        pages: current?.pages,
        isDone: true,
      );
      _snapshot.docucraftMeta = meta;
    }

    _bumpActivity();
    // If state is still RunStarting (AI called tool without producing text
    // first), force a notify so the UI picks up the tool activity immediately.
    // Otherwise the message stays empty and the spinner never resolves.
    final shouldNotify = _state is RunStarting;
    _transition(ToolExecuted(now: DateTime.now(), toolName: toolName, result: result), notify: shouldNotify);
  }

  /// LLM returned control at the end of a turn.
  void onTurnEnd() {
    _transition(TurnEnd(now: DateTime.now()), notify: false);
  }

  /// Run finished. The host can read _snapshot.* to persist results.
  void onDone({required bool cancelled, required bool ok, required Duration duration}) {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _silenceFlag = false;
    _transition(DoneRun(now: DateTime.now(), cancelled: cancelled, ok: ok, duration: duration));
  }

  /// Run errored.
  void onError(String message, {bool recoverable = true}) {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _silenceFlag = false;
    _snapshot.docucraftMeta = null; // don't save a half-baked blueprint
    _transition(ErrorRun(now: DateTime.now(), message: message, recoverable: recoverable));
  }

  /// AI planned a deck and is paused for the user to edit the outline.
  /// Returns a Future that resolves with the edited pages (or null if
  /// cancelled). The host awaits this before continuing the run.
  /// Also receives [planSummary] from AI's "Briefly explain your reasoning" text.
  Future<List<OutlinePage>?> enterOutlineReview({
    required String topic,
    required List<OutlinePage> pages,
    String? planSummary,
  }) {
    final completer = Completer<List<OutlinePage>?>();
    _outlineResolver = (p, c) {
      if (!completer.isCompleted) completer.complete(c ? null : p);
    };
    _transition(EnterOutlineReview(now: DateTime.now(), topic: topic, pages: pages, planSummary: planSummary));
    return completer.future;
  }

  /// Resolve a pending outline review.
  void resolveOutlineReview({List<OutlinePage>? pages, bool cancelled = false}) {
    if (_state is! RunAwaitingOutlineReview) return;
    _transition(ResolveOutlineReview(now: DateTime.now(), pages: pages, cancelled: cancelled));
    final r = _outlineResolver;
    _outlineResolver = null;
    r?.call(pages, cancelled);
  }

  /// QC pass started.
  void enterQc({required int total}) {
    _transition(EnterQc(now: DateTime.now(), total: total));
  }

  /// One page finished QC.
  void tickQcProgress({required int done}) {
    _transition(TickQcProgress(now: DateTime.now(), done: done), notify: false);
  }

  /// Progress callback from coordinator (style → plan → images → pages stages)
  /// Updates snapshot with granular stage progress info for UI display
  void onProgress({
    required String stage,
    required String label,
    required int done,
    required int total,
    required String status,
    String? summary,
    List<PageProgressItem>? pages,
  }) {
    // Update docucraftMeta with progress info for the UI
    final current = _snapshot.docucraftMeta;

    StageProgress? style = current?.style;
    StageProgress? plan = current?.plan;
    StageProgress? images = current?.images;
    PagesProgress? pagesProgress = current?.pages;

    // Update the specific stage that changed
    final stageProgress = StageProgress(
      label: label,
      done: done,
      total: total,
      status: status,
      summary: summary,
    );

    switch (stage) {
      case 'style':
        style = stageProgress;
        break;
      case 'plan':
        plan = stageProgress;
        break;
      case 'images':
        images = stageProgress;
        break;
      case 'pages':
        pagesProgress = PagesProgress(
          label: label,
          done: done,
          total: total,
          status: status,
          summary: summary,
          items: pages,
        );
        break;
    }

    final isDone = stage == 'done' || status == 'done';

    _snapshot.docucraftMeta = DeckBlueprintMeta(
      topic: current?.topic,
      styleSkill: current?.styleSkill,
      outlineJson: current?.outlineJson,
      pageCount: current?.pageCount,
      style: style,
      plan: plan,
      images: images,
      pages: pagesProgress,
      isDone: isDone,
    );
    // Bump activity to reset silence timer
    _bumpActivity();
    // Notify listeners so UI rebuilds with updated deck progress
    notifyListeners();
  }

  /// QC pass finished.
  void exitQc() {
    _transition(ExitQc(now: DateTime.now()));
  }

  // ── Internal ──────────────────────────────────────────────────────

  void _transition(RunEvent event, {bool notify = true}) {
    final next = reduce(_state, event);
    if (identical(next, _state)) return;
    _state = next;
    if (notify) notifyListeners();
  }

  void _bumpActivity() {
    if (_state is! RunStreaming) return;
    if (_silenceFlag) {
      _silenceFlag = false;
      notifyListeners();
    }
    _silenceTimer?.cancel();
    _silenceTimer = Timer.periodic(silenceTick, (_) {
      if (_state is! RunStreaming) {
        _silenceTimer?.cancel();
        return;
      }
      final last = (_state as RunStreaming).lastActivityAt;
      if (last == null) return;
      final age = DateTime.now().difference(last);
      if (age >= silenceThreshold && !_silenceFlag) {
        _silenceFlag = true;
        notifyListeners();
      }
    });
  }

  void _drainOutlineReview({required bool cancelled}) {
    final r = _outlineResolver;
    _outlineResolver = null;
    if (r != null) {
      r(null, cancelled);
    }
  }
}
