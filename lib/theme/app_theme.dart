import 'package:flutter/material.dart';

// ============================================================
// LingoFlowColors — ThemeExtension for app-specific colors
// ============================================================

// Word type color palette (11 parts of speech).
// Light = mid-saturation 500-600, Dark = lighter 400 for legibility on dark bg.
// Distinct from mastery colors and cardPalettes.
const Map<String, Color> _wordTypeColorsLight = {
  'noun': Color(0xFF0EA5E9),         // Sky 500
  'verb': Color(0xFF16A34A),         // Green 600
  'adjective': Color(0xFFD97706),    // Amber 600
  'adverb': Color(0xFF7C3AED),       // Violet 600
  'preposition': Color(0xFF64748B),  // Slate 500
  'conjunction': Color(0xFF475569),  // Slate 600
  'pronoun': Color(0xFF0891B2),      // Cyan 600
  'interjection': Color(0xFFDB2777), // Pink 600
  'phrasal_verb': Color(0xFFEA580C), // Orange 600
  'idiom': Color(0xFF9333EA),        // Purple 600
  'collocation': Color(0xFF0D9488),  // Teal 600
  'grammar': Color(0xFF1E40AF),      // Blue 800
};

const Map<String, Color> _wordTypeColorsDark = {
  'noun': Color(0xFF38BDF8),         // Sky 400
  'verb': Color(0xFF4ADE80),         // Green 400
  'adjective': Color(0xFFFBBF24),    // Amber 400
  'adverb': Color(0xFF8B5CF6),       // Violet 500 (avoid cardPalettes dark Violet 400)
  'preposition': Color(0xFF94A3B8),  // Slate 400
  'conjunction': Color(0xFF64748B),  // Slate 500
  'pronoun': Color(0xFF22D3EE),      // Cyan 400
  'interjection': Color(0xFFF472B6), // Pink 400
  'phrasal_verb': Color(0xFFFB923C), // Orange 400
  'idiom': Color(0xFFC084FC),        // Purple 400
  'collocation': Color(0xFF2DD4BF),  // Teal 400
  'grammar': Color(0xFF60A5FA),      // Blue 400
};

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
  final Map<String, Color> wordTypeColors;

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
    required this.wordTypeColors,
  });

  static const light = LingoFlowColors(
    masteryNew: Color(0xFF9E9E9E),
    masteryLearning: Color(0xFF3B82F6),    // Blue 500
    masteryReviewing: Color(0xFFF59E0B),   // Amber 500
    masteryMastered: Color(0xFF10B981),    // Emerald 500
    cardPalettes: [
      [Color(0xFF6366F1), Color(0xFF818CF8)],  // Indigo
      [Color(0xFFF43F5E), Color(0xFFFB7185)],  // Rose
      [Color(0xFF10B981), Color(0xFF34D399)],  // Emerald
      [Color(0xFFF59E0B), Color(0xFFFBBF24)],  // Amber
      [Color(0xFF8B5CF6), Color(0xFFA78BFA)],  // Violet
    ],
    reviewBannerDue: [Color(0xFF6366F1), Color(0xFF818CF8)],
    reviewBannerDone: [Color(0xFF10B981), Color(0xFF34D399)],
    navActiveBg: Color(0xFF6366F1),
    navActiveContent: Colors.white,
    navInactiveContent: Color(0xFF94A3B8),
    streakFire: Color(0xFFF59E0B),
    confettiGold: Color(0xFFFFD600),
    wordTypeColors: _wordTypeColorsLight,
  );

  static const dark = LingoFlowColors(
    masteryNew: Color(0xFF757575),
    masteryLearning: Color(0xFF60A5FA),    // Blue 400
    masteryReviewing: Color(0xFFFBBF24),   // Amber 400
    masteryMastered: Color(0xFF34D399),    // Emerald 400
    cardPalettes: [
      [Color(0xFF818CF8), Color(0xFFA5B4FC)],  // Indigo
      [Color(0xFFFB7185), Color(0xFFFDA4AF)],  // Rose
      [Color(0xFF34D399), Color(0xFF6EE7B7)],  // Emerald
      [Color(0xFFFBBF24), Color(0xFFFCD34D)],  // Amber
      [Color(0xFFA78BFA), Color(0xFFC4B5FD)],  // Violet
    ],
    reviewBannerDue: [Color(0xFF818CF8), Color(0xFFA5B4FC)],
    reviewBannerDone: [Color(0xFF34D399), Color(0xFF6EE7B7)],
    navActiveBg: Color(0xFF818CF8),
    navActiveContent: Color(0xFF1E1B4B),
    navInactiveContent: Color(0xFF64748B),
    streakFire: Color(0xFFFBBF24),
    confettiGold: Color(0xFFFFD600),
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
// Indigo color palette
// ============================================================

const _primaryLight = Color(0xFF6366F1);   // Indigo 500
const _secondaryLight = Color(0xFFFFD600); // Yellow accent
const _tertiaryLight = Color(0xFFF43F5E);  // Rose

const _primaryDark = Color(0xFF818CF8);    // Indigo 400 (lighter for dark bg)
const _secondaryDark = Color(0xFFFFEA00);
const _tertiaryDark = Color(0xFFFB7185);

final _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: _primaryLight,
  onPrimary: Colors.white,
  primaryContainer: const Color(0xFFE0E7FF),   // Indigo 100
  onPrimaryContainer: const Color(0xFF312E81), // Indigo 900
  secondary: _secondaryLight,
  onSecondary: const Color(0xFF433500),
  secondaryContainer: const Color(0xFFFFF9C4),
  onSecondaryContainer: const Color(0xFF433500),
  tertiary: _tertiaryLight,
  onTertiary: Colors.white,
  tertiaryContainer: const Color(0xFFFFE4E8),
  onTertiaryContainer: const Color(0xFF9F1239),
  error: const Color(0xFFEF4444),
  onError: Colors.white,
  surface: const Color(0xFFF8F8FF),            // Very light indigo tint
  onSurface: const Color(0xFF1E1B4B),          // Indigo 950
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: const Color(0xFFF0F0FB),
  surfaceContainer: const Color(0xFFE8E8F6),
  surfaceContainerHigh: const Color(0xFFDDDDF2),
  onSurfaceVariant: const Color(0xFF6366A0),
  outline: const Color(0xFFC7C7E8),
  outlineVariant: const Color(0xFFDEDEF4),
  shadow: const Color(0xFF1E1B4B),
  scrim: Colors.black26,
  inverseSurface: const Color(0xFF312E81),
  onInverseSurface: const Color(0xFFEEF2FF),
  inversePrimary: const Color(0xFFA5B4FC),     // Indigo 300
);

