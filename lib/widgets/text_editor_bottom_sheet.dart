// DocuCraft — Text Editor Bottom Sheet (Mobile)
// Tap pada elemen teks → buka bottom sheet ini untuk mengedit.
//
// Kenapa terpisah dari canvas:
//   - Keyboard di mobile mendorong layout secara tidak terduga
//   - Bottom sheet memberi editan teks full-width + kontrol kaya
//   - Preview real-time tersinkron kembali ke canvas
//
// Fitur:
//   - Bold, italic, underline, strikethrough
//   - Ukuran font (slider +/-)
//   - Warna font (palet 12 warna)
//   - Font family (DM Sans, Inter, JetBrains Mono)
//   - Perataan teks (kiri, tengah, kanan, justify)
//   - Line height / letter spacing
//   - Auto-save saat ditutup

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/slide.dart';
import '../providers/slide_provider.dart';
import '../themes/app_theme.dart';

class TextEditorSheet extends StatefulWidget {
  final SlideElement element;

  const TextEditorSheet({super.key, required this.element});

  static void show(BuildContext context, SlideElement element) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TextEditorSheet(element: element),
    );
  }

  @override
  State<TextEditorSheet> createState() => _TextEditorSheetState();
}

class _TextEditorSheetState extends State<TextEditorSheet> {
  late TextEditingController _textCtrl;
  late TextStyleData _style;

