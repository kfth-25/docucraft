// DocuCraft — Intro Slide Template (Flutter-native)
// Render layout 1:1 dengan IntroSlideLayout.tsx (Presenton).
//
// Design space 1280x720 (sama dengan TSX):
//   - Latar putih #FFFFFF
//   - Header: px-12 pt-6 → diamond 12px + gap-3
//   - Konten grid: grid-cols-[58%_42%] gap-10 px-12 pt-4
//     - Judul 64px semibold lh 1.05 (pt-4 di dalam kolom)
//     - Paragraf mt-5 16px #6B7280 lh 1.6 max-w-620
//     - Kartu intro mt-6: border 1px #BFF4FF + bg #BFF4FF rounded-sm
//       accent 8x24 + name 16px semibold + date 14px
//   - Panel kanan: absolute top-0 right-0 w-[36%] h-[520px]
//   - Diamond vertikal: absolute top-8 right-[38%] flex-col gap-3 (3x 12px)
//   - Footer: absolute bottom-8 left-12 right-12 → website 14px + ml-6 line flex-1
//   - Diamond besar: absolute bottom-7 right-6 w-8 h-8 rotate-45

import 'package:flutter/material.dart';

class IntroSlideTemplate extends StatelessWidget {
  final String title;
  final String paragraph;
  final String companyName;
  final String website;
  final String cardName;
  final String cardDate;
  final String imageUrl;
  final bool introCardEnabled;

  const IntroSlideTemplate({
    super.key,
    required this.title,
    required this.paragraph,
    required this.companyName,
    required this.website,
    required this.cardName,
    required this.cardDate,
    required this.imageUrl,
    this.introCardEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Scale tunggal dari design space 1280x720 (TSX)
      final s = constraints.maxWidth / 1280;

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // ── Background putih ──
          Positioned.fill(
            child: Container(color: const Color(0xFFFFFFFF)),
          ),

          // ── Right panel image: top-0 right-0 w-[36%] h-[520px] ──
          Positioned(
            right: 0,
            top: 0,
            width: 1280 * 0.36 * s, // 36% dari 1280
            height: 520 * s, // h-[520px]
            child: imageUrl.startsWith('http')
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Color(0xFFF3F4F6),
                      child: Center(
                        child: Icon(Icons.image, color: Color(0xFFD1D5DB), size: 64),
                      ),
                    ),
                  )
                : const ColoredBox(
                    color: Color(0xFFF3F4F6),
                    child: Center(
                      child: Icon(Icons.image, color: Color(0xFFD1D5DB), size: 64),
                    ),
                  ),
          ),

          // ── Header: px-12 pt-6 → diamond 12px + gap-3 + company name ──
          Positioned(
            left: 48 * s, // px-12
            top: 24 * s, // pt-6
            child: Row(
              children: [
                Container(
                  width: 12 * s,
                  height: 12 * s,
                  transform: Matrix4.rotationZ(0.785398), // 45°
                  decoration: const BoxDecoration(color: Color(0xFF111827)),
                ),
                SizedBox(width: 12 * s), // gap-3
                if (companyName.isNotEmpty)
                  Text(
                    companyName,
                    style: TextStyle(
                      fontSize: 16 * s,
                      color: const Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),

          // ── Vertical diamonds: top-8 right-[38%] flex-col gap-3 ──
          // right 38% dari 1280 = 486.4 → left = 1280 - 486.4 - 12 = 781.6
          for (var i = 0; i < 3; i++)
            Positioned(
              left: (1280 - 1280 * 0.38 - 12) * s,
              top: (32 + i * 12) * s, // top-8 = 32px, gap-3 = 12px
              child: Container(
                width: 12 * s,
                height: 12 * s,
                transform: Matrix4.rotationZ(0.785398), // 45°
                decoration: const BoxDecoration(color: Color(0xFF111827)),
              ),
            ),

          // ── Content (mirror grid-cols-[58%_42%] gap-10 px-12 pt-4) ──
          // Header tinggi: pt-6(24) + diamond(12) + pb-2(8) = 44px
          // Content mulai: 44 + pt-4(16) = 60px
          Positioned(
            left: 48 * s, // px-12
            top: 60 * s,
            width: (1280 - 96 - 40) * 0.58 * s, // 58% dari grid
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title: pt-4 dalam grid child + 64px ──
                Padding(
                  padding: EdgeInsets.only(top: 16 * s),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 64 * s,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                      height: 1.05,
                      letterSpacing: -0.02 * s, // tracking-tight
                    ),
                  ),
                ),

                // ── Paragraph: mt-5 ──
                Padding(
                  padding: EdgeInsets.only(top: 20 * s),
                  child: Text(
                    paragraph,
                    style: TextStyle(
                      fontSize: 16 * s,
                      color: const Color(0xFF6B7280),
                      height: 1.6,
                    ),
                  ),
                ),

                // ── Intro card: mt-6 inline-flex border rounded-sm ──
                if (introCardEnabled)
                  Padding(
                    padding: EdgeInsets.only(top: 24 * s),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 12 * s), // px-4 py-3
                      decoration: BoxDecoration(
                        color: const Color(0xFFBFF4FF),
                        border: Border.all(color: const Color(0xFFBFF4FF)), // border 1px
                        borderRadius: BorderRadius.circular(2 * s), // rounded-sm
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Accent bar w-2 h-6
                          Container(
                            width: 8 * s,
                            height: 24 * s,
                            decoration: const BoxDecoration(color: Color(0xFF111827)),
                          ),
                          SizedBox(width: 16 * s), // gap-4
                          // Name + date (items-baseline gap-3)
                          Text(
                            cardName,
                            style: TextStyle(
                              fontSize: 16 * s,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          SizedBox(width: 12 * s), // gap-3
                          Text(
                            cardDate,
                            style: TextStyle(
                              fontSize: 14 * s,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
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
                    color: const Color(0xFFE5E7EB), // bg E5E7EB
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
