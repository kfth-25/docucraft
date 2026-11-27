// DocuCraft — Table Editor Panel
// Editan cell inline untuk elemen tabel

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/slide.dart';
import '../providers/slide_provider.dart';
import '../themes/app_theme.dart';

class TableEditorPanel extends StatefulWidget {
  final SlideElement element;

  const TableEditorPanel({super.key, required this.element});

  static void show(BuildContext context, SlideElement element) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TableEditorPanel(element: element),
    );
  }

  @override
  State<TableEditorPanel> createState() => _TableEditorPanelState();
}

class _TableEditorPanelState extends State<TableEditorPanel> {
  late List<List<TextEditingController>> _cellCtrls;
  int _rows = 3;
  int _cols = 3;
  late bool _hasHeader;

  @override
  void initState() {
    super.initState();
    final td = widget.element.tableData ?? TableData();
    _rows = td.rows;
    _cols = td.cols;
    _hasHeader = td.hasHeader;
    _initControllers(td);
  }

  void _initControllers(TableData td) {
    _cellCtrls = List.generate(_rows, (r) =>
      List.generate(_cols, (c) => TextEditingController(
        text: (r < td.cells.length && c < td.cells[r].length) ? td.cells[r][c] : '',
      )),
    );
  }

  @override
  void dispose() {
    for (final row in _cellCtrls) for (final c in row) c.dispose();
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _rows++;
      _cellCtrls.add(List.generate(_cols, (c) => TextEditingController(text: '')));
    });
  }

  void _addColumn() {
    setState(() {
      _cols++;
      for (var r = 0; r < _rows; r++) {
        _cellCtrls[r].add(TextEditingController(text: ''));
      }
    });
  }

  void _removeRow() {
    if (_rows <= 1) return;
    setState(() {
      _rows--;
      final lastRow = _cellCtrls.removeLast();
      for (final c in lastRow) c.dispose();
    });
  }

  void _removeColumn() {
    if (_cols <= 1) return;
    setState(() {
      _cols--;
      for (var r = 0; r < _rows; r++) {
        final last = _cellCtrls[r].removeLast();
        last.dispose();
      }
    });
  }

  void _save() {
    final cells = _cellCtrls.map((row) =>
      row.map((c) => c.text).toList()
    ).toList();
    final newTd = TableData(rows: _rows, cols: _cols, cells: cells, hasHeader: _hasHeader);
    widget.element.tableData = newTd;
    widget.element.bumpVersion();
    context.read<SlideProvider>().notify();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
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
                    const Icon(Icons.table_chart, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 10),
                    const Text('Edit Tabel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const Spacer(),
                    // Row controls
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline, size: 18, color: _rows <= 1 ? AppTheme.textMuted : AppTheme.error),
                      onPressed: _rows <= 1 ? null : _removeRow,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                    Text('$_rows baris', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 18, color: AppTheme.primary),
                      onPressed: _addRow,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                    const SizedBox(width: 8),
                    // Column controls
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline, size: 18, color: _cols <= 1 ? AppTheme.textMuted : AppTheme.error),
                      onPressed: _cols <= 1 ? null : _removeColumn,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                    Text('$_cols kolom', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 18, color: AppTheme.primary),
                      onPressed: _addColumn,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                    const SizedBox(width: 8),
                    // Header toggle
                    GestureDetector(
                      onTap: () => setState(() => _hasHeader = !_hasHeader),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _hasHeader ? AppTheme.primary.withAlpha(30) : AppTheme.surface3,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Header ${_hasHeader ? "ON" : "OFF"}',
                          style: TextStyle(fontSize: 10, color: _hasHeader ? AppTheme.primary : AppTheme.textMuted)),
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
              // Table editor
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: _rows,
                  itemBuilder: (ctx, r) => Row(
                    children: List.generate(_cols, (c) {
                      final isFirstRow = r == 0 && _hasHeader;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          child: TextField(
                            controller: _cellCtrls[r][c],
                            style: TextStyle(
                              color: isFirstRow ? Colors.white : AppTheme.textPrimary,
                              fontSize: 11,
                              fontWeight: isFirstRow ? FontWeight.bold : FontWeight.normal,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                              hintText: isFirstRow ? 'Header' : 'Cell',
                              hintStyle: TextStyle(color: AppTheme.textMuted.withAlpha(80), fontSize: 10),
                              filled: true,
                              fillColor: isFirstRow ? AppTheme.primary : AppTheme.surface3,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
