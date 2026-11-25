// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/rounded_square_border.dart';

class AppColors {
  // Light
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF1F5F9);
  static const Color lightPrimary = Color(0xFF2563EB);

  // Dark
  static const Color darkBg = Color(0xFF141218);
  static const Color darkCard = Color(0xFF2B2930);
  static const Color darkSurface = Color(0xFF211F26);
  static const Color darkPrimary = Color(0xFFD0BCFF);

  // Shared Fintech Accents
  static const Color primary = Color(0xFF2563EB);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color darkBorder = Color(0xFF36343B);
  static const Color good = Color(0xFF10B981);       // Emerald
  static const Color fair = Color(0xFFF59E0B);       // Amber
  static const Color poor = Color(0xFFEF4444);       // Coral
  static const Color borrowed = Color(0xFFF59E0B);   // Amber
  static const Color available = Color(0xFF10B981);  // Emerald
  static const Color laptopColor = Color(0xFF2E7D32); // Forest Green
  static const Color networkColor = Color(0xFF8B5CF6); // Electric Violet
  static const Color printerColor = Color(0xFF06B6D4); // Cyan
  static const Color electronicColor = Color(0xFF6366F1); // Indigo
  static const Color employeeColor = Color(0xFF0EA5E9); // Sky
  static const Color expenseColor = Color(0xFFEC4899); // Rose
  static const Color billColor = Color(0xFF8B5CF6); // Purple
  static const Color subscriptionColor = Color(0xFFF43F5E); // Red-Rose
  static const Color vendorColor = Color(0xFF0284C7); // Cyan-Blue

  /// Returns context-aware card background surface color respecting AMOLED dark mode.
  static Color cardSurface(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final isAmoled = isDark && bg == Colors.black;
    if (isAmoled) {
      return const Color(0xFF121212);
    }
    return isDark ? darkCard : lightCard;
  }
}

// ── Seed colors ─────────────────────────────────────────────────────────────
const Map<String, Color> kSeedColors = {
  'violet': Color(0xFF6750A4),
  'blue': Color(0xFF0061A4),
  'green': Color(0xFF386A1F),
  'rose': Color(0xFF9C4257),
  'amber': Color(0xFF785900),
  'teal': Color(0xFF006874),
  'orange': Color(0xFFBF360C),
  'indigo': Color(0xFF283593),
  'cyan': Color(0xFF00838F),
  'pink': Color(0xFFAD1457),
  'lime': Color(0xFF558B2F),
  'deep_purple': Color(0xFF4527A0),
  'crimson': Color(0xFFB71C1C),
  'midnight': Color(0xFF1A237E),
  // Greens
  'forest': Color(0xFF1B5E20),
  'mint': Color(0xFF00695C),
  'olive': Color(0xFF827717),
  'sage': Color(0xFF33691E),
  // Blues
  'sky': Color(0xFF0277BD),
  'navy': Color(0xFF0D47A1),
  'cobalt': Color(0xFF1565C0),
  'ocean': Color(0xFF006064),
  // Others
  'coral': Color(0xFFD84315),
  'gold': Color(0xFFF9A825),
  'slate': Color(0xFF37474F),
  'magenta': Color(0xFF880E4F),
  'turquoise': Color(0xFF004D40),
  'brown': Color(0xFF4E342E),
  'lavender': Color(0xFF6A1B9A),
};

const Map<String, String> kSeedLabels = {
  'violet': 'Violet',
  'blue': 'Blue',
  'green': 'Green',
  'rose': 'Rose',
  'amber': 'Amber',
  'teal': 'Teal',
  'orange': 'Orange',
  'indigo': 'Indigo',
  'cyan': 'Cyan',
  'pink': 'Pink',
  'lime': 'Lime',
  'deep_purple': 'Deep Purple',
  'crimson': 'Crimson',
  'midnight': 'Midnight',
  'forest': 'Forest',
  'mint': 'Mint',
  'olive': 'Olive',
  'sage': 'Sage',
  'sky': 'Sky Blue',
  'navy': 'Navy',
  'cobalt': 'Cobalt',
  'ocean': 'Ocean',
  'coral': 'Coral',
  'gold': 'Gold',
  'slate': 'Slate',
  'magenta': 'Magenta',
  'turquoise': 'Turquoise',
  'brown': 'Brown',
  'lavender': 'Lavender',
};

