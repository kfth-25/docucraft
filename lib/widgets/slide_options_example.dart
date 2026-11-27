// DocuCraft — Contoh Pemakaian SlideOptionsPicker
// Contoh integrasi widget SlideOptionsPicker ke aplikasi kamu sendiri.

// Example usage of SlideOptionsPicker widget
// This shows how to integrate it into your existing app

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'slide_options_picker.dart';
import '../services/api_client.dart';

/// Example: Slide generation page with options picker
class SlideGenerationPage extends StatefulWidget {
  const SlideGenerationPage({super.key});

  @override
  State<SlideGenerationPage> createState() => _SlideGenerationPageState();
}

class _SlideGenerationPageState extends State<SlideGenerationPage> {
  final _topicController = TextEditingController(text: 'Digital Marketing Strategy');
  final _titleController = TextEditingController(text: 'Social Media Trends');
  int _optionCount = 3;
  SlideOption? _selectedOption;
  final GenOfficeClient _client = GenOfficeClient();

  @override
  void dispose() {
    _topicController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Slide Generator'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Input fields
            TextField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'Topic',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Slide Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Option count selector
            Row(
              children: [
                const Text('Number of options:'),
                const SizedBox(width: 12),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 2, label: Text('2')),
                    ButtonSegment(value: 3, label: Text('3')),
                    ButtonSegment(value: 4, label: Text('4')),
                  ],
                  selected: {_optionCount},
                  onSelectionChanged: (Set<int> values) {
                    setState(() {
                      _optionCount = values.first;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Generate button
            FilledButton.icon(
              onPressed: _generateOptions,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Design Options'),
            ),
            const SizedBox(height: 24),

            // Options picker
            SlideOptionsPicker(
              topic: _topicController.text,
              title: _titleController.text,
              optionCount: _optionCount,
              client: _client,
              onSelected: (option) {
                setState(() {
                  _selectedOption = option;
                });
                _showSelectedSnackBar(option);
              },
            ),

            // Selected option preview
            if (_selectedOption != null) ...[
              const SizedBox(height: 24),
              _buildSelectedPreview(),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _generateOptions() async {
    // Force rebuild of SlideOptionsPicker
    setState(() {});
  }

  void _showSelectedSnackBar(SlideOption option) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected: ${option.style.toUpperCase()} style'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            SlideOptionPreviewDialog.show(
              context,
              option,
              onSelect: () {
                // Handle selection
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSelectedPreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Selected: ${_selectedOption!.style.toUpperCase()}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    SlideOptionPreviewDialog.show(
                      context,
                      _selectedOption!,
                    );
                  },
                  child: const Text('Preview Full Size'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: SvgPicture.string(
                  _selectedOption!.svg,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _selectedOption = null;
                    });
                  },
                  child: const Text('Change Selection'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    _addToPresentation(_selectedOption!);
                  },
                  child: const Text('Add to Presentation'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addToPresentation(SlideOption option) {
    // TODO: Implement adding slide to presentation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${option.style} slide to presentation'),
      ),
    );
  }
}

/// Example: Inline usage in a chat interface
class ChatWithSlideOptions extends StatelessWidget {
  final String topic;
  final String title;
  final Function(SlideOption) onSlideSelected;

  const ChatWithSlideOptions({
    super.key,
    required this.topic,
    required this.title,
    required this.onSlideSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a design for "$title"',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            SlideOptionsPicker(
              topic: topic,
              title: title,
              optionCount: 3,
              onSelected: onSlideSelected,
            ),
          ],
        ),
      ),
    );
  }
}
