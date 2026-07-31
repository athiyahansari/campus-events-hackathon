import 'package:flutter/material.dart';

/// Spacing scale — use these instead of ad-hoc numbers so gaps stay consistent
/// across screens (4/8/12/16/24/32 rhythm).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radius scale.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;
}

/// Brand constants that do NOT change between light and dark.
abstract final class AppBrand {
  /// Deep navy — headers, primary text, brand chrome.
  static const Color navy = Color(0xFF1E2F4D);

  /// Vivid blue — primary CTA / selected state.
  static const Color accent = Color(0xFF3366FF);
}

/// Every colour a screen should need, resolved for the current brightness.
///
/// Screens read these via `context.palette` rather than hardcoding
/// `Colors.white` / `Colors.black54`, which is what previously made dark mode
/// render unreadable.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color brand;
  final Color accent;

  /// Page background (behind cards).
  final Color background;

  /// Card / sheet background.
  final Color surface;

  /// Subtle fill for search fields, unselected chips, image placeholders.
  final Color surfaceAlt;

  /// Colour of the top app bar.
  final Color appBar;

  /// Text that sits on top of [appBar].
  final Color onAppBar;

  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color highlight;

  /// Shadow used by raised cards.
  final Color shadow;

  const AppPalette({
    required this.brand,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.appBar,
    required this.onAppBar,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.highlight,
    required this.shadow,
  });

  static const light = AppPalette(
    brand: AppBrand.navy,
    accent: AppBrand.accent,
    background: Color(0xFFF8F9FA),
    surface: Colors.white,
    surfaceAlt: Color(0xFFF1F3F5),
    appBar: AppBrand.navy,
    onAppBar: Colors.white,
    textPrimary: AppBrand.navy,
    textSecondary: Color(0xFF5F6B7A),
    border: Color(0xFFE3E7EC),
    success: Color(0xFF1E8E3E),
    warning: Color(0xFFE8710A),
    danger: Color(0xFFD93025),
    info: Color(0xFF1A73E8),
    highlight: Color(0xFF8E24AA),
    shadow: Color(0x14000000),
  );

  static const dark = AppPalette(
    // On dark, the navy brand colour is too close to the background to read as
    // an accent, so headings/brand chrome shift to a light tint.
    brand: Color(0xFFE8EDF5),
    accent: Color(0xFF6D9BFF),
    background: Color(0xFF101318),
    surface: Color(0xFF1A1F27),
    surfaceAlt: Color(0xFF242A34),
    appBar: Color(0xFF151A22),
    onAppBar: Colors.white,
    textPrimary: Color(0xFFECEFF3),
    textSecondary: Color(0xFF9BA6B4),
    border: Color(0xFF2E3641),
    success: Color(0xFF5BD675),
    warning: Color(0xFFFFB86B),
    danger: Color(0xFFFF6B5E),
    info: Color(0xFF6D9BFF),
    highlight: Color(0xFFCE93D8),
    shadow: Color(0x33000000),
  );

  @override
  AppPalette copyWith({
    Color? brand,
    Color? accent,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? appBar,
    Color? onAppBar,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? highlight,
    Color? shadow,
  }) {
    return AppPalette(
      brand: brand ?? this.brand,
      accent: accent ?? this.accent,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      appBar: appBar ?? this.appBar,
      onAppBar: onAppBar ?? this.onAppBar,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      highlight: highlight ?? this.highlight,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      brand: Color.lerp(brand, other.brand, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      appBar: Color.lerp(appBar, other.appBar, t)!,
      onAppBar: Color.lerp(onAppBar, other.onAppBar, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension AppPaletteX on BuildContext {
  /// Theme-aware colours. Falls back to the light palette if the extension is
  /// somehow missing so widgets can never crash on a null palette.
  AppPalette get palette => Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  /// Standard elevation shadow for cards.
  List<BoxShadow> get cardShadow => [
        BoxShadow(color: palette.shadow, blurRadius: 12, offset: const Offset(0, 4)),
      ];
}

abstract final class AppTheme {
  static ThemeData light() => _build(AppPalette.light, Brightness.light);
  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppBrand.accent,
      brightness: brightness,
    ).copyWith(
      surface: p.surface,
      error: p.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      extensions: [p],
      appBarTheme: AppBarTheme(
        backgroundColor: p.appBar,
        foregroundColor: p.onAppBar,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: p.onAppBar,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: p.onAppBar),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: p.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.accent,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: p.accent.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.accent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.accent, width: 1.6),
        ),
        labelStyle: TextStyle(color: p.textSecondary),
        hintStyle: TextStyle(color: p.textSecondary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.accent.withValues(alpha: 0.14),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.bold : FontWeight.normal,
            color: states.contains(WidgetState.selected) ? p.accent : p.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? p.accent : p.textSecondary,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceAlt,
        side: BorderSide(color: p.border),
        labelStyle: TextStyle(color: p.textPrimary, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.brand,
        contentTextStyle: TextStyle(color: p.surface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
      textTheme: (brightness == Brightness.dark
              ? Typography.material2021(platform: TargetPlatform.android).white
              : Typography.material2021(platform: TargetPlatform.android).black)
          .apply(bodyColor: p.textPrimary, displayColor: p.textPrimary),
    );
  }
}
