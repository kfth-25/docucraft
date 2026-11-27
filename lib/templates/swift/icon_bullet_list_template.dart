// DocuCraft — Icon Bullet List Template (Flutter-native)
// 1:1 dengan IconBulletListDescription.tsx (Presenton)
// Design space 1280×720 (sama dengan TSX)
//
// Tata letak:
//   Header: px-12 pt-6 pb-2 → diamond 12px
//   Judul + deskripsi: px-12 pt-3, title 48px semibold lh 1.1, desc mt-3 16px max-w-760
//   Pita cyan: absolute left-0 right-0 bottom-20 h-[160px] #BFF4FF
//   Kartu fitur: relative px-12 mt-8, auto-cols-[260px] gap-6 justify-center
//     Kartu: rounded-[22px] shadow, bg #BFF4FF, px-6 py-5
//       Kotak ikon: w-10 h-10 rounded-sm bg white, icon 24px
//       Judul: mt-4 text-[18px] semibold
//       Isi: mt-3 text-[14px] lh 1.7
//   Footer: bottom-8 left-12 right-12, website 14px + ml-6 line flex-1
//   Diamond besar: bottom-7 right-6 w-8 h-8

import 'package:flutter/material.dart';
import '../icon_mapper.dart';

class IconBulletListTemplate extends StatelessWidget {
  final String title;
  final String description;
  final List<Map<String, String>> features;
  final String website;
  final String companyName;

  const IconBulletListTemplate({
    super.key,
    required this.title,
    required this.description,
    this.features = const [],
    this.website = 'www.yourwebsite.com',
    this.companyName = '',
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Scale dari design space 1280×720 (sama dengan TSX)
      final s = constraints.maxWidth / 1280;
      final displayFeatures = features.length > 4 ? features.sublist(0, 4) : features;

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
        // Header: 24+12+8 = 44px, pt-3 = 12px → y=56
        Positioned(
          left: 48 * s, // px-12
          top: 56 * s,
          child: SizedBox(
            width: 760 * s, // max-w-[760px]
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
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Cyan band: absolute left-0 right-0 bottom-20 h-[160px] ──
        Positioned(
          left: 0,
          right: 0,
          bottom: 80 * s, // bottom-20 = 80px
          height: 160 * s, // h-[160px]
          child: Container(color: const Color(0xFFBFF4FF)),
        ),

        // ── Feature cards: relative px-12 mt-8 auto-cols-[260px] gap-6 justify-center ──
        // Setelah title + desc: y = 56 + 53(title) + 12(mt) + 26(desc) + 32(mt-8) = ~56+53+12+26+32 = 179
        // Tapi TSX punya position relative, jadi letakkan dari bawah title
        // Mulai cards: 56 + (48*1.1=53) + 12 + (16*1.6=26) + 32(mt-8) = ~56+53+12+26+32 = 179 → pakai y = 300
        Positioned(
          left: 48 * s, // px-12
          right: 48 * s,
          top: 200 * s, // di bawah title+desc
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(displayFeatures.length, (i) {
              return Container(
                width: 260 * s, // auto-cols-[260px]
                margin: EdgeInsets.symmetric(horizontal: 12 * s), // gap-6 = 24px → 12 each side
                decoration: BoxDecoration(
                  color: const Color(0xFFBFF4FF),
                  borderRadius: BorderRadius.circular(22 * s), // rounded-[22px]
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 40 * s, // 40px blur
                      offset: Offset(0, 16 * s), // 16px offset
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24 * s, vertical: 20 * s), // px-6 py-5
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon box w-10 h-10 rounded-sm bg white
                      Container(
                        width: 40 * s, // w-10
                        height: 40 * s, // h-10
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2 * s), // rounded-sm (2px)
                        ),
                        child: Center(
                          child: Icon(
                            TemplateIconMapper.iconFor(displayFeatures[i]['icon']),
                            size: 24 * s, // w-6 h-6 = 24px
                            color: TemplateIconMapper.colorFor(displayFeatures[i]['icon']),
                          ),
                        ),
                      ),
                      SizedBox(height: 16 * s), // mt-4
                      Text(
                        displayFeatures[i]['title'] ?? '',
                        style: TextStyle(
                          fontSize: 18 * s,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 12 * s), // mt-3
                      Text(
                        displayFeatures[i]['body'] ?? '',
                        style: TextStyle(
                          fontSize: 14 * s,
                          color: const Color(0xFF6B7280),
                          height: 1.7,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }),
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

        // ── Diamond besar: bottom-7 right-6 w-8 h-8 rotate-45 ──
        Positioned(
          right: 24 * s, // right-6
          bottom: 28 * s, // bottom-7
          child: Container(
            width: 32 * s, // w-8
            height: 32 * s, // h-8
            transform: Matrix4.rotationZ(0.785398),
            decoration: const BoxDecoration(color: Color(0xFF111827)),
          ),
        ),
      ]);
    });
  }
}
