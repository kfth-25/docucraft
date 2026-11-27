// DocuCraft — Code Explanation Split Template (Flutter-native)
// 1:1 dengan CodeExplanationSplitSlide.tsx (Presenton Code theme)
// Design space 1280×720 (sama dengan TSX)
//
// Tata letak:
//   p-[53px] container
//   Title: 64px font-medium lh 105% #ffffff
//   Grid: mt-[22px] grid-cols-2 gap-[34px]
//     Left: code card rounded-[18px] border bg #0F172B80
//       Header: rounded-t-[18px] px-[26px] py-3 bg #0F172BCC
//         fileName 18px #CAD5E2
//       Code: px-[32px] py-[20px] teks putih, tipografi hasil fit
//     Right: description title 24px + paragraph 22px lh 145%

import 'package:flutter/material.dart';
import 'code_block_fitting.dart';

class CodeExplanationSplitTemplate extends StatelessWidget {
  final String title;
  final String codeFileName;
  final String codeLanguage;
  final String codeContent;
  final String descriptionTitle;
  final String description;

  const CodeExplanationSplitTemplate({
    super.key,
    this.title = 'Code Breakdown',
    this.codeFileName = 'services/createPresentation.ts',
    this.codeLanguage = 'typescript',
    this.codeContent = '',
    this.descriptionTitle = 'Description',
    this.description = '',
  });

  // ── Code theme colors ──
  static const _bg = Color(0xFF101B37);
  static const _cardBg = Color(0x800F172B); // #0F172B80
  static const _headerBg = Color(0xCC0F172B); // #0F172BCC
  static const _stroke = Color(0x801D293D);
  static const _title = Color(0xFFFFFFFF);
  static const _headerText = Color(0xFFCAD5E2);
  static const _descTitle = Color(0xFFF1F4FF);
  static const _descText = Color(0xFFD2D9FF);
  static const _codeText = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Scale dari design space 1280×720 (sama dengan TSX)
      final s = constraints.maxWidth / 1280;
      final pad = 53 * s; // p-[53px]

      // Fit code
      final fittedCode = fitCodeBlock(FitCodeBlockOptions(
        language: codeLanguage,
        content: codeContent,
        maxWidth: 506,
        maxHeight: 408,
        maxFontSize: 16,
        minFontSize: 6,
        lineHeightRatio: 1.18,
      ));

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
                // ── Title: 64px font-medium lh 105% ──
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 64 * s,
                    fontWeight: FontWeight.w500,
                    color: _title,
                    height: 1.05,
                  ),
                ),

                // ── Grid: mt-[22px] grid-cols-2 gap-[34px] ──
                Padding(
                  padding: EdgeInsets.only(top: 22 * s),
                  child: Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Left: code card ──
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: _cardBg,
                              borderRadius: BorderRadius.circular(18 * s),
                              border: Border.all(color: _stroke),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // File name header
                                Container(
                                  padding: EdgeInsets.fromLTRB(26 * s, 12 * s, 26 * s, 12 * s),
                                  decoration: BoxDecoration(
                                    color: _headerBg,
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(18 * s)),
                                    border: Border(bottom: BorderSide(color: _stroke)),
                                  ),
                                  child: Text(
                                    codeFileName,
                                    style: TextStyle(
                                      fontSize: 18 * s,
                                      color: _headerText,
                                    ),
                                  ),
                                ),
                                // Code content
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(32 * s, 20 * s, 32 * s, 20 * s),
                                    child: SingleChildScrollView(
                                      child: Text(
                                        fittedCode.text,
                                        style: TextStyle(
                                          color: _codeText,
                                          fontFamily: fittedCode.fontFamily,
                                          fontSize: fittedCode.fontSize,
                                          height: fittedCode.lineHeight / fittedCode.fontSize,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(width: 34 * s), // gap-[34px]

                        // ── Right: description ──
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Description title: 24px font-medium
                              Text(
                                descriptionTitle,
                                style: TextStyle(
                                  fontSize: 24 * s,
                                  fontWeight: FontWeight.w500,
                                  color: _descTitle,
                                ),
                              ),
                              // Description: mt-[18px] 22px lh 145%
                              Padding(
                                padding: EdgeInsets.only(top: 18 * s),
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
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}
