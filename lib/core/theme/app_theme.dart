import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData dark() => light();

  static ThemeData light() {
    const primary = AppColors.primary;
    const secondary = AppColors.secondary;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: AppColors.lightSurface,
        secondary: secondary,
        onSecondary: AppColors.lightText,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightText,
        error: AppColors.error,
        onError: AppColors.lightSurface,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightText,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.lightText,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        indicatorColor: AppColors.primaryVeryLight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.primaryDark : AppColors.lightGreyMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primaryDark : AppColors.lightGreyMuted,
            size: 24,
          );
        }),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.lightSurface,
        elevation: 2,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.lightBorder),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(color: AppColors.lightGreyMuted),
        labelStyle: GoogleFonts.inter(color: AppColors.lightGreyMuted),
      ),
      textTheme: _textTheme(isDark: false),
      extensions: const [CPoolThemeExtension(isDark: false)],
    );
  }

  static TextTheme _textTheme({required bool isDark}) {
    final primary = isDark ? AppColors.darkText : AppColors.lightText;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return TextTheme(
      displayLarge: GoogleFonts.spaceGrotesk(
  fontSize: 40,
  fontWeight: FontWeight.w700,
  color: primary,
  letterSpacing: -1,
),

headlineMedium: GoogleFonts.spaceGrotesk(
  fontSize: 24,
  fontWeight: FontWeight.w700,
  color: primary,
),

titleLarge: GoogleFonts.spaceGrotesk(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  color: primary,
),

bodyLarge: GoogleFonts.inter(
  fontSize: 16,
  fontWeight: FontWeight.w400,
  color: primary,
),

bodyMedium: GoogleFonts.inter(
  fontSize: 14,
  fontWeight: FontWeight.w400,
  color: secondary,
),

labelLarge: GoogleFonts.inter(
  fontSize: 14,
  fontWeight: FontWeight.w600,
  color: primary,
),
    );
  }
}

class CPoolThemeExtension extends ThemeExtension<CPoolThemeExtension> {
  const CPoolThemeExtension({this.isDark = false});

  final bool isDark;

  Color get background => AppColors.lightBg;
  Color get surface => AppColors.lightSurface;
  Color get card => AppColors.lightCard;
  Color get elevated => AppColors.lightElevated;
  Color get border => AppColors.lightBorder;
  Color get textPrimary => AppColors.lightText;
  Color get textSecondary => AppColors.lightTextSecondary;
  Color get accent => AppColors.primary;
  Color get accentMuted => AppColors.primaryLight;
  Color get navBarBg => AppColors.lightSurface;

  @override
  CPoolThemeExtension copyWith({bool? isDark}) =>
      CPoolThemeExtension(isDark: isDark ?? this.isDark);

  @override
  CPoolThemeExtension lerp(ThemeExtension<CPoolThemeExtension>? other, double t) {
    if (other is! CPoolThemeExtension) return this;
    return t < 0.5 ? this : other;
  }
}

extension CPoolThemeContext on BuildContext {
  CPoolThemeExtension get cpoolTheme =>
      Theme.of(this).extension<CPoolThemeExtension>()!;
}
