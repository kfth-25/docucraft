// DocuCraft — Color Picker Canva-Style with Smooth Drag (Kompatibel Flutter Web)
// Saturation box + Hue slider menggunakan Stack + Container gradient, bukan CustomPaint

import 'package:flutter/material.dart';

class ColorPicker {
  static Future<Color?> show(BuildContext context, {Color initial = const Color(0xFF6366F1)}) {
    return showModalBottomSheet<Color>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ColorPickerSheet(initialColor: initial),
    );
  }
}

class _ColorPickerSheet extends StatefulWidget {
  final Color initialColor;
  const _ColorPickerSheet({required this.initialColor});
  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  double _hue = 0;
  double _sat = 1.0;
  double _bri = 1.0;
  final _hexCtrl = TextEditingController();

  Color get _color => HSVColor.fromAHSV(1, _hue, _sat, _bri).toColor();
  String get _hex => _color.toARGB32().toRadixString(16).substring(2).toUpperCase().padLeft(6, '0');

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue; _sat = hsv.saturation; _bri = hsv.value;
    _hexCtrl.text = _hex;
  }

  void _update(double h, double s, double v) {
    setState(() { _hue = h.clamp(0, 360); _sat = s.clamp(0, 1); _bri = v.clamp(0, 1); });
    _hexCtrl.text = _hex;
  }

  void _fromHex(String hex) {
    try {
      final h = hex.replaceAll('#', '').trim();
      if (h.length == 6) {
        final c = Color(int.parse(h, radix: 16) | 0xFF000000);
        final hsv = HSVColor.fromColor(c);
        _update(hsv.hue, hsv.saturation, hsv.value);
      }
    } catch (_) {}
  }

  @override
  void dispose() { _hexCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Padding(padding: const EdgeInsets.only(top: 8),
            child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),

          // Tab
          _tabBar(),
          const SizedBox(height: 12),

          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // SATURATION-BRIGHTNESS BOX (Stack + Container, bukan CustomPaint)
              _buildSatBox(),
              const SizedBox(height: 10),

              // HUE SLIDER
              _buildHueSlider(),
              const SizedBox(height: 12),

              // HEX INPUT + PREVIEW + EYEDROPPER
              _hexRow(),
              const SizedBox(height: 14),

              // PRESET GRID
              const Text('Preset Colors', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white54)),
              const SizedBox(height: 8),
              _presetGrid(),

              const SizedBox(height: 16),
              // APPLY BUTTON
              SizedBox(width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, _color),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: _color.withValues(alpha: 0.3), blurRadius: 12)],
                    ),
                    child: const Center(child: Text('Apply Color', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ]),
          )),
        ],
      ),
    );
  }

  // ══ TAB BAR ══
  Widget _tabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white.withAlpha(8), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        _tab('Solid Color', true),
        _tab('Gradient', false),
      ]),
    );
  }
  Widget _tab(String label, bool active) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(color: active ? Colors.white.withAlpha(15) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
    child: Center(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : Colors.white38))),
  ));

  // ══ SATURATION-BRIGHTNESS BOX (DRAGGABLE) ══
  Widget _buildSatBox() {
    return LayoutBuilder(builder: (ctx, c) {
      final w = c.maxWidth;
      final h = w * 0.68;
      return SizedBox(
        width: w, height: h,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Layer 1: Hue color
              Container(color: HSVColor.fromAHSV(1, _hue, 1, 1).toColor()),
              // Layer 2: White → transparent (saturation)
              Positioned.fill(child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.white, Colors.white.withAlpha(0)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                ),
              )),
              // Layer 3: Transparent → black (brightness)
              Positioned.fill(child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.black.withAlpha(0), Colors.black], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                ),
              )),
              // Border
              Positioned.fill(child: IgnorePointer(child: Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.white.withAlpha(20)), borderRadius: BorderRadius.circular(12)),
              ))),
              // Pointer (draggable)
              Positioned(
                left: (_sat * w) - 9,
                top: ((1 - _bri) * h) - 9,
                child: GestureDetector(
                  onPanStart: (_) {},
                  onPanUpdate: (d) {
                    final RenderBox box = context.findRenderObject() as RenderBox;
                    final pos = box.globalToLocal(d.globalPosition);
                    final s = (pos.dx / w).clamp(0.0, 1.0);
                    final v = (1 - pos.dy / h).clamp(0.0, 1.0);
                    _update(_hue, s, v);
                  },
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _color,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
                    ),
                  ),
                ),
              ),
              // Click anywhere to jump
              Positioned.fill(child: GestureDetector(
                onTapDown: (d) {
                  final s = (d.localPosition.dx / w).clamp(0.0, 1.0);
                  final v = (1 - d.localPosition.dy / h).clamp(0.0, 1.0);
                  _update(_hue, s, v);
                },
                onPanDown: (d) {
                  final s = (d.localPosition.dx / w).clamp(0.0, 1.0);
                  final v = (1 - d.localPosition.dy / h).clamp(0.0, 1.0);
                  _update(_hue, s, v);
                },
                onPanUpdate: (d) {
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final pos = box.globalToLocal(d.globalPosition);
                  final s = (pos.dx / w).clamp(0.0, 1.0);
                  final v = (1 - pos.dy / h).clamp(0.0, 1.0);
                  _update(_hue, s, v);
                },
              )),
            ],
          ),
        ),
      );
    });
  }

  // ══ HUE SLIDER (DRAGGABLE) ══
  Widget _buildHueSlider() {
    return LayoutBuilder(builder: (ctx, c) {
      final w = c.maxWidth;
      return SizedBox(
        width: w, height: 22,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            children: [
              Positioned.fill(child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    Color(0xFFFF0000), Color(0xFFFF8800), Color(0xFFFFFF00),
                    Color(0xFF00FF00), Color(0xFF00FFFF), Color(0xFF0088FF),
                    Color(0xFF8800FF), Color(0xFFFF0088), Color(0xFFFF0000),
                  ]),
                  border: Border.all(color: Colors.white.withAlpha(20)),
                  borderRadius: BorderRadius.circular(11),
                ),
              )),
              // Handle
              Positioned(
                left: (_hue / 360 * w) - 9,
                top: 1,
                child: GestureDetector(
                  onPanStart: (_) {},
                  onPanUpdate: (d) {
                    final RenderBox box = context.findRenderObject() as RenderBox;
                    final pos = box.globalToLocal(d.globalPosition);
                    final h = (pos.dx / w * 360).clamp(0.0, 360.0);
                    _update(h, _sat, _bri);
                  },
                  child: Container(
                    width: 18, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HSVColor.fromAHSV(1, _hue, 1, 1).toColor(),
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
                    ),
                  ),
                ),
              ),
              // Click anywhere on slider
              Positioned.fill(child: GestureDetector(
                onTapDown: (d) {
                  final h = (d.localPosition.dx / w * 360).clamp(0.0, 360.0);
                  _update(h, _sat, _bri);
                },
                onPanDown: (d) {
                  final h = (d.localPosition.dx / w * 360).clamp(0.0, 360.0);
                  _update(h, _sat, _bri);
                },
                onPanUpdate: (d) {
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final pos = box.globalToLocal(d.globalPosition);
                  final h = (pos.dx / w * 360).clamp(0.0, 360.0);
                  _update(h, _sat, _bri);
                },
              )),
            ],
          ),
        ),
      );
    });
  }

  // ══ HEX INPUT + PREVIEW + EYEDROPPER ══
  Widget _hexRow() {
    return Row(children: [
      // Preview
      Container(width: 36, height: 36,
        decoration: BoxDecoration(
          color: _color, shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withAlpha(30)),
          boxShadow: [BoxShadow(color: _color.withValues(alpha: 0.4), blurRadius: 8)],
        ),
      ),
      const SizedBox(width: 10),
      // Hex field
      Expanded(child: Container(
        decoration: BoxDecoration(color: Colors.white.withAlpha(8), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withAlpha(20))),
        child: Row(children: [
          const Padding(padding: EdgeInsets.only(left: 10), child: Text('#', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700))),
          Expanded(child: TextField(
            controller: _hexCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w600),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
            onSubmitted: _fromHex,
            onChanged: (v) { if (v.length == 6) _fromHex(v); },
          )),
        ]),
      )),
      const SizedBox(width: 10),
      // Eyedropper
      Container(width: 36, height: 36,
        decoration: BoxDecoration(color: Colors.white.withAlpha(8), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withAlpha(20))),
        child: const Icon(Icons.colorize, color: Colors.white54, size: 18),
      ),
    ]);
  }

  // ══ PRESET GRID (5 rows) ══
  Widget _presetGrid() {
    final rows = [
      ['#EF4444','#F97316','#F59E0B','#EAB308','#84CC16','#22C55E','#10B981','#14B8A6','#06B6D4','#0EA5E9','#3B82F6','#6366F1','#8B5CF6'],
      ['#DC2626','#EA580C','#D97706','#CA8A04','#65A30D','#16A34A','#059669','#0D9488','#0891B2','#0284C7','#2563EB','#4F46E5','#7C3AED'],
      ['#B91C1C','#C2410C','#B45309','#A16207','#4D7C0F','#15803D','#047857','#0F766E','#0E7490','#0369A1','#1D4ED8','#4338CA','#6D28D9'],
      ['#991B1B','#9A3412','#92400E','#854D0E','#3F6212','#166534','#065F46','#115E59','#155E75','#075985','#1E40AF','#3730A3','#5B21B6'],
      ['#FFFFFF','#F3F4F6','#D1D5DB','#9CA3AF','#6B7280','#4B5563','#374151','#1F2937','#111827','#000000','#FF00FF','#00FFFF','#FFFF00'],
    ];
    return Column(children: rows.map((row) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: row.map((hex) {
        final c = Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);
        final isWhite = hex == '#FFFFFF';
        return Expanded(child: GestureDetector(
          onTap: () {
            final hsv = HSVColor.fromColor(c);
            _update(hsv.hue, hsv.saturation, hsv.value);
          },
          child: Container(
            margin: const EdgeInsets.all(2), height: 28,
            decoration: BoxDecoration(
              color: c, borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isWhite ? Colors.white.withAlpha(30) : Colors.white.withAlpha(10), width: isWhite ? 1.5 : 0.5),
            ),
          ),
        ));
      }).toList()),
    )).toList());
  }
}
