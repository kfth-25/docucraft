// DocuCraft — Table of Contents Template (Flutter-native)
// 1:1 dengan TableOfContents.tsx (Presenton)
// Design space 1280×720 (sama dengan TSX)
//
// Tata letak:
//   Header: px-12 pt-6 pb-2 → diamond 12px + gap-3
//   Judul: px-12 pt-3 → 48px semibold lh 1.1
//   Daftar: px-12 pt-8 grid grid-cols-2 gap-x-12 gap-y-6 max-w-[1180px]
//     Item: flex items-start gap-6
//       Nomor: 48px w600 leading-none #BFF4FF (padStart 2 digits)
//       Konten: min-w-0 flex-1 pt-1
//         Judul: 22px w600 lh 1.2
//         Deskripsi (mt-2): 14px lh 1.6 #6B7280
//       Pemisah: mt-4 h-px #E5E7EB
//   Footer: bottom-8 left-12 right-12 → website 14px + ml-6 line 2px #111827
//   Diamond besar: bottom-7 right-6 w-8 h-8

import 'package:flutter/material.dart';

class TableOfContentsTemplate extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Map<String, String>> items; // [{title, description}]
  final String website;
  final String companyName;

  const TableOfContentsTemplate({
    super.key,
    this.title = 'Table of Contents',
    this.subtitle = '',
    this.items = const [],
    this.website = 'www.yourwebsite.com',
    this.companyName = '',
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Scale dari design space 1280×720 (sama dengan TSX)
      final s = constraints.maxWidth / 1280;
      final displayItems = items.length > 10 ? items.sublist(0, 10) : items;

      // Grid: px-12 pt-8, grid-cols-2 gap-x-12(48) gap-y-6(24) max-w-[1180px]
      // Header: 24+12+8=44, pt-3=12 → title y=56
      // Title h ≈ 48×1.1 = 53 → list y = 56+53+pt-8(32) = 141
      // 2 kolom: contentW = 1180, colW = (1180-48)/2 = 566
      // col1 x=48, col2 x=48+566+48=662
      final contentW = 1180.0;
      final colW = (contentW - 48) / 2; // 566
      final col2X = 48 + colW + 48; // 662

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

        // ── Title: px-12 pt-3 → 48px semibold lh 1.1 ──
        Positioned(
          left: 48 * s, // px-12
          top: 56 * s, // 44 + pt-3(12)
          child: Text(
            title,
            style: TextStyle(
              fontSize: 48 * s,
              fontWeight: FontWeight.w600, // font-semibold (bukan w700!)
              color: const Color(0xFF111827),
              height: 1.1,
            ),
          ),
        ),

        // ── List: px-12 pt-8 grid-cols-2 gap-x-12 gap-y-6 ──
        // y = 56 + 53(title) + 32(pt-8) = 141
        for (var i = 0; i < displayItems.length; i++)
          Positioned(
            left: (i % 2 == 0 ? 48 : col2X) * s,
            top: (141 + (i ~/ 2) * 90) * s, // rowH: 24(title)+32(desc)+16(divider)+24(gap) ≈ 90
            width: colW * s,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Number: 48px w600 leading-none #BFF4FF
                    SizedBox(
                      width: 64 * s, // space untuk 2 digit 48px
                      child: Text(
                        (i + 1).toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 48 * s,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFBFF4FF),
                          height: 1, // leading-none
                        ),
                      ),
                    ),
                    SizedBox(width: 24 * s), // gap-6
                    // Content: min-w-0 flex-1 pt-1
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 4 * s), // pt-1
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayItems[i]['title'] ?? '',
                              style: TextStyle(
                                fontSize: 22 * s, // text-[22px]
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF111827),
                                height: 1.2,
                              ),
                            ),
                            if ((displayItems[i]['description'] ?? '').isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: 8 * s), // mt-2
                                child: Text(
                                  displayItems[i]['description'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14 * s, // text-[14px]
                                    color: const Color(0xFF6B7280),
                                    height: 1.6,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16 * s), // mt-4
                Container(
                  height: 1 * s, // h-px
                  color: const Color(0xFFE5E7EB), // stroke
                ),
              ],
            ),
          ),

        // ── Footer: bottom-8 left-12 right-12 ──
        Positioned(
          left: 48 * s, // left-12
          right: 48 * s, // right-12
          bottom: 32 * s, // bottom-8
          child: Row(
            children: [
              Text(
                website,
                style: TextStyle(fontSize: 14 * s, color: const Color(0xFF6B7280)),
              ),
              SizedBox(width: 24 * s), // ml-6
              Expanded(
                child: Container(
                  height: 2 * s, // h-[2px]
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),

        // ── Diamond besar: bottom-7 right-6 w-8 h-8 ──
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
      ]);
    });
  }
}
