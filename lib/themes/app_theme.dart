// DocuCraft — Theme Configuration (KEKO Intelligence — Light)

import 'package:flutter/material.dart';

class AppTheme {
  // ── KEKO Intelligence color tokens ───────────────────────────────
  static const Color primary      = Color(0xFF3F51B5); // Indigo 500
  static const Color primaryDark  = Color(0xFF293CA0); // Indigo 700
  static const Color primaryLight = Color(0xFF5D6FD4); // Indigo 400
  static const Color secondary    = Color(0xFF00B0FF); // Cyan accent
  static const Color secondaryDark= Color(0xFF007EB8); // Cyan 600
  static const Color tertiary     = Color(0xFF7986CB); // Indigo 200
  static const Color surface      = Color(0xFFF8F9FA); // Neutral 50
  static const Color surface2     = Color(0xFFFFFFFF); // Pure white card
  static const Color surface3     = Color(0xFFF3F4F5); // Neutral 80
  static const Color surfaceCard  = Color(0xFFFFFFFF);
  static const Color surfaceContainerHighest = Color(0xFFE8E9EB); // Neutral 85
  static const Color outline      = Color(0xFFC5C7C8); // Neutral 80
  static const Color textPrimary  = Color(0xFF191C1D); // Neutral 90
  static const Color textSecondary= Color(0xFF454748); // Neutral 70
  static const Color textMuted    = Color(0xFF757778); // Neutral 60
  static const Color textOnPrimary= Color(0xFFFFFFFF);
  static const Color border       = Color(0xFFE1E3E4); // Neutral 90
  static const Color success      = Color(0xFF10B981);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color error        = Color(0xFFEF4444);
  static const Color divider      = Color(0xFFE1E3E4);

  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: surface,
    colorScheme: const ColorScheme.light(
      primary: primary,
      onPrimary: textOnPrimary,
      secondary: secondary,
      surface: surface,
      error: error,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surface2,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        fontFamily: 'NotoSans',
      ),
      iconTheme: const IconThemeData(color: textSecondary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surface2,
      selectedItemColor: primary,
      unselectedItemColor: textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    cardTheme: CardThemeData(
      color: surface2,
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: const DividerThemeData(color: divider, thickness: 1),
    fontFamily: 'NotoSans',
  );

  // Gradient helpers — 16 beautiful options + custom
  static List<Color> gradientFor(String name) {
    // Custom format: 'custom_HEX1,HEX2'
    if (name.startsWith('custom_')) {
      try {
        final parts = name.substring(7).split(',');
        if (parts.length == 2) {
          final c1 = int.parse(parts[0], radix: 16);
          final c2 = int.parse(parts[1], radix: 16);
          return [Color(0xFF000000 | c1), Color(0xFF000000 | c2)];
        }
      } catch (_) {}
      return const [Color(0xFF6366F1), Color(0xFF4F46E5)];
    }

    const gradients = {
      'white': [Color(0xFFFFFFFF), Color(0xFFF8F9FA)],
      'clean-white': [Color(0xFFFFFFFF), Color(0xFFF8F9FA)],
      'indigo': [Color(0xFF6366F1), Color(0xFF4F46E5)],
      'purple': [Color(0xFFA855F7), Color(0xFFEC4899)],
      'blue': [Color(0xFF3B82F6), Color(0xFF0891B2)],
      'emerald': [Color(0xFF10B981), Color(0xFF0D9488)],
      'amber': [Color(0xFFF59E0B), Color(0xFFEA580C)],
      'rose': [Color(0xFFF43F5E), Color(0xFFBE185D)],
      'teal': [Color(0xFF14B8A6), Color(0xFF0E7490)],
      'orange': [Color(0xFFF97316), Color(0xFFC2410C)],
      'pink': [Color(0xFFE11D48), Color(0xFFBE123C)],
      'cyan': [Color(0xFF06B6D4), Color(0xFF0891B2)],
      'lime': [Color(0xFF65A30D), Color(0xFF4D7C0F)],
      'violet': [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
      'slate': [Color(0xFF475569), Color(0xFF1E293B)],
      'warm': [Color(0xFFD97706), Color(0xFFDC2626)],
      'frost': [Color(0xFF2DD4BF), Color(0xFF3B82F6)],
      'midnight': [Color(0xFF1E1B4B), Color(0xFF0B0F19)],
      // Light → Dark gradients (putih ke warna pekat)
      'light-red': [Color(0xFFFEE2E2), Color(0xFF991B1B)],
      'light-blue': [Color(0xFFDBEAFE), Color(0xFF1E3A8A)],
      'light-green': [Color(0xFFD1FAE5), Color(0xFF064E3B)],
      'light-purple': [Color(0xFFF3E8FF), Color(0xFF4C1D95)],
      'light-orange': [Color(0xFFFFEDD5), Color(0xFF7C2D12)],
      'light-pink': [Color(0xFFFCE7F3), Color(0xFF831843)],
      'light-teal': [Color(0xFFCCFBF1), Color(0xFF134E4A)],
      'light-yellow': [Color(0xFFFEF9C3), Color(0xFF713F12)],
      'light-indigo': [Color(0xFFE0E7FF), Color(0xFF312E81)],
      'light-cyan': [Color(0xFFCFFAFE), Color(0xFF164E63)],
      'light-gray': [Color(0xFFF3F4F6), Color(0xFF111827)],
      'light-rose': [Color(0xFFFFE4E6), Color(0xFF881337)],
    };
    return gradients[name] ?? gradients['indigo']!;
  }
}