Color seedColor(String key) => kSeedColors[key] ?? const Color(0xFF6750A4);

// ── Fonts ─────────────────────────────────────────────────────────────────────
/// Key stored in AppSettings.appFont → display label shown in Settings UI.
const Map<String, String> kFonts = {
  'default': 'System Default',
  'plus_jakarta_sans': 'Plus Jakarta Sans',
  'dm_sans': 'DM Sans',
  'inter': 'Inter',
  'nunito_sans': 'Nunito Sans',
  'space_grotesk': 'Space Grotesk',
  'outfit': 'Outfit',
  'sora': 'Sora',
  'poppins': 'Poppins',
  'nunito': 'Nunito',
  'jetbrains_mono': 'JetBrains Mono',
};

TextTheme _applyFont(String font, TextTheme base) {
  switch (font) {
    case 'plus_jakarta_sans':
      return GoogleFonts.plusJakartaSansTextTheme(base);
    case 'dm_sans':
      return GoogleFonts.dmSansTextTheme(base);
    case 'inter':
      return GoogleFonts.interTextTheme(base);
    case 'nunito_sans':
      return GoogleFonts.nunitoSansTextTheme(base);
    case 'space_grotesk':
      return GoogleFonts.spaceGroteskTextTheme(base);
    case 'outfit':
      return GoogleFonts.outfitTextTheme(base);
    case 'sora':
      return GoogleFonts.soraTextTheme(base);
    case 'poppins':
      return GoogleFonts.poppinsTextTheme(base);
    case 'nunito':
      return GoogleFonts.nunitoTextTheme(base);
    case 'jetbrains_mono':
      return GoogleFonts.jetBrainsMonoTextTheme(base);
    default:
      return base; // Flutter default
  }
}

