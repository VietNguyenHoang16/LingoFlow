import 'package:flutter/material.dart';

// ============================================================
// LingoFlowColors — ThemeExtension for app-specific colors
// ============================================================

// Word type color palette (Emerald base + warm spectrum).
// Each part of speech gets its own hue so badges stay readable and lively.
const Map<String, Color> _wordTypeColorsLight = {
  'noun': Color(0xFF1D4ED8), // blue
  'verb': Color(0xFFB91C1C), // red
  'adjective': Color(0xFF7C3AED), // violet
  'adverb': Color(0xFFC2410C), // orange
  'preposition': Color(0xFF0F766E), // teal
  'conjunction': Color(0xFFA16207), // amber
  'pronoun': Color(0xFFBE185D), // pink
  'interjection': Color(0xFF4338CA), // indigo
  'phrasal_verb': Color(0xFF047857), // emerald
  'idiom': Color(0xFF9A3412), // rust
  'collocation': Color(0xFF6D28D9), // purple
  'grammar': Color(0xFF0E7490), // cyan
};

const Map<String, Color> _wordTypeColorsDark = {
  'noun': Color(0xFF60A5FA),
  'verb': Color(0xFFF87171),
  'adjective': Color(0xFFA78BFA),
  'adverb': Color(0xFFFB923C),
  'preposition': Color(0xFF2DD4BF),
  'conjunction': Color(0xFFFCD34D),
  'pronoun': Color(0xFFF472B6),
  'interjection': Color(0xFF818CF8),
  'phrasal_verb': Color(0xFF34D399),
  'idiom': Color(0xFFFDBA74),
  'collocation': Color(0xFFC4B5FD),
  'grammar': Color(0xFF22D3EE),
};

class LingoFlowColors extends ThemeExtension<LingoFlowColors> {
  final Color masteryNew;
  final Color masteryLearning;
  final Color masteryReviewing;
  final Color masteryMastered;
  final List<List<Color>> cardPalettes;
  final List<Color> reviewBannerDue;
  final List<Color> reviewBannerDone;
  final List<Color> reviewBannerGrammar;
  final Color navActiveBg;
  final Color navActiveContent;
  final Color navInactiveContent;
  final Color streakFire;
  final Color confettiGold;
  final Map<String, Color> wordTypeColors;

  const LingoFlowColors({
    required this.masteryNew,
    required this.masteryLearning,
    required this.masteryReviewing,
    required this.masteryMastered,
    required this.cardPalettes,
    required this.reviewBannerDue,
    required this.reviewBannerDone,
    required this.reviewBannerGrammar,
    required this.navActiveBg,
    required this.navActiveContent,
    required this.navInactiveContent,
    required this.streakFire,
    required this.confettiGold,
    required this.wordTypeColors,
  });

  static const light = LingoFlowColors(
    masteryNew: Color(0xFFB45309), // amber 700
    masteryLearning: Color(0xFFC2410C), // orange 700
    masteryReviewing: Color(0xFF1D4ED8), // blue 700
    masteryMastered: Color(0xFF047857), // emerald 700
    cardPalettes: [
      [Color(0xFFECFDF5), Color(0xFFA7F3D0)],
      [Color(0xFFFFF7ED), Color(0xFFFED7AA)],
      [Color(0xFFEFF6FF), Color(0xFFBFDBFE)],
    ],
    reviewBannerDue: [Color(0xFF064E3B), Color(0xFF047857)],
    reviewBannerDone: [Color(0xFFD1FAE5), Color(0xFFA7F3D0)],
    reviewBannerGrammar: [Color(0xFFB45309), Color(0xFFF59E0B)],
    navActiveBg: Color(0xFF047857),
    navActiveContent: Color(0xFFFFFFFF),
    navInactiveContent: Color(0xFF7A7164),
    streakFire: Color(0xFFEA580C),
    confettiGold: Color(0xFFF59E0B),
    wordTypeColors: _wordTypeColorsLight,
  );

