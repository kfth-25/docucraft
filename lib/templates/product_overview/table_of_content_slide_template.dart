// DocuCraft — Table of Content Slide Template (Flutter-native)
// 1:1 dengan TableOfContentSlide.tsx (Presenton ProductOverview)
// Design space 1280×720 (sama dengan TSX)
//
// Tata letak:
//   Grid 2 kolom: 1fr 1fr (h-full)
//   Left panel (bg gelap): px-56 pt-50
//     - Sections list: space-y-28 (jika >3) / space-y-40 (jika ≤3)
//     - Item: flex items-center gap-4 justify-between
//       Title: text-20 font-semibold tracking-[0.2em] #ecf2f1
//       Desc (mt-6): text-18 leading-1.2 #ecf2f1
//       Number: text-22 font-medium #ecf2f1
//   Right panel: px-42 pt-118
//     Title: text-80 font-semibold leading-108.4% tracking-[-2.419px] #15342D
//     Description (mt-28): w-560 text-24 #15342DCC

import 'package:flutter/material.dart';

class TableOfContentSlideTemplate extends StatelessWidget {
  final String title;
  final String description;
  final List<Map<String, String>> sections; // [{title, number, description}]
  final String fontFamily;

  const TableOfContentSlideTemplate({
    super.key,
    this.title = 'Table Of Content',
    this.description = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore.',
    this.sections = const [],
    this.fontFamily = 'Bricolage Grotesque',
  });

  static const _leftBg = Color(0xFF05463D); // PRODUCT_DARK
  static const _rightBg = Color(0xFFD7DDDD); // PRODUCT_BG
  static const _textLight = Color(0xFFECF2F1); // primary-text
  static const _textDark = Color(0xFF15342D); // primary-color
  static const _textDarkMuted = Color(0xCC15342D); // background-text with alpha

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Scale dari design space 1280×720
      final s = constraints.maxWidth / 1280;
      final maxSections = sections.length > 6 ? sections.sublist(0, 6) : sections;
      final useTightSpacing = maxSections.length > 3;

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // ── Background kanan (light) ──
          Positioned.fill(
            child: Container(color: _rightBg),
          ),

          // ── Grid 2 kolom 1fr 1fr ──
          Row(
            children: [
              // ── Left panel (dark) ──
              Expanded(
                child: Container(
                  color: _leftBg,
                  padding: EdgeInsets.only(
                    left: 56 * s,
                    right: 56 * s,
                    top: 50 * s,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: maxSections.asMap().entries.map((entry) {
                      final i = entry.key;
                      final section = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: i == maxSections.length - 1 ? 0 : (useTightSpacing ? 28 : 40) * s,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title & Description
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    section['title'] ?? '',
                                    style: TextStyle(
                                      fontSize: 20 * s,
                                      fontWeight: FontWeight.w600, // font-semibold
                                      color: _textLight,
                                      letterSpacing: 0.2 * 20 * s, // tracking-[0.2em]
                                      height: 1.0,
                                    ),
                                  ),
                                  if ((section['description'] ?? '').isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(top: 6 * s), // mt-6
                                      child: Text(
                                        section['description'] ?? '',
                                        style: TextStyle(
                                          fontSize: 18 * s,
                                          color: _textLight,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Number
                            Text(
                              section['number'] ?? (i + 1).toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 22 * s,
                                fontWeight: FontWeight.w500, // font-medium
                                color: _textLight,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // ── Right panel (light) ──
              Expanded(
                child: Container(
                  color: _rightBg,
                  padding: EdgeInsets.only(
                    left: 42 * s,
                    right: 42 * s,
                    top: 118 * s,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title: text-80 font-semibold leading-108.4% tracking-[-2.419px]
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 80 * s,
                          fontWeight: FontWeight.w600,
                          color: _textDark,
                          height: 1.084, // 108.4%
                          letterSpacing: -2.419 * s,
                        ),
                      ),
                      // Description: mt-28 w-560 text-24
                      Padding(
                        padding: EdgeInsets.only(top: 28 * s),
                        child: SizedBox(
                          width: 560 * s,
                          child: Text(
                            description,
                            style: TextStyle(
                              fontSize: 24 * s,
                              fontWeight: FontWeight.w400,
                              color: _textDarkMuted,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    });
  }
}