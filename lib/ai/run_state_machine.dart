// DocuCraft Flutter — Run State Machine (Sprint 12)
//
// Di-port dari GenOffice DocuCraft (apps/slides/src/renderer/ai/runStateMachine.ts).
// Dart murni, TANPA dependency Flutter, sehingga bisa di-unit-test tanpa
// `flutter test` (tetap jalan dengan `dart test` / `flutter test` biasa).
//
// Desain:
//   - `RunState` adalah hierarki sealed class (Dart 3) sehingga compiler
//     memaksa `switch` ekhaustif pada state.kind.
//   - `RunEvent` adalah hierarki sealed class untuk event yang bisa
//     di-dispatch host ke mesin.
//   - `reduce(state, event, now)` adalah fungsi murni — tanpa side effect,
//     tanpa sumber waktu selain argumen `now`, tanpa I/O. Hook layer
//     (AiRunProvider) yang memiliki side effect.
//   - Field snapshot yang mutable (qcPages, runTools, streamedText, dll.)
//     berada di `RunSnapshot` terpisah agar host bisa membacanya di
//     tengah jalan tanpa re-render.
//
// Kenapa state machine:
//   - AiPanel GenOffice punya 25+ deklarasi useRef untuk state lifecycle
//     run dan kebocoran state antar-run di newChat() / cancel(). Mesin ini
//     adalah single source of truth untuk "fase apa sedang dijalani run"
//     dan aksi `newChat` menjamin reset yang bersih.
//   - Test untuk reducer berupa data murni dan tidak butuh render tree.

import 'dart:convert';

/// Phases of an AI run. The machine transitions between these as the host
/// dispatches events from the AgentLoop callbacks (onText, onTool*, onDone,
/// onError) and user actions (start, cancel, newChat, outline review).
sealed class RunState {
  const RunState();

  /// Discriminator string for debug + telemetry.
  String get kind;

  /// True iff a run is "active" — i.e. the UI should show a spinner,
  /// disable the composer, hide certain chrome. Mirrors the GenOffice
  /// `isRunBusy()` helper.
  bool get isBusy;
}

/// Idle — no run in flight. Initial state and terminal state after done.
class RunIdle extends RunState {
  const RunIdle();
  @override
  String get kind => 'idle';
  @override
  bool get isBusy => false;
}

/// Starting — async prep (history batch open, runTools reset) is in flight.
/// Transitions to `streaming` on the first onText/onToolStart, or to `error`
/// if prep throws.
class RunStarting extends RunState {
  final String instruction;
  final DateTime since;
  const RunStarting({required this.instruction, required this.since});
  @override
  String get kind => 'starting';
  @override
  bool get isBusy => true;
}

/// Streaming — the AgentLoop is producing text + tool calls.
class RunStreaming extends RunState {
  final DateTime startedAt;
  final DateTime? lastActivityAt;
  /// Set when the user has clicked cancel but the loop hasn't yet
  /// emitted onDone({cancelled: true}). Lets the UI show a "Cancelling…"
  /// pulse instead of the normal "Thinking…" indicator.
  final DateTime? cancellingSince;
  const RunStreaming({
    required this.startedAt,
    required this.lastActivityAt,
    required this.cancellingSince,
  });
  @override
  String get kind => 'streaming';
  @override
  bool get isBusy => true;
}

/// Awaiting outline review — the AI planned a deck and is paused so the
/// user can edit the page titles + briefs before generation starts. This
/// is the Sprint 8 "OutlinePreview" integration point.
class RunAwaitingOutlineReview extends RunState {
  final String topic;
  final List<OutlinePage> pages;
  final DateTime since;
  final String? planSummary;
  const RunAwaitingOutlineReview({
    required this.topic,
    required this.pages,
    required this.since,
    this.planSummary,
  });
  @override
  String get kind => 'awaiting_outline_review';
  @override
  bool get isBusy => true;
}