  static const dark = LingoFlowColors(
    masteryNew: Color(0xFFFBBF24),
    masteryLearning: Color(0xFFFB923C),
    masteryReviewing: Color(0xFF60A5FA),
    masteryMastered: Color(0xFF34D399),
    cardPalettes: [
      [Color(0xFF052E23), Color(0xFF064E3B)],
      [Color(0xFF3B1D07), Color(0xFF5A2E0B)],
      [Color(0xFF0B1F3A), Color(0xFF122E52)],
    ],
    reviewBannerDue: [Color(0xFF047857), Color(0xFF065F46)],
    reviewBannerDone: [Color(0xFF064E3B), Color(0xFF065F46)],
    reviewBannerGrammar: [Color(0xFFB45309), Color(0xFFF59E0B)],
    navActiveBg: Color(0xFF34D399),
    navActiveContent: Color(0xFF04261A),
    navInactiveContent: Color(0xFF93A39A),
    streakFire: Color(0xFFFB923C),
    confettiGold: Color(0xFFFBBF24),
    wordTypeColors: _wordTypeColorsDark,
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
    List<Color>? reviewBannerGrammar,
    Color? navActiveBg,
    Color? navActiveContent,
    Color? navInactiveContent,
    Color? streakFire,
    Color? confettiGold,
    Map<String, Color>? wordTypeColors,
  }) {
    return LingoFlowColors(
      masteryNew: masteryNew ?? this.masteryNew,
      masteryLearning: masteryLearning ?? this.masteryLearning,
      masteryReviewing: masteryReviewing ?? this.masteryReviewing,
      masteryMastered: masteryMastered ?? this.masteryMastered,
      cardPalettes: cardPalettes ?? this.cardPalettes,
      reviewBannerDue: reviewBannerDue ?? this.reviewBannerDue,
      reviewBannerDone: reviewBannerDone ?? this.reviewBannerDone,
      reviewBannerGrammar: reviewBannerGrammar ?? this.reviewBannerGrammar,
      navActiveBg: navActiveBg ?? this.navActiveBg,
      navActiveContent: navActiveContent ?? this.navActiveContent,
      navInactiveContent: navInactiveContent ?? this.navInactiveContent,
      streakFire: streakFire ?? this.streakFire,
      confettiGold: confettiGold ?? this.confettiGold,
      wordTypeColors: wordTypeColors ?? this.wordTypeColors,
    );
  }

  @override
  LingoFlowColors lerp(ThemeExtension<LingoFlowColors>? other, double t) {
    if (other is! LingoFlowColors) return this;
    final otherColors = other.wordTypeColors;
    final mergedColors = <String, Color>{};
    for (final key in wordTypeColors.keys) {
      final o = otherColors[key] ?? wordTypeColors[key]!;
      mergedColors[key] = Color.lerp(wordTypeColors[key]!, o, t)!;
    }
    return LingoFlowColors(
      masteryNew: Color.lerp(masteryNew, other.masteryNew, t)!,
      masteryLearning:
          Color.lerp(masteryLearning, other.masteryLearning, t)!,
      masteryReviewing:
          Color.lerp(masteryReviewing, other.masteryReviewing, t)!,
      masteryMastered:
          Color.lerp(masteryMastered, other.masteryMastered, t)!,
      cardPalettes: t < 0.5 ? cardPalettes : other.cardPalettes,
      reviewBannerDue: t < 0.5 ? reviewBannerDue : other.reviewBannerDue,
      reviewBannerDone: t < 0.5 ? reviewBannerDone : other.reviewBannerDone,
      reviewBannerGrammar: t < 0.5 ? reviewBannerGrammar : other.reviewBannerGrammar,
      navActiveBg: Color.lerp(navActiveBg, other.navActiveBg, t)!,
      navActiveContent:
          Color.lerp(navActiveContent, other.navActiveContent, t)!,
      navInactiveContent:
          Color.lerp(navInactiveContent, other.navInactiveContent, t)!,
      streakFire: Color.lerp(streakFire, other.streakFire, t)!,
      confettiGold: Color.lerp(confettiGold, other.confettiGold, t)!,
      wordTypeColors: mergedColors,
    );
  }
}

// ============================================================
// Color Schemes — Light & Dark
// ============================================================

// ============================================================
// Emerald + warm cream palette
// Accent: emerald. Neutrals are tinted warm (cream/sand) so no
// surface reads as neutral gray.
// ============================================================

