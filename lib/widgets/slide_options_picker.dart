// DocuCraft — Slide Options Picker Widget
// Menampilkan beberapa variasi desain hasil AI untuk dipilih user
//
// Kenapa:
//   - User bisa melihat 3-4 gaya berbeda berdampingan
//   - Perbandingan mudah sebelum memilih satu desain
//   - Umpan balik visual selama generate dengan indikator progress
//   - Mendukung tap untuk memilih dan preview

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_client.dart';

/// Callback when user selects an option
typedef OnOptionSelected = void Function(SlideOption option);

/// Widget that displays multiple slide design options
class SlideOptionsPicker extends StatefulWidget {
  final String topic;
  final String title;
  final int optionCount;
  final String style;
  final String color;
  final int index;
  final int total;
  final OnOptionSelected? onSelected;
  final GenOfficeClient? client;

  const SlideOptionsPicker({
    super.key,
    required this.topic,
    required this.title,
    this.optionCount = 3,
    this.style = 'modern',
    this.color = 'indigo',
    this.index = 0,
    this.total = 1,
    this.onSelected,
    this.client,
  });

  @override
  State<SlideOptionsPicker> createState() => _SlideOptionsPickerState();
}

class _SlideOptionsPickerState extends State<SlideOptionsPicker>
    with SingleTickerProviderStateMixin {
  late final GenOfficeClient _client;
  SlideMultiResponse? _response;
  bool _isLoading = false;
  String? _error;
  int _selected_index = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? GenOfficeClient();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _generateOptions();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _generateOptions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _client.generateSlideMulti(
        topic: widget.topic,
        title: widget.title,
        style: widget.style,
        color: widget.color,
        index: widget.index,
        total: widget.total,
        optionCount: widget.optionCount,
      );

      setState(() {
        _response = response;
        _isLoading = false;
        _selected_index = response.selected;
      });

      _animController.forward(from: 0);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _selectOption(int index) {
    setState(() {
      _selected_index = index;
    });

    if (_response != null && index < _response!.options.length) {
      widget.onSelected?.call(_response!.options[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        _buildHeader(),
        const SizedBox(height: 12),

        // Content
        if (_isLoading)
          _buildLoading()
        else if (_error != null)
          _buildError()
        else if (_response != null)
          _buildOptionsGrid()
        else
          const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.palette_outlined,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          'Design Options',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const Spacer(),
        if (_response != null)
          Text(
            '${_response!.options.length} variations',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
      ],
    );
  }

  Widget _buildLoading() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Generating design options...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Creating ${widget.optionCount} variations',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onError,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Failed to generate options',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onError,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onError,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _generateOptions,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsGrid() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SizedBox(
        height: 220,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _response!.options.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final option = _response!.options[index];
            final isSelected = index == _selected_index;

            return _buildOptionCard(option, index, isSelected);
          },
        ),
      ),
    );
  }

  Widget _buildOptionCard(SlideOption option, int index, bool isSelected) {
    return GestureDetector(
      onTap: () => _selectOption(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 280,
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SVG Preview
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11),
                ),
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 2.0,
                    child: SvgPicture.string(
                      option.svg,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),

            // Style Label + Selection Indicator
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(11),
                ),
              ),
              child: Row(
                children: [
                  // Style name
                  Expanded(
                    child: Text(
                      option.style.toUpperCase(),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ),

                  // Selection indicator
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 18,
                    )
                  else
                    Icon(
                      Icons.radio_button_unchecked,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 18,
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

/// Compact version for inline use
class SlideOptionsChip extends StatelessWidget {
  final SlideOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const SlideOptionsChip({
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
          borderRadius: BorderRadius.circular(20),
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

/// Preview dialog for full-screen viewing
class SlideOptionPreviewDialog extends StatelessWidget {
  final SlideOption option;
  final VoidCallback? onSelect;

  const SlideOptionPreviewDialog({
    super.key,
    required this.option,
    this.onSelect,
  });

  static void show(BuildContext context, SlideOption option, {VoidCallback? onSelect}) {
    showDialog(
      context: context,
      builder: (_) => SlideOptionPreviewDialog(
        option: option,
        onSelect: onSelect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Style: ${option.style.toUpperCase()}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // SVG Preview
            Expanded(
              child: InteractiveViewer(
                minScale: 0.3,
                maxScale: 3.0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SvgPicture.string(
                    option.svg,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      onSelect?.call();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Select This Design'),
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
