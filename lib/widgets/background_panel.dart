// DocuCraft — Background Panel V2
// Custom gradient picker dengan toggle Solid/Gradient + sorotan slot aktif

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/slide_provider.dart';
import '../themes/app_theme.dart';
import 'color_picker_dialog.dart';

class BackgroundPanel extends StatelessWidget {
  const BackgroundPanel({super.key});
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: AppTheme.surface2, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const BackgroundPanel(),
    );
  }
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.outline, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            const Text('Background Slide', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _CustomGradientPicker())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.palette_outlined, size: 14, color: AppTheme.textOnPrimary), SizedBox(width: 4),
                  Text('Custom', style: TextStyle(color: AppTheme.textOnPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Pilih warna latar slide', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          const SizedBox(height: 16),
          SizedBox(height: 240, child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.7),
            itemCount: _gradients.length,
            itemBuilder: (context, index) {
              final g = _gradients[index];
              return GestureDetector(
                onTap: () { context.read<SlideProvider>().updateSlideBackground(g.name); Navigator.pop(context); },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: g.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withAlpha(20), width: 2),
                    boxShadow: [BoxShadow(color: g.colors[0].withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Align(alignment: Alignment.bottomLeft,
                    child: Padding(padding: const EdgeInsets.all(8),
                      child: Text(g.label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              );
            },
          )),
        ]),
      ),
    );
  }
}

// ══ CUSTOM GRADIENT/SOLID PICKER ══
class _CustomGradientPicker extends StatefulWidget {
  const _CustomGradientPicker();
  @override
  State<_CustomGradientPicker> createState() => _CustomGradientPickerState();
}

class _CustomGradientPickerState extends State<_CustomGradientPicker> {
  Color _color1 = const Color(0xFF6366F1);
  Color _color2 = const Color(0xFF4F46E5);
  int _activeSlot = 0;
  bool _useGradient = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Custom', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          GestureDetector(
            onTap: _applyCustomGradient,
            child: Container(
              margin: const EdgeInsets.only(right: 16, top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8)),
              child: const Text('Apply', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Toggle
          _buildToggle(),
          const SizedBox(height: 16),
          // Preview
          _buildPreview(),
          const SizedBox(height: 20),
          // Color slots
          _buildSlots(),
          const SizedBox(height: 20),
          // Open picker
          _buildOpenPicker(),
          const SizedBox(height: 20),
          // Quick presets
          const Text('Quick Presets', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          _quickPresets(),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white.withAlpha(8), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Expanded(child: GestureDetector(
          onTap: () => setState(() => _useGradient = false),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: !_useGradient ? AppTheme.primary.withAlpha(80) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text('Solid', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: !_useGradient ? Colors.white : Colors.white54))),
          ),
        )),
        Expanded(child: GestureDetector(
          onTap: () => setState(() => _useGradient = true),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: _useGradient ? AppTheme.primary.withAlpha(80) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text('Gradient', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _useGradient ? Colors.white : Colors.white54))),
          ),
        )),
      ]),
    );
  }

  Widget _buildPreview() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: _useGradient ? LinearGradient(colors: [_color1, _color2], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
        color: _useGradient ? null : _color1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Center(child: Text(
        _useGradient ? 'Gradient Preview' : 'Solid Color Preview',
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
      )),
    );
  }

  Widget _buildSlots() {
    if (_useGradient) {
      return Row(children: [
        Expanded(child: _colorSlot('Color A', _color1, 0)),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, color: Colors.white38, size: 16)),
        Expanded(child: _colorSlot('Color B', _color2, 1)),
      ]);
    }
    return Center(child: SizedBox(width: 120, child: _colorSlot('Color', _color1, 0)));
  }

  Widget _buildOpenPicker() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        _useGradient ? (_activeSlot == 0 ? 'Pick Color A' : 'Pick Color B') : 'Pick Color',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
      ),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () async {
          final c = _useGradient ? (_activeSlot == 0 ? _color1 : _color2) : _color1;
          final picked = await ColorPicker.show(context, initial: c);
          if (picked != null && mounted) {
            setState(() {
              if (_useGradient) {
                if (_activeSlot == 0) _color1 = picked; else _color2 = picked;
                // After picking one color, stay on same slot for editing (don't auto-switch)
                // User can tap color A/B chips to manually switch
              } else {
                _color1 = picked;
              }
            });
          }
        },
        child: Container(
          width: double.infinity, height: 48,
          decoration: BoxDecoration(
            color: _useGradient ? (_activeSlot == 0 ? _color1 : _color2) : _color1,
            borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withAlpha(20)),
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.colorize, color: Colors.white, size: 18), SizedBox(width: 8),
            Text('Open Color Picker', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    ]);
  }

  Widget _colorSlot(String label, Color color, int slot) {
    final isActive = _activeSlot == slot;
    return GestureDetector(
      onTap: () => setState(() => _activeSlot = slot),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? Colors.white : Colors.transparent, width: isActive ? 3 : 0),
          boxShadow: isActive ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 14)] : [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 6)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.colorize, color: Colors.white, size: isActive ? 20 : 16),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white, fontSize: isActive ? 12 : 10, fontWeight: FontWeight.w700)),
          Text('#${color.toARGB32().toRadixString(16).substring(2).toUpperCase().padLeft(6, '0')}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 9, fontFamily: 'monospace')),
        ]),
      ),
    );
  }

  Widget _quickPresets() {
    final presets = [
      [Color(0xFF6366F1), Color(0xFF4F46E5)], [Color(0xFFF43F5E), Color(0xFFBE185D)],
      [Color(0xFFF59E0B), Color(0xFFEA580C)], [Color(0xFF10B981), Color(0xFF0D9488)],
      [Color(0xFF3B82F6), Color(0xFF0891B2)], [Color(0xFFA855F7), Color(0xFFEC4899)],
      [Color(0xFFFEE2E2), Color(0xFF991B1B)], [Color(0xFFDBEAFE), Color(0xFF1E3A8A)],
      [Color(0xFFE0E7FF), Color(0xFF312E81)], [Color(0xFFFFEDD5), Color(0xFF7C2D12)],
      [Color(0xFFD1FAE5), Color(0xFF064E3B)], [Color(0xFFF3E8FF), Color(0xFF4C1D95)],
      [Color(0xFFCCFBF1), Color(0xFF134E4A)], [Color(0xFFFCE7F3), Color(0xFF831843)],
      [Color(0xFFFEF9C3), Color(0xFF713F12)], [Color(0xFFCFFAFE), Color(0xFF164E63)],
      [Color(0xFF1E1B4B), Color(0xFF0B0F19)], [Color(0xFF65A30D), Color(0xFF4D7C0F)],
      [Color(0xFF8B5CF6), Color(0xFF6D28D9)], [Color(0xFFF97316), Color(0xFFC2410C)],
      [Color(0xFF475569), Color(0xFF1E293B)], [Color(0xFF2DD4BF), Color(0xFF3B82F6)],
      [Color(0xFFD97706), Color(0xFFDC2626)], [Color(0xFF06B6D4), Color(0xFF0891B2)],
      [Color(0xFF14B8A6), Color(0xFF0E7490)], [Color(0xFFEC4899), Color(0xFF831843)],
      [Color(0xFFE11D48), Color(0xFFBE123C)], [Color(0xFF84CC16), Color(0xFF4D7C0F)],
      [Color(0xFF0EA5E9), Color(0xFF0369A1)], [Color(0xFFFBBF24), Color(0xFFB45309)],
      [Color(0xFFEF4444), Color(0xFF991B1B)], [Color(0xFF6366F1), Color(0xFF312E81)],
    ];
    return Wrap(spacing: 6, runSpacing: 6,
      children: presets.map((colors) => GestureDetector(
        onTap: () => setState(() { _color1 = colors[0]; _color2 = colors[1]; }),
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withAlpha(20)),
            boxShadow: [BoxShadow(color: colors[0].withValues(alpha: 0.3), blurRadius: 4)],
          ),
        ),
      )).toList(),
    );
  }

  void _applyCustomGradient() {
    final provider = context.read<SlideProvider>();
    if (_useGradient) {
      provider.updateSlideBackgroundCustom(_color1, _color2);
    } else {
      final c = _color1.toARGB32().toRadixString(16).substring(2).toUpperCase();
      provider.updateSlideBackground('custom_$c,$c');
    }
    Navigator.pop(context); Navigator.pop(context);
  }
}