final _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: const Color(0xFF047857), // emerald 700
  onPrimary: const Color(0xFFFFFFFF),
  primaryContainer: const Color(0xFFD1FAE5), // emerald 100
  onPrimaryContainer: const Color(0xFF064E3B),
  secondary: const Color(0xFFB45309), // amber 700
  onSecondary: const Color(0xFFFFFFFF),
  secondaryContainer: const Color(0xFFFEF3C7), // amber 100
  onSecondaryContainer: const Color(0xFF78350F),
  tertiary: const Color(0xFF0F766E), // teal 700
  onTertiary: const Color(0xFFFFFFFF),
  tertiaryContainer: const Color(0xFFCCFBF1),
  onTertiaryContainer: const Color(0xFF134E4A),
  error: const Color(0xFFDC2626),
  onError: const Color(0xFFFFFFFF),
  errorContainer: const Color(0xFFFEE2E2),
  onErrorContainer: const Color(0xFF7F1D1D),
  surface: const Color(0xFFFFFCF6), // warm ivory
  onSurface: const Color(0xFF1B1A17),
  surfaceContainerLowest: const Color(0xFFFFFFFF),
  surfaceContainerLow: const Color(0xFFFAF5EC),
  surfaceContainer: const Color(0xFFF4EDE0),
  surfaceContainerHigh: const Color(0xFFEDE4D4),
  surfaceContainerHighest: const Color(0xFFE5DAC6),
  onSurfaceVariant: const Color(0xFF6B6357), // warm taupe
  outline: const Color(0xFFD5C9B6),
  outlineVariant: const Color(0xFFE8DFCF),
  shadow: const Color(0xFF3B2F1F),
  scrim: const Color(0x661B1A17),
  inverseSurface: const Color(0xFF1B1A17),
  onInverseSurface: const Color(0xFFFAF5EC),
  inversePrimary: const Color(0xFF6EE7B7),
);

final _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: const Color(0xFF34D399), // emerald 400
  onPrimary: const Color(0xFF04261A),
  primaryContainer: const Color(0xFF065F46),
  onPrimaryContainer: const Color(0xFFD1FAE5),
  secondary: const Color(0xFFFBBF24), // amber 400
  onSecondary: const Color(0xFF3B2606),
  secondaryContainer: const Color(0xFF78350F),
  onSecondaryContainer: const Color(0xFFFEF3C7),
  tertiary: const Color(0xFF2DD4BF), // teal 400
  onTertiary: const Color(0xFF04201C),
  tertiaryContainer: const Color(0xFF134E4A),
  onTertiaryContainer: const Color(0xFFCCFBF1),
  error: const Color(0xFFF87171),
  onError: const Color(0xFF450A0A),
  errorContainer: const Color(0xFF7F1D1D),
  onErrorContainer: const Color(0xFFFEE2E2),
  surface: const Color(0xFF0C1210), // deep green-black, not pure black
  onSurface: const Color(0xFFF4F1E9),
  surfaceContainerLowest: const Color(0xFF080C0A),
  surfaceContainerLow: const Color(0xFF111815),
  surfaceContainer: const Color(0xFF16201B),
  surfaceContainerHigh: const Color(0xFF1D2923),
  surfaceContainerHighest: const Color(0xFF24332B),
  onSurfaceVariant: const Color(0xFFA7B3AB),
  outline: const Color(0xFF46554C),
  outlineVariant: const Color(0xFF26332C),
  shadow: const Color(0xFF000000),
  scrim: const Color(0xCC000000),
  inverseSurface: const Color(0xFFF4F1E9),
  onInverseSurface: const Color(0xFF14100C),
  inversePrimary: const Color(0xFF047857),
);

// ============================================================
// Text Theme
// ============================================================

