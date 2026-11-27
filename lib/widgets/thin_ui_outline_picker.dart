// DocuCraft — Thin UI Outline Picker
// Menampilkan beberapa opsi outline dari GenOffice untuk dipilih user

import 'package:flutter/material.dart';
import '../services/api_client.dart';

/// Callback when user selects an outline
typedef OnOutlineSelected = void Function(ThinUiOutlineOption option);

/// Widget that displays outline options in a selectable list
class ThinUiOutlinePicker extends StatefulWidget {
  final List<ThinUiOutlineOption> outlines;
  final String topic;
  final OnOutlineSelected? onSelected;

  const ThinUiOutlinePicker({
    super.key,
    required this.outlines,
    required this.topic,
    this.onSelected,
  });

  @override
  State<ThinUiOutlinePicker> createState() => _ThinUiOutlinePickerState();
}

class _ThinUiOutlinePickerState extends State<ThinUiOutlinePicker> {
  int _selectedIndex = 0;

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
                Icon(Icons.list_alt, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Choose Your Outline', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      Text('${widget.outlines.length} options available', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Outline list
          ...List.generate(widget.outlines.length, (index) {
            final outline = widget.outlines[index];
            final isSelected = index == _selectedIndex;

            return InkWell(
              onTap: () {
                setState(() => _selectedIndex = index);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2) : null,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            outline.title,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${outline.slides} slides',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // Select button
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton(
              onPressed: () {
                if (widget.onSelected != null && widget.outlines.isNotEmpty) {
                  widget.onSelected!(widget.outlines[_selectedIndex]);
                }
              },
              child: const Text('Use This Outline'),
            ),
          ),
        ],
      ),
    );
  }
}
