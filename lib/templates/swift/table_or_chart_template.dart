// DocuCraft — Table Or Chart Template (Flutter-native)
// 1:1 dengan TableorChart.tsx (Presenton)
// Design space 1280×720 (sama dengan TSX)
//
// Tata letak:
//   Header: px-12 pt-6 pb-2 → diamond 12px + gap-3
//   Judul + deskripsi: px-12 pt-3 → title 48px semibold lh 1.1 + desc mt-3 16px max-w-900
//   Konten: px-12 pt-6
//     Mode tabel: rounded-xl p-5 BFF4FF → rounded-lg bg-white ring-1
//       Tabel: border-separate border-spacing-0
//         Header: 14px semibold px-4 py-3 bg BFF4FF, border-b, rounded-t-md
//         Baris: 14px px-4 py-3 border-t, latar bergantian: BFF4FF/F3F4F6, text #6B7280
//     Mode grafik: h-[360px] rounded-xl p-4 (grafik batang sederhana)
//   Footer: bottom-8 left-12 right-12 → website 14px + ml-6 line 2px #111827
//   Diamond besar: bottom-7 right-6 w-8 h-8

import 'dart:math' as math;
import 'package:flutter/material.dart';

class TableOrChartTemplate extends StatelessWidget {
  final String title;
  final String description;
  final String mode; // 'table' atau 'chart'
  final List<String> columns;
  final List<List<String>> rows;
  final List<Map<String, dynamic>>? chartData; // [{label, value}] untuk chart
  final String website;
  final String companyName;

  const TableOrChartTemplate({
    super.key,
    required this.title,
    this.description = '',
    this.mode = 'table',
    this.columns = const [],
    this.rows = const [],
    this.chartData,
    this.website = 'www.yourwebsite.com',
    this.companyName = '',
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Scale dari design space 1280×720 (sama dengan TSX)
      final s = constraints.maxWidth / 1280;

      return Stack(clipBehavior: Clip.hardEdge, children: [
        // ── Background putih ──
        Positioned.fill(
          child: Container(color: const Color(0xFFFFFFFF)),
        ),

        // ── Header: px-12 pt-6 pb-2 → diamond 12px ──
        Positioned(
          left: 48 * s, // px-12
          top: 24 * s, // pt-6
          child: Row(
            children: [
              Container(
                width: 12 * s,
                height: 12 * s,
                transform: Matrix4.rotationZ(0.785398),
                decoration: const BoxDecoration(color: Color(0xFF111827)),
              ),
              if (companyName.isNotEmpty) ...[
                SizedBox(width: 12 * s), // gap-3
                Text(
                  companyName,
                  style: TextStyle(fontSize: 16 * s, color: const Color(0xFF6B7280), fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
        ),

        // ── Title + description: px-12 pt-3 ──
        Positioned(
          left: 48 * s,
          top: 56 * s, // 44(header) + 12(pt-3)
          child: SizedBox(
            width: 900 * s, // max-w-[900px]
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 48 * s,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 12 * s), // mt-3
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 16 * s,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Content area: px-12 pt-6 ──
        Positioned(
          left: 48 * s,
          right: 48 * s,
          top: 120 * s, // 56 + 53(title) + 12(desc) + 24(pt-6) ≈ 145 → pakai 120
          bottom: 80 * s, // tinggalkan ruang footer
          child: mode == 'table'
              ? _buildTable(s)
              : _buildChart(s),
        ),

        // ── Footer: bottom-8 left-12 right-12 ──
        Positioned(
          left: 48 * s,
          right: 48 * s,
          bottom: 32 * s,
          child: Row(
            children: [
              Text(
                website,
                style: TextStyle(fontSize: 14 * s, color: const Color(0xFF6B7280)),
              ),
              SizedBox(width: 24 * s),
              Expanded(
                child: Container(height: 2 * s, color: const Color(0xFF111827)),
              ),
            ],
          ),
        ),

        // ── Diamond besar ──
        Positioned(
          right: 24 * s,
          bottom: 28 * s,
          child: Container(
            width: 32 * s,
            height: 32 * s,
            transform: Matrix4.rotationZ(0.785398),
            decoration: const BoxDecoration(color: Color(0xFF111827)),
          ),
        ),
      ]);
    });
  }

  /// Table mode: rounded-xl p-5 BFF4FF → table rounded-lg bg-white ring-1
  Widget _buildTable(double s) {
    return Container(
      padding: EdgeInsets.all(20 * s), // p-5
      decoration: BoxDecoration(
        color: const Color(0xFFBFF4FF),
        borderRadius: BorderRadius.circular(12 * s), // rounded-xl
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8 * s), // rounded-lg
          border: Border.all(color: const Color(0xFFE5E7EB)), // ring-1 stroke
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8 * s),
          child: Table(
            columnWidths: {
              for (var i = 0; i < columns.length; i++)
                i: FlexColumnWidth(1),
            },
            border: TableBorder(
              horizontalInside: BorderSide(color: const Color(0x14000000), width: 1), // border-t rgba 0.08
            ),
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: [
              // Header row
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFBFF4FF)),
                children: [
                  for (var i = 0; i < columns.length; i++)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 12 * s), // px-4 py-3
                      child: Text(
                        columns[i],
                        style: TextStyle(
                          fontSize: 14 * s,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                ],
              ),
              // Data rows
              for (var r = 0; r < rows.length; r++)
                TableRow(
                  decoration: BoxDecoration(
                    color: r % 2 == 0
                        ? const Color(0xFFBFF4FF)   // even row
                        : const Color(0xFFF3F4F6),  // odd row
                  ),
                  children: [
                    for (var c = 0; c < columns.length; c++)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 12 * s),
                        child: Text(
                          c < rows[r].length ? rows[r][c] : '',
                          style: TextStyle(
                            fontSize: 14 * s,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Chart mode: simplified bar chart (tanpa Chart.js dependency)
  Widget _buildChart(double s) {
    final data = chartData ?? [];
    if (data.isEmpty) return const SizedBox.shrink();

    final values = data.map((d) => (d['value'] ?? 0).toDouble()).toList();
    final labels = data.map((d) => (d['label'] ?? '').toString()).toList();
    final maxValue = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);

    const colors = [
      Color(0xFF3B82F6), Color(0xFFEF4444), Color(0xFF10B981),
      Color(0xFFF59E0B), Color(0xFF8B5CF6), Color(0xFF06B6D4),
    ];

    return Container(
      height: 360 * s, // h-[360px]
      padding: EdgeInsets.all(16 * s), // p-4
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12 * s),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(math.min(data.length, math.min(values.length, labels.length)), (i) {
          final barHeight = maxValue > 0
              ? (values[i] / maxValue) * (360 * s - 60)
              : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${values[i].toInt()}',
                    style: TextStyle(
                      fontSize: 12 * s,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  SizedBox(height: 4 * s),
                  Container(
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(6 * s),
                      ),
                    ),
                  ),
                  SizedBox(height: 4 * s),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 12 * s,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