TextTheme _buildTextTheme(Color onSurface, Color onSurfaceVariant) {
  return TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontWeight: FontWeight.w800,
      fontSize: 57,
      letterSpacing: -1.5,
      height: 1.12,
      color: onSurface,
    ),
    displayMedium: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontWeight: FontWeight.w800,
      fontSize: 45,
      letterSpacing: -0.5,
      height: 1.16,
      color: onSurface,
    ),
    displaySmall: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontWeight: FontWeight.w800,
      fontSize: 36,
      letterSpacing: 0,
      height: 1.22,
      color: onSurface,
    ),
    headlineLarge: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontWeight: FontWeight.w700,
      fontSize: 32,
      letterSpacing: -0.5,
      height: 1.25,
      color: onSurface,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontWeight: FontWeight.w700,
      fontSize: 28,
      letterSpacing: -0.3,
      height: 1.29,
      color: onSurface,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontWeight: FontWeight.w700,
      fontSize: 24,
      letterSpacing: -0.2,
      height: 1.33,
      color: onSurface,
    ),
    titleLarge: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontWeight: FontWeight.w700,
      fontSize: 20,
      letterSpacing: -0.1,
      height: 1.4,
      color: onSurface,
    ),
    titleMedium: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontWeight: FontWeight.w600,
      fontSize: 16,
      letterSpacing: 0,
      height: 1.5,
      color: onSurface,
    ),
    titleSmall: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontWeight: FontWeight.w600,
      fontSize: 14,
      letterSpacing: 0,
      height: 1.43,
      color: onSurface,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Be Vietnam Pro',
      fontWeight: FontWeight.w400,
      fontSize: 16,
      letterSpacing: 0.15,
      height: 1.6,
      color: onSurface,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Be Vietnam Pro',
      fontWeight: FontWeight.w400,
      fontSize: 14,
      letterSpacing: 0.1,
      height: 1.5,
      color: onSurface,
    ),
    bodySmall: TextStyle(
      fontFamily: 'Be Vietnam Pro',
      fontWeight: FontWeight.w400,
      fontSize: 12,
      letterSpacing: 0.2,
      height: 1.5,
      color: onSurfaceVariant,
    ),
    labelLarge: TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontWeight: FontWeight.w700,
      fontSize: 14,
      letterSpacing: 0.1,
      height: 1.43,
    ),
    labelMedium: TextStyle(
      fontFamily: 'Be Vietnam Pro',
      fontWeight: FontWeight.w600,
      fontSize: 12,
      letterSpacing: 0.3,
      height: 1.33,
    ),
    labelSmall: TextStyle(
      fontFamily: 'Be Vietnam Pro',
      fontWeight: FontWeight.w600,
      fontSize: 11,
      letterSpacing: 0.4,
      height: 1.45,
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
  final isDark = colorScheme.brightness == Brightness.dark;

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    textTheme: _buildTextTheme(
        colorScheme.onSurface, colorScheme.onSurfaceVariant),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontWeight: FontWeight.w700,
        fontSize: 20,
        letterSpacing: -0.1,
        color: colorScheme.onSurface,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainerLowest,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? colorScheme.surfaceContainerLow
          : colorScheme.surfaceContainerLowest,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: colorScheme.outlineVariant, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: colorScheme.error, width: 1),
      ),
      hintStyle: TextStyle(
        fontFamily: 'Be Vietnam Pro',
        color: colorScheme.onSurfaceVariant.withAlpha(160),
        fontSize: 14,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: 0,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: colorScheme.shadow.withAlpha(40),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: TextStyle(
        fontFamily: 'Be Vietnam Pro',
        color: colorScheme.onInverseSurface,
        fontSize: 14,
      ),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: isDark
          ? colorScheme.surfaceContainerHigh
          : colorScheme.primaryContainer.withAlpha(140),
      labelStyle: TextStyle(
        fontFamily: 'Be Vietnam Pro',
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: colorScheme.onSurface,
      ),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: isDark ? colorScheme.outline : colorScheme.outlineVariant, width: 1),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: SlideUpPageTransition(),
        TargetPlatform.iOS: SlideUpPageTransition(),
        TargetPlatform.windows: SlideUpPageTransition(),
        TargetPlatform.macOS: SlideUpPageTransition(),
        TargetPlatform.linux: SlideUpPageTransition(),
        TargetPlatform.fuchsia: SlideUpPageTransition(),
      },
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: colorScheme.primary,
      inactiveTrackColor: colorScheme.outlineVariant,
      thumbColor: colorScheme.primary,
      overlayColor: colorScheme.primary.withAlpha(30),
      trackHeight: 4,
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
      Theme.of(this).extension<LingoFlowColors>() ??
      LingoFlowColors.light;
}

// ============================================================
// Page Transitions
// ============================================================

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
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      )),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
        ),
        child: child,
      ),
    );
  }
}
