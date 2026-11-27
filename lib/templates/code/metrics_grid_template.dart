// DocuCraft — Metrics Grid Template (Flutter-native)
// 1:1 dengan MetricsGridSlide.tsx (Presenton Code theme)
// Design space 1280×720 (sama dengan TSX)
//
// Tata letak:
//   Container: rounded-[24px] border p-[40px] borderColor #243272
//   Title: 64px font-medium #ffffff
//   Grid: mt-[53px] grid-cols-3 gap-[14px]
//     6 metric cards: rounded-[16px] border bg #0F172B80
//       value: 64px font-semibold #8bb4ff
//       label: 26px #edf1ff
//       subtext: 18px #8fa2d8

import 'package:flutter/material.dart';

class MetricsGridTemplate extends StatelessWidget {
  final String title;
  final List<Map<String, String>> metrics;

  const MetricsGridTemplate({
    super.key,
    this.title = 'Metrics',
    this.metrics = const [],
  });

  static const _bg = Color(0xFF101B37);
  static const _border = Color(0xFF243272);
  static const _title = Color(0xFFFFFFFF);
  static const _cardBg = Color(0x800F172B);
  static const _cardBorder = Color(0x801D293D);
  static const _metricValue = Color(0xFF8BB4FF);
  static const _metricLabel = Color(0xFFEDF1FF);
  static const _metricSub = Color(0xFF8FA2D8);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final s = constraints.maxWidth / 1280;
      final displayMetrics = metrics.length > 6 ? metrics.sublist(0, 6) : metrics;

      return Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(24 * s),
          border: Border.all(color: _border),
        ),
        padding: EdgeInsets.all(40 * s), // p-[40px]
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title: 64px font-medium #ffffff
            Text(title, style: TextStyle(fontSize: 64 * s, fontWeight: FontWeight.w500, color: _title)),
            SizedBox(height: 53 * s), // mt-[53px]
            // Grid: grid-cols-3 gap-[14px]
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 14 * s,
                crossAxisSpacing: 14 * s,
                childAspectRatio: 1.8,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final m in displayMetrics)
                    Container(
                      padding: EdgeInsets.fromLTRB(26 * s, 26 * s, 26 * s, 16 * s),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(16 * s),
                        border: Border.all(color: _cardBorder),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(m['value'] ?? '', style: TextStyle(fontSize: 64 * s, fontWeight: FontWeight.w600, color: _metricValue, height: 1)),
                          SizedBox(height: 13 * s),
                          Text(m['label'] ?? '', style: TextStyle(fontSize: 26 * s, color: _metricLabel)),
                          SizedBox(height: 13 * s),
                          Text(m['subtext'] ?? '', style: TextStyle(fontSize: 18 * s, color: _metricSub)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