/// QC pass — per-slide quality audit running in the background.
class RunQc extends RunState {
  final int total;
  final int done;
  final DateTime startedAt;
  const RunQc({required this.total, required this.done, required this.startedAt});
  @override
  String get kind => 'qc';
  @override
  bool get isBusy => true;
}

/// Terminal — run finished successfully (or was cancelled). Auto-transitions
/// to `idle` after a small delay so the UI can flash the success/fail pulse.
class RunDone extends RunState {
  final bool ok;
  final bool cancelled;
  final Duration duration;
  const RunDone({required this.ok, required this.cancelled, required this.duration});
  @override
  String get kind => 'done';
  @override
  bool get isBusy => true;
}

/// Terminal — run errored. Auto-transitions to `idle` after a small delay.
class RunError extends RunState {
  final String message;
  final bool recoverable;
  const RunError({required this.message, required this.recoverable});
  @override
  String get kind => 'error';
  @override
  bool get isBusy => true;
}

/// One page in the deck outline (Sprint 8). Shown in OutlinePreview for
/// the user to edit before generation starts.
class OutlinePage {
  final int index;
  final String title;
  final String brief;
  final String? layout;
  const OutlinePage({
    required this.index,
    required this.title,
    required this.brief,
    this.layout,
  });

  OutlinePage copyWith({int? index, String? title, String? brief, String? layout}) {
    return OutlinePage(
      index: index ?? this.index,
      title: title ?? this.title,
      brief: brief ?? this.brief,
      layout: layout ?? this.layout,
    );
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'title': title,
        'brief': brief,
        if (layout != null) 'layout': layout,
      };

  factory OutlinePage.fromJson(Map<String, dynamic> j) => OutlinePage(
        index: (j['index'] as num?)?.toInt() ?? 0,
        title: (j['title'] as String?) ?? '',
        brief: (j['brief'] as String?) ?? '',
        layout: j['layout'] as String?,
      );
}

/// Mutable snapshot — the bits the host reads mid-flight without triggering
/// a re-render. Owned by AiRunProvider, updated by the action functions,
/// read by the AgentLoop callbacks.
class RunSnapshot {
  String instruction;
  String? displayText;
  String streamedText;
  List<int> qcPages;
  List<int> qcPagesPinned; // Pages user pinned (skip QC)
  List<ToolActivity> runTools;
  DeckBlueprintMeta? docucraftMeta;
  String? lastInstruction;
  String? lastDisplayText;

  RunSnapshot({
    this.instruction = '',
    this.displayText,
    this.streamedText = '',
    List<int>? qcPages,
    List<int>? qcPagesPinned,
    List<ToolActivity>? runTools,
    this.docucraftMeta,
    this.lastInstruction,
    this.lastDisplayText,
  })  : qcPages = qcPages ?? <int>[],
        qcPagesPinned = qcPagesPinned ?? <int>[],
        runTools = runTools ?? <ToolActivity>[];

  RunSnapshot copy() => RunSnapshot(
        instruction: instruction,
        displayText: displayText,
        streamedText: streamedText,
        qcPages: List<int>.from(qcPages),
        qcPagesPinned: List<int>.from(qcPagesPinned),
        runTools: List<ToolActivity>.from(runTools),
        docucraftMeta: docucraftMeta,
        lastInstruction: lastInstruction,
        lastDisplayText: lastDisplayText,
      );

  /// Reset everything to "fresh chat" defaults. Called by `newChat`.
  void reset() {
    instruction = '';
    displayText = null;
    streamedText = '';
    qcPages = <int>[];
    qcPagesPinned = <int>[];
    runTools = <ToolActivity>[];
    docucraftMeta = null;
    lastInstruction = null;
    lastDisplayText = null;
  }
}

