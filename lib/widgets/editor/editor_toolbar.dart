// DocuCraft — Editor Toolbar (Insert + Tools)
// Diekstrak dari slide_editor_screen.dart demi modularitas

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../models/slide.dart';
import '../../providers/slide_provider.dart';
import '../../widgets/insert_panel.dart';
import '../../widgets/background_panel.dart';
import '../../widgets/template_panel.dart';
import '../../widgets/layout_panel.dart';
import '../../widgets/transition_panel.dart';
import '../../widgets/version_history.dart';
import '../../widgets/outline_panel.dart';
import '../../widgets/ai_chat_panel.dart';
import '../../widgets/comments_panel.dart';
import '../../widgets/icon_picker.dart';
import '../../themes/app_theme.dart';

class EditorToolbar extends StatelessWidget {
  final SlideProvider provider;
  final bool drawActive;
  final VoidCallback onDrawToggle;
  final VoidCallback onSketchToDesign;
  final VoidCallback onImportPPT;

  const EditorToolbar({
    super.key,
    required this.provider,
    required this.drawActive,
    required this.onDrawToggle,
    required this.onSketchToDesign,
    required this.onImportPPT,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _toolBtn(Icons.text_fields, 'Teks', () => provider.addElement(
              SlideElement(type: ElementType.text, content: 'Text Baru', x: 60, y: 200, width: 600, height: 100,
                textStyle: TextStyleData(fontSize: 28)),
            )),
            _toolBtn(Icons.image, 'Gambar', () => InsertPanel.show(context)),
            _toolBtn(Icons.category, 'Shape', () => provider.addElement(
              SlideElement(type: ElementType.shape, x: 400, y: 300, width: 300, height: 300,
                shapeStyle: ShapeStyleData(fillColorValue: 0xFF6366F1, borderRadius: 12, shapeType: 'rect')),
            )),
            _toolBtn(Icons.bar_chart, 'Chart', () => provider.addElement(
              SlideElement(type: ElementType.chart, x: 120, y: 250, width: 800, height: 400,
                chartData: ChartData(
                  dataSets: [
                    ChartDataSet(values: [60, 80, 45, 90, 70], label: 'Series 1', colorValue: 0xFF6366F1),
                    ChartDataSet(values: [30, 50, 60, 40, 80], label: 'Series 2', colorValue: 0xFFEC4899),
                  ],
                  labels: ['Jan', 'Feb', 'Mar', 'Apr', 'Mei'],
                )),
            )),
            _toolBtn(Icons.draw, 'Coret', onDrawToggle),
            // AI dari Coretan button (only show when not drawing and has draw strokes)
            if (!drawActive)
              Consumer<SlideProvider>(
                builder: (ctx, provider, _) {
                  if (provider.hasDrawStrokes) {
                    return _toolBtn(Icons.auto_awesome, 'AI Coret', onSketchToDesign, primary: true);
                  }
                  return const SizedBox.shrink();
                },
              ),
            _divider(),
            _toolBtn(Icons.table_chart, 'Tabel', () => provider.addElement(
              SlideElement(type: ElementType.table, x: 100, y: 250, width: 800, height: 400,
                tableData: TableData()),
            )),
            _toolBtn(Icons.emoji_symbols, 'Icon', () async {
              final result = await showIconPicker(context);
              if (result != null && context.mounted) {
                context.read<SlideProvider>().addElement(
                  SlideElement(type: ElementType.icon, content: result, x: 900, y: 400, width: 120, height: 120,
                    textStyle: TextStyleData(fontSize: 64)),
                );
              }
            }),
            _divider(),
            _divider(),
            _toolBtn(Icons.palette, 'BG', () => BackgroundPanel.show(context), primary: true),
            _toolBtn(Icons.dashboard, 'Templ', () => TemplatePanel.show(context)),
            _toolBtn(Icons.view_quilt, 'Layout', () => LayoutPanel.show(context)),
            _toolBtn(Icons.swap_horiz, 'Trans', () => TransitionPanel.show(context)),
            _divider(),
            _toolBtn(Icons.file_upload, 'Import', onImportPPT),
            _divider(),
            _toolBtn(Icons.history, 'Versi', () => VersionHistoryPanel.show(context)),
            _toolBtn(Icons.auto_awesome, 'Outline', () => OutlinePanel.show(context), primary: true),
            _toolBtn(Icons.chat_bubble_outline, 'AI Chat', () => AiChatPanel.show(context)),
            _toolBtn(Icons.comment, 'Komen', () => CommentsPanel.show(context)),
          ],
        ),
      ),
    );
  }

  Widget _toolBtn(IconData icon, String label, VoidCallback onTap, {bool primary = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: primary ? AppTheme.primary : AppTheme.textSecondary),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppTheme.outline,
    );
  }
}