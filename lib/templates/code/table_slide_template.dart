// DocuCraft — Table Slide Template (Flutter-native, Code theme)
// 1:1 dengan TableSlide.tsx (Presenton Code theme)
// Design space 1280×720 (sama dengan TSX)
//
// Tata letak:
//   Container: p-53px, bg #101B37, font Nunito Sans
//   Title: 64px font-medium #ffffff
//   Table Card: mt-22px rounded-16px border
//     bg #0F172BCC, border #1D293D80
//   Table: grid cols = tableColumns.length, rows = 1 header + baris data
//   Header: px-28 py-16, font-size dinamis (13-18px), border-b border-r #1D293D80
//   Cell: flex items-center px-28 py-14, border-b border-r #1D293D80
//   Spesial: "check" di kolom selain pertama → ✓ hijau 26px
//   Teks kolom pertama: #d5dcff, kolom lain: #CAD5E2
//   Ukuran font dinamis berdasarkan panjang konten & kepadatan

import 'package:flutter/material.dart';

class CodeTableSlideTemplate extends StatelessWidget {
  final String title;
  final List<String> tableColumns;
  final List<List<String>> rows; // each row = list of cell strings

  const CodeTableSlideTemplate({
    super.key,
    this.title = 'Comparison',
    this.tableColumns = const ['Feature', 'Column 1', 'Column 2', 'Column 3'],
    this.rows = const [
      ['Component-based', 'check', 'check', 'check'],
      ['TypeScript Support', 'check', 'check', 'check'],
      ['Learning Curve', 'Medium', 'Easy', 'Steep'],
      ['Bundle Size', '40KB', '34KB', '167KB'],
      ['Performance', 'Excellent', 'Excellent', 'Good'],
      ['Community Size', 'Huge', 'Large', 'Large'],
    ],
  });

  static const _bg = Color(0xFF101B37);
  static const _cardBg = Color(0xCC0F172B); // #0F172BCC
  static const _stroke = Color(0x801D293D); // #1D293D80
  static const _titleColor = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final s = constraints.maxWidth / 1280;
      final colCount = tableColumns.length.clamp(1, 6);
      final _ = rows.length.clamp(1, 6); // rowCount used in getCellFontSize

      // Normalize columns (take first 6)
      final displayColumns = tableColumns.take(6).toList();
      if (displayColumns.length < colCount) {
        displayColumns.addAll(List.filled(colCount - displayColumns.length, ''));
      }

      // Normalize rows (take first 6, pad to colCount)
      final displayRows = rows.take(6).map((row) {
        final cells = row.take(colCount).toList();
        if (cells.length < colCount) {
          cells.addAll(List.filled(colCount - cells.length, ''));
        }
        return cells;
      }).toList();

      // Dynamic header font size (matches TSX clamp logic)
      final headerFontSize = _clamp(18 - (colCount - 4).clamp(0, 100) * 1.2, 13, 18) * s;

      // Dynamic cell font size calculator
      double getCellFontSize(int colCount, int rowCount, String value) {
        final lengthPenalty = (value.length - 18).clamp(0, 100) * 0.18;
        final densityPenalty = (colCount - 4).clamp(0, 100) * 1.2 + (rowCount - 5).clamp(0, 100) * 0.8;
        return _clamp(19 - lengthPenalty - densityPenalty, 13, 19) * s;
      }

      return Container(
        width: constraints.maxWidth,
        height: constraints.maxWidth * 720 / 1280,
        color: _bg,
        padding: EdgeInsets.all(53 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title: 64px font-medium #ffffff
            Text(
              title,
              style: TextStyle(
                fontSize: 64 * s,
                fontWeight: FontWeight.w500,
                color: _titleColor,
                fontFamily: 'Nunito Sans',
              ),
            ),
            // Table Card: mt-22px
            SizedBox(height: 22 * s),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(16 * s),
                  border: Border.all(color: _stroke, width: 1 * s),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16 * s),
                  child: _TableGrid(
                    scale: s,
                    columns: displayColumns,
                    rows: displayRows,
                    headerFontSize: headerFontSize,
                    getCellFontSize: getCellFontSize,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  static double _clamp(double value, double min, double max) =>
      value < min ? min : (value > max ? max : value);
}

class _TableGrid extends StatelessWidget {
  final double scale;
  final List<String> columns;
  final List<List<String>> rows;
  final double headerFontSize;
  final double Function(int, int, String) getCellFontSize;

  const _TableGrid({
    required this.scale,
    required this.columns,
    required this.rows,
    required this.headerFontSize,
    required this.getCellFontSize,
  });

  static const _stroke = Color(0x801D293D);
  static const _firstColColor = Color(0xFFD5DCFF);
  static const _otherColColor = Color(0xFFCAD5E2);
  static const _checkColor = Color(0xFF37F08E);
  static const _white = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final colCount = columns.length;

    return Column(
      children: [
        // Header row
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: columns.asMap().entries.map((entry) {
              final i = entry.key;
              final col = entry.value;
              final isLast = i == colCount - 1;
              return Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 28 * scale,
                    vertical: 16 * scale,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: _stroke, width: 1 * scale),
                      right: isLast ? BorderSide.none : BorderSide(color: _stroke, width: 1 * scale),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      col,
                      style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.w400,
                        color: _white,
                        fontFamily: 'Nunito Sans',
                        height: 1.2,
                      ),
                      textAlign: TextAlign.left,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Data rows
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final rowHeight = constraints.maxHeight / rows.length;
              return Column(
                children: rows.asMap().entries.map((entry) {
                  final rowIdx = entry.key;
                  final row = entry.value;
                  final isLastRow = rowIdx == rows.length - 1;
                  return SizedBox(
                    height: rowHeight,
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: row.asMap().entries.map((cellEntry) {
                          final colIdx = cellEntry.key;
                          final cell = cellEntry.value;
                          final isLastCol = colIdx == colCount - 1;
                          final isFirstCol = colIdx == 0;
                          final isCheck = !isFirstCol && cell.toLowerCase() == 'check';

                          return Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 28 * scale,
                                vertical: 14 * scale,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: isLastRow ? BorderSide.none : BorderSide(color: _stroke, width: 1 * scale),
                                  right: isLastCol ? BorderSide.none : BorderSide(color: _stroke, width: 1 * scale),
                                ),
                              ),
                              child: Center(
                                child: isCheck
                                    ? // Check mark: 26px green, centered
                                      Icon(
                                        Icons.check,
                                        size: 26 * scale,
                                        color: _checkColor,
                                      )
                                    : // Normal text
                                      Text(
                                        cell,
                                        style: TextStyle(
                                          fontSize: getCellFontSize(colCount, rows.length, cell),
                                          fontWeight: FontWeight.w400,
                                          color: isFirstCol ? _firstColColor : _otherColColor,
                                          fontFamily: 'Nunito Sans',
                                          height: 1.3,
                                        ),
                                        textAlign: TextAlign.left,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}