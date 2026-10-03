import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'prompts.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Design tokens — Dark Neumorphic / Glow theme.
/// ─────────────────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();
  static const bg = Color(0xFF0F172A);        // deep slate
  static const surface = Color(0xFF1E293B);   // slate-800
  static const surfaceHi = Color(0xFF273449); // raised
  static const surfaceLo = Color(0xFF0B1222); // sunken
  static const border = Color(0x1FFFFFFF);
  static const text = Color(0xFFF8FAFC);
  static const muted = Color(0xFF94A3B8);
  static const primary = Color(0xFF818CF8);   // indigo-400
  static const fire = Color(0xFFFB923C);
  static const success = Color(0xFF34D399);
  static const danger = Color(0xFFFB7185);

  /// Module gradient palette (per spec).
  static List<Color> gradient(StudyModule m) => switch (m) {
        StudyModule.solver => const [Color(0xFF7C3AED), Color(0xFF4F46E5)],   // purple → indigo
        StudyModule.text => const [Color(0xFF10B981), Color(0xFF06B6D4)],     // emerald → cyan
        StudyModule.summary => const [Color(0xFFF59E0B), Color(0xFFF97316)],  // amber → orange
        StudyModule.grammar => const [Color(0xFFF43F5E), Color(0xFFFB7185)],  // rose → coral
        StudyModule.dialect => const [Color(0xFF22C55E), Color(0xFFEAB308)],  // green → gold (Darija)
      };
  static Color accent(StudyModule m) => gradient(m).first;
  static String emoji(StudyModule m) => switch (m) { StudyModule.text => '📖', StudyModule.solver => '🧮', StudyModule.summary => '📝', StudyModule.grammar => '🔤', StudyModule.dialect => '🇩🇿' };
  static IconData icon(StudyModule m) => switch (m) { StudyModule.text => Icons.auto_stories_rounded, StudyModule.solver => Icons.functions_rounded, StudyModule.summary => Icons.summarize_rounded, StudyModule.grammar => Icons.translate_rounded, StudyModule.dialect => Icons.record_voice_over_rounded };
}

class AppRadii {
  static const card = 24.0;
  static const chip = 14.0;
  static final rCard = BorderRadius.circular(card);
  static final rChip = BorderRadius.circular(chip);
}

/// Neumorphic dual shadow: dark bottom-right, light top-left.
List<BoxShadow> neuShadow({double blur = 18, double offset = 8}) => [
      BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: blur, offset: Offset(offset, offset)),
      BoxShadow(color: Colors.white.withOpacity(0.04), blurRadius: blur, offset: Offset(-offset, -offset)),
    ];

List<BoxShadow> glowShadow(Color c, {double strength = 0.45}) => [
      BoxShadow(color: c.withOpacity(strength), blurRadius: 28, spreadRadius: -4, offset: const Offset(0, 10)),
    ];

ThemeData buildTheme(bool isArabic) {
  final base = ThemeData.dark(useMaterial3: true);
  final text = isArabic ? GoogleFonts.cairoTextTheme(base.textTheme) : GoogleFonts.plusJakartaSansTextTheme(base.textTheme);
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.dark, surface: AppColors.surface);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: scheme,
    textTheme: text.apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
    cardTheme: CardTheme(color: AppColors.surface, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: AppRadii.rCard, side: const BorderSide(color: AppColors.border))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: AppColors.surfaceLo,
      hintStyle: const TextStyle(color: AppColors.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      contentPadding: const EdgeInsets.all(18),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surfaceLo.withOpacity(0.92), height: 72, indicatorColor: AppColors.primary.withOpacity(0.2),
      labelTextStyle: WidgetStatePropertyAll(text.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.text)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted)),
    ),
    snackBarTheme: SnackBarThemeData(backgroundColor: AppColors.surfaceHi, contentTextStyle: const TextStyle(color: AppColors.text), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    dividerColor: AppColors.border,
  );
}
