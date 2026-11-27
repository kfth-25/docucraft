// DocuCraft — Simple Bullet Points Template (Flutter-native)
// 1:1 dengan SimpleBulletPointsLayout.tsx (Presenton)
// Design space 1280×720 (sama dengan TSX)
//
// Tata letak:
//   Header: px-12 pt-6 pb-2 → diamond 12px + gap-3
//   Motif halus: absolute left-1/2 -translate-x-1/2 bottom-[140px] w-[900px] h-[260px] radial-gradient
//   Grid: px-12 pt-4 grid-cols-[48%_52%] gap-10 items-start
//     Kiri: title 56px semibold lh 1.05 + mt-10 statement 16px lh 1.8 max-w-520
//     Kanan: flex flex-col gap-6 → point title 24px semibold + mt-3 body 16px lh 1.8
//   Footer: bottom-8 left-12 right-12 → website 14px + ml-6 line 2px #111827
//   Diamond besar: bottom-7 right-6 w-8 h-8

import 'package:flutter/material.dart';

class SimpleBulletPointsTemplate extends StatelessWidget {
  final String title;
  final String statement;
  final List<Map<String, String>> points;
  final String website;

  const SimpleBulletPointsTemplate({
    super.key,
    required this.title,
    required this.statement,
    this.points = const [],
    this.website = 'www.yourwebsite.com',
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Scale dari design space 1280×720 (sama dengan TSX)
      final s = constraints.maxWidth / 1280;

      // Grid dimensions
      // Header: 24+12+8=44px, pt-4=16px → grid y=60
      // 48%/52% dari (1280-96)=1184 → leftW=568, gap=40, rightX=568+40+48=656
      final contentW = 1280 - 96; // 1184
      final leftW = contentW * 0.48; // 568
      final gap = 40.0; // gap-10
      final rightX = 48 + leftW + gap; // 656
      final rightW = contentW - leftW - gap; // 576

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
            ],
          ),
        ),

        // ── Subtle motif: absolute left-1/2 -translate-x-1/2 bottom-[140px] w-[900px] h-[260px] ──
        Positioned(
          left: (1280 / 2 - 450) * s, // left-1/2 - w/2
          bottom: 140 * s, // bottom-[140px]
          width: 900 * s,
          height: 260 * s,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF111827).withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  radius: 0.7,
                ),
              ),
            ),
          ),
        ),

        // ── Grid: px-12 pt-4 grid-cols-[48%_52%] gap-10 items-start ──
        // Grid y = 44(header) + 16(pt-4) = 60

        // ── Left: title + statement ──
        Positioned(
          left: 48 * s, // px-12
          top: 60 * s,
          width: leftW * s,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 56 * s, // text-[56px]
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111827),
                  height: 1.05,
                ),
              ),
              SizedBox(height: 40 * s), // mt-10
              SizedBox(
                width: 520 * s, // max-w-[520px]
                child: Text(
                  statement,
                  style: TextStyle(
                    fontSize: 16 * s, // text-[16px]
                    color: const Color(0xFF6B7280),
                    height: 1.8,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Right: points flex-col gap-6 ──
        Positioned(
          left: rightX * s,
          top: 60 * s,
          width: rightW * s,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              points.length > 4 ? 4 : points.length,
              (i) => Padding(
                padding: EdgeInsets.only(bottom: i < 3 ? 24 * s : 0), // gap-6
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      points[i]['title'] ?? '',
                      style: TextStyle(
                        fontSize: 24 * s, // text-[24px]
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 12 * s), // mt-3
                    Text(
                      points[i]['body'] ?? '',
                      style: TextStyle(
                        fontSize: 16 * s, // text-[16px]
                        color: const Color(0xFF6B7280),
                        height: 1.8,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
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
