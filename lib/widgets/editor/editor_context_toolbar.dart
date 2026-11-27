// DocuCraft — Editor Context Toolbar
// Diekstrak dari slide_editor_screen.dart demi modularitas

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/slide.dart';
import '../../providers/slide_provider.dart';
import '../../themes/app_theme.dart';
import '../../widgets/color_picker_dialog.dart';
import '../../widgets/image_editor.dart';
import '../../widgets/text_editor_bottom_sheet.dart';

class EditorContextToolbar extends StatelessWidget {
  final SlideProvider provider;
  final Slide slide;
  final BuildContext parentContext;

  const EditorContextToolbar({
    super.key,
    required this.provider,
    required this.slide,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: provider.selectedElementId != null ? 44 : 0,
      child: provider.selectedElementId != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surface2,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _contextBtn(Icons.format_bold, 'Bold', () {
                      final el = _findElement(provider);
                      if (el != null && el.type == ElementType.text) {
                        final isBold = el.textStyle?.fontWeight == 'bold';
                        provider.updateElementStyle(el.id, {'fontWeight': isBold ? 'normal' : 'bold'});
                      }
                    }),
                    _contextBtn(Icons.format_italic, 'Italic', () {
                      final el = _findElement(provider);
                      if (el != null && el.type == ElementType.text) {
                        final isItalic = el.textStyle?.fontStyle == 'italic';
                        provider.updateElementStyle(el.id, {'fontStyle': isItalic ? 'normal' : 'italic'});
                      }
                    }),
                    _contextBtn(Icons.format_underlined, 'Underline', () {
                      final el = _findElement(provider);
                      if (el != null && el.type == ElementType.text) {
                        final current = el.textStyle?.textDecoration ?? 'none';
                        provider.updateElementStyle(el.id, {
                          'textDecoration': current == 'underline' ? 'none' : 'underline',
                        });
                      }
                    }),
                    _contextBtn(Icons.format_align_left, 'Left', () {
                      final el = _findElement(provider);
                      if (el != null) provider.updateElementStyle(el.id, {'textAlign': 'left'});
                    }),
                    _contextBtn(Icons.format_align_center, 'Center', () {
                      final el = _findElement(provider);
                      if (el != null) provider.updateElementStyle(el.id, {'textAlign': 'center'});
                    }),
                    _contextBtn(Icons.format_align_right, 'Right', () {
                      final el = _findElement(provider);
                      if (el != null) provider.updateElementStyle(el.id, {'textAlign': 'right'});
                    }),
                    const SizedBox(width: 12),
                    // Color picker button
                    _contextBtn(Icons.palette, 'Color', () async {
                      final el = _findElement(provider);
                      if (el == null) return;
                      if (el.type == ElementType.shape) {
                        final currentColor = Color(el.shapeStyle?.fillColorValue ?? 0xFF6366F1);
                        final result = await ColorPicker.show(parentContext, initial: currentColor);
                        if (result != null && parentContext.mounted) {
                          provider.updateElementStyle(el.id, {'fillColorValue': result.toARGB32()});
                        }
                      } else {
                        final currentColor = Color(el.textStyle?.colorValue ?? 0xFFFFFFFF);
                        final result = await ColorPicker.show(parentContext, initial: currentColor);
                        if (result != null && parentContext.mounted) {
                          provider.updateElementStyle(el.id, {'colorValue': result.toARGB32()});
                        }
                      }
                    }),
                    // Shape type picker (only for shapes)
                    if (_findElement(provider) != null && _findElement(provider)!.type == ElementType.shape)
                      _contextBtn(Icons.category, 'Bentuk', () {
                        final el = _findElement(provider);
                        if (el != null) _showShapeTypePicker(parentContext, el, provider);
                      }),
                    _contextBtn(Icons.image_outlined, 'Image', () async {
                      final el = _findElement(provider);
                      if (el == null || el.type != ElementType.image) return;
                      final result = await ImageEditor.show(parentContext, currentImageUrl: el.imageStyle?.src);
                      if (result != null && parentContext.mounted) {
                        provider.updateElementStyle(el.id, {'src': result.imageUrl});
                      }
                    }),
                    _contextBtn(Icons.format_size, 'A+', () {
                      final el = _findElement(provider);
                      if (el != null && el.type == ElementType.text) {
                        final newSize = (el.textStyle?.fontSize ?? 14) + 2;
                        provider.updateElementStyle(el.id, {'fontSize': newSize});
                      }
                    }, text: 'A+'),
                    _contextBtn(Icons.format_size, 'A-', () {
                      final el = _findElement(provider);
                      if (el != null && el.type == ElementType.text) {
                        final newSize = ((el.textStyle?.fontSize ?? 14) - 2).clamp(8, 72);
                        provider.updateElementStyle(el.id, {'fontSize': newSize});
                      }
                    }, text: 'A-'),
                    const SizedBox(width: 8),
                    // Edit text — opens TextEditorSheet
                    _contextBtn(Icons.edit, 'Edit', () {
                      final el = _findElement(provider);
                      if (el != null && (el.type == ElementType.text || el.type == ElementType.icon)) {
                        TextEditorSheet.show(parentContext, el);
                      }
                    }),
                    const SizedBox(width: 12),
                    _contextBtn(Icons.delete_outline, 'Hapus', () {
                      final id = provider.selectedElementId;
                      if (id != null) provider.deleteElement(id);
                    }, isDanger: true),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _contextBtn(IconData icon, String tooltip, VoidCallback onTap, {bool isDanger = false, String? text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isDanger ? AppTheme.error.withAlpha(30) : Colors.transparent,
          ),
          child: text != null
              ? Center(child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDanger ? AppTheme.error : AppTheme.textSecondary)))
              : Icon(icon, size: 18, color: isDanger ? AppTheme.error : AppTheme.textSecondary),
        ),
      ),
    );
  }

  SlideElement? _findElement(SlideProvider provider) {
    final id = provider.selectedElementId;
    if (id == null || provider.currentSlide == null) return null;
    try {
      return provider.currentSlide!.elements.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  void _showShapeTypePicker(BuildContext ctx, SlideElement el, SlideProvider provider) {
    const shapes = [
      {'key': 'rect', 'icon': '⬛', 'label': 'Rectangle'},
      {'key': 'circle', 'icon': '⬤', 'label': 'Circle'},
      {'key': 'diamond', 'icon': '◆', 'label': 'Diamond'},
      {'key': 'triangle', 'icon': '▲', 'label': 'Triangle'},
    ];
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: AppTheme.outline, borderRadius: BorderRadius.circular(2)))),
          const Text('Pilih Bentuk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: shapes.map((s) => GestureDetector(
              onTap: () {
                provider.updateElementStyle(el.id, {'shapeType': s['key']!});
                Navigator.pop(ctx);
              },
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: el.shapeStyle?.shapeType == s['key']
                      ? AppTheme.primary.withAlpha(30) : AppTheme.surface3,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: el.shapeStyle?.shapeType == s['key']
                        ? AppTheme.primary : AppTheme.outline,
                  ),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(s['icon']!, style: const TextStyle(fontSize: 28)),
                  const SizedBox(height: 4),
                  Text(s['label']!, style: TextStyle(fontSize: 9, color: el.shapeStyle?.shapeType == s['key']
                      ? AppTheme.primary : AppTheme.textMuted)),
                ]),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}