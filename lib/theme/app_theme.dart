import 'package:flutter/material.dart';

// ============================================================
// LingoFlowColors — ThemeExtension for app-specific colors
// ============================================================

// Word type color palette (Monochrome & Muted Slate).
// Subtle, elegant tones suitable for modern editorial learning apps.
const Map<String, Color> _wordTypeColorsLight = {
  'noun': Color(0xFF000000),         // Pure black
  'verb': Color(0xFF1F1F1F),         // Neutral dark
  'adjective': Color(0xFF3D3D3D),
  'adverb': Color(0xFF3D3D3D),
  'preposition': Color(0xFF5C5C5C),
  'conjunction': Color(0xFF5C5C5C),
  'pronoun': Color(0xFF1F1F1F),
  'interjection': Color(0xFF3D3D3D),
  'phrasal_verb': Color(0xFF000000),
  'idiom': Color(0xFF000000),
  'collocation': Color(0xFF1F1F1F),
  'grammar': Color(0xFF000000),
};

const Map<String, Color> _wordTypeColorsDark = {
  'noun': Color(0xFFFFFFFF),         // Pure white
  'verb': Color(0xFFE0E0E0),
  'adjective': Color(0xFFC2C2C2),
  'adverb': Color(0xFFC2C2C2),
  'preposition': Color(0xFFA3A3A3),
  'conjunction': Color(0xFFA3A3A3),
  'pronoun': Color(0xFFE0E0E0),
  'interjection': Color(0xFFC2C2C2),
  'phrasal_verb': Color(0xFFFFFFFF),
  'idiom': Color(0xFFFFFFFF),
  'collocation': Color(0xFFE0E0E0),
  'grammar': Color(0xFFFFFFFF),
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
    masteryNew: Color(0xFF8C8C8C),
    masteryLearning: Color(0xFF555555),
    masteryReviewing: Color(0xFF1F1F1F),
    masteryMastered: Color(0xFF000000),
    cardPalettes: [
      [Color(0xFF000000), Color(0xFF000000)],
      [Color(0xFF000000), Color(0xFF000000)],
      [Color(0xFF000000), Color(0xFF000000)],
    ],
    reviewBannerDue: [Color(0xFF000000), Color(0xFF000000)],
    reviewBannerDone: [Color(0xFF000000), Color(0xFF000000)],
    reviewBannerGrammar: [Color(0xFF000000), Color(0xFF000000)],
    navActiveBg: Color(0xFF000000),
    navActiveContent: Colors.white,
    navInactiveContent: Color(0xFF666666),
    streakFire: Color(0xFF000000),
    confettiGold: Color(0xFF000000),
    wordTypeColors: _wordTypeColorsLight,
  );

  static const dark = LingoFlowColors(
    masteryNew: Color(0xFF8C8C8C),
    masteryLearning: Color(0xFFB8B8B8),
    masteryReviewing: Color(0xFFE0E0E0),
    masteryMastered: Color(0xFFFFFFFF),
    cardPalettes: [
      [Color(0xFF000000), Color(0xFF000000)],
      [Color(0xFF000000), Color(0xFF000000)],
      [Color(0xFF000000), Color(0xFF000000)],
    ],
    reviewBannerDue: [Color(0xFF000000), Color(0xFF000000)],
    reviewBannerDone: [Color(0xFF000000), Color(0xFF000000)],
    reviewBannerGrammar: [Color(0xFF000000), Color(0xFF000000)],
    navActiveBg: Color(0xFFFFFFFF),
    navActiveContent: Color(0xFF000000),
    navInactiveContent: Color(0xFFB3B3B3),
    streakFire: Color(0xFFFFFFFF),
    confettiGold: Color(0xFFFFFFFF),
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
// Monochrome (Black & White) palette
// ============================================================

const _primaryLight = Color(0xFF000000);   // Pure black
const _secondaryLight = Color(0xFF000000); // Pure black
const _tertiaryLight = Color(0xFF666666);  // Neutral

const _primaryDark = Color(0xFFFFFFFF);    // Pure white
const _secondaryDark = Color(0xFFFFFFFF);  // Pure white
const _tertiaryDark = Color(0xFFB3B3B3);   // Neutral

final _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: _primaryLight,
  onPrimary: Colors.white,
  primaryContainer: const Color(0xFFFFFFFF),   // Pure white
  onPrimaryContainer: const Color(0xFF000000), // Pure black
  secondary: _secondaryLight,
  onSecondary: Colors.white,
  secondaryContainer: const Color(0xFFF2F2F2),
  onSecondaryContainer: const Color(0xFF000000),
  tertiary: _tertiaryLight,
  onTertiary: Colors.white,
  tertiaryContainer: const Color(0xFFF4F4F5),
  onTertiaryContainer: const Color(0xFF18181B),
  error: const Color(0xFFDC2626),
  onError: Colors.white,
  surface: const Color(0xFFFFFFFF),            // Clean white
  onSurface: const Color(0xFF000000),          // Pure black
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: const Color(0xFFFAFAFA),
  surfaceContainer: const Color(0xFFF7F7F7),
  surfaceContainerHigh: const Color(0xFFEDEDED),
  onSurfaceVariant: const Color(0xFF666666),   // Neutral text gray
  outline: const Color(0xFFD4D4D8),            // Hairline 1px border
  outlineVariant: const Color(0xFFE7E7E7),     // Hairline 1px border
  shadow: Colors.black,
  scrim: Colors.black26,
  inverseSurface: const Color(0xFF000000),
  onInverseSurface: const Color(0xFFFFFFFF),
  inversePrimary: const Color(0xFF000000),
);

final _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: _primaryDark,
  onPrimary: const Color(0xFF000000),
  primaryContainer: const Color(0xFF000000),   // Pure black card
  onPrimaryContainer: const Color(0xFFFFFFFF),
  secondary: _secondaryDark,
  onSecondary: const Color(0xFF000000),
  secondaryContainer: const Color(0xFF0D0D0D),
  onSecondaryContainer: const Color(0xFFFFFFFF),
  tertiary: _tertiaryDark,
  onTertiary: Colors.white,
  tertiaryContainer: const Color(0xFF000000),
  onTertiaryContainer: const Color(0xFFFFFFFF),
  error: const Color(0xFFEF4444),
  onError: Colors.black,
  surface: const Color(0xFF000000),            // Pure obsidian black
  onSurface: const Color(0xFFFFFFFF),          // Pure white
  surfaceContainerLowest: const Color(0xFF000000),
  surfaceContainerLow: const Color(0xFF000000),
  surfaceContainer: const Color(0xFF000000),
  surfaceContainerHigh: const Color(0xFF0D0D0D),
  onSurfaceVariant: const Color(0xFFB3B3B3),   // Neutral text on black
  outline: const Color(0xFF666666),
  outlineVariant: const Color(0xFF3D3D3D),     // Hairline 1px border dark
  shadow: Colors.black,
  scrim: Colors.black54,
  inverseSurface: const Color(0xFFFFFFFF),
  onInverseSurface: const Color(0xFF000000),
  inversePrimary: const Color(0xFF000000),
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
      backgroundColor: colorScheme.surfaceContainerLow,
      labelStyle: TextStyle(
        fontFamily: 'Be Vietnam Pro',
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: colorScheme.onSurface,
      ),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
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
