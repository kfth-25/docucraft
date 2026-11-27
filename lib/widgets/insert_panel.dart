// DocuCraft — Insert Panel V2 (Bottom Sheet)
// Diperbarui untuk model V2: posisi px, enum ElementType, style terstruktur

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/slide.dart';
import '../providers/slide_provider.dart';
import '../themes/app_theme.dart';
import 'image_editor.dart';

class InsertPanel extends StatelessWidget {
  const InsertPanel({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const InsertPanel(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Sisipkan Element',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            _gridItems(context),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _gridItems(BuildContext context) {
    final items = [
      _InsertItem(Icons.text_fields, 'Teks', 'text', AppTheme.primary),
      _InsertItem(Icons.image, 'Gambar', 'image', AppTheme.success),
      _InsertItem(Icons.category, 'Shape', 'shape', const Color(0xFFA855F7)),
      _InsertItem(Icons.bar_chart, 'Chart', 'chart', AppTheme.warning),
      _InsertItem(Icons.table_chart, 'Tabel', 'table', const Color(0xFF3B82F6)),
      _InsertItem(Icons.emoji_symbols, 'Icon', 'icon', const Color(0xFF06B6D4)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _itemBtn(ctx, items[i]),
    );
  }

  Widget _itemBtn(BuildContext context, _InsertItem item) {
    return GestureDetector(
      onTap: () => _insertElement(context, item),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: item.color.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: item.color.withAlpha(50)),
            ),
            child: Icon(item.icon, color: item.color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(item.label, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  void _insertElement(BuildContext context, _InsertItem item) {
    final provider = context.read<SlideProvider>();
    if (provider.currentSlide == null) return;

    // Image: open editor directly instead of adding placeholder
    if (item.type == 'image') {
      Navigator.pop(context);
      ImageEditor.show(context, promptHint: 'Paste URL gambar atau upload').then((result) {
        if (result != null && context.mounted) {
          provider.addElement(SlideElement(
            type: ElementType.image,
            x: 120, y: 200, width: 600, height: 400,
            imageStyle: ImageStyleData(src: result.imageUrl, placeholderLabel: '🖼 Image'),
          ));
        }
      });
      return;
    }

    final element = _createElementForType(item.type);
    provider.addElement(element);

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${item.label} ditambahkan ke slide'),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  SlideElement _createElementForType(String type) {
    switch (type) {
      case 'text':
        return SlideElement(
          type: ElementType.text,
          content: 'Text Baru',
          x: 60, y: 200, width: 600, height: 100,
          textStyle: TextStyleData(fontSize: 28, colorValue: 0xFFFFFFFF),
        );
      case 'image':
        return SlideElement(
          type: ElementType.image,
          x: 120, y: 200, width: 600, height: 400,
          imageStyle: ImageStyleData(placeholderLabel: '🖼 Image'),
        );
      case 'shape':
        return SlideElement(
          type: ElementType.shape,
          x: 400, y: 300, width: 300, height: 300,
          shapeStyle: ShapeStyleData(fillColorValue: 0xFF6366F1, borderRadius: 12, shapeType: 'rect'),
        );
      case 'chart':
        return SlideElement(
          type: ElementType.chart,
          x: 120, y: 250, width: 800, height: 400,
          chartData: ChartData(
            chartType: 'bar',
            dataSets: [
              ChartDataSet(values: [60, 80, 45, 90, 70], label: 'Series 1', colorValue: 0xFF6366F1),
            ],
            labels: ['Jan', 'Feb', 'Mar', 'Apr', 'Mei'],
          ),
        );
      case 'table':
        return SlideElement(
          type: ElementType.table,
          x: 100, y: 250, width: 800, height: 400,
          tableData: TableData(
            rows: 4, cols: 3,
            cells: [
              ['Product', 'Q1', 'Q2'],
              ['Widget A', '120', '180'],
              ['Widget B', '85', '110'],
              ['Widget C', '200', '250'],
            ],
            hasHeader: true,
          ),
        );
      case 'icon':
        return SlideElement(
          type: ElementType.icon,
          content: '⭐',
          x: 900, y: 400, width: 120, height: 120,
          textStyle: TextStyleData(fontSize: 64),
        );
      default:
        return SlideElement(
          type: ElementType.text,
          content: 'Element',
          x: 60, y: 200, width: 400, height: 100,
          textStyle: TextStyleData(fontSize: 16),
        );
    }
  }
}

class _InsertItem {
  final IconData icon;
  final String label;
  final String type;
  final Color color;
  _InsertItem(this.icon, this.label, this.type, this.color);
}
