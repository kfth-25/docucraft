// DocuCraft — Transition Panel (transisi slide + preview)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/slide_provider.dart';
import '../themes/app_theme.dart';

class TransitionPanel extends StatefulWidget {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const TransitionPanel(),
    );
  }

  const TransitionPanel({super.key});

  @override
  State<TransitionPanel> createState() => _TransitionPanelState();
}

class _TransitionPanelState extends State<TransitionPanel> {
  String _selected = 'Fade';
  String _scope = 'single';

  final _options = [
    ('None', '—', 'Tanpa transisi', Icons.block),
    ('Fade', 'F', 'Transisi halus antar slide', Icons.blur_on),
    ('Slide Left', '→', 'Slide dari kanan ke kiri', Icons.arrow_forward),
    ('Slide Up', '↑', 'Slide dari bawah ke atas', Icons.arrow_upward),
    ('Scale', 'Z', 'Zoom masuk dari tengah', Icons.zoom_in),
    ('Zoom', '◆', 'Zoom besar ke kecil', Icons.aspect_ratio),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.swap_horiz, size: 18, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            const Text('Transisi Slide', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const Spacer(),
            // Scope picker
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surface3,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _scope,
                  dropdownColor: AppTheme.surface2,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 10),
                  items: const [
                    DropdownMenuItem(value: 'single', child: Text('Slide ini', style: TextStyle(fontSize: 10))),
                    DropdownMenuItem(value: 'all', child: Text('Semua slide', style: TextStyle(fontSize: 10))),
                  ],
                  onChanged: (v) => setState(() => _scope = v ?? 'single'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
            ),
          ]),
          const SizedBox(height: 12),
          ..._options.map((opt) => _optionCard(opt.$1, opt.$2, opt.$3, opt.$4)),
          const SizedBox(height: 12),
          // Apply button
          GestureDetector(
            onTap: () {
              final provider = context.read<SlideProvider>();
              if (_scope == 'all') {
                for (var slide in provider.slides) {
                  if (!slide.hidden) slide.extra ??= {};
                  slide.extra!['transition'] = _selected;
                }
              } else {
                final slide = provider.currentSlide;
                if (slide != null) {
                  slide.extra ??= {};
                  slide.extra!['transition'] = _selected;
                }
              }
              provider.notify();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('✅ Transisi "$_selected" diterapkan ke ${_scope == 'all' ? 'semua slide' : 'slide ini'}'),
                    behavior: SnackBarBehavior.floating),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.primary, const Color(0xFFA855F7)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Text('Terapkan Transisi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionCard(String name, String symbol, String desc, IconData icon) {
    final isSelected = _selected == name;
    return GestureDetector(
      onTap: () => setState(() => _selected = name),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withAlpha(25) : AppTheme.surface3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppTheme.primary.withAlpha(50) : Colors.white.withAlpha(8)),
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 24,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary.withAlpha(30) : Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(child: Text(symbol, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                    color: isSelected ? AppTheme.primary : AppTheme.textPrimary)),
                Text(desc, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
              ],
            )),
            if (isSelected)
              Container(
                width: 18, height: 18,
                decoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 12, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
