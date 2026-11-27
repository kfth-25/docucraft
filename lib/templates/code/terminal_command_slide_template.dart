// DocuCraft — Terminal Command Slide Template (Flutter-native, Code theme)
// 1:1 dengan TerminalCommandSlide.tsx (Presenton Code theme)
// Design space 1280×720 (sama dengan TSX)
//
// Tata letak:
//   Container: p-53px, bg #101B37, font Nunito Sans
//   Title: 52px font-medium leading-105% #ffffff
//   Description: mt-12px max-w-1120px 21px leading-135% #CAD5E2
//   Terminal Block: mt-24px flex-1 min-h-0
//     CodeBlockPanel (terminal mode):
//       maxWidth: 1130, maxHeight: 248
//       maxFontSize: 16, minFontSize: 5
//       lineHeightRatio: 1.12
//       label: "Terminal" (default)
//       commands: multi-baris bash
//   Note: mt-18px rounded-14px border px-20 py-14 19px leading-130%
//     bg #0F172B80, border #1D293D80, text #d2d9ff

import 'package:flutter/material.dart';
import 'code_block_panel.dart';

class CodeTerminalCommandSlideTemplate extends StatelessWidget {
  final String title;
  final String description;
  final String terminalLabel;
  final String terminalCommands;
  final String note;

  const CodeTerminalCommandSlideTemplate({
    super.key,
    this.title = 'Local Development Setup',
    this.description = 'Run these commands to start the application locally with Docker.',
    this.terminalLabel = 'Terminal',
    this.terminalCommands = 'pnpm install\npnpm dev',
    this.note = 'The application should be available after the containers finish booting.',
  });

  static const _bg = Color(0xFF101B37);
  static const _titleColor = Color(0xFFFFFFFF);
  static const _descColor = Color(0xFFCAD5E2);
  static const _noteBg = Color(0x800F172B); // #0F172B80
  static const _noteBorder = Color(0x801D293D); // #1D293D80
  static const _noteText = Color(0xFFD2D9FF);

  // Terminal block constants
  static const _terminalMaxWidth = 1130.0;
  static const _terminalMaxHeight = 248.0;
  static const _terminalMaxFontSize = 16.0;
  static const _terminalMinFontSize = 5.0;
  // lineHeightRatio (1.12) passed to CodeBlockPanel

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final s = constraints.maxWidth / 1280;

      return Container(
        width: constraints.maxWidth,
        height: constraints.maxWidth * 720 / 1280,
        color: _bg,
        padding: EdgeInsets.all(53 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title: 52px font-medium leading-105% #ffffff
            Text(
              title,
              style: TextStyle(
                fontSize: 52 * s,
                fontWeight: FontWeight.w500,
                color: _titleColor,
                fontFamily: 'Nunito Sans',
                height: 1.05,
              ),
            ),
            // Description: mt-12px max-w-1120px 21px leading-135% #CAD5E2
            SizedBox(height: 12 * s),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 1120 * s),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 21 * s,
                  fontWeight: FontWeight.w400,
                  color: _descColor,
                  fontFamily: 'Nunito Sans',
                  height: 1.35,
                ),
              ),
            ),
            // Terminal Block: mt-24px flex-1 min-h-0
            SizedBox(height: 24 * s),
            Expanded(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: _terminalMaxWidth * s,
                  maxHeight: _terminalMaxHeight * s,
                ),
                child: CodeBlockPanel(
                  title: terminalLabel,
                  language: 'bash',
                  content: terminalCommands,
                  maxWidth: _terminalMaxWidth * s,
                  maxHeight: _terminalMaxHeight * s,
                  maxFontSize: _terminalMaxFontSize,
                  minFontSize: _terminalMinFontSize,
                  showLanguage: false,
                  terminal: true,
                ),
              ),
            ),
            // Note: mt-18px rounded-14px border px-20 py-14 19px leading-130%
            SizedBox(height: 18 * s),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 14 * s),
              decoration: BoxDecoration(
                color: _noteBg,
                borderRadius: BorderRadius.circular(14 * s),
                border: Border.all(color: _noteBorder, width: 1 * s),
              ),
              child: Text(
                note,
                style: TextStyle(
                  fontSize: 19 * s,
                  fontWeight: FontWeight.w400,
                  color: _noteText,
                  fontFamily: 'Nunito Sans',
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}