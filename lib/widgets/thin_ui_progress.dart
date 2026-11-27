// DocuCraft — Thin UI Progress & Completion Widget
// Menampilkan progress selama generate deck dan status penyelesaian

import 'package:flutter/material.dart';
import '../services/api_client.dart';

/// Widget that shows generation progress and completion status
class ThinUiProgress extends StatelessWidget {
  final ThinUiState state;
  final VoidCallback? onDownload;
  final VoidCallback? onNewChat;

  const ThinUiProgress({
    super.key,
    required this.state,
    this.onDownload,
    this.onNewChat,
  });

  @override
  Widget build(BuildContext context) {
    if (state.stage == ThinUiStage.done) {
      return _buildCompletion(context);
    }

    if (state.stage == ThinUiStage.error) {
      return _buildError(context);
    }

    return _buildProgress(context);
  }

  Widget _buildProgress(BuildContext context) {
    final progress = state.total != null && state.total! > 0
        ? (state.done ?? 0) / state.total!
        : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress > 0 ? progress : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.stageName ?? 'Processing...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                if (state.done != null && state.total != null)
                  Text(
                    '${state.done}/${state.total}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
            if (progress > 0) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompletion(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Presentation Ready!',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        state.message ?? 'Your deck has been generated',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (onDownload != null)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onDownload,
                      icon: const Icon(Icons.download),
                      label: const Text('Download PPTX'),
                    ),
                  ),
                if (onDownload != null && onNewChat != null)
                  const SizedBox(width: 12),
                if (onNewChat != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onNewChat,
                      icon: const Icon(Icons.chat),
                      label: const Text('New Chat'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Generation Failed',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  Text(
                    state.error ?? 'Unknown error',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onError,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
