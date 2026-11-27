// DocuCraft — File Tree Structure Template (Flutter-native)
// 1:1 dengan FileTreeStructureSlide.tsx (Presenton Code theme)
// Design space 1280×720 (sama dengan TSX)
//
// Tata letak:
//   p-[53px] container
//   Title: 50px font-medium lh 105% #ffffff
//   Description: mt-[10px] 20px lh 135% max-w-[1050px] #CAD5E2
//   Grid: mt-[22px] grid-cols-[1.55fr_0.95fr] gap-[22px]
//     Left: CodeBlockPanel (file tree) — maxWidth 684, maxHeight 338, maxFS 17, showLanguage=false
//     Right: Notes panel rounded-[18px] border p-[18px] bg #0F172B80
//       Title "Notes" 19px + Highlights grid mt-[14px] gap-[10px]
//         Tiap: rounded-[10px] border px-[14px] py-[12px] bg #1D293D4D
//           label: (15/16px) font-medium + description: (13/14px) mt-[6px]

import 'package:flutter/material.dart';
import 'code_block_panel.dart';

class FileTreeStructureTemplate extends StatelessWidget {
  final String title;
  final String description;
  final String rootLabel;
  final String tree;
  final List<Map<String, String>> highlights; // [{label, description}]

  const FileTreeStructureTemplate({
    super.key,
    this.title = 'Template Folder Structure',
    this.description = '',
    this.rootLabel = 'servers/nextjs/app',
    this.tree = '',
    this.highlights = const [],
  });

  static const _bg = Color(0xFF101B37);
  static const _title = Color(0xFFFFFFFF);
  static const _desc = Color(0xFFCAD5E2);
  static const _cardBg = Color(0x800F172B);
  static const _stroke = Color(0x801D293D);
  static const _highlightBg = Color(0x4D1D293D); // #1D293D4D
  static const _label = Color(0xFFF1F4FF);
  static const _body = Color(0xFFAEBBE5);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final s = constraints.maxWidth / 1280;
      final pad = 53 * s;
      final displayHighlights = highlights.length > 5 ? highlights.sublist(0, 5) : highlights;
      final highlightTitleSize = displayHighlights.length > 4 ? 15.0 : 16.0;
      final highlightBodySize = displayHighlights.length > 4 ? 13.0 : 14.0;

      // Grid: 1.55fr : 0.95fr
      final leftFlex = 155;
      final rightFlex = 95;

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(child: Container(color: _bg)),

          Positioned(
            left: pad, right: pad, top: pad, bottom: pad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title: 50px font-medium
                Text(title, style: TextStyle(fontSize: 50 * s, fontWeight: FontWeight.w500, color: _title, height: 1.05)),
                // Description: mt-[10px] 20px lh 135%
                Padding(
                  padding: EdgeInsets.only(top: 10 * s),
                  child: SizedBox(
                    width: 1050 * s,
                    child: Text(description, style: TextStyle(fontSize: 20 * s, color: _desc, height: 1.35)),
                  ),
                ),
                // Grid: mt-[22px] 1.55fr/0.95fr gap-[22px]
                Padding(
                  padding: EdgeInsets.only(top: 22 * s),
                  child: Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left: File tree
                        Expanded(
                          flex: leftFlex,
                          child: CodeBlockPanel(
                            title: 'File Tree',
                            fileName: rootLabel,
                            language: 'tree',
                            content: tree,
                            maxWidth: 684,
                            maxHeight: 338,
                            maxFontSize: 17,
                            minFontSize: 7,
                            showLanguage: false,
                          ),
                        ),
                        SizedBox(width: 22 * s),
                        // Right: Notes panel
                        Expanded(
                          flex: rightFlex,
                          child: _buildNotesPanel(displayHighlights, highlightTitleSize, highlightBodySize, s),
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

  Widget _buildNotesPanel(List<Map<String, String>> items, double titleSize, double bodySize, double s) {
    return Container(
      padding: EdgeInsets.all(18 * s),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18 * s),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Notes title: 19px #ffffff
          Text('Notes', style: TextStyle(fontSize: 19 * s, color: _title)),
          // Highlights grid: mt-[14px] gap-[10px]
          Padding(
            padding: EdgeInsets.only(top: 14 * s),
            child: Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  mainAxisSpacing: 10 * s,
                  childAspectRatio: 5.0,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) => _buildHighlight(items[i], titleSize, bodySize, s),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlight(Map<String, String> item, double titleSize, double bodySize, double s) {
    return Container(
      padding: EdgeInsets.fromLTRB(14 * s, 12 * s, 14 * s, 12 * s),
      decoration: BoxDecoration(
        color: _highlightBg,
        borderRadius: BorderRadius.circular(10 * s),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item['label'] ?? '',
            style: TextStyle(
              fontSize: titleSize * s,
              fontWeight: FontWeight.w500,
              color: _label,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 6 * s),
          Text(
            item['description'] ?? '',
            style: TextStyle(
              fontSize: bodySize * s,
              color: _body,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
