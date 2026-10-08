import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The app's colours by **role** — what a colour is for, not what it looks
/// like — for every experience (Adult, Junior, Teacher) at once (Issue
/// #252, `docs/design-system/DARK_MODE_ARCHITECTURE_AUDIT.md` §14).
///
/// A [ThemeExtension], so the active theme decides the values and a widget
/// reads them with `context.palette` instead of a `const` class. Today there
/// is only [light], and it is built **from the existing constants**
/// ([AppColors], and `HomePalette`'s values) rather than new ones, so a widget moved onto
/// a role draws exactly what it drew before. A dark palette is not defined
/// here and must not be until approved design values exist (audit §12.B).
///
/// `core` does not import features, so the roles whose light value lives in
/// `HomePalette` today ([divider], [accent], [accentSubtle]) spell that
/// value out; `app_palette_test.dart` holds every role equal to its legacy
/// constant, so the two cannot drift.
///
/// Roles are added as features migrate (audit §15); a role exists only once
/// something reads it. Where two repeated literals had no shared name yet
/// ([textTitle], [textInactive]) the role gives them one — the value is the
/// one those screens already drew.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.pageBackground,
    required this.surface,
    required this.surfaceSubtle,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTitle,
    required this.textInactive,
    required this.border,
    required this.borderFocused,
    required this.divider,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.accentSubtle,
    required this.disabled,
    required this.error,
    required this.success,
    required this.warning,
  });

  /// Today's app, unchanged.
  static const AppPalette light = AppPalette(
    pageBackground: AppColors.background,
    surface: AppColors.surface,
    surfaceSubtle: AppColors.surfaceSubtle,
    surfaceMuted: AppColors.surfaceMuted,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textTitle: Color(0xFF191919),
    textInactive: Color(0xFFB2B2B2),
    border: AppColors.border,
    borderFocused: AppColors.borderFocused,
    divider: Color(0xFFEAEDF0),
    primary: AppColors.blue,
    onPrimary: AppColors.onPrimary,
    accent: Color(0xFF2970FF),
    accentSubtle: Color(0xFFE5F4FF),
    disabled: AppColors.disabled,
    error: AppColors.error,
    success: AppColors.success,
    warning: AppColors.warning,
  );

  /// The grey page behind white controls — [AppColors.background].
  final Color pageBackground;

  /// Cards, sheets, white pages — [AppColors.surface].
  final Color surface;

  /// A ground barely off [surface] — [AppColors.surfaceSubtle].
  final Color surfaceSubtle;

  /// A field not accepting input — [AppColors.surfaceMuted].
  final Color surfaceMuted;

  /// Body text — [AppColors.textPrimary].
  final Color textPrimary;

  /// Supporting text — [AppColors.textSecondary].
  final Color textSecondary;

  /// The opaque near-black the later Figma frames draw titles in (`#191919`,
  /// eight call sites — the Notification header among them).
  final Color textTitle;

  /// Text and glyphs that have been dealt with — a read notification's row,
  /// the Teacher grid's weekday (`#B2B2B2`).
  final Color textInactive;

  /// A field's or outlined control's resting edge — [AppColors.border].
  final Color border;

  /// A focused field's edge and cursor — [AppColors.borderFocused].
  final Color borderFocused;

  /// The light rule between rows and under headers — `HomePalette.headerRule`.
  final Color divider;

  /// Login's filled-button blue — [AppColors.blue].
  final Color primary;

  /// Text and icons on [primary] — [AppColors.onPrimary].
  final Color onPrimary;

  /// The blue of every frame after Login — the bottom bar's selection, the
  /// unread dot — `HomePalette.accent`. Not [primary] (`#296CFF`): the two
  /// blues differ and both are drawn.
  final Color accent;

  /// The pale-blue fill behind [accent] ink — `HomePalette.liveFill`.
  final Color accentSubtle;

  /// A control that cannot be used — [AppColors.disabled].
  final Color disabled;

  final Color error;
  final Color success;
  final Color warning;

  @override
  AppPalette copyWith({
    Color? pageBackground,
    Color? surface,
    Color? surfaceSubtle,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTitle,
    Color? textInactive,
    Color? border,
    Color? borderFocused,
    Color? divider,
    Color? primary,
    Color? onPrimary,
    Color? accent,
    Color? accentSubtle,
    Color? disabled,
    Color? error,
    Color? success,
    Color? warning,
  }) => AppPalette(
    pageBackground: pageBackground ?? this.pageBackground,
    surface: surface ?? this.surface,
    surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
    surfaceMuted: surfaceMuted ?? this.surfaceMuted,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textTitle: textTitle ?? this.textTitle,
    textInactive: textInactive ?? this.textInactive,
    border: border ?? this.border,
    borderFocused: borderFocused ?? this.borderFocused,
    divider: divider ?? this.divider,
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    accent: accent ?? this.accent,
    accentSubtle: accentSubtle ?? this.accentSubtle,
    disabled: disabled ?? this.disabled,
    error: error ?? this.error,
    success: success ?? this.success,
    warning: warning ?? this.warning,
  );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      pageBackground: mix(pageBackground, other.pageBackground),
      surface: mix(surface, other.surface),
      surfaceSubtle: mix(surfaceSubtle, other.surfaceSubtle),
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTitle: mix(textTitle, other.textTitle),
      textInactive: mix(textInactive, other.textInactive),
      border: mix(border, other.border),
      borderFocused: mix(borderFocused, other.borderFocused),
      divider: mix(divider, other.divider),
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      accent: mix(accent, other.accent),
      accentSubtle: mix(accentSubtle, other.accentSubtle),
      disabled: mix(disabled, other.disabled),
      error: mix(error, other.error),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
    );
  }
}

/// `context.palette` — the active theme's [AppPalette].
extension AppPaletteContext on BuildContext {
  /// Falls back to [AppPalette.light] when the theme carries none — a
  /// widget test pumping a bare `MaterialApp` without `AppTheme.light` — so
  /// a migrated widget never draws differently for want of a theme.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