/// Tool activity for runTools list. Mirrors the React-side ToolActivity with
/// full fields for UI display (name, summary, running, isError, output).
class ToolActivity {
  final String name;
  final String summary;
  final bool running;
  final bool isError;
  final String? output; // Full tool output (truncated to 2000 chars by caller)

  const ToolActivity({
    required this.name,
    required this.summary,
    this.running = false,
    this.isError = false,
    this.output,
  });

  ToolActivity copyWith({
    String? name,
    String? summary,
    bool? running,
    bool? isError,
    String? output,
  }) {
    return ToolActivity(
      name: name ?? this.name,
      summary: summary ?? this.summary,
      running: running ?? this.running,
      isError: isError ?? this.isError,
      output: output ?? this.output,
    );
  }
}

/// Per-page progress status (mirrors GenOffice's PageProgressStatus)
enum PageProgressStatus { pending, running, done, error }

/// Per-page progress item (mirrors GenOffice's PageProgressItem)
class PageProgressItem {
  final String title;
  final PageProgressStatus status;
  final String? error;

  const PageProgressItem({
    required this.title,
    required this.status,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'status': status.name,
        if (error != null) 'error': error,
      };

  factory PageProgressItem.fromJson(Map<String, dynamic> j) => PageProgressItem(
        title: j['title'] as String,
        status: PageProgressStatus.values.byName(j['status'] as String),
        error: j['error'] as String?,
      );
}

/// Captured at onToolExecuted('generate_deck') so the host can persist a
/// blueprint at onDone. Matches the GenOffice DocucraftBlueprintMeta.
class DeckBlueprintMeta {
  final String? topic;
  final String? styleSkill;
  final String? outlineJson;
  final int? pageCount;
  // Per-stage progress (cumulative - each stage stores its own data)
  final StageProgress? style;
  final StageProgress? plan;
  final StageProgress? images;
  final PagesProgress? pages;
  final bool isDone;

  const DeckBlueprintMeta({
    this.topic,
    this.styleSkill,
    this.outlineJson,
    this.pageCount,
    this.style,
    this.plan,
    this.images,
    this.pages,
    this.isDone = false,
  });

  DeckBlueprintMeta copyWith({
    String? topic,
    String? styleSkill,
    String? outlineJson,
    int? pageCount,
    StageProgress? style,
    StageProgress? plan,
    StageProgress? images,
    PagesProgress? pages,
    bool? isDone,
  }) {
    return DeckBlueprintMeta(
      topic: topic ?? this.topic,
      styleSkill: styleSkill ?? this.styleSkill,
      outlineJson: outlineJson ?? this.outlineJson,
      pageCount: pageCount ?? this.pageCount,
      style: style ?? this.style,
      plan: plan ?? this.plan,
      images: images ?? this.images,
      pages: pages ?? this.pages,
      isDone: isDone ?? this.isDone,
    );
  }

  Map<String, dynamic> toJson() => {
        if (topic != null) 'topic': topic,
        if (styleSkill != null) 'styleSkill': styleSkill,
        if (outlineJson != null) 'outlineJson': outlineJson,
        if (pageCount != null) 'pageCount': pageCount,
        if (style != null) 'style': style!.toJson(),
        if (plan != null) 'plan': plan!.toJson(),
        if (images != null) 'images': images!.toJson(),
        if (pages != null) 'pages': pages!.toJson(),
        if (isDone) 'isDone': isDone,
      };

  factory DeckBlueprintMeta.fromJson(Map<String, dynamic> j) => DeckBlueprintMeta(
        topic: j['topic'] as String?,
        styleSkill: j['styleSkill'] as String?,
        outlineJson: j['outlineJson'] as String?,
        pageCount: (j['pageCount'] as num?)?.toInt(),
        style: j['style'] != null ? StageProgress.fromJson(j['style'] as Map<String, dynamic>) : null,
        plan: j['plan'] != null ? StageProgress.fromJson(j['plan'] as Map<String, dynamic>) : null,
        images: j['images'] != null ? StageProgress.fromJson(j['images'] as Map<String, dynamic>) : null,
        pages: j['pages'] != null ? PagesProgress.fromJson(j['pages'] as Map<String, dynamic>) : null,
        isDone: j['isDone'] as bool? ?? false,
      );
}

/// Progress for style/plan/images stages
class StageProgress {
  final String label;
  final int done;
  final int total;
  final String status; // 'running' | 'done' | 'error'
  final String? summary;

