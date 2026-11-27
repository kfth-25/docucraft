// DocuCraft — Description Text Template (Flutter-native)
// 1:1 dengan DescriptionTextSlide.tsx (Presenton Code theme)
// Design space 1280×720 (sama dengan TSX)
//
// Tata letak:
//   p-[53px] container
//   Title: 64px font-medium #f2f4ff
//   Content: max-w-[560px]
//     descriptionTitle: mt-[34px] 24px font-medium #f1f4ff
//     description: mt-[16px] 22px lh 145% #d2d9ff

import 'package:flutter/material.dart';

class DescriptionTextTemplate extends StatelessWidget {
  final String title;
  final String descriptionTitle;
  final String description;

  const DescriptionTextTemplate({
    super.key,
    this.title = 'Code + Explanation',
    this.descriptionTitle = 'Explanation',
    this.description = '',
  });

  static const _bg = Color(0xFF101B37);
  static const _title = Color(0xFFF2F4FF);
  static const _descTitle = Color(0xFFF1F4FF);
  static const _descText = Color(0xFFD2D9FF);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final s = constraints.maxWidth / 1280;
      final pad = 53 * s;

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Background
          Positioned.fill(child: Container(color: _bg)),

          // Content
          Positioned(
            left: pad,
            right: pad,
            top: pad,
            bottom: pad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title: 64px font-medium
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 64 * s,
                    fontWeight: FontWeight.w500,
                    color: _title,
                  ),
                ),

                // Content wrapper: max-w-[560px]
                Container(
                  constraints: BoxConstraints(maxWidth: 560 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description title: mt-[34px] 24px font-medium
                      Padding(
                        padding: EdgeInsets.only(top: 34 * s),
                        child: Text(
                          descriptionTitle,
                          style: TextStyle(
                            fontSize: 24 * s,
                            fontWeight: FontWeight.w500,
                            color: _descTitle,
                          ),
                        ),
                      ),

                      // Description: mt-[16px] 22px lh 145%
                      Padding(
                        padding: EdgeInsets.only(top: 16 * s),
                        child: Text(
                          description,
                          style: TextStyle(
                            fontSize: 22 * s,
                            color: _descText,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
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
