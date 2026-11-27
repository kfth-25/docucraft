// DocuCraft — Timeline Template (Flutter-native)
// 1:1 dengan Timeline.tsx (Presenton)
// Design space 1280×720 (sama dengan TSX)
//
// Tata letak:
//   Header: px-12 pt-6 pb-2 → diamond 12px + gap-3
//   Diamond kanan: absolute top-16 right-6 flex-col gap-3 (3x 12px)
//   Judul: px-12 pt-3 flex-col items-center → 48px semibold center
//   Banner subjudul: mt-5 max-w-[720px] rounded-md border px-6 py-3 bg BFF4FF
//   Timeline: px-12 pt-10
//     Garis tengah: absolute left-12 right-12 top-1/2 h-[4px] BFF4FF
//     Kartu: flex justify-center gap-10
//       Badge tahun: mb-2 px-5 py-2 rounded-md #111827 teks putih
//       Titik: w-5 h-5 rounded-full border-4 BFF4FF latar putih
//       Kartu: mt-4 rounded-[16px] shadow px-6 pt-6 pb-5 w-[260px] text-center
//         Lingkaran ikon: mx-auto w-12 h-12 rounded-full BFF4FF mb-4
//         Judul: text-[18px] semibold
//         Isi: mt-3 text-[14px]
//   Footer: bottom-8 left-12 right-12 → website 14px + ml-6 line 2px #111827
//   Diamond besar: bottom-7 right-6 w-8 h-8

import 'package:flutter/material.dart';
import '../icon_mapper.dart';

class TimelineTemplate extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Map<String, String>> events; // [{year, heading, body, icon}]
  final String website;
  final String companyName;

  const TimelineTemplate({
    super.key,
    required this.title,
    required this.subtitle,
    this.events = const [],
    this.website = 'www.yourwebsite.com',
    this.companyName = '',
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Scale dari design space 1280×720 (sama dengan TSX)
      final s = constraints.maxWidth / 1280;
      final displayEvents = events.length > 4 ? events.sublist(0, 4) : events;

      // Timeline block: px-12 pt-10 → y = 44(header) + 12(pt-3) + 53(title) + 20(mt-5) + 44(banner) + 40(pt-10) = ~213
      // Center line: top-1/2 dari timeline block → y = 213 + 150 = ~363
      // Card: mt-4 → dot(20) + badge(36) + mb-2(8) + card(16) = ~80 dari line center
      final timelineTop = 213.0;
      final lineY = timelineTop + 150; // top-1/2 area timeline

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

        // ── Right diamonds: absolute top-16 right-6 flex-col gap-3 ──
        for (var i = 0; i < 3; i++)
          Positioned(
            right: 24 * s, // right-6
            top: (64 + i * 12) * s, // top-16(64) + gap-3(12)
            child: Container(
              width: 12 * s,
              height: 12 * s,
              transform: Matrix4.rotationZ(0.785398),
              decoration: const BoxDecoration(color: Color(0xFF111827)),
            ),
          ),

        // ── Title: px-12 pt-3 flex-col items-center ──
        Positioned(
          left: 48 * s,
          right: 48 * s,
          top: 56 * s, // 44 + 12(pt-3)
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 48 * s,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111827),
              height: 1.1,
            ),
          ),
        ),

        // ── Subtitle banner: mt-5 max-w-[720px] rounded-md border px-6 py-3 ──
        Positioned(
          left: (1280 - 720) / 2 * s, // center, max-w-720
          top: (56 + 53 + 20) * s, // title bottom + mt-5
          width: 720 * s,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24 * s, vertical: 12 * s), // px-6 py-3
            decoration: BoxDecoration(
              color: const Color(0xFFBFF4FF),
              border: Border.all(color: const Color(0x40000000)), // rgba(0,0,0,0.25)
              borderRadius: BorderRadius.circular(6 * s), // rounded-md
            ),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16 * s, color: const Color(0xFF6B7280)),
            ),
          ),
        ),

        // ── Timeline line: absolute left-12 right-12 top-1/2 h-[4px] ──
        Positioned(
          left: 48 * s, // left-12
          right: 48 * s, // right-12
          top: lineY * s,
          child: Container(height: 4 * s, color: const Color(0xFFBFF4FF)),
        ),

        // ── Timeline cards: flex justify-center gap-10 ──
        // Card width 260px, gap 40px, center: (4×260 + 3×40)=1160 → x0=(1280-1160)/2=60
        for (var i = 0; i < displayEvents.length; i++)
          Positioned(
            left: (60 + i * 300) * s, // 260 + 40 gap
            top: (lineY - 60) * s, // badge + dot di atas line
            width: 260 * s,
            child: Column(
              children: [
                // Year badge: mb-2 px-5 py-2 rounded-md
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 8 * s), // px-5 py-2
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(6 * s), // rounded-md
                  ),
                  child: Text(
                    displayEvents[i]['year'] ?? '',
                    style: TextStyle(
                      fontSize: 16 * s,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFFFFFF),
                    ),
                  ),
                ),
                SizedBox(height: 8 * s), // mb-2
                // Connector dot: w-5 h-5 rounded-full border-4
                Container(
                  width: 20 * s, // w-5
                  height: 20 * s, // h-5
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFBFF4FF), width: 4 * s),
                  ),
                ),
                SizedBox(height: 16 * s), // mt-4
                // Card: rounded-[16px] shadow px-6 pt-6 pb-5 w-[260px] text-center
                Container(
                  width: 260 * s,
                  padding: EdgeInsets.fromLTRB(
                    24 * s, // px-6
                    24 * s, // pt-6
                    24 * s,
                    20 * s, // pb-5
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(16 * s),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 40 * s,
                        offset: Offset(0, 16 * s),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Icon circle: mx-auto w-12 h-12 rounded-full mb-4
                      Container(
                        width: 48 * s,
                        height: 48 * s,
                        decoration: const BoxDecoration(
                          color: Color(0xFFBFF4FF),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            TemplateIconMapper.iconFor(displayEvents[i]['icon']),
                            size: 24 * s,
                            color: TemplateIconMapper.colorFor(displayEvents[i]['icon']),
                          ),
                        ),
                      ),
                      SizedBox(height: 16 * s), // mb-4
                      Text(
                        displayEvents[i]['heading'] ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18 * s,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 12 * s), // mt-3
                      Text(
                        displayEvents[i]['body'] ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14 * s,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
              SizedBox(width: 24 * s), // ml-6
              Expanded(
                child: Container(height: 2 * s, color: const Color(0xFF111827)),
              ),
            ],
          ),
        ),

        // ── Diamond besar: bottom-7 right-6 w-8 h-8 ──
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
}
