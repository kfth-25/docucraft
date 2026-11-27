// DocuCraft — Full Code Block Template (Flutter-native)
// 1:1 dengan FullCodeBlockSlide.tsx (Presenton Code theme)
// Design space 1280×720 (sama dengan TSX)
//
// Tata letak:
//   p-[53px] container
//   Title: 52px font-medium lh 105% #ffffff
//   Description: mt-[12px] 21px lh 135% max-w-[980px] #CAD5E2
//   Code block: mt-[22px] flex-1
//     CodeBlockPanel: maxWidth 1130, maxHeight 404, maxFS 15, minFS 6

import 'package:flutter/material.dart';
import 'code_block_panel.dart';

class FullCodeBlockTemplate extends StatelessWidget {
  final String title;
  final String description;
  final String codeLanguage;
  final String codeFileName;
  final String codeContent;

  const FullCodeBlockTemplate({
    super.key,
    this.title = 'Core Implementation',
    this.description = '',
    this.codeLanguage = 'typescript',
    this.codeFileName = 'src/services/renderSlide.ts',
    this.codeContent = '',
  });

  static const _bg = Color(0xFF101B37);
  static const _title = Color(0xFFFFFFFF);
  static const _desc = Color(0xFFCAD5E2);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final s = constraints.maxWidth / 1280;
      final pad = 53 * s;

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(child: Container(color: _bg)),

          Positioned(
            left: pad, right: pad, top: pad, bottom: pad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title: 52px font-medium lh 105%
                Text(title, style: TextStyle(fontSize: 52 * s, fontWeight: FontWeight.w500, color: _title, height: 1.05)),

                // Description: mt-[12px] 21px lh 135% max-w-[980px]
                Padding(
                  padding: EdgeInsets.only(top: 12 * s),
                  child: SizedBox(
                    width: 980 * s,
                    child: Text(description, style: TextStyle(fontSize: 21 * s, color: _desc, height: 1.35)),
                  ),
                ),

                // Code block: mt-[22px] flex-1
                Padding(
                  padding: EdgeInsets.only(top: 22 * s),
                  child: Expanded(
                    child: CodeBlockPanel(
                      title: codeFileName,
                      language: codeLanguage,
                      content: codeContent,
                      maxWidth: 1130,
                      maxHeight: 404,
                      maxFontSize: 15,
                      minFontSize: 6,
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