  // ── Quick color palette ──
  static const List<int> _colors = [
    0xFFFFFFFF, // White
    0xFF000000, // Black
    0xFF6366F1, // Indigo
    0xFFA855F7, // Purple
    0xFFEC4899, // Pink
    0xFF10B981, // Green
    0xFF3B82F6, // Blue
    0xFFF59E0B, // Amber
    0xFFEF4444, // Red
    0xFF6B7280, // Gray
    0xFF1E293B, // Dark
    0xFF94A3B8, // Light Gray
  ];

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.element.content ?? '');
    _style = widget.element.textStyle ?? TextStyleData();
  }

  @override
  void dispose() {
    _saveAndClose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _saveAndClose() {
    final provider = context.read<SlideProvider>();
    final el = widget.element;

    // Save text content
    provider.captureUndo();
    el.content = _textCtrl.text;
    el.textStyle = _style;
    el.richRuns = null; // manual edit replaces the mixed-style run layout
    el.version++;
    provider.notify();
  }

  void _setFontWeight(String w) {
    setState(() => _style.fontWeight = w);
  }

  void _toggleItalic() {
    setState(() => _style.fontStyle = _style.fontStyle == 'italic' ? 'normal' : 'italic');
  }

  void _toggleUnderline() {
    setState(() => _style.textDecoration = _style.textDecoration == 'underline' ? 'none' : 'underline');
  }

  void _toggleStrikethrough() {
    setState(() => _style.textDecoration = _style.textDecoration == 'line-through' ? 'none' : 'line-through');
  }

  void _setTextAlign(String a) {
    setState(() => _style.textAlign = a);
  }

  void _setColor(int c) {
    setState(() => _style.colorValue = c);
  }

  void _setFontSize(double size) {
    setState(() => _style.fontSize = size.clamp(8, 72));
  }

  void _setFontFamily(String? family) {
    setState(() => _style.fontFamily = family);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(bottom: bottom),
          child: Column(
            children: [
              // ── Handle ──
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.edit, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    const Text('Edit Teks', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const Spacer(),

                    // Undo / Redo
                    GestureDetector(
                      onTap: () {
                        final p = context.read<SlideProvider>();
                        if (p.canUndo) p.undo();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.surface3,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.undo, size: 14, color: AppTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        final p = context.read<SlideProvider>();
                        if (p.canRedo) p.redo();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.surface3,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.redo, size: 14, color: AppTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Close
                    GestureDetector(
                      onTap: () {
                        _saveAndClose();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.check, size: 14, color: AppTheme.textOnPrimary),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: AppTheme.textMuted, height: 1),

              // ── Text Input ──
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Live preview
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _previewBg(),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        _textCtrl.text.isEmpty ? 'Ketik teks...' : _textCtrl.text,
                        style: TextStyle(
                          fontSize: _style.fontSize,
                          color: Color(_style.colorValue),
                          fontWeight: _parseWeight(_style.fontWeight),
                          fontStyle: _style.fontStyle == 'italic' ? FontStyle.italic : FontStyle.normal,
                          fontFamily: _style.fontFamily,
                          letterSpacing: _style.letterSpacing,
                          height: _style.lineHeight,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Text field
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface3,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _textCtrl,
                        maxLines: 8,
                        minLines: 3,
                        autofocus: true,
                        style: TextStyle(
                          color: Color(_style.colorValue),
                          fontSize: _style.fontSize,
                          fontWeight: _parseWeight(_style.fontWeight),
                          fontStyle: _style.fontStyle == 'italic' ? FontStyle.italic : FontStyle.normal,
                          fontFamily: _style.fontFamily,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(14),
                          hintText: 'Ketik teks...',
                          hintStyle: TextStyle(color: AppTheme.textMuted),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Rich Text Controls ──

                    // 1. Bold, Italic, Size
                    _sectionLabel('Style Teks'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _toggleBtn('B', _style.fontWeight == 'bold', _style.fontWeight == 'bold' ? () => _setFontWeight('normal') : () => _setFontWeight('bold')),
                        const SizedBox(width: 8),
                        _toggleBtn('I', _style.fontStyle == 'italic', _toggleItalic),
                        const SizedBox(width: 8),
                        _toggleBtn('U', _style.textDecoration == 'underline', _toggleUnderline),
                        const SizedBox(width: 16),
                        // Size slider
                        Expanded(
                          child: Row(
                            children: [
                              const Text('A', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                              Expanded(
                                child: Slider(
                                  value: _style.fontSize,
                                  min: 8, max: 72,
                                  divisions: 32,
                                  activeColor: AppTheme.primary,
                                  inactiveColor: AppTheme.surface3,
                                  onChanged: _setFontSize,
                                ),
                              ),
                              Text('A', style: TextStyle(fontSize: 18, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.surface3,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_style.fontSize.round().toString()}px',
                            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 2. Color palette
                    _sectionLabel('Warna'),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _colors.map((c) => GestureDetector(
                        onTap: () => _setColor(c),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _style.colorValue == c
                                  ? AppTheme.primary
                                  : AppTheme.outline,
                              width: _style.colorValue == c ? 3 : 1,
                            ),
                          ),
                        ),
                      )).toList(),
                    ),

                    const SizedBox(height: 14),

                    // 3. Font family
                    _sectionLabel('Font'),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _fontChip('DM Sans', 'DM Sans'),
                          const SizedBox(width: 6),
                          _fontChip('Inter', 'Inter'),
                          const SizedBox(width: 6),
                          _fontChip('Mono', 'JetBrains Mono'),
                          const SizedBox(width: 6),
                          _fontChip('Serif', 'Georgia'),
                          const SizedBox(width: 6),
                          _fontChip('Default', null),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 4. Text alignment
                    _sectionLabel('Rata Teks'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _alignBtn(Icons.format_align_left, 'left'),
                        const SizedBox(width: 8),
                        _alignBtn(Icons.format_align_center, 'center'),
                        const SizedBox(width: 8),
                        _alignBtn(Icons.format_align_right, 'right'),
                        const SizedBox(width: 8),
                        _alignBtn(Icons.format_align_justify, 'justify'),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 5. Letter spacing + line height
                    _sectionLabel('Spasi'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text('Letter', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                        Expanded(
                          child: Slider(
                            value: _style.letterSpacing ?? 0,
                            min: -2, max: 8,
                            divisions: 20,
                            activeColor: AppTheme.primary,
                            inactiveColor: AppTheme.surface3,
                            onChanged: (v) => setState(() => _style.letterSpacing = v),
                          ),
                        ),
                        const Text('Line', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                        Expanded(
                          child: Slider(
                            value: (_style.lineHeight ?? 1.4).clamp(0.8, 3.0),
                            min: 0.8, max: 3.0,
                            divisions: 22,
                            activeColor: AppTheme.primary,
                            inactiveColor: AppTheme.surface3,
                            onChanged: (v) => setState(() => _style.lineHeight = v),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary));
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : AppTheme.surface3,
          border: Border.all(
            color: active ? AppTheme.primary : AppTheme.outline,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? AppTheme.textOnPrimary : AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _fontChip(String label, String? family) {
    final active = (family == null && _style.fontFamily == null) ||
                   (_style.fontFamily == family);
    return GestureDetector(
      onTap: () => _setFontFamily(family),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary.withAlpha(25) : AppTheme.surface3,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppTheme.primary : AppTheme.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? AppTheme.primary : AppTheme.textSecondary,
            fontFamily: family,
          ),
        ),
      ),
    );
  }

  Widget _alignBtn(IconData icon, String align) {
    final active = _style.textAlign == align;
    return GestureDetector(
      onTap: () => _setTextAlign(align),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : AppTheme.surface3,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppTheme.primary : AppTheme.outline,
          ),
        ),
        child: Icon(icon, size: 18, color: active ? AppTheme.textOnPrimary : AppTheme.textSecondary),
      ),
    );
  }

  Color _previewBg() {
    // Check if text is dark → light background, or light text → dark background
    final isDark = _style.colorValue == 0xFF000000 || _style.colorValue == 0xFF1E293B ||
                   _style.colorValue == 0xFF6B7280;
    return isDark ? AppTheme.surface3 : AppTheme.surface;
  }

  FontWeight _parseWeight(String w) {
    switch (w) {
      case 'thin': return FontWeight.w100;
      case 'light': return FontWeight.w300;
      case 'normal': return FontWeight.w400;
      case 'medium': return FontWeight.w500;
      case 'semibold': return FontWeight.w600;
      case 'bold': return FontWeight.w700;
      case 'extrabold': return FontWeight.w800;
      case 'black': return FontWeight.w900;
      default: return FontWeight.w400;
    }
  }
}
