// DocuCraft — Image List Template (Flutter-native)
// 1:1 dengan ImageListDescription.tsx (Presenton)
// Design space 1280×720 (sama dengan TSX)
//
// Tata letak:
//   Header: px-12 pt-6 pb-2 → diamond 12px
//   Grid: px-12 pt-6 grid-cols-[36%_64%] gap-8 items-start
//     Kiri: titleLine1<br/>titleLine2 56px semibold lh 1.05 + desc mt-8 16px lh 1.8 max-w-300
//     Kanan: grid-cols-3 gap-10 → 3 kartu gambar
//       Foto: h-[180px] rounded-t-md object-cover
//       Panel: -mt-[1px] rounded-b-[28px] px-6 pt-6 pb-7 bg #BFF4FF
//         Judul 20px semibold + desc mt-3 14px lh 1.7
//   Footer: bottom-8 left-12 right-12 → website 14px + ml-6 line 2px #E5E7EB
//   Diamond besar: bottom-7 right-6 w-8 h-8 rotate-45

import 'package:flutter/material.dart';

class ImageListTemplate extends StatelessWidget {
  final String titleLine1;
  final String titleLine2;
  final String description;
  final List<Map<String, String>> items; // [{title, description, imageUrl}]
  final String website;
  final String companyName;

  const ImageListTemplate({
    super.key,
    this.titleLine1 = 'Meet Our',
    this.titleLine2 = 'Team',
    this.description = '',
    this.items = const [],
    this.website = 'www.yourwebsite.com',
    this.companyName = '',
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Scale dari design space 1280×720 (sama dengan TSX)
      final s = constraints.maxWidth / 1280;
      final displayItems = items.length > 3 ? items.sublist(0, 3) : items;

      // ── Grid: px-12 pt-6 grid-cols-[36%_64%] gap-8 items-start ──
      // Content width = 1280 - 96 = 1184
      // Left col = 36% × 1184 = 426, Right col = 64% × 1184 = 758
      // Header: 24 + 12 + 8 = 44px, pt-6 = 24px → grid y = 44 + 24 = 68
      final leftColW = 1184 * 0.36;
      final rightColW = 1184 * 0.64;
      final gridY = 68 * s;
      // Card col: (758 - 2×40 gap) / 3 = 226
      final cardW = (rightColW - 80) / 3;

      return Stack(clipBehavior: Clip.hardEdge, children: [
        // ── Background putih ──
        Positioned.fill(
          child: Container(color: const Color(0xFFFFFFFF)),
        ),

        // ── Header: px-12 pt-6 pb-2 → diamond 12px ──
        Positioned(
          left: 48 * s, // px-12
          top: 24 * s, // pt-6
          child: Row(
            children: [
              Container(
                width: 12 * s,
                height: 12 * s,
                transform: Matrix4.rotationZ(0.785398),
                decoration: const BoxDecoration(color: Color(0xFF111827)),
              ),
              if (companyName.isNotEmpty) ...[
                SizedBox(width: 12 * s), // gap-3
                Text(
                  companyName,
                  style: TextStyle(fontSize: 16 * s, color: const Color(0xFF6B7280), fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
        ),

        // ── Left: title (2 line) + description ──
        Positioned(
          left: 48 * s, // px-12
          top: gridY,
          width: leftColW * s,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$titleLine1\n$titleLine2',
                style: TextStyle(
                  fontSize: 56 * s, // text-[56px]
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111827),
                  height: 1.05,
                ),
              ),
              SizedBox(height: 32 * s), // mt-8
              Text(
                description,
                style: TextStyle(
                  fontSize: 16 * s, // text-[16px]
                  color: const Color(0xFF6B7280),
                  height: 1.8,
                ),
              ),
            ],
          ),
        ),

        // ── Right: 3 image cards (grid-cols-3 gap-10) ──
        Positioned(
          left: (48 + 1184 * 0.36 + 32) * s, // px-12 + 36% + gap-8(32)
          top: gridY,
          width: rightColW * s,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(3, (i) {
              final item = i < displayItems.length ? displayItems[i] : null;
              final imgUrl = item?['imageUrl'] ?? '';
              final title = item?['title'] ?? 'Sample Title';
              final desc = item?['description'] ?? '';
              return Container(
                width: cardW * s,
                margin: EdgeInsets.only(right: i < 2 ? 40 * s : 0), // gap-10
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Photo h-[180px] rounded-t-md
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(6 * s)), // rounded-t-md (6px)
                      child: SizedBox(
                        height: 180 * s, // h-[180px]
                        child: imgUrl.isNotEmpty
                            ? Image.network(
                                imgUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, _, _) => const ColoredBox(
                                  color: Color(0xFFF3F4F6),
                                  child: Center(child: Icon(Icons.image, color: Color(0xFFD1D5DB), size: 40)),
                                ),
                              )
                            : const ColoredBox(
                                color: Color(0xFFF3F4F6),
                                child: Center(child: Icon(Icons.image, color: Color(0xFFD1D5DB), size: 40)),
                              ),
                      ),
                    ),
                    // Panel cyan: -mt-[1px] rounded-b-[28px] px-6 pt-6 pb-7
                    Container(
                      margin: EdgeInsets.only(top: -1 * s), // -mt-[1px]
                      padding: EdgeInsets.fromLTRB(
                        24 * s, // px-6
                        24 * s, // pt-6
                        24 * s,
                        28 * s, // pb-7
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBFF4FF),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28 * s)), // rounded-b-[28px]
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 20 * s, // text-[20px]
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          SizedBox(height: 12 * s), // mt-3
                          Text(
                            desc,
                            style: TextStyle(
                              fontSize: 14 * s, // text-[14px]
                              color: const Color(0xFF6B7280),
                              height: 1.7,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),

        // ── Footer: absolute bottom-8 left-12 right-12 ──
        Positioned(
          left: 48 * s, // left-12
          right: 48 * s, // right-12
          bottom: 32 * s, // bottom-8
          child: Row(
            children: [
              Text(
                website,
                style: TextStyle(fontSize: 14 * s, color: const Color(0xFF6B7280)),
              ),
              SizedBox(width: 24 * s), // ml-6
              Expanded(
                child: Container(
                  height: 2 * s, // h-[2px]
                  color: const Color(0xFFE5E7EB), // bg #E5E7EB
                ),
              ),
            ],
          ),
        ),

        // ── Diamond besar: bottom-7 right-6 w-8 h-8 rotate-45 ──
        Positioned(
          right: 24 * s, // right-6
          bottom: 28 * s, // bottom-7
          child: Container(
            width: 32 * s, // w-8
            height: 32 * s, // h-8
            transform: Matrix4.rotationZ(0.785398),
            decoration: const BoxDecoration(color: Color(0xFF111827)),
          ),
        ),
      ]);
    });
  }
}
