// DocuCraft — Code Output Template (Flutter-native)
// 1:1 dengan CodeOutputSlide.tsx (Presenton Code theme)
// Design space 1280×720 (sama dengan TSX)
//
// Tata letak:
//   p-[53px] container
//   Title: 50px font-medium lh 105% #ffffff
//   Summary: mt-[10px] 20px lh 135% max-w-[1050px] #CAD5E2
//   Grid: mt-[20px] grid-cols-[1.15fr_0.85fr] gap-[22px]
//     Left: CodeBlockPanel (code) — maxWidth 616, maxHeight 298
//     Right: CodeBlockPanel (output) — maxWidth 440, maxHeight 298
//   Insight: mt-[18px] rounded-[14px] border bg #2B7FFF1F border #2B7FFF66 text #d2d9ff

import 'package:flutter/material.dart';
import 'code_block_panel.dart';

class CodeOutputTemplate extends StatelessWidget {
  final String title;
  final String summary;
  final String codeLabel;
  final String codeLanguage;
  final String codeFileName;
  final String codeContent;
  final String outputLabel;
  final String outputLanguage;
  final String outputContent;
  final String insight;

  const CodeOutputTemplate({
    super.key,
    this.title = 'Code to Output',
    this.summary = 'This slide shows how the implementation transforms input data into output.',
    this.codeLabel = 'Code',
    this.codeLanguage = 'typescript',
    this.codeFileName = 'transform.ts',
    this.codeContent = '',
    this.outputLabel = 'Output',
    this.outputLanguage = 'json',
    this.outputContent = '',
    this.insight = '',
  });

  static const _bg = Color(0xFF101B37);
  static const _title = Color(0xFFFFFFFF);
  static const _summary = Color(0xFFCAD5E2);
  static const _insightBg = Color(0x1F2B7FFF);
  static const _insightBorder = Color(0x662B7FFF);
  static const _insightText = Color(0xFFD2D9FF);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final s = constraints.maxWidth / 1280;
      final pad = 53 * s;

      // Grid: 1.15fr : 0.85fr → left ≈ 674, right ≈ 500
      // Grid: 1.15fr : 0.85fr → left ≈ 674, right ≈ 500

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(child: Container(color: _bg)),

          Positioned(
            left: pad, right: pad, top: pad, bottom: pad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title: 50px font-medium lh 105%
                Text(title, style: TextStyle(fontSize: 50 * s, fontWeight: FontWeight.w500, color: _title, height: 1.05)),

                // Summary: mt-[10px] 20px lh 135% max-w-[1050px]
                Padding(
                  padding: EdgeInsets.only(top: 10 * s),
                  child: SizedBox(
                    width: 1050 * s,
                    child: Text(summary, style: TextStyle(fontSize: 20 * s, color: _summary, height: 1.35)),
                  ),
                ),

                // Grid: mt-[20px] 1.15fr / 0.85fr gap-[22px]
                Padding(
                  padding: EdgeInsets.only(top: 20 * s),
                  child: Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left: Code (1.15fr)
                        Expanded(
                          flex: 115,
                          child: CodeBlockPanel(
                            title: codeLabel,
                            fileName: codeFileName,
                            language: codeLanguage,
                            content: codeContent,
                            maxWidth: 616,
                            maxHeight: 298,
                            maxFontSize: 13,
                            minFontSize: 6,
                          ),
                        ),
                        SizedBox(width: 22 * s),
                        // Right: Output (0.85fr)
                        Expanded(
                          flex: 85,
                          child: CodeBlockPanel(
                            title: outputLabel,
                            language: outputLanguage,
                            content: outputContent,
                            maxWidth: 440,
                            maxHeight: 298,
                            maxFontSize: 13,
                            minFontSize: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Insight note: mt-[18px] rounded-[14px]
                Padding(
                  padding: EdgeInsets.only(top: 18 * s),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 22 * s, vertical: 15 * s),
                    decoration: BoxDecoration(
                      color: _insightBg,
                      borderRadius: BorderRadius.circular(14 * s),
                      border: Border.all(color: _insightBorder),
                    ),
                    child: Text(insight, style: TextStyle(fontSize: 19 * s, color: _insightText, height: 1.3)),
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
