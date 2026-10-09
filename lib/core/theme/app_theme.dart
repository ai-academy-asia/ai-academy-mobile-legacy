import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_typography.dart';

/// The app-wide theme.
///
/// Deliberately thin: screens paint themselves from [AppPalette] roles,
/// [AppTypography] and `AppDimens` rather than from Material component themes,
/// because the design is not a Material design. What lives here is only what
/// the framework needs in order to not contradict it — the font family, the
/// scaffold background, and the text-selection colours — plus [AppPalette],
/// the colour roles migrated widgets read instead of [AppColors] (Issue #252).
///
/// [dark] is the **candidate** dark theme (Dark Mode Phase 9, Issue #276):
/// built from [AppPalette.dark], whose values are proposed, not approved.
/// It is wired into `MaterialApp` but unreachable — `AppThemeController`
/// stays [ThemeMode.light] until Phase 10.
abstract final class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: AppTypography.fontFamily,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      primary: AppColors.blue,
      error: AppColors.error,
      surface: AppColors.background,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.borderFocused,
      selectionColor: Color(0x33296CFF),
      selectionHandleColor: AppColors.borderFocused,
    ),
    // The app's colour roles, read with `context.palette` (Issue #252).
    extensions: const [AppPalette.light],
  );

  /// The candidate dark theme, from [AppPalette.dark] alone (proposal §5,
  /// §6, §9):
  ///  * `Brightness.dark`, so `AppSystemUi.page` turns the status-bar glyphs
  ///    light on its own;
  ///  * a `ColorScheme` for stock widgets (spinners' defaults, snack bars,
  ///    pickers) with `primary` = `accent` and `surface` = `surfaceElevated`;
  ///  * the selection in `accentText` @ 30 % with a `borderFocused` cursor.
  static ThemeData get dark {
    const palette = AppPalette.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: palette.pageBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.accent,
        brightness: Brightness.dark,
        primary: palette.accent,
        error: palette.error,
        surface: palette.surfaceElevated,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.borderFocused,
        selectionColor: palette.accentText.withValues(alpha: 0.3),
        selectionHandleColor: palette.borderFocused,
      ),
      extensions: const [AppPalette.dark],
    );
  }
}
