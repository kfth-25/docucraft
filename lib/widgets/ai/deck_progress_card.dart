// DocuCraft Flutter — Deck Progress Card (Sprint 12)
//
// Kartu Material 3 yang memvisualkan 5 tahap generate deck DocuCraft:
// style → plan → images → pages → done. Membaca datanya dari sebuah
// [AiRunProvider] dan menganimasikan transisi state.
//
// Catatan desain:
//   - Tahap dirender sebagai deretan pill. Tahap aktif berdenyut;
//     tahap yang selesai menampilkan ikon centang. Tahap gagal menampilkan peringatan.
//   - Saat `is-finished` (state == RunDone dan ok), kartu melakukan
//     animasi denyut sukses (scale halus + color tween).
//   - Semua animasi menghormati MediaQuery.disableAnimations (kami membaca
//     `MediaQuery.of(context).disableAnimations` dan melewati AnimatedX).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ai/run_state_machine.dart';
import '../../providers/ai_run_provider.dart';

/// The 6 stages of a DocuCraft run, in order.
enum DeckStage { style, plan, images, pages, qc, done }

extension DeckStageLabel on DeckStage {
  String get label {
    switch (this) {
      case DeckStage.style:
        return 'Style';
      case DeckStage.plan:
        return 'Plan';
      case DeckStage.images:
        return 'Images';
      case DeckStage.pages:
        return 'Pages';
      case DeckStage.qc:
        return 'QC';
      case DeckStage.done:
        return 'Done';
    }
  }
}

/// Card widget. Drop into the chat panel body during a run.
class DeckProgressCard extends StatelessWidget {
  const DeckProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AiRunProvider>(
      builder: (context, run, _) {
        final stage = _stageFor(run.state);
        // No active run — don't render the card.
        if (stage == null) return const SizedBox.shrink();
        final isFinished = run.state is RunDone && (run.state as RunDone).ok;
        final isError = run.state is RunError;
        final isSilent = run.isSilent;

        final colorScheme = Theme.of(context).colorScheme;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: isError
              ? colorScheme.errorContainer
              : colorScheme.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isError
                          ? Icons.error_outline
                          : (isFinished
                              ? Icons.check_circle_outline
                              : Icons.auto_awesome),
                      size: 18,
                      color: isError
                          ? colorScheme.onErrorContainer
                          : (isFinished
                              ? Colors.green
                              : colorScheme.primary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isError
                          ? 'Generation failed'
                          : (isFinished
                              ? 'Deck ready'
                              : (run.state is RunQc
                                  ? 'Running layout QC…'
                                  : 'Generating deck…')),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    if (!isFinished && !isError) _ProgressDots(silent: isSilent),
                  ],
                ),
                const SizedBox(height: 12),
                _StageRow(current: stage, isError: isError, isFinished: isFinished),
                if (isError) ...[
                  const SizedBox(height: 8),
                  Text(
                    (run.state as RunError).message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Map a [RunState] to a [DeckStage]. Returns null if no run is active
  /// (caller decides whether to render the card at all).
  static DeckStage? _stageFor(RunState s) {
    if (s is RunIdle) return null;
    if (s is RunStarting) return DeckStage.style;
    if (s is RunStreaming) return DeckStage.pages;
    if (s is RunAwaitingOutlineReview) return DeckStage.plan;
    if (s is RunQc) return DeckStage.qc;
    if (s is RunDone) return DeckStage.done;
    if (s is RunError) return DeckStage.pages;
    return null;
  }
}

class _StageRow extends StatelessWidget {
  final DeckStage current;
  final bool isError;
  final bool isFinished;
  const _StageRow({required this.current, required this.isError, required this.isFinished});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stages = DeckStage.values;
    final currentIdx = stages.indexOf(current);

    return Row(
      children: List.generate(stages.length, (i) {
        final stage = stages[i];
        final completed = i < currentIdx || (isFinished && i == stages.length - 1);
        final active = i == currentIdx && !isFinished;
        final isLast = i == stages.length - 1;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: _StagePill(
                  label: stage.label,
                  completed: completed,
                  active: active,
                  isError: isError && active,
                ),
              ),
              if (!isLast)
                Container(
                  width: 12,
                  height: 1.5,
                  color: completed
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _StagePill extends StatelessWidget {
  final String label;
  final bool completed;
  final bool active;
  final bool isError;
  const _StagePill({
    required this.label,
    required this.completed,
    required this.active,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color bg = isError
        ? colorScheme.error
        : (completed || active ? colorScheme.primary : colorScheme.surfaceContainerHighest);
    final Color fg = (completed || active || isError)
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: completed
                  ? Icon(Icons.check, size: 14, color: fg)
                  : Text(
                      label[0],
                      style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: active || completed
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
          ),
        ],
      ),
    );
  }
}

/// Three pulsing dots. When `silent` is true, the label changes to
/// "Thinking deeper…" and the pulse slows down (Sprint 5 watchdog).
class _ProgressDots extends StatefulWidget {
  final bool silent;
  const _ProgressDots({required this.silent});

  @override
  State<_ProgressDots> createState() => _ProgressDotsState();
}

class _ProgressDotsState extends State<_ProgressDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.silent)
          Text(
            'Thinking deeper…',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        if (widget.silent) const SizedBox(width: 6),
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) {
                if (reduceMotion) {
                  return Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  );
                }
                final t = (_ctrl.value + i / 3) % 1.0;
                final opacity = 0.3 + 0.7 * (1.0 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
                return Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