/// themeMode: 'system' | 'light' | 'dark'
ThemeMode resolveThemeMode(String mode) {
  switch (mode) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

/// [dynamicScheme] — when provided (Android 12+),
/// uses the device's wallpaper-extracted palette instead of [seed].
/// [amoled] — forces pure-black surfaces on any dark theme.
ThemeData buildTheme({
  required String seed,
  required bool dark,
  bool amoled = false,
  String appFont = 'default',
  ColorScheme? dynamicScheme,
}) {
  final ColorScheme base;

  if (dynamicScheme != null) {
    // Device palette: apply AMOLED surface override if requested.
    base = (dark && amoled)
        ? dynamicScheme.copyWith(
            surface: Colors.black,
            onSurface: const Color(0xFFF8FAFC),
            onSurfaceVariant: const Color(0xFFCBD5E1),
            surfaceContainerLowest: const Color(0xFF0C0C10),
            surfaceContainerLow: const Color(0xFF141419),
            surfaceContainer: const Color(0xFF1A1A22),
            surfaceContainerHigh: const Color(0xFF22222C),
            surfaceContainerHighest: const Color(0xFF2B2B38),
            outline: const Color(0xFF4C4C5E),
            outlineVariant: const Color(0xFF383848),
          )
        : dynamicScheme;
  } else {
    final sColor = kSeedColors[seed] ?? const Color(0xFF6750A4);
    final seeded = ColorScheme.fromSeed(
      seedColor: sColor,
      brightness: dark ? Brightness.dark : Brightness.light,
    );
    base = (dark && amoled)
        ? seeded.copyWith(
            surface: Colors.black,
            onSurface: const Color(0xFFF8FAFC),
            onSurfaceVariant: const Color(0xFFCBD5E1),
            surfaceContainerLowest: const Color(0xFF0C0C10),
            surfaceContainerLow: const Color(0xFF141419),
            surfaceContainer: const Color(0xFF1A1A22),
            surfaceContainerHigh: const Color(0xFF22222C),
            surfaceContainerHighest: const Color(0xFF2B2B38),
            outline: const Color(0xFF4C4C5E),
            outlineVariant: const Color(0xFF383848),
          )
        : seeded;
  }

  return _base(base, appFont, isAmoled: dark && amoled);
}

ThemeData _base(ColorScheme cs, String appFont, {bool isAmoled = false}) {
  final baseTextTheme = ThemeData(brightness: cs.brightness).textTheme;
  final fontTextTheme = _applyFont(appFont, baseTextTheme);

  const tabularFigures = [FontFeature.tabularFigures()];
  final readableTextTheme = fontTextTheme.copyWith(
    headlineLarge: fontTextTheme.headlineLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      fontFeatures: tabularFigures,
    ),
    headlineMedium: fontTextTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      fontFeatures: tabularFigures,
    ),
    headlineSmall: fontTextTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      fontFeatures: tabularFigures,
    ),
    titleLarge: fontTextTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      fontFeatures: tabularFigures,
    ),
    titleMedium: fontTextTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: tabularFigures,
    ),
    titleSmall: fontTextTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 14,
      fontFeatures: tabularFigures,
    ),
    bodyLarge: fontTextTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w500,
      fontFeatures: tabularFigures,
    ),
    bodyMedium: fontTextTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w500,
      fontFeatures: tabularFigures,
    ),
    bodySmall: fontTextTheme.bodySmall?.copyWith(
      color: isAmoled ? const Color(0xFF94A3B8) : cs.onSurface.withValues(alpha: 0.65),
      fontSize: 12,
      fontWeight: FontWeight.w500,
      fontFeatures: tabularFigures,
    ),
    labelLarge: fontTextTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      fontFeatures: tabularFigures,
    ),
    labelSmall: fontTextTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 11,
      letterSpacing: 0.5,
      color: isAmoled ? const Color(0xFF94A3B8) : cs.onSurface.withValues(alpha: 0.7),
      fontFeatures: tabularFigures,
    ),
  );

  return ThemeData(
    colorScheme: cs,
    scaffoldBackgroundColor: cs.surface,
    useMaterial3: true,
    textTheme: readableTextTheme,
    // Android 15+ predictive back gesture support with smooth Cupertino transitions.
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: cs.onSurface,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            cs.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            cs.brightness == Brightness.dark ? Brightness.dark : Brightness.light,
      ),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: cs.onSurface,
        letterSpacing: -0.3,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorShape: const RoundedSquareBorder(
        borderRadius: 14,
        size: 40,
      ),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final style = readableTextTheme.labelMedium ?? const TextStyle();
        if (states.contains(WidgetState.selected)) {
          return style.copyWith(
              fontSize: (style.fontSize ?? 12) - 1,
              fontWeight: FontWeight.bold);
        }
        return style.copyWith(fontSize: (style.fontSize ?? 12) - 1);
      }),
    ),
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isAmoled
            ? const BorderSide(color: Color(0xFF282834), width: 1)
            : BorderSide.none,
      ),
      elevation: 0,
      color: isAmoled
          ? const Color(0xFF131318)
          : cs.surfaceContainerHighest.withValues(alpha: 0.3),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: isAmoled ? const Color(0xFF131318) : cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: isAmoled ? const Color(0xFF131318) : cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isAmoled
              ? const Color(0xFF2E2E3C)
              : cs.outlineVariant.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textColor: isAmoled ? const Color(0xFFF8FAFC) : null,
      iconColor: isAmoled ? const Color(0xFFCBD5E1) : null,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isAmoled
          ? const Color(0xFF131318)
          : cs.surfaceContainerHighest.withValues(alpha: 0.3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isAmoled
              ? const Color(0xFF2E2E3C)
              : cs.outlineVariant.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.error, width: 2),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isAmoled
          ? const Color(0xFF1B1B22)
          : (cs.brightness == Brightness.dark ? const Color(0xFF22222E) : cs.surfaceContainerHighest),
      elevation: 6,
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: isAmoled
          ? const Color(0xFF262632)
          : cs.outlineVariant.withValues(alpha: 0.18),
      thickness: 1,
      space: 24,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: readableTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: readableTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(
          color: isAmoled
              ? const Color(0xFF2E2E3C)
              : cs.outlineVariant.withValues(alpha: 0.35),
        ),
        textStyle: readableTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: readableTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

/// Fixed-width, highly legible font specifically tuned for emails, passwords,
/// serial numbers, and security credentials where uppercase 'I' (eye), lowercase 'l' (el),
/// and digit '1' (one) or '0' (zero) and 'O' (oh) must be distinctly recognizable.
TextStyle credentialFont({
  TextStyle? baseStyle,
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? letterSpacing,
}) {
  return GoogleFonts.jetBrainsMono(
    textStyle: baseStyle,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
  );
}

