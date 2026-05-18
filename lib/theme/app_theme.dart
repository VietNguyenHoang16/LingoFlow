import 'package:flutter/material.dart';

// ============================================================
// LingoFlowColors — ThemeExtension for app-specific colors
// ============================================================

class LingoFlowColors extends ThemeExtension<LingoFlowColors> {
  final Color masteryNew;
  final Color masteryLearning;
  final Color masteryReviewing;
  final Color masteryMastered;
  final List<List<Color>> cardPalettes;
  final List<Color> reviewBannerDue;
  final List<Color> reviewBannerDone;
  final Color navActiveBg;
  final Color navActiveContent;
  final Color navInactiveContent;
  final Color streakFire;
  final Color confettiGold;

  const LingoFlowColors({
    required this.masteryNew,
    required this.masteryLearning,
    required this.masteryReviewing,
    required this.masteryMastered,
    required this.cardPalettes,
    required this.reviewBannerDue,
    required this.reviewBannerDone,
    required this.navActiveBg,
    required this.navActiveContent,
    required this.navInactiveContent,
    required this.streakFire,
    required this.confettiGold,
  });

  static const light = LingoFlowColors(
    masteryNew: Color(0xFF9E9E9E),
    masteryLearning: Color(0xFF42A5F5),
    masteryReviewing: Color(0xFFFFA726),
    masteryMastered: Color(0xFF66BB6A),
    cardPalettes: [
      [Color(0xFF6366F1), Color(0xFF818CF8)],
      [Color(0xFFF43F5E), Color(0xFFFB7185)],
      [Color(0xFF10B981), Color(0xFF34D399)],
      [Color(0xFFF59E0B), Color(0xFFFBBF24)],
      [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    ],
    reviewBannerDue: [Color(0xFFFF6B35), Color(0xFFFFA726)],
    reviewBannerDone: [Color(0xFF2D8F4E), Color(0xFF4ADE80)],
    navActiveBg: Color(0xFFFFD600),
    navActiveContent: Color(0xFF433500),
    navInactiveContent: Color(0xFF64748B),
    streakFire: Color(0xFFFF6B35),
    confettiGold: Color(0xFFFFD600),
  );

  static const dark = LingoFlowColors(
    masteryNew: Color(0xFF757575),
    masteryLearning: Color(0xFF64B5F6),
    masteryReviewing: Color(0xFFFFB74D),
    masteryMastered: Color(0xFF81C784),
    cardPalettes: [
      [Color(0xFF818CF8), Color(0xFFA5B4FC)],
      [Color(0xFFFB7185), Color(0xFFFDA4AF)],
      [Color(0xFF34D399), Color(0xFF6EE7B7)],
      [Color(0xFFFBBF24), Color(0xFFFCD34D)],
      [Color(0xFFA78BFA), Color(0xFFC4B5FD)],
    ],
    reviewBannerDue: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
    reviewBannerDone: [Color(0xFF4CAF50), Color(0xFF81C784)],
    navActiveBg: Color(0xFFFFD600),
    navActiveContent: Color(0xFF433500),
    navInactiveContent: Color(0xFF94A3B8),
    streakFire: Color(0xFFFF8A65),
    confettiGold: Color(0xFFFFD600),
  );

  @override
  LingoFlowColors copyWith({
    Color? masteryNew,
    Color? masteryLearning,
    Color? masteryReviewing,
    Color? masteryMastered,
    List<List<Color>>? cardPalettes,
    List<Color>? reviewBannerDue,
    List<Color>? reviewBannerDone,
    Color? navActiveBg,
    Color? navActiveContent,
    Color? navInactiveContent,
    Color? streakFire,
    Color? confettiGold,
  }) {
    return LingoFlowColors(
      masteryNew: masteryNew ?? this.masteryNew,
      masteryLearning: masteryLearning ?? this.masteryLearning,
      masteryReviewing: masteryReviewing ?? this.masteryReviewing,
      masteryMastered: masteryMastered ?? this.masteryMastered,
      cardPalettes: cardPalettes ?? this.cardPalettes,
      reviewBannerDue: reviewBannerDue ?? this.reviewBannerDue,
      reviewBannerDone: reviewBannerDone ?? this.reviewBannerDone,
      navActiveBg: navActiveBg ?? this.navActiveBg,
      navActiveContent: navActiveContent ?? this.navActiveContent,
      navInactiveContent: navInactiveContent ?? this.navInactiveContent,
      streakFire: streakFire ?? this.streakFire,
      confettiGold: confettiGold ?? this.confettiGold,
    );
  }

  @override
  LingoFlowColors lerp(ThemeExtension<LingoFlowColors>? other, double t) {
    if (other is! LingoFlowColors) return this;
    return LingoFlowColors(
      masteryNew: Color.lerp(masteryNew, other.masteryNew, t)!,
      masteryLearning: Color.lerp(masteryLearning, other.masteryLearning, t)!,
      masteryReviewing: Color.lerp(masteryReviewing, other.masteryReviewing, t)!,
      masteryMastered: Color.lerp(masteryMastered, other.masteryMastered, t)!,
      cardPalettes: t < 0.5 ? cardPalettes : other.cardPalettes,
      reviewBannerDue: t < 0.5 ? reviewBannerDue : other.reviewBannerDue,
      reviewBannerDone: t < 0.5 ? reviewBannerDone : other.reviewBannerDone,
      navActiveBg: Color.lerp(navActiveBg, other.navActiveBg, t)!,
      navActiveContent: Color.lerp(navActiveContent, other.navActiveContent, t)!,
      navInactiveContent: Color.lerp(navInactiveContent, other.navInactiveContent, t)!,
      streakFire: Color.lerp(streakFire, other.streakFire, t)!,
      confettiGold: Color.lerp(confettiGold, other.confettiGold, t)!,
    );
  }
}

// ============================================================
// Color Schemes — Light & Dark
// ============================================================

const _primaryLight = Color(0xFF58CC02);
const _secondaryLight = Color(0xFFFFD600);
const _tertiaryLight = Color(0xFFFF4B4B);

const _primaryDark = Color(0xFF76FF03);
const _secondaryDark = Color(0xFFFFEA00);
const _tertiaryDark = Color(0xFFFF6E6E);

final _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: _primaryLight,
  onPrimary: Colors.white,
  primaryContainer: const Color(0xFFA5E887),
  onPrimaryContainer: const Color(0xFF1B5E00),
  secondary: _secondaryLight,
  onSecondary: const Color(0xFF433500),
  secondaryContainer: const Color(0xFFFFF176),
  onSecondaryContainer: const Color(0xFF433500),
  tertiary: _tertiaryLight,
  onTertiary: Colors.white,
  tertiaryContainer: const Color(0xFFFFCDD2),
  onTertiaryContainer: const Color(0xFFB71C1C),
  error: const Color(0xFFFF5252),
  onError: Colors.white,
  surface: const Color(0xFFFFFDF7),
  onSurface: const Color(0xFF1E293B),
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: const Color(0xFFF8F6F0),
  surfaceContainer: const Color(0xFFF1EFE8),
  surfaceContainerHigh: const Color(0xFFE8E5DC),
  onSurfaceVariant: const Color(0xFF64748B),
  outline: const Color(0xFFCBD5E1),
  outlineVariant: const Color(0xFFE2E8F0),
  shadow: const Color(0xFF1E293B),
  scrim: Colors.black26,
  inverseSurface: const Color(0xFF334155),
  onInverseSurface: const Color(0xFFF8FAFC),
  inversePrimary: const Color(0xFFA5E887),
);

