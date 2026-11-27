// DocuCraft — Code Diff Comparison Template (Flutter-native)
// 1:1 dengan CodeDiffComparisonSlide.tsx (Presenton Code theme)
// Design space 1280×720 (sama dengan TSX)
//
// Tata letak:
//   p-[53px] container
//   Title: 50px font-medium lh 105% #ffffff
//   Summary: mt-[10px] 20px lh 135% max-w-[1060px] #CAD5E2
//   Grid: mt-[18px] grid-cols-2 gap-[22px]
//     Left: CodeBlockPanel (before) — maxWidth 532, maxHeight 282
//     Right: CodeBlockPanel (after) — maxWidth 532, maxHeight 282
//   Catatan dampak: mt-[18px] rounded-[14px] border px-[22px] py-[15px]
//     19px lh 130% bg #2B7FFF1F border #2B7FFF66 text #d2d9ff

import 'package:flutter/material.dart';
import 'code_block_panel.dart';

class CodeDiffComparisonTemplate extends StatelessWidget {
  final String title;
  final String summary;
  final String beforeLabel;
  final String beforeLanguage;
  final String beforeFileName;
  final String beforeContent;
  final String afterLabel;
  final String afterLanguage;
  final String afterFileName;
  final String afterContent;
  final String impact;

  const CodeDiffComparisonTemplate({
    super.key,
    this.title = 'Before / After Refactor',
    this.summary = 'This slide compares the old implementation with the improved version.',
    this.beforeLabel = 'Before',
    this.beforeLanguage = 'tsx',
    this.beforeFileName = 'OldChart.tsx',
    this.beforeContent = '',
    this.afterLabel = 'After',
    this.afterLanguage = 'tsx',
    this.afterFileName = 'ChartRenderer.tsx',
    this.afterContent = '',
    this.impact = '',
  });

  // ── Code theme colors ──
  static const _bg = Color(0xFF101B37);
  static const _title = Color(0xFFFFFFFF);
  static const _summary = Color(0xFFCAD5E2);
  static const _impactBg = Color(0x1F2B7FFF); // #2B7FFF1F
  static const _impactBorder = Color(0x662B7FFF); // #2B7FFF66
  static const _impactText = Color(0xFFD2D9FF);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Scale dari design space 1280×720 (sama dengan TSX)
      final s = constraints.maxWidth / 1280;
      final pad = 53 * s; // p-[53px]

      // Grid col width: (1280-106-22)/2 = 576

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
                // ── Title: 50px font-medium lh 105% ──
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 50 * s,
                    fontWeight: FontWeight.w500,
                    color: _title,
                    height: 1.05,
                  ),
                ),

                // ── Summary: mt-[10px] 20px lh 135% max-w-[1060px] ──
                Padding(
                  padding: EdgeInsets.only(top: 10 * s),
                  child: SizedBox(
                    width: 1060 * s,
                    child: Text(
                      summary,
                      style: TextStyle(
                        fontSize: 20 * s,
                        color: _summary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),

                // ── Grid: mt-[18px] grid-cols-2 gap-[22px] ──
                Padding(
                  padding: EdgeInsets.only(top: 18 * s),
                  child: Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Before (left) ──
                        Expanded(
                          child: CodeBlockPanel(
                            title: beforeLabel,
                            fileName: beforeFileName,
                            language: beforeLanguage,
                            content: beforeContent,
                            maxWidth: 532,
                            maxHeight: 282,
                            maxFontSize: 13,
                            minFontSize: 6,
                          ),
                        ),

                        SizedBox(width: 22 * s), // gap-[22px]

                        // ── After (right) ──
                        Expanded(
                          child: CodeBlockPanel(
                            title: afterLabel,
                            fileName: afterFileName,
                            language: afterLanguage,
                            content: afterContent,
                            maxWidth: 532,
                            maxHeight: 282,
                            maxFontSize: 13,
                            minFontSize: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Impact note: mt-[18px] rounded-[14px] ──
                Padding(
                  padding: EdgeInsets.only(top: 18 * s),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 22 * s, vertical: 15 * s),
                    decoration: BoxDecoration(
                      color: _impactBg,
                      borderRadius: BorderRadius.circular(14 * s),
                      border: Border.all(color: _impactBorder),
                    ),
                    child: Text(
                      impact,
                      style: TextStyle(
                        fontSize: 19 * s,
                        color: _impactText,
                        height: 1.3,
                      ),
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
