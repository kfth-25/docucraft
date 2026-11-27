// DocuCraft — Cards Grid Template (Flutter-native)
// 1:1 dengan CardsGridSlide.tsx (Presenton Code theme)
// Design space 1280×720 (sama dengan TSX)
//
// Tema code:
//   - Background #101B37 (navy gelap)
//   - Font: Nunito Sans
//   - Card: #0F172B80, Stroke: #1D293D80
//   - Primary: #2B7FFF33 (icon badge bg), #2B7FFF4D (border)
//   - Text: #f2f4ff (title), #ffffff (card title), #90A1B9 (desc)
//
// Tata letak:
//   p-[53px] container
//   Title: 64px font-medium tracking-[-0.03em] #f2f4ff
//   Grid: mt-[26px] grid-cols-3 gap-[26px]
//     6 cards: rounded-[18px] border p-[26px] shadow
//       Row: title 26px + icon circle 52px (border #2B7FFF4D bg #2B7FFF33)
//       Desc: mt-[12px] 18px lh 136% #90A1B9

import 'package:flutter/material.dart';

class CardsGridTemplate extends StatelessWidget {
  final String title;
  final List<Map<String, String>> features; // [{title, description}]

  const CardsGridTemplate({
    super.key,
    this.title = 'Feature Grid',
    this.features = const [],
  });

  // ── Code theme colors ──
  static const _bg = Color(0xFF101B37);
  static const _card = Color(0x800F172B); // #0F172B80
  static const _stroke = Color(0x801D293D); // #1D293D80
  static const _title = Color(0xFFF2F4FF);
  static const _cardTitle = Color(0xFFFFFFFF);
  static const _desc = Color(0xFF90A1B9);
  static const _badgeBg = Color(0x332B7FFF); // #2B7FFF33
  static const _badgeBorder = Color(0x4D2B7FFF); // #2B7FFF4D

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Scale dari design space 1280×720 (sama dengan TSX)
      final s = constraints.maxWidth / 1280;
      final pad = 53 * s; // p-[53px]

      // Grid: 3 col × gap 26px, content W = 1280 - 106 = 1174
      final gridW = 1280 - 106; // 1174
      final cardW = (gridW - 2 * 26) / 3; // (1174-52)/3 = 374
      final cardH = 170.0; // diperkirakan dari isi card (title 26 + desc 18×1.36×3)

      final displayFeatures = features.length > 6 ? features.sublist(0, 6) : features;

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // ── Background ──
          Positioned.fill(
            child: Container(color: _bg),
          ),

          // ── Container p-[53px] ──
          Positioned(
            left: pad,
            right: pad,
            top: pad,
            bottom: pad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title: 64px font-medium tracking-[-0.03em] ──
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 64 * s,
                    fontWeight: FontWeight.w500,
                    color: _title,
                    letterSpacing: -0.03 * 64 * s, // tracking-[-0.03em]
                  ),
                ),

                SizedBox(height: 26 * s), // mt-[26px]

                // ── Grid: grid-cols-3 gap-[26px] ──
                Expanded(
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 26 * s,
                      crossAxisSpacing: 26 * s,
                      childAspectRatio: cardW / cardH,
                    ),
                    itemCount: displayFeatures.length,
                    itemBuilder: (context, i) => _buildCard(displayFeatures[i], s),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  /// Card: rounded-[18px] border p-[26px] shadow
  Widget _buildCard(Map<String, String> feature, double s) {
    return Container(
      padding: EdgeInsets.all(26 * s), // p-[26px]
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18 * s), // rounded-[18px]
        border: Border.all(color: _stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 66.667 * s,
            offset: Offset(0, 33.333 * s),
            spreadRadius: -16 * s,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: title + icon circle
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title: 26px font-medium
              Expanded(
                child: Text(
                  feature['title'] ?? '',
                  style: TextStyle(
                    fontSize: 26 * s,
                    fontWeight: FontWeight.w500,
                    color: _cardTitle,
                  ),
                ),
              ),
              SizedBox(width: 8 * s), // gap-[8px]
              // Icon circle: w-[52px] h-[52px] rounded-full border
              Container(
                width: 52 * s,
                height: 52 * s,
                decoration: BoxDecoration(
                  color: _badgeBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: _badgeBorder),
                ),
                child: Center(
                  child: Icon(
                    Icons.check_rounded,
                    size: 24 * s, // h-[24px]
                    color: const Color(0xFFFFFFFF),
                  ),
                ),
              ),
            ],
          ),
          // Desc: mt-[12px] 18px lh 136%
          Padding(
            padding: EdgeInsets.only(top: 12 * s), // mt-[12px]
            child: Text(
              feature['description'] ?? '',
              style: TextStyle(
                fontSize: 18 * s,
                color: _desc,
                height: 1.36, // leading-[136%]
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}