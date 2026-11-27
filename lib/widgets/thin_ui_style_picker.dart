// DocuCraft — Thin UI Style Picker
// Menampilkan beberapa opsi style dari GenOffice untuk dipilih user

import 'package:flutter/material.dart';
import '../services/api_client.dart';

/// Callback when user selects a style
typedef OnStyleSelected = void Function(ThinUiStyleOption option);

/// Widget that displays style options as color preview cards
class ThinUiStylePicker extends StatefulWidget {
  final List<ThinUiStyleOption> styles;
  final String topic;
  final OnStyleSelected? onSelected;

  const ThinUiStylePicker({
    super.key,
    required this.styles,
    required this.topic,
    this.onSelected,
  });

  @override
  State<ThinUiStylePicker> createState() => _ThinUiStylePickerState();
}

class _ThinUiStylePickerState extends State<ThinUiStylePicker> {
  int _selectedIndex = 0;

  Color _parseColor(String hex) {
    try {
      final hexStr = hex.replaceAll('#', '');
      return Color(int.parse('FF$hexStr', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.palette, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Choose Your Style', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      Text('${widget.styles.length} styles available', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Style options grid
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              itemCount: widget.styles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final style = widget.styles[index];
                final isSelected = index == _selectedIndex;

                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 150,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Color preview circle
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: _parseColor(style.primaryColor),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _parseColor(style.primaryColor).withOpacity(0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 24)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          style.name,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Select button
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton(
              onPressed: () {
                if (widget.onSelected != null && widget.styles.isNotEmpty) {
                  widget.onSelected!(widget.styles[_selectedIndex]);
                }
              },
              child: const Text('Use This Style'),
            ),
          ),
        ],
      ),
    );
  }
}
