import 'package:flutter/material.dart';

/// Palet warna adaptif UMKM Sight (mengikuti desain Figma "UMKM Sight — Rapi & Padat")
/// dengan dukungan penuh Light Mode dan Dark/Night Mode.
abstract final class AppColors {
  // ---- Brand Colors (Figma) ----
  static const primary = Color(0xFF174EA6); // Deep Cobalt Blue
  static const primaryDark = Color(0xFF103A7E);
  static const primaryLight = Color(0xFF60A5FA); // Vibrant Blue for Dark Mode
  static const primaryTint = Color(0xFFEAF0FB);
  static const primaryTintDark = Color(0x333B82F6);

  // ---- Light Mode Canvas (Figma Exact) ----
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSecondary = Color(0xFFF3F5F8);
  static const cardBorder = Color(0xFFD8E0EA);
  static const chipFill = surfaceSecondary;

  // ---- Dark Mode Canvas (Slate Midnight) ----
  static const backgroundDark = Color(0xFF0F172A);
  static const surfaceDark = Color(0xFF1E293B);
  static const surfaceSecondaryDark = Color(0xFF273449);
  static const cardBorderDark = Color(0xFF334155);
  static const chipFillDark = surfaceSecondaryDark;

  // ---- Typography (Light - Figma Exact) ----
  static const textPrimary = Color(0xFF16233A);
  static const textSecondary = Color(0xFF5B6779);
  static const textHint = Color(0xFF8A94A3);

  // ---- Typography (Dark) ----
  static const textPrimaryDark = Color(0xFFF8FAFC);
  static const textSecondaryDark = Color(0xFF94A3B8);
  static const textHintDark = Color(0xFF64748B);

  // ---- Status Alert & Accents ----
  static const success = Color(0xFF1F6B4F);
  static const successDark = Color(0xFF34D399);
  static const successBg = Color(0xFFE8F3EE);
  static const successBgDark = Color(0x2910B981);

  static const warning = Color(0xFF9A6700);
  static const warningDark = Color(0xFFFBBF24);
  static const warningBg = Color(0xFFFBF1DE);
  static const warningBgDark = Color(0x29F59E0B);

  static const danger = Color(0xFFB3261E);
  static const dangerDark = Color(0xFFF87171);
  static const dangerBg = Color(0xFFFCEAE8);
  static const dangerBgDark = Color(0x29EF4444);

  // ---- Shadows & Dividers ----
  static const softShadow = Color(0x0816233A);
  static const softShadowDark = Color(0x33000000);
  static const divider = cardBorder;
  static const dividerDark = cardBorderDark;

  // ---- Backward Compatibility Aliases ----
  static const chip = chipFill;
  static const hint = textHint;
  static const textDark = textPrimary;
  static const textMuted = textSecondary;
  static const shadow = softShadow;
  static const error = danger;
  static const fieldBorder = cardBorder;

  /// Helper untuk mengecek apakah saat ini Dark Mode.
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color primaryOf(BuildContext context) =>
      isDark(context) ? primaryLight : primary;

  static Color primaryTintOf(BuildContext context) =>
      isDark(context) ? primaryTintDark : primaryTint;

  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? surfaceDark : surface;

  static Color surfaceSecondaryOf(BuildContext context) =>
      isDark(context) ? surfaceSecondaryDark : surfaceSecondary;

  static Color backgroundOf(BuildContext context) =>
      isDark(context) ? backgroundDark : background;

  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? textPrimaryDark : textPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? textSecondaryDark : textSecondary;

  static Color textHintOf(BuildContext context) =>
      isDark(context) ? textHintDark : textHint;

  static Color borderOf(BuildContext context) =>
      isDark(context) ? cardBorderDark : cardBorder;

  static Color chipOf(BuildContext context) =>
      isDark(context) ? chipFillDark : chipFill;

  static Color shadowOf(BuildContext context) =>
      isDark(context) ? softShadowDark : softShadow;

  static Color successOf(BuildContext context) =>
      isDark(context) ? successDark : success;

  static Color successBgOf(BuildContext context) =>
      isDark(context) ? successBgDark : successBg;

  static Color warningOf(BuildContext context) =>
      isDark(context) ? warningDark : warning;

  static Color warningBgOf(BuildContext context) =>
      isDark(context) ? warningBgDark : warningBg;

  static Color dangerOf(BuildContext context) =>
      isDark(context) ? dangerDark : danger;

  static Color dangerBgOf(BuildContext context) =>
      isDark(context) ? dangerBgDark : dangerBg;
}