// ══ PRESET GRADIENTS ══
class _GradientEntry {
  final String name; final String label; final List<Color> colors;
  const _GradientEntry({required this.name, required this.label, required this.colors});
}

const _gradients = <_GradientEntry>[
  _GradientEntry(name: 'indigo', label: 'Indigo', colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
  _GradientEntry(name: 'purple', label: 'Purple', colors: [Color(0xFFA855F7), Color(0xFFEC4899)]),
  _GradientEntry(name: 'blue', label: 'Ocean', colors: [Color(0xFF3B82F6), Color(0xFF0891B2)]),
  _GradientEntry(name: 'emerald', label: 'Emerald', colors: [Color(0xFF10B981), Color(0xFF0D9488)]),
  _GradientEntry(name: 'amber', label: 'Sunset', colors: [Color(0xFFF59E0B), Color(0xFFEA580C)]),
  _GradientEntry(name: 'rose', label: 'Rose', colors: [Color(0xFFF43F5E), Color(0xFFBE185D)]),
  _GradientEntry(name: 'teal', label: 'Teal', colors: [Color(0xFF14B8A6), Color(0xFF0E7490)]),
  _GradientEntry(name: 'orange', label: 'Orange', colors: [Color(0xFFF97316), Color(0xFFC2410C)]),
  _GradientEntry(name: 'pink', label: 'Pink', colors: [Color(0xFFE11D48), Color(0xFFBE123C)]),
  _GradientEntry(name: 'cyan', label: 'Cyan', colors: [Color(0xFF06B6D4), Color(0xFF0891B2)]),
  _GradientEntry(name: 'lime', label: 'Lime', colors: [Color(0xFF65A30D), Color(0xFF4D7C0F)]),
  _GradientEntry(name: 'violet', label: 'Violet', colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
  _GradientEntry(name: 'slate', label: 'Slate', colors: [Color(0xFF475569), Color(0xFF1E293B)]),
  _GradientEntry(name: 'warm', label: 'Warm', colors: [Color(0xFFD97706), Color(0xFFDC2626)]),
  _GradientEntry(name: 'frost', label: 'Frost', colors: [Color(0xFF2DD4BF), Color(0xFF3B82F6)]),
  _GradientEntry(name: 'midnight', label: 'Midnight', colors: [Color(0xFF1E1B4B), Color(0xFF0B0F19)]),
  _GradientEntry(name: 'light-red', label: 'Red Fade', colors: [Color(0xFFFEE2E2), Color(0xFF991B1B)]),
  _GradientEntry(name: 'light-blue', label: 'Blue Fade', colors: [Color(0xFFDBEAFE), Color(0xFF1E3A8A)]),
  _GradientEntry(name: 'light-green', label: 'Green Fade', colors: [Color(0xFFD1FAE5), Color(0xFF064E3B)]),
  _GradientEntry(name: 'light-purple', label: 'Purple Fade', colors: [Color(0xFFF3E8FF), Color(0xFF4C1D95)]),
];
