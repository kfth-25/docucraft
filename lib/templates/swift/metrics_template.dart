// DocuCraft — Metrics Numbers Template (Flutter-native)
// 1:1 dengan MetricsNumbers.tsx (Presenton)
// Design space 1280×720 (sama dengan TSX)
//
// Tata letak:
//   Header: px-12 pt-6 pb-2 → diamond 12px + gap-3
//   Garis pemisah: absolute top-0 left-1/2 w-[1px] h-full rgba(0,0,0,0.1)
//   Grid: px-12 pt-3 grid-cols-[42%_58%] gap-8 items-start
//     Kiri: title 48px semibold lh 1.1 max-w-420 + mt-8 lingkaran 20px + leftTitle 20px + mt-5 body 16px lh 1.8 max-w-360
//     Kanan (relative):
//       Lingkaran dekorasi: absolute top-6 -right-24 w-[220px] h-[220px] rounded-full border rgba(0,0,0,0.2)
//       3 kartu: flex-col gap-6 → rounded-[18px] px-6 py-5 grid-cols-[38%_62%] shadow
//         Nilai 40px + line1 16px w600 + line2 (-mt-1) + desc mt-3 12px lh 1.6
//   Footer: bottom-8 left-12 right-12 → website 14px + ml-6 line 2px #111827
//   Diamond besar: bottom-7 right-6 w-8 h-8 rotate-45

import 'package:flutter/material.dart';

class MetricsTemplate extends StatelessWidget {
  final String title;
  final String leftTitle;
  final String leftBody;
  final List<Map<String, String>> metrics;
  final String website;
  final String companyName;

  const MetricsTemplate({
    super.key,
    this.title = 'Our Impact in Numbers',
    this.leftTitle = 'Proven Results\nThrough Data',
    this.leftBody = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    this.metrics = const [],
    this.website = 'www.yourwebsite.com',
    this.companyName = '',
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Scale dari design space 1280×720 (sama dengan TSX)
      final s = constraints.maxWidth / 1280;
      final displayMetrics = metrics.length > 3 ? metrics.sublist(0, 3) : metrics;

      // Grid dimensions: px-12(48), pt-3(12), 42%/58%, gap-8(32)
      // Header: pt-6(24) + diamond(12) + pb-2(8) = 44px
      // Grid y = 44 + pt-3(12) = 56
      final contentW = 1280 - 96; // 1184
      final leftW = contentW * 0.42; // 497
      final rightX = 48 + leftW + 32; // 48+497+32 = 577
      final rightW = contentW - leftW - 32; // 655

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

        // ── Separator line: absolute top-0 left-1/2 w-[1px] h-full ──
        Positioned(
          left: 640 * s, // left-1/2
          top: 0,
          width: 1 * s,
          height: 720 * s,
          child: Container(color: const Color(0x1A000000)), // rgba(0,0,0,0.1)
        ),

        // ── Grid: px-12 pt-3 grid-cols-[42%_58%] gap-8 ──
        // y = 56, left=48, leftW=497, gap=32, rightX=577, rightW=655

        // ── Left: title + circle + leftTitle + body ──
        // Title: 48px semibold lh 1.1, max-w-[420px]
        Positioned(
          left: 48 * s,
          top: 56 * s, // grid pt-3
          width: 420 * s,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 48 * s,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111827),
              height: 1.1,
            ),
          ),
        ),

        // Circle (w-5 h-5 = 20px) + leftTitle (text-[20px]) + mt-8
        // mt-8 = 32px dari title bottom (56 + 48×1.1 = 56+53 = 109 → 109+32 = 141)
        Positioned(
          left: 48 * s,
          top: 168 * s, // 109+32(gap)+27(circle half)
          child: Row(
            children: [
              Container(
                width: 20 * s,
                height: 20 * s,
                decoration: const BoxDecoration(color: Color(0xFF111827), shape: BoxShape.circle),
              ),
              SizedBox(width: 12 * s), // gap-3
              SizedBox(
                width: 380 * s, // sisa dari leftW - circle - gap
                child: Text(
                  leftTitle,
                  style: TextStyle(
                    fontSize: 20 * s,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Left body: mt-5 = 20px dari leftTitle bottom
        // y = 168 + 20(circle) + 20(leftTitle) + 20(mt-5) = ~228
        Positioned(
          left: 48 * s,
          top: 248 * s, // 168+20+20+20+20
          width: 360 * s, // max-w-[360px]
          child: Text(
            leftBody,
            style: TextStyle(
              fontSize: 16 * s,
              color: const Color(0xFF6B7280),
              height: 1.8,
            ),
          ),
        ),

        // ── Right (relative): deco circle + metric cards ──

        // Deco circle: absolute top-6 -right-24 → top=24, right=-96 dari kanan grid
        // rightX = 577, rightW = 655 → circle posisi x = rightX+rightW+96-220 = 577+655+96-220 = 1108
        // tapi -right-24 = -96 dari kanan → x = 1280-96-220 = 964
        Positioned(
          left: 964 * s,
          top: 80 * s, // top-6 = 24 → 24 + 56(grid top) = 80
          width: 220 * s,
          height: 220 * s,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x33000000), width: 1), // rgba(0,0,0,0.2)
            ),
          ),
        ),

        // 3 metric cards: flex-col gap-6 (24px)
        // Grid right col mulai: y=56, card mulai di bawah deco circle
        // Card 1: y=56, h=~140, gap=24
        for (var i = 0; i < displayMetrics.length; i++)
          Positioned(
            left: rightX * s, // 577
            top: (56 + i * 184) * s, // gap 160(card)+24(gap)=184
            width: rightW * s, // 655
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 24 * s, vertical: 20 * s), // px-6 py-5
              decoration: BoxDecoration(
                color: const Color(0xFFBFF4FF),
                borderRadius: BorderRadius.circular(18 * s),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 40 * s,
                    offset: Offset(0, 16 * s),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Value 40px: 38% dari card width
                  SizedBox(
                    width: rightW * 0.38 * s,
                    child: Text(
                      displayMetrics[i]['value'] ?? '',
                      style: TextStyle(
                        fontSize: 40 * s,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                  // 62%: line1 + line2(-mt-1) + desc(mt-3)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayMetrics[i]['line1'] ?? '',
                          style: TextStyle(
                            fontSize: 16 * s,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        if ((displayMetrics[i]['line2'] ?? '').isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: -4 * s), // -mt-1
                            child: Text(
                              displayMetrics[i]['line2'] ?? '',
                              style: TextStyle(
                                fontSize: 16 * s,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ),
                        SizedBox(height: 12 * s), // mt-3
                        Text(
                          displayMetrics[i]['description'] ?? '',
                          style: TextStyle(
                            fontSize: 12 * s,
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
