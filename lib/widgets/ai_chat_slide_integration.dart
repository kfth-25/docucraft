// DocuCraft — Integrasi Chat AI ↔ Slide (Contoh Pemakaian)
// Contoh cara memasang SlideOptionsPicker ke interface chat yang sudah ada
// (menambahkan pilihan gaya slide di dalam chat).

// Integration example for AI Chat Panel
// Shows how to add slide options to existing chat interface

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'slide_options_picker.dart';
import '../services/api_client.dart';

/// Widget to display in AI chat when user asks for a slide
class AiChatSlideCard extends StatefulWidget {
  final String topic;
  final String title;
  final Function(Map<String, dynamic>) onSlideGenerated;

  const AiChatSlideCard({
    super.key,
    required this.topic,
    required this.title,
    required this.onSlideGenerated,
  });

  @override
  State<AiChatSlideCard> createState() => _AiChatSlideCardState();
}

class _AiChatSlideCardState extends State<AiChatSlideCard> {
  SlideOption? _selectedOption;
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Slide Design Options',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        '"${widget.title}"',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
              ],
            ),
          ),

          // Options picker (collapsible)
          if (_isExpanded) ...[
            SlideOptionsPicker(
              topic: widget.topic,
              title: widget.title,
              optionCount: 3,
              onSelected: (option) {
                setState(() {
                  _selectedOption = option;
                });
              },
            ),
          ],

          // Quick preview (always visible)
          if (!_isExpanded && _selectedOption != null)
            Container(
              height: 100,
              padding: const EdgeInsets.all(8),
              child: SvgPicture.string(
                _selectedOption!.svg,
                fit: BoxFit.contain,
              ),
            ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                // Expand/collapse button
                if (!_isExpanded)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isExpanded = true;
                      });
                    },
                    icon: const Icon(Icons.palette, size: 18),
                    label: const Text('View Options'),
                  ),

                const Spacer(),

                // Select button (only when option is selected)
                if (_selectedOption != null)
                  FilledButton.tonal(
                    onPressed: () {
                      widget.onSlideGenerated({
                        'svg': _selectedOption!.svg,
                        'style': _selectedOption!.style,
                        'topic': widget.topic,
                        'title': widget.title,
                      });
                    },
                    child: const Text('Use This Design'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple button to trigger slide generation in chat
class GenerateSlideButton extends StatelessWidget {
  final VoidCallback onPressed;

  const GenerateSlideButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        Icons.slideshow,
        color: Theme.of(context).colorScheme.primary,
        size: 18,
      ),
      label: const Text('Generate Slide'),
      onPressed: onPressed,
    );
  }
}

/// Compact option chip for inline display
class SlideOptionChip extends StatelessWidget {
  final SlideOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const SlideOptionChip({
    super.key,
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getStyleColor(option.style),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              option.style,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStyleColor(String style) {
    switch (style) {
      case 'modern':
        return Colors.blue;
      case 'minimal':
        return Colors.grey;
      case 'bold':
        return Colors.orange;
      case 'elegant':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }
}