final _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: _primaryDark,
  onPrimary: const Color(0xFF1B5E00),
  primaryContainer: const Color(0xFF33691E),
  onPrimaryContainer: const Color(0xFFCCFF90),
  secondary: _secondaryDark,
  onSecondary: const Color(0xFF433500),
  secondaryContainer: const Color(0xFF5D4E00),
  onSecondaryContainer: const Color(0xFFFFF9C4),
  tertiary: _tertiaryDark,
  onTertiary: const Color(0xFFB71C1C),
  tertiaryContainer: const Color(0xFF7F0000),
  onTertiaryContainer: const Color(0xFFFFCDD2),
  error: const Color(0xFFFF5252),
  onError: Colors.black,
  surface: const Color(0xFF0F172A),
  onSurface: const Color(0xFFF1F5F9),
  surfaceContainerLowest: const Color(0xFF0A0E1A),
  surfaceContainerLow: const Color(0xFF111827),
  surfaceContainer: const Color(0xFF1E293B),
  surfaceContainerHigh: const Color(0xFF334155),
  onSurfaceVariant: const Color(0xFFCBD5E1),
  outline: const Color(0xFF475569),
  outlineVariant: const Color(0xFF334155),
  shadow: Colors.black,
  scrim: Colors.black54,
  inverseSurface: const Color(0xFFF1F5F9),
  onInverseSurface: const Color(0xFF1E293B),
  inversePrimary: const Color(0xFF33691E),
);

