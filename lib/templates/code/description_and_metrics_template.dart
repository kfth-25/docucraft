// DocuCraft — Description and Metrics Template (Flutter-native)
// 1:1 dengan DescriptionAndMetricsSlide.tsx (Presenton Code theme)
// Design space 1280×720 (sama dengan TSX)
//
// Tata letak:
//   p-[53px] container
//   Title: 64px font-medium tracking-[-0.03em] #f2f4ff
//   Content area: min-h-[520px] gap-10
//     Left (w-1/2): explanationTitle 24px + explanation 22px lh 145%
//     Right (w-1/2): grid-cols-2 gap-x-[16px] gap-y-[25px]
//       4 metric cards: rounded-[16px] border bg #0F172B80
//         value: 64px font-semibold #8bb4ff
//         label: 26px #edf1ff
//         subtext: 18px #8fa2d8

import 'package:flutter/material.dart';

class DescriptionAndMetricsTemplate extends StatelessWidget {
  final String title;
  final String explanationTitle;
  final String explanation;
  final List<Map<String, String>> metrics; // [{value, label, subtext}]

  const DescriptionAndMetricsTemplate({
    super.key,
    this.title = 'Metrics',
    this.explanationTitle = 'Explanation',
    this.explanation = '',
    this.metrics = const [],
  });

  static const _bg = Color(0xFF101B37);
  static const _title = Color(0xFFF2F4FF);
  static const _descTitle = Color(0xFFF1F4FF);
  static const _descText = Color(0xFFD2D9FF);
  static const _cardBg = Color(0x800F172B);
  static const _stroke = Color(0x801D293D);
  static const _metricValue = Color(0xFF8BB4FF);
  static const _metricLabel = Color(0xFFEDF1FF);
  static const _metricSub = Color(0xFF8FA2D8);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final s = constraints.maxWidth / 1280;
      final pad = 53 * s;
      final displayMetrics = metrics.length > 4 ? metrics.sublist(0, 4) : metrics;

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(child: Container(color: _bg)),

          Positioned(
            left: pad, right: pad, top: pad, bottom: pad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title: 64px font-medium tracking-[-0.03em]
                Text(title, style: TextStyle(fontSize: 64 * s, fontWeight: FontWeight.w500, color: _title, letterSpacing: -0.03 * 64 * s)),

                SizedBox(height: 12 * s),

                // Content: min-h-[520px] gap-10
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left (w-1/2): explanation
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(explanationTitle, style: TextStyle(fontSize: 24 * s, fontWeight: FontWeight.w500, color: _descTitle)),
                            SizedBox(height: 16 * s),
                            Text(explanation, style: TextStyle(fontSize: 22 * s, color: _descText, height: 1.45)),
                          ],
                        ),
                      ),

                      SizedBox(width: 40 * s), // gap-10

                      // Right (w-1/2): metrics grid
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 25 * s,
                          crossAxisSpacing: 16 * s,
                          childAspectRatio: 280 / 130,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (final m in displayMetrics)
                              Container(
                                padding: EdgeInsets.fromLTRB(26 * s, 26 * s, 26 * s, 16 * s),
                                decoration: BoxDecoration(
                                  color: _cardBg,
                                  borderRadius: BorderRadius.circular(16 * s),
                                  border: Border.all(color: _stroke),
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
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}
