// DocuCraft — Code Block Panel (Flutter-native)
// Port dari CodeBlockPanel.tsx (Presenton Code theme)
// Widget reusable: code block dengan header bar + tipografi hasil fit
//
// Props:
//   title/judul, fileName, language, content
//   maxWidth/maxHeight: area yang tersedia
//   maxFontSize/minFontSize: range font
//   showLanguage: tampilkan badge bahasa
//   terminal: mode terminal (dot merah/kuning/hijau, bg lebih gelap)

import 'package:flutter/material.dart';
import 'code_block_fitting.dart';

class CodeBlockPanel extends StatelessWidget {
  final String? title;
  final String? fileName;
  final String? language;
  final String? content;
  final double maxWidth;
  final double maxHeight;
  final double maxFontSize;
  final double minFontSize;
  final bool showLanguage;
  final bool terminal;

  const CodeBlockPanel({
    super.key,
    this.title,
    this.fileName,
    this.language,
    this.content,
    required this.maxWidth,
    required this.maxHeight,
    this.maxFontSize = 15,
    this.minFontSize = 7,
    this.showLanguage = true,
    this.terminal = false,
  });

  // ── Code theme colors ──
  static const _cardBg = Color(0x800F172B); // #0F172B80
  static const _cardBgTerminal = Color(0xCC080D1F); // #080D1FCC
  static const _headerBg = Color(0x801D293D); // #1D293D80
  static const _headerBgTerminal = Color(0xFF0B1027); // #0B1027
  static const _stroke = Color(0x801D293D);
  static const _headerText = Color(0xFFCAD5E2);
  static const _badgeBg = Color(0x332B7FFF);
  static const _badgeText = Color(0xFF51A2FF);
  static const _codeText = Color(0xFFFFFFFF);

  // Terminal dot colors
  static const _dotRed = Color(0xFFFF5F57);
  static const _dotYellow = Color(0xFFFFBD2E);
  static const _dotGreen = Color(0xFF28C840);

  @override
  Widget build(BuildContext context) {
    // Fit code ke area
    final fittedCode = fitCodeBlock(FitCodeBlockOptions(
      language: language,
      content: content,
      maxWidth: maxWidth,
      maxHeight: maxHeight - 52, // header height
      maxFontSize: maxFontSize,
      minFontSize: minFontSize,
    ));

    final normalizedLanguage = language?.trim();
    final displayTitle = title ?? fileName ?? 'Code';

    return Container(
      decoration: BoxDecoration(
        color: terminal ? _cardBgTerminal : _cardBg,
        borderRadius: BorderRadius.circular(18 * 1.0),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header bar: h-[52px] border-b px-[22px] ──
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              color: terminal ? _headerBgTerminal : _headerBg,
              border: const Border(bottom: BorderSide(color: _stroke)),
            ),
            child: Row(
              children: [
                // Terminal dots (3 circles)
                if (terminal) ...[
                  Container(
                    width: 9, height: 9,
                    decoration: const BoxDecoration(color: _dotRed, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 9, height: 9,
                    decoration: const BoxDecoration(color: _dotYellow, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 9, height: 9,
                    decoration: const BoxDecoration(color: _dotGreen, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                ],
                // Title
                Expanded(
                  child: Text(
                    displayTitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      color: _headerText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // File name (jika ada title + fileName)
                if (fileName != null && title != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    fileName!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0x80CAD5E2), // opacity 70%
                    ),
                  ),
                ],
                // Language badge
                if (showLanguage && normalizedLanguage != null && normalizedLanguage.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _badgeBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      normalizedLanguage.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: _badgeText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Code content: px-[22px] py-[20px] ──
          Expanded(
            child: Padding(
              padding: terminal
                  ? const EdgeInsets.symmetric(horizontal: 22, vertical: 16)
                  : const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
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
    );
  }
}
