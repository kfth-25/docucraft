// DocuCraft — Bullets With Icons Template (Flutter-native)
// 1:1 dengan BulletsWithIconsTitleDescription.tsx (Presenton)
// Design space 1280×720 (sama dengan TSX)
//
// Tata letak:
//   Header: px-12 pt-6 pb-2 → diamond 12px + gap-3
//   Grid: px-12 pt-2 grid-cols-[1.2fr_1fr] gap-10
//     Kiri: title 56px semibold lh 1.05
//     Kanan: sideHeading 16px mb-2 semibold + sideParagraph 14px lh 1.6
//   Baris ikon: px-12 pt-12, auto-cols-[260px] gap-8 justify-center
//     4 lingkaran 160×160 rounded-full shadow, icon 56px, title 16px mt-5, desc 13px mt-2
//   Footer: bottom-8 left-12 right-12 → website 14px + ml-6 line flex-1
//   Diamond besar: bottom-7 right-6 w-8 h-8 rotate-45

import 'package:flutter/material.dart';
import '../icon_mapper.dart';

class BulletsWithIconsTemplate extends StatelessWidget {
  final String title;
  final String sideHeading;
  final String sideParagraph;
  final List<Map<String, String>> points;
  final String website;
  final String companyName;

  const BulletsWithIconsTemplate({
    super.key,
    this.title = 'Our Infographic',
    this.sideHeading = 'Lorem ipsum dolor sit amet,',
    this.sideParagraph =
        'Concise paragraph describing context. Keep it short and readable across one or two lines.',
    this.points = const [],
    this.website = 'www.yourwebsite.com',
    this.companyName = '',
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Scale dari design space 1280×720 (sama dengan TSX)
      final s = constraints.maxWidth / 1280;

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // ── Background putih ──
          Positioned.fill(
            child: Container(color: const Color(0xFFFFFFFF)),
          ),

          // ── Header: px-12 pt-6 pb-2 ──
          Positioned(
            left: 48 * s, // px-12
            top: 24 * s, // pt-6
            child: Row(
              children: [
                // Diamond 12×12 rotate-45
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
                    style: TextStyle(
                      fontSize: 16 * s,
                      color: const Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Grid: px-12 pt-2 grid-cols-[1.2fr_1fr] gap-10 ──
          // Header tinggi: pt-6(24) + diamond(12) + pb-2(8) = 44px
          // Grid mulai: 44 + pt-2(8) = 52px
          Positioned(
            left: 48 * s, // px-12
            top: 52 * s,
            right: 48 * s,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Left: title 56px ──
                // 1.2fr / (1.2fr + 1fr) = 1.2/2.2 = 54.5% dari content width
                Expanded(
                  flex: 12,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 56 * s,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                      height: 1.05,
                    ),
                  ),
                ),
                SizedBox(width: 40 * s), // gap-10
                // ── Right: sideHeading + sideParagraph ──
                Expanded(
                  flex: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sideHeading.isNotEmpty)
                        Text(
                          sideHeading,
                          style: TextStyle(
                            fontSize: 16 * s,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      if (sideHeading.isNotEmpty && sideParagraph.isNotEmpty)
                        SizedBox(height: 8 * s), // mb-2
                      if (sideParagraph.isNotEmpty)
                        Text(
                          sideParagraph,
                          style: TextStyle(
                            fontSize: 14 * s,
                            color: const Color(0xFF6B7280),
                            height: 1.6,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Icons row: px-12 pt-12, auto-cols-[260px] gap-8 justify-center ──
          // Grid bottom = 52 + 16 (title 56px×1.05) + 8 + 40 (desc) + 48 (pt-12) = ~552
          // Mulai icons: 52 + 60(title) + 8(mb) + 56(para) + 48(pt-12) = ~552
          Positioned(
            left: 48 * s, // px-12
            right: 48 * s,
            top: 340 * s,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                (points.length > 4 ? 4 : points.length),
                (i) => Container(
                  width: 260 * s, // auto-cols-[260px]
                  margin: EdgeInsets.symmetric(horizontal: 16 * s), // gap-8
                  child: Column(
                    children: [
                      // Circle 160×160 rounded-full shadow
                      Container(
                        width: 160 * s,
                        height: 160 * s,
                        decoration: BoxDecoration(
                          color: const Color(0xFFBFF4FF),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 20 * s,
                              offset: Offset(0, 8 * s),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            TemplateIconMapper.iconFor(points[i]['icon']),
                            size: 56 * s,
                            color: TemplateIconMapper.colorFor(points[i]['icon']),
                          ),
                        ),
                      ),
                      SizedBox(height: 20 * s), // mt-5
                      Text(
                        points[i]['title'] ?? '',
                        style: TextStyle(
                          fontSize: 16 * s,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8 * s), // mt-2
                      Text(
                        points[i]['description'] ?? '',
                        style: TextStyle(
                          fontSize: 13 * s,
                          color: const Color(0xFF6B7280),
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Footer: absolute bottom-8 left-12 right-12 ──
          Positioned(
            left: 48 * s, // left-12
            right: 48 * s, // right-12
            bottom: 32 * s, // bottom-8
            child: Row(
              children: [
                Text(
                  website,
                  style: TextStyle(
                    fontSize: 14 * s,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                SizedBox(width: 24 * s), // ml-6
                Expanded(
                  child: Container(
                    height: 2 * s, // h-[2px]
                    color: const Color(0xFF111827), // bg #111827
                  ),
                ),
              ],
            ),
          ),

          // ── Diamond besar: bottom-7 right-6 w-8 h-8 rotate-45 ──
          Positioned(
            right: 24 * s, // right-6
            bottom: 28 * s, // bottom-7
            child: Container(
              width: 32 * s,
              height: 32 * s,
              transform: Matrix4.rotationZ(0.785398),
              decoration: const BoxDecoration(color: Color(0xFF111827)),
            ),
          ),
        ],
      );
    });
  }
}
