// DocuCraft — Cover Slide Template (Flutter-native)
// 1:1 dengan CoverSlide.tsx (Presenton Code theme)
// Design space 1280×720 (sama dengan TSX)
//
// Tata letak:
//   p-[53px] container
//   Konten terpusat (flex-col items-center justify-center px-[200px] text-center)
//     companyName: 22px #d7dcff
//     title: mt-[10px] 64px font-medium #ffffff
//     subtitle: mt-[35px] 26px lh 132% #d8ddff

import 'package:flutter/material.dart';

class CoverSlideTemplate extends StatelessWidget {
  final String companyName;
  final String title;
  final String subtitle;

  const CoverSlideTemplate({
    super.key,
    this.companyName = 'COMPANY NAME',
    this.title = 'Development Roadmap',
    this.subtitle = 'We transform ideas into market-ready solutions through systematic development processes.',
  });

  static const _bg = Color(0xFF101B37);
  static const _company = Color(0xFFD7DCFF);
  static const _title = Color(0xFFFFFFFF);
  static const _subtitle = Color(0xFFD8DDFF);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final s = constraints.maxWidth / 1280;
      final pad = 53 * s;

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // ── Background ──
          Positioned.fill(child: Container(color: _bg)),

          // ── Centered content ──
          Positioned(
            left: pad + 200 * s,
            right: pad + 200 * s,
            top: pad,
            bottom: pad,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Company name: 22px #d7dcff
                Text(
                  companyName,
                  style: TextStyle(fontSize: 22 * s, color: _company),
                  textAlign: TextAlign.center,
                ),

                // Title: mt-[10px] 64px font-medium #ffffff
                Padding(
                  padding: EdgeInsets.only(top: 10 * s),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 64 * s,
                      fontWeight: FontWeight.w500,
                      color: _title,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Subtitle: mt-[35px] 26px lh 132% #d8ddff
                Padding(
                  padding: EdgeInsets.only(top: 35 * s),
                  child: SizedBox(
                    width: 700 * s,
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 26 * s,
                        color: _subtitle,
                        height: 1.32,
                      ),
                      textAlign: TextAlign.center,
                    ),
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
