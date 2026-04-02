import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// VocabGame Design System
///
/// Dark-first with a polished light variant.
/// All colors, gradients, radii, and shadows are defined here.
class AppTheme {
  AppTheme._();

  // ─── Color Palette ──────────────────────────────────────────────────

  // Dark palette
  static const _darkBg = Color(0xFF0F1123);
  static const _darkSurface = Color(0xFF1A1D3A);
  static const _darkCard = Color(0xFF1E2140);
  static const _darkCardBorder = Color(0xFF2A2D50);

  // Light palette
  static const _lightBg = Color(0xFFF5F6FA);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightCard = Color(0xFFF0F1F8);

  // Accent colors (shared)
  static const violet = Color(0xFF7C4DFF);
  static const violetLight = Color(0xFFA47AFF);
  static const violetDark = Color(0xFF5C2FE0);
  static const amber = Color(0xFFFFB300);
  static const amberDark = Color(0xFFFF8F00);
  static const fire = Color(0xFFFF6D00);
  static const success = Color(0xFF00E676);
  static const successDark = Color(0xFF00C853);
  static const error = Color(0xFFFF5252);
  static const errorDark = Color(0xFFD32F2F);
  static const textSecondaryDark = Color(0xFF8B8FAD);
  static const textSecondaryLight = Color(0xFF6B7082);

  // ─── Gradients ──────────────────────────────────────────────────────