  const StageProgress({
    required this.label,
    this.done = 0,
    required this.total,
    required this.status,
    this.summary,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'done': done,
        'total': total,
        'status': status,
        if (summary != null) 'summary': summary,
      };

  factory StageProgress.fromJson(Map<String, dynamic> j) => StageProgress(
        label: j['label'] as String,
        done: (j['done'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        status: j['status'] as String,
        summary: j['summary'] as String?,
      );
}

/// Progress for pages stage (includes per-page items)
class PagesProgress {
  final String label;
  final int done;
  final int total;
  final String status; // 'running' | 'done' | 'error'
  final String? summary;
  final List<PageProgressItem>? items;

  const PagesProgress({
    required this.label,
    this.done = 0,
    required this.total,
    required this.status,
    this.summary,
    this.items,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'done': done,
        'total': total,
        'status': status,
        if (summary != null) 'summary': summary,
        if (items != null) 'items': items!.map((p) => p.toJson()).toList(),
      };

  factory PagesProgress.fromJson(Map<String, dynamic> j) => PagesProgress(
        label: j['label'] as String,
        done: (j['done'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        status: j['status'] as String,
        summary: j['summary'] as String?,
        items: (j['items'] as List?)?.map((p) => PageProgressItem.fromJson(p as Map<String, dynamic>)).toList(),
      );
}

/// Progress event union type for generation stages (mirrors GenOffice's DeckProgressEvent)
sealed class DeckProgressEvent {
  const DeckProgressEvent();
}

class StyleProgressEvent extends DeckProgressEvent {
  final String label;
  final String status; // 'running' | 'done' | 'error'
  final String summary;

  const StyleProgressEvent({
    required this.label,
    required this.status,
    required this.summary,
  });
}

class PlanProgressEvent extends DeckProgressEvent {
  final String label;
  final int done;
  final int total;
  final String status;
  final String summary;

  const PlanProgressEvent({
    required this.label,
    required this.done,
    required this.total,
    required this.status,
    required this.summary,
  });
}

class ImagesProgressEvent extends DeckProgressEvent {
  final String label;
  final int done;
  final int total;
  final String status;
  final String summary;

  const ImagesProgressEvent({
    required this.label,
    required this.done,
    required this.total,
    required this.status,
    required this.summary,
  });
}

class PagesProgressEvent extends DeckProgressEvent {
  final String label;
  final int done;
  final int total;
  final String status;
  final String summary;
  final List<PageProgressItem>? pages;

  const PagesProgressEvent({
    required this.label,
    required this.done,
    required this.total,
    required this.status,
    required this.summary,
    this.pages,
  });
}

class DoneProgressEvent extends DeckProgressEvent {
  final int total;
  final String summary;

  const DoneProgressEvent({
    required this.total,
    required this.summary,
  });
}

/// Sealed event hierarchy. The host dispatches these to `reduce()`.
sealed class RunEvent {
  const RunEvent();
  DateTime get now;
  String get name;
}

/// start({instruction, displayText?}) — begin a new run.
class StartRun extends RunEvent {
  @override final DateTime now;
  final String instruction;
  final String? displayText;
  StartRun({required this.now, required this.instruction, this.displayText});
  @override String get name => 'start';
}

/// User-cancelled the run. Loop is still alive; we wait for onDone({cancelled:true}).
class CancelRun extends RunEvent {
  @override final DateTime now;
  final String reason; // 'user' | 'new_chat' | 'unmount'
  CancelRun({required this.now, this.reason = 'user'});
  @override String get name => 'cancel';
}

/// Reset to idle. Called when the user clicks "New Chat" or the panel unmounts.
class NewChat extends RunEvent {
  @override final DateTime now;
  NewChat({required this.now});
  @override String get name => 'new_chat';
}

/// Streamed a chunk of text from the LLM.
class TextChunk extends RunEvent {
  @override final DateTime now;
  final String text;
  TextChunk({required this.now, required this.text});
  @override String get name => 'text';
}

/// A tool call started.
class ToolStart extends RunEvent {
  @override final DateTime now;
  final String toolName;
  ToolStart({required this.now, required this.toolName});
  @override String get name => 'tool_start';
}

/// A tool call finished. If the tool is `generate_deck`, capture blueprint meta.
class ToolExecuted extends RunEvent {
  @override final DateTime now;
  final String toolName;
  final Map<String, dynamic>? result; // optional raw tool result
  ToolExecuted({required this.now, required this.toolName, this.result});
  @override String get name => 'tool_executed';
}

/// A turn ended (LLM returned control). Useful for per-turn housekeeping.
class TurnEnd extends RunEvent {
  @override final DateTime now;
  TurnEnd({required this.now});
  @override String get name => 'turn_end';
}

/// Run finished (success or cancel).
class DoneRun extends RunEvent {
  @override final DateTime now;
  final bool cancelled;
  final bool ok;
  final Duration duration;
  DoneRun({required this.now, required this.cancelled, required this.ok, required this.duration});
  @override String get name => 'done';
}

/// Run errored.
class ErrorRun extends RunEvent {
  @override final DateTime now;
  final String message;
  final bool recoverable;
  ErrorRun({required this.now, required this.message, this.recoverable = true});
  @override String get name => 'error';
}

/// AI planned a deck and is paused for outline review (Sprint 8).
class EnterOutlineReview extends RunEvent {
  @override final DateTime now;
  final String topic;
  final List<OutlinePage> pages;
  final String? planSummary;
  EnterOutlineReview({required this.now, required this.topic, required this.pages, this.planSummary});
  @override String get name => 'enter_outline_review';
}

/// User resolved the outline review (either confirmed with edited pages
/// or cancelled). The host's run loop continues or aborts accordingly.
class ResolveOutlineReview extends RunEvent {
  @override final DateTime now;
  final List<OutlinePage>? pages; // null = cancelled
  final bool cancelled;
  ResolveOutlineReview({required this.now, this.pages, this.cancelled = false});
  @override String get name => 'resolve_outline_review';
}

/// QC pass started.
class EnterQc extends RunEvent {
  @override final DateTime now;
  final int total;
  EnterQc({required this.now, required this.total});
  @override String get name => 'enter_qc';
}

/// Tick QC progress (one page finished).
class TickQcProgress extends RunEvent {
  @override final DateTime now;
  final int done;
  TickQcProgress({required this.now, required this.done});
  @override String get name => 'tick_qc';
}

/// QC pass finished.
class ExitQc extends RunEvent {
  @override final DateTime now;
  ExitQc({required this.now});
  @override String get name => 'exit_qc';
}

/// Pure reducer. Returns the new state for the given (state, event) pair.
/// The host (AiRunProvider) reads/writes the mutable `RunSnapshot` itself;
/// the reducer is responsible only for the RunState transition.
RunState reduce(RunState state, RunEvent event) {
  switch (event) {
    case StartRun():
      // Starting a new run from any non-terminal state is a no-op.
      // (Caller should call newChat first if a run is in flight.)
      if (state.isBusy) return state;
      return RunStarting(instruction: event.instruction, since: event.now);

    case CancelRun():
      // Only valid from streaming. Starting / awaiting / qc are not cancellable
      // from the user's perspective (they're "pre-loop" or "post-loop").
      if (state is RunStreaming) {
        return RunStreaming(
          startedAt: state.startedAt,
          lastActivityAt: state.lastActivityAt,
          cancellingSince: event.now,
        );
      }
      return state;

    case NewChat():
      // Always reset to idle, regardless of where we are. The host also
      // resets the mutable snapshot.
      return const RunIdle();

    case TextChunk():
      // First text from the loop → starting → streaming.
      if (state is RunStarting) {
        return RunStreaming(
          startedAt: state.since,
          lastActivityAt: event.now,
          cancellingSince: null,
        );
      }
      // Already streaming → update lastActivityAt, keep cancellingSince.
      if (state is RunStreaming) {
        return RunStreaming(
          startedAt: state.startedAt,
          lastActivityAt: event.now,
          cancellingSince: state.cancellingSince,
        );
      }
      return state;

    case ToolStart():
      // Tool activity also transitions starting → streaming.
      if (state is RunStarting) {
        return RunStreaming(
          startedAt: state.since,
          lastActivityAt: event.now,
          cancellingSince: null,
        );
      }
      if (state is RunStreaming) {
        return RunStreaming(
          startedAt: state.startedAt,
          lastActivityAt: event.now,
          cancellingSince: state.cancellingSince,
        );
      }
      return state;

    case ToolExecuted():
      // While in streaming: update lastActivityAt. (Blueprint meta capture
      // is the host's job — reducer doesn't touch the snapshot.)
      if (state is RunStreaming) {
        return RunStreaming(
          startedAt: state.startedAt,
          lastActivityAt: event.now,
          cancellingSince: state.cancellingSince,
        );
      }
      return state;

    case TurnEnd():
      // No state change, but the host can use this to commit per-turn work.
      return state;

    case DoneRun():
      return RunDone(ok: event.ok, cancelled: event.cancelled, duration: event.duration);

    case ErrorRun():
      return RunError(message: event.message, recoverable: event.recoverable);

    case EnterOutlineReview():
      // Valid from streaming (after the planning loop emits it). Other
      // states ignore it.
      if (state is RunStreaming || state is RunStarting) {
        return RunAwaitingOutlineReview(
          topic: event.topic,
          pages: List<OutlinePage>.from(event.pages),
          since: event.now,
          planSummary: event.planSummary,
        );
      }
      return state;

    case ResolveOutlineReview():
      // Resolution brings us back to streaming so the run continues, or to
      // idle if cancelled. The host aborts the loop in the cancelled case.
      if (state is RunAwaitingOutlineReview) {
        if (event.cancelled) {
          return const RunIdle();
        }
        // Resume streaming — the startedAt is reset because the "main" run
        // hasn't actually started yet.
        return RunStreaming(
          startedAt: event.now,
          lastActivityAt: event.now,
          cancellingSince: null,
        );
      }
      return state;

    case EnterQc():
      return RunQc(total: event.total, done: 0, startedAt: event.now);

    case TickQcProgress():
      if (state is RunQc) {
        return RunQc(total: state.total, done: event.done, startedAt: state.startedAt);
      }
      return state;

    case ExitQc():
      // Exit QC doesn't auto-transition to done — the host emits DoneRun
      // after QC finishes. From QC we return to idle here (the host will
      // dispatch DoneRun next if it wants the success pulse).
      if (state is RunQc) {
        return const RunIdle();
      }
      return state;
  }
}

/// Convenience: encode the current state as a JSON string for logging /
/// crash reports. Pure function.
String encodeRunState(RunState s) {
  final base = {'kind': s.kind, 'isBusy': s.isBusy};
  if (s is RunStreaming) {
    base['cancelling'] = s.cancellingSince != null;
  }
  if (s is RunDone) {
    base['ok'] = s.ok;
    base['cancelled'] = s.cancelled;
  }
  if (s is RunError) {
    base['recoverable'] = s.recoverable;
  }
  return jsonEncode(base);
}