// ============================================================
// Text Theme
// ============================================================

TextTheme _buildTextTheme(Color onSurface, Color onSurfaceVariant) {
  return TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontWeight: FontWeight.w800,
      fontSize: 57, letterSpacing: -1.5, height: 1.12,
      color: onSurface,
    ),
    displayMedium: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontWeight: FontWeight.w800,
      fontSize: 45, letterSpacing: -0.5, height: 1.16,
      color: onSurface,
    ),
    displaySmall: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontWeight: FontWeight.w800,
      fontSize: 36, letterSpacing: 0, height: 1.22,
      color: onSurface,
    ),
    headlineLarge: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontWeight: FontWeight.w700,
      fontSize: 32, letterSpacing: 0, height: 1.25,
      color: onSurface,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontWeight: FontWeight.w700,
      fontSize: 28, letterSpacing: 0, height: 1.29,
      color: onSurface,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontWeight: FontWeight.w700,
      fontSize: 24, letterSpacing: 0, height: 1.33,
      color: onSurface,
    ),
    titleLarge: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontWeight: FontWeight.w600,
      fontSize: 22, letterSpacing: 0, height: 1.27,
      color: onSurface,
    ),
    titleMedium: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontWeight: FontWeight.w600,
      fontSize: 16, letterSpacing: 0.15, height: 1.5,
      color: onSurface,
    ),
    titleSmall: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontWeight: FontWeight.w600,
      fontSize: 14, letterSpacing: 0.1, height: 1.43,
      color: onSurface,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Be Vietnam Pro',
      fontWeight: FontWeight.w400,
      fontSize: 16, letterSpacing: 0.5, height: 1.5,
      color: onSurface,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Be Vietnam Pro',
      fontWeight: FontWeight.w400,
      fontSize: 14, letterSpacing: 0.25, height: 1.43,
      color: onSurface,
    ),
    bodySmall: TextStyle(
      fontFamily: 'Be Vietnam Pro',
      fontWeight: FontWeight.w400,
      fontSize: 12, letterSpacing: 0.4, height: 1.33,
      color: onSurfaceVariant,
    ),
    labelLarge: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontWeight: FontWeight.w600,
      fontSize: 14, letterSpacing: 0.1, height: 1.43,
    ),
    labelMedium: TextStyle(
      fontFamily: 'Be Vietnam Pro',
      fontWeight: FontWeight.w500,
      fontSize: 12, letterSpacing: 0.5, height: 1.33,
    ),
    labelSmall: TextStyle(
      fontFamily: 'Be Vietnam Pro',
      fontWeight: FontWeight.w500,
      fontSize: 11, letterSpacing: 0.5, height: 1.45,
    ),
  );
}

// ============================================================
// Theme Data Builder
// ============================================================

ThemeData _buildTheme({
  required ColorScheme colorScheme,
  required LingoFlowColors lingoColors,
}) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    textTheme: _buildTextTheme(colorScheme.onSurface, colorScheme.onSurfaceVariant),

    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontWeight: FontWeight.w700,
        fontSize: 20,
        color: colorScheme.onSurface,
      ),
      iconTheme: IconThemeData(color: colorScheme.primary),
    ),

    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainerLowest,
      elevation: 2,
      shadowColor: colorScheme.shadow.withAlpha(30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      hintStyle: TextStyle(
        fontFamily: 'Be Vietnam Pro',
        color: colorScheme.onSurfaceVariant.withAlpha(128),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: SlideUpPageTransition(),
        TargetPlatform.iOS: SlideUpPageTransition(),
      },
    ),

    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
    ),

    extensions: [lingoColors],
  );
}

// ============================================================
// Public Theme Accessors
// ============================================================

class AppTheme {
  AppTheme._();

  static ThemeData get light => _buildTheme(
        colorScheme: _lightScheme,
        lingoColors: LingoFlowColors.light,
      );

  static ThemeData get dark => _buildTheme(
        colorScheme: _darkScheme,
        lingoColors: LingoFlowColors.dark,
      );
}

// ============================================================
// Convenience Extension
// ============================================================

extension LingoFlowTheme on BuildContext {
  LingoFlowColors get lingoColors =>
      Theme.of(this).extension<LingoFlowColors>() ?? LingoFlowColors.light;
}

class SlideUpPageTransition extends PageTransitionsBuilder {
  const SlideUpPageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
}