final _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: _primaryDark,
  onPrimary: const Color(0xFF1E1B4B),
  primaryContainer: const Color(0xFF3730A3),   // Indigo 700
  onPrimaryContainer: const Color(0xFFE0E7FF),
  secondary: _secondaryDark,
  onSecondary: const Color(0xFF3A2D00),
  secondaryContainer: const Color(0xFF4D3D00),
  onSecondaryContainer: const Color(0xFFFFF9C4),
  tertiary: _tertiaryDark,
  onTertiary: const Color(0xFF9F1239),
  tertiaryContainer: const Color(0xFF881337),
  onTertiaryContainer: const Color(0xFFFFE4E8),
  error: const Color(0xFFF87171),
  onError: Colors.black,
  surface: const Color(0xFF0F0E1A),            // Very dark indigo
  onSurface: const Color(0xFFEEEFFF),
  surfaceContainerLowest: const Color(0xFF09091A),
  surfaceContainerLow: const Color(0xFF161528),
  surfaceContainer: const Color(0xFF1E1D35),
  surfaceContainerHigh: const Color(0xFF27264A),
  onSurfaceVariant: const Color(0xFFA5B4FC),   // Indigo 300
  outline: const Color(0xFF4A4880),
  outlineVariant: const Color(0xFF2E2D5A),
  shadow: Colors.black,
  scrim: Colors.black54,
  inverseSurface: const Color(0xFFEEEFFF),
  onInverseSurface: const Color(0xFF1E1D35),
  inversePrimary: const Color(0xFF4338CA),     // Indigo 600
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
          borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 6,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? colorScheme.surfaceContainerLow
          : colorScheme.surfaceContainerLowest,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
            color: colorScheme.outlineVariant, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
            BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
            BorderSide(color: colorScheme.error, width: 1.5),
      ),
      hintStyle: TextStyle(
        fontFamily: 'Be Vietnam Pro',
        color: colorScheme.onSurfaceVariant.withAlpha(140),
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
            borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(
            horizontal: 24, vertical: 16),
        textStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontWeight: FontWeight.w700,
          fontSize: 16,
          letterSpacing: 0,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: colorScheme.outline, width: 1.5),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(
            horizontal: 24, vertical: 16),
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
