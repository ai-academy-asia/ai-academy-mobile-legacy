import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// The app-wide theme.
///
/// Deliberately thin: the login screen paints itself from [AppColors],
/// [AppTypography] and `AppDimens` rather than from Material component themes,
/// because the design is not a Material design. What lives here is only what
/// the framework needs in order to not contradict it — the font family, the
/// scaffold background, and the text-selection colours.
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
  );
}
