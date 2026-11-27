// DocuCraft — Table of Content Slide Template (Flutter-native, Code theme)
// 1:1 dengan TableOfContentSlide.tsx (Presenton Code theme)
// Design space 1280×720 (sama dengan TSX)
//
// Tata letak:
//   Container: p-53px, bg #101B37, font Nunito Sans
//   Title: 64px font-medium #f2f4ff
//   Grid: mt-53px grid-cols-2 gap-24px flex-1
//   Column: space-y-26px
//   Item: flex items-start gap-10px
//     Diamond icon: 22x22 stroke #51A2FF strokeWidth 1.78
//     Number: w-36px 18px leading-none #8EC5FF
//     Label: 18px #ffffff
//     Description: 18px #ffffff gap-26px dari label

import 'package:flutter/material.dart';

class CodeTableOfContentSlideTemplate extends StatelessWidget {
  final String title;
  final List<Map<String, String>> items; // [{number, label, description}]

  const CodeTableOfContentSlideTemplate({
    super.key,
    this.title = 'Table of Content',
    this.items = const [],
  });

  static const _bg = Color(0xFF101B37);
  static const _titleColor = Color(0xFFF2F4FF);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Scale dari design space 1280×720
      final s = constraints.maxWidth / 1280;
      final displayItems = items.length > 12 ? items.sublist(0, 12) : items;

      // Split into 2 columns (6 each like TSX)
      final mid = (displayItems.length / 2).ceil();
      final leftItems = displayItems.sublist(0, mid);
      final rightItems = displayItems.sublist(mid);

      return Container(
        width: constraints.maxWidth,
        height: constraints.maxWidth * 720 / 1280,
        color: _bg,
        padding: EdgeInsets.all(53 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title: 64px font-medium #f2f4ff
            Text(
              title,
              style: TextStyle(
                fontSize: 64 * s,
                fontWeight: FontWeight.w500,
                color: _titleColor,
                fontFamily: 'Nunito Sans',
              ),
            ),
            // Grid: mt-53px grid-cols-2 gap-24px flex-1
            SizedBox(height: 53 * s),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column
                  Expanded(
                    child: _TocColumn(
                      items: leftItems,
                      scale: s,
                    ),
                  ),
                  SizedBox(width: 24 * s), // gap-24px
                  // Right column
                  Expanded(
                    child: _TocColumn(
                      items: rightItems,
                      scale: s,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _TocColumn extends StatelessWidget {
  final List<Map<String, String>> items;
  final double scale;

  const _TocColumn({required this.items, required this.scale});

  static const _primaryText = Color(0xFF8EC5FF);
  static const _backgroundText = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        return Padding(
          padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 26 * scale),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Diamond icon: 22x22 stroke #51A2FF
              _DiamondIcon(scale: scale),
              SizedBox(width: 10 * scale),
              // Number: w-36px 18px leading-none #8EC5FF
              SizedBox(
                width: 36 * scale,
                child: Text(
                  item['number'] ?? '',
                  style: TextStyle(
                    fontSize: 18 * scale,
                    fontWeight: FontWeight.w400,
                    color: _primaryText,
                    height: 1.0, // leading-none
                    fontFamily: 'Nunito Sans',
                  ),
                ),
              ),
              SizedBox(width: 26 * scale), // gap-26px
              // Label + Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['label'] ?? '',
                      style: TextStyle(
                        fontSize: 18 * scale,
                        fontWeight: FontWeight.w400,
                        color: _backgroundText,
                        fontFamily: 'Nunito Sans',
                      ),
                    ),
                    if ((item['description'] ?? '').isNotEmpty)
                      Text(
                        item['description'] ?? '',
                        style: TextStyle(
                          fontSize: 18 * scale,
                          fontWeight: FontWeight.w400,
                          color: _backgroundText,
                          fontFamily: 'Nunito Sans',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DiamondIcon extends StatelessWidget {
  final double scale;

  const _DiamondIcon({required this.scale});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF51A2FF);
    return SizedBox(
      width: 22 * scale,
      height: 22 * scale,
      child: CustomPaint(
        painter: _DiamondPainter(
          color: primaryColor,
          strokeWidth: 1.77778 * scale,
        ),
      ),
    );
  }
}

class _DiamondPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _DiamondPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Path based on the SVG path in the TSX
    // M17.7778 17.7776... (rotated square/diamond shape)
    final path = Path();

    // Draw a rounded diamond/rectangle rotated 45 degrees
    // The SVG draws a rotated square with rounded corners
    final centerX = w / 2;
    final centerY = h / 2;
    final radius = (w < h ? w : h) * 0.45; // slightly smaller for stroke

    path.moveTo(centerX, centerY - radius);
    path.lineTo(centerX + radius, centerY);
    path.lineTo(centerX, centerY + radius);
    path.lineTo(centerX - radius, centerY);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}