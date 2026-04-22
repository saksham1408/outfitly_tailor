import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralised color tokens for the Tailor Partner app.
///
/// The palette is intentionally dark + desaturated (dispatch-room
/// aesthetic) with a single saturated accent (`accent` — radar green)
/// that claims all attention-grabbing affordances. Keeping the accent
/// rare is what makes the "NEW REQUEST" sheet feel urgent.
abstract final class AppColors {
  // ── Surfaces ─────────────────────────────────────────────────────
  static const Color background = Color(0xFF08080C);
  static const Color surface = Color(0xFF12121A);
  static const Color surfaceRaised = Color(0xFF1C1C26);
  static const Color divider = Color(0xFF24242F);

  // ── Accents ──────────────────────────────────────────────────────
  /// Radar / accept-CTA green. Only used for "active dispatch" moments
  /// (pulse, accept button, live dot) — using it anywhere else dilutes
  /// its urgency.
  static const Color accent = Color(0xFF00E5A0);
  static const Color accentMuted = Color(0xFF008F66);

  // ── Semantics ────────────────────────────────────────────────────
  static const Color danger = Color(0xFFFF4B5C);
  static const Color warning = Color(0xFFFFC15C);

  // ── Typography ───────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFFA5A5B4);
  static const Color textTertiary = Color(0xFF6C6C7A);
}

/// Dark theme definition. Inter typeface throughout — picked for its
/// clean tabular numerals (timestamps / customer IDs read cleanly)
/// and its balanced letterforms at small sizes.
abstract final class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: AppColors.accent,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.danger,
        onPrimary: Colors.black,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      dividerColor: AppColors.divider,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textTertiary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }
}
