// DocuCraft — Chart Editor Panel
// Mengizinkan edit data chart: label, nilai, warna per seri

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/slide.dart';
import '../providers/slide_provider.dart';
import '../themes/app_theme.dart';

class ChartEditorPanel extends StatefulWidget {
  final SlideElement element;

  const ChartEditorPanel({super.key, required this.element});

  static void show(BuildContext context, SlideElement element) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChartEditorPanel(element: element),
    );
  }

  @override
  State<ChartEditorPanel> createState() => _ChartEditorPanelState();
}

class _ChartEditorPanelState extends State<ChartEditorPanel> {
  late List<TextEditingController> _labelCtrls;
  late List<List<TextEditingController>> _valueCtrls;
  late List<TextEditingController> _seriesCtrls;
  late String _chartType;
  int _seriesCount = 1;

  @override
  void initState() {
    super.initState();
    final cd = widget.element.chartData ?? ChartData();
    _chartType = cd.chartType;
    _seriesCount = cd.dataSets.length;
    _initControllers(cd);
  }

  void _initControllers(ChartData cd) {
    _labelCtrls = cd.labels.map((l) => TextEditingController(text: l)).toList();
    _seriesCtrls = cd.dataSets.map((ds) => TextEditingController(text: ds.label)).toList();
    _valueCtrls = cd.dataSets.map((ds) =>
      ds.values.map((v) => TextEditingController(text: v.toString())).toList()
    ).toList();
  }

  @override
  void dispose() {
    for (final c in _labelCtrls) c.dispose();
    for (final c in _seriesCtrls) c.dispose();
    for (final row in _valueCtrls) for (final c in row) c.dispose();
    super.dispose();
  }

  void _addSeries() {
    setState(() {
      _seriesCtrls.add(TextEditingController(text: 'Series ${_seriesCount + 1}'));
      _valueCtrls.add(_labelCtrls.map((_) => TextEditingController(text: '50')).toList());
      _seriesCount++;
    });
  }

  void _addLabel() {
    setState(() {
      _labelCtrls.add(TextEditingController(text: 'Label ${_labelCtrls.length + 1}'));
      for (final row in _valueCtrls) {
        row.add(TextEditingController(text: '50'));
      }
    });
  }

  void _save() {
    final cd = widget.element.chartData ?? ChartData();
    cd.chartType = _chartType;
    cd.labels = _labelCtrls.map((c) => c.text).toList();
    cd.dataSets = List.generate(_seriesCtrls.length, (i) {
      final values = i < _valueCtrls.length
          ? _valueCtrls[i].map((c) => double.tryParse(c.text) ?? 0).toList()
          : [];
      return ChartDataSet(
        values: values.map((v) => (v as num).toDouble()).toList(),
        label: _seriesCtrls[i].text,
        colorValue: cd.dataSets.length > i ? cd.dataSets[i].colorValue : _defaultColor(i),
      );
    });
    widget.element.bumpVersion();
    context.read<SlideProvider>().notify();
    Navigator.pop(context);
  }

  int _defaultColor(int i) {
    const colors = [0xFF6366F1, 0xFFEC4899, 0xFF10B981, 0xFFF59E0B, 0xFF3B82F6];
    return colors[i % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(2)))),
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withAlpha(12)))),
                child: Row(
                  children: [
                    const Icon(Icons.bar_chart, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 10),
                    const Text('Edit Chart', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const Spacer(),
                    // Chart type
                    DropdownButton<String>(
                      value: _chartType,
                      dropdownColor: AppTheme.surface3,
                      items: const [
                        DropdownMenuItem(value: 'bar', child: Text('Bar', style: TextStyle(fontSize: 12, color: AppTheme.textPrimary))),
                        DropdownMenuItem(value: 'line', child: Text('Line', style: TextStyle(fontSize: 12, color: AppTheme.textPrimary))),
                        DropdownMenuItem(value: 'pie', child: Text('Pie', style: TextStyle(fontSize: 12, color: AppTheme.textPrimary))),
                      ],
                      onChanged: (v) => setState(() => _chartType = v ?? 'bar'),
                      underline: const SizedBox(),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _addLabel,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.surface3, borderRadius: BorderRadius.circular(6)),
                        child: const Row(
                          children: [
                            Icon(Icons.add, size: 12, color: AppTheme.primary),
                            SizedBox(width: 4),
                            Text('Label', style: TextStyle(fontSize: 10, color: AppTheme.primary)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _addSeries,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.surface3, borderRadius: BorderRadius.circular(6)),
                        child: const Row(
                          children: [
                            Icon(Icons.add, size: 12, color: Color(0xFFA855F7)),
                            SizedBox(width: 4),
                            Text('Series', style: TextStyle(fontSize: 10, color: Color(0xFFA855F7))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8)),
                        child: const Text('Simpan', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              // Editor body
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Series labels
                    if (_seriesCount > 1)
                      ...List.generate(_seriesCtrls.length, (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(width: 12, height: 12,
                              decoration: BoxDecoration(color: Color(_defaultColor(i)), borderRadius: BorderRadius.circular(3))),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _seriesCtrls[i],
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: 'Nama Series ${i + 1}',
                                  hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  filled: true, fillColor: AppTheme.surface3,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                    const SizedBox(height: 8),
                    // Data table: rows = labels, cols = series
                    ...List.generate(_labelCtrls.length, (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: _labelCtrls[row],
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                filled: true, fillColor: AppTheme.surface3,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ...List.generate(_seriesCount, (col) {
                            final ctrl = (col < _valueCtrls.length && row < _valueCtrls[col].length)
                                ? _valueCtrls[col][row]
                                : TextEditingController(text: '0');
                            return Container(
                              width: 60,
                              margin: const EdgeInsets.only(right: 4),
                              child: TextField(
                                controller: ctrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                  filled: true, fillColor: Color(_defaultColor(col)).withAlpha(20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
