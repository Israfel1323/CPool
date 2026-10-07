import 'package:flutter/material.dart';

/// CPool brand palette — Soft White & Purple (cool white, subtle lavender-grey, muted purple, soft lavender).
abstract final class AppColors {
  // Background / Surfaces
  static const Color lightBg = Color(0xFFF8F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFEEEAF4);
  static const Color lightElevated = Color(0xFFE6E0EE);
  static const Color lightBorder = Color(0xFFD4CCDF);

  // Text / Typography Neutrals
  static const Color lightText = Color(0xFF292530);
  static const Color lightTextSecondary = Color(0xFF625C69);
  static const Color lightGrey = Color(0xFF625C69);
  static const Color lightGreyMuted = Color(0xFF918A99);

  // Primary — Soft Muted Purple
  static const Color primary = Color(0xFF8F7AA8);
  static const Color primaryDark = Color(0xFF705A8B);
  static const Color primaryLight = Color(0xFFC7B9D8);
  static const Color primaryVeryLight = Color(0xFFE9E3F0);

  // Secondary — Soft Lavender
  static const Color secondary = Color(0xFFA99ABD);
  static const Color secondaryDark = Color(0xFF827096);
  static const Color secondaryLight = Color(0xFFD8CFE2);
  static const Color secondaryVeryLight = Color(0xFFEEEAF3);

  // Home Action Cards (compatibility constants)
  static const Color ridePurple = Color(0xFF8F7AA8);
  static const Color ridePurpleDark = Color(0xFF705A8B);
  static const Color ridePurpleLight = Color(0xFFC7B9D8);
  static const Color ridePink = ridePurple;
  static const Color ridePinkDark = ridePurpleDark;
  static const Color ridePinkLight = ridePurpleLight;

  static const Color offerTeal = Color(0xFFA99ABD);
  static const Color offerTealDark = Color(0xFF827096);
  static const Color offerTealLight = Color(0xFFD8CFE2);
  static const Color offerSage = offerTeal;
  static const Color offerSageDark = offerTealDark;
  static const Color offerSageLight = offerTealLight;

  // Status Colors
  static const Color error = Color(0xFFC46F78);
  static const Color success = Color(0xFF719276);
  static const Color warning = Color(0xFFC19A61);

  // Compatibility Neutrals (single-theme fallbacks)
  static const Color darkBg = lightBg;
  static const Color darkSurface = lightSurface;
  static const Color darkCard = lightCard;
  static const Color darkElevated = lightElevated;
  static const Color darkBorder = lightBorder;
  static const Color darkText = lightText;
  static const Color darkTextSecondary = lightTextSecondary;
  static const Color darkGrey = lightGrey;
  static const Color darkGreyMuted = lightGreyMuted;
  static const Color darkPrimaryVariant = primaryDark;
  static const Color darkSecondaryVariant = secondaryDark;

  // Legacy Violet Aliases (mapped to soft purple palette)
  static const Color violet50 = primaryVeryLight;
  static const Color violet100 = primaryLight;
  static const Color violet200 = lightBorder;
  static const Color violet300 = primaryLight;
  static const Color violet400 = primary;
  static const Color violet500 = primary;
  static const Color violet600 = primaryDark;
  static const Color violet700 = primaryDark;
  static const Color violet800 = lightText;
  static const Color violet900 = lightCard;
}