  /// Main background gradient (dark)
  static const darkBgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_darkBg, Color(0xFF141733), _darkSurface],
    stops: [0.0, 0.5, 1.0],
  );

  /// Main background gradient (light)
  static const lightBgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF8F7FF), Color(0xFFF2F0FB), _lightBg],
    stops: [0.0, 0.5, 1.0],
  );

  /// Primary accent gradient (buttons, highlights)
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violetLight, violet, violetDark],
  );

  /// XP / gold gradient
  static const xpGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [amber, Color(0xFFFFC107), Color(0xFFFFD54F)],
  );

  /// Streak / fire gradient
  static const fireGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFF9100), fire, Color(0xFFFF3D00)],
  );

  /// Success gradient
  static const successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [success, successDark],
  );

  /// Glass card gradient (dark)
  static LinearGradient get darkGlassGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _darkCard.withValues(alpha: 0.85),
          _darkCard.withValues(alpha: 0.6),
        ],
      );

  /// Glass card gradient (light)
  static LinearGradient get lightGlassGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.9),
          Colors.white.withValues(alpha: 0.7),
        ],
      );

  // ─── Radius ─────────────────────────────────────────────────────────

  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusXl = 32;

  static final borderRadiusSm = BorderRadius.circular(radiusSm);
  static final borderRadiusMd = BorderRadius.circular(radiusMd);
  static final borderRadiusLg = BorderRadius.circular(radiusLg);
  static final borderRadiusXl = BorderRadius.circular(radiusXl);

  // ─── Shadows ────────────────────────────────────────────────────────

  static List<BoxShadow> get shadowSoft => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get shadowMedium => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> shadowGlow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.3),
          blurRadius: 20,
          spreadRadius: 2,
        ),
      ];

  // ─── Glass Card Decoration ──────────────────────────────────────────

  static BoxDecoration glassCard({required bool isDark}) => BoxDecoration(
        gradient: isDark ? darkGlassGradient : lightGlassGradient,
        borderRadius: borderRadiusMd,
        border: Border.all(
          color: isDark
              ? _darkCardBorder.withValues(alpha: 0.5)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: shadowSoft,
      );

  // ─── Dark Theme ─────────────────────────────────────────────────────

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: _darkBg,
      colorScheme: ColorScheme.dark(
        primary: violet,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFF2E1F7A),
        onPrimaryContainer: violetLight,
        secondary: amber,
        onSecondary: Colors.black,
        secondaryContainer: const Color(0xFF3D2E00),
        onSecondaryContainer: const Color(0xFFFFE082),
        surface: _darkSurface,
        onSurface: Colors.white,
        onSurfaceVariant: textSecondaryDark,
        error: error,
        onError: Colors.white,
        outline: _darkCardBorder,
        outlineVariant: _darkCardBorder.withValues(alpha: 0.3),
        surfaceContainerHighest: _darkCard,
      ),
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
        ),
        displayMedium: textTheme.displayMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: Colors.white.withValues(alpha: 0.9),
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.8),
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: textSecondaryDark,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: _darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadiusMd,
          side: BorderSide(color: _darkCardBorder.withValues(alpha: 0.4)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _darkSurface.withValues(alpha: 0.95),
        selectedItemColor: violet,
        unselectedItemColor: textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkCard.withValues(alpha: 0.8),
        border: OutlineInputBorder(
          borderRadius: borderRadiusMd,
          borderSide: BorderSide(color: _darkCardBorder.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadiusMd,
          borderSide: BorderSide(color: _darkCardBorder.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadiusMd,
          borderSide: const BorderSide(color: violet, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: TextStyle(
          color: textSecondaryDark.withValues(alpha: 0.6),
          fontWeight: FontWeight.w400,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: violet,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: borderRadiusMd),
          elevation: 0,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: violet,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: borderRadiusMd),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: violet,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: borderRadiusMd),
          side: BorderSide(color: _darkCardBorder),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: violet,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: borderRadiusMd),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _darkSurface,
        shape: RoundedRectangleBorder(borderRadius: borderRadiusLg),
        elevation: 20,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkCard,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: borderRadiusSm),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(
        color: _darkCardBorder.withValues(alpha: 0.3),
        thickness: 1,
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: violet,
        labelColor: Colors.white,
        unselectedLabelColor: textSecondaryDark,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _darkCard,
        side: BorderSide(color: _darkCardBorder.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: borderRadiusSm),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  // ─── Light Theme ────────────────────────────────────────────────────

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: _lightBg,
      colorScheme: ColorScheme.light(
        primary: violet,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFE8DEFF),
        onPrimaryContainer: violetDark,
        secondary: amberDark,
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFFFF3D6),
        onSecondaryContainer: const Color(0xFF5D4200),
        surface: _lightSurface,
        onSurface: const Color(0xFF1A1D3A),
        onSurfaceVariant: textSecondaryLight,
        error: errorDark,
        onError: Colors.white,
        outline: const Color(0xFFD8DAE5),
        outlineVariant: const Color(0xFFE8EAF0),
        surfaceContainerHighest: _lightCard,
      ),
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
          color: const Color(0xFF1A1D3A),
        ),
        displayMedium: textTheme.displayMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: const Color(0xFF1A1D3A),
        ),
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: const Color(0xFF1A1D3A),
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1A1D3A),
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1A1D3A),
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1A1D3A),
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: const Color(0xFF2D3152),
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF3E4268),
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: textSecondaryLight,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1A1D3A),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          color: const Color(0xFF1A1D3A),
        ),
      ),
      cardTheme: CardThemeData(
        color: _lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadiusMd,
          side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        selectedItemColor: violet,
        unselectedItemColor: textSecondaryLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightCard,
        border: OutlineInputBorder(
          borderRadius: borderRadiusMd,
          borderSide:
              BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadiusMd,
          borderSide:
              BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadiusMd,
          borderSide: const BorderSide(color: violet, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: TextStyle(
          color: textSecondaryLight.withValues(alpha: 0.6),
          fontWeight: FontWeight.w400,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: violet,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: borderRadiusMd),
          elevation: 2,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: violet,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: borderRadiusMd),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: violet,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: borderRadiusMd),
          side: const BorderSide(color: Color(0xFFD8DAE5)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: violet,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: borderRadiusMd),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _lightSurface,
        shape: RoundedRectangleBorder(borderRadius: borderRadiusLg),
        elevation: 8,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A1D3A),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: borderRadiusSm),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.black.withValues(alpha: 0.06),
        thickness: 1,
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: violet,
        labelColor: const Color(0xFF1A1D3A),
        unselectedLabelColor: textSecondaryLight,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFFEDE7F6),
        side: BorderSide(color: const Color(0xFFD8DAE5)),
        shape: RoundedRectangleBorder(borderRadius: borderRadiusSm),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1D3A),
        ),
        secondaryLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF5C2FE0),
        ),
        checkmarkColor: violet,
      ),
    );
  }
}
