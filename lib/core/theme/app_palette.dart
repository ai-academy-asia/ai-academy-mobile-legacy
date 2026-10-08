import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The app's colours by **role** — what a colour is for, not what it looks
/// like — for every experience (Adult, Junior, Teacher) at once (Issue
/// #252; roles completed in Phase 2, Issue #256, icon roles in Phase 3, #258 —
/// `docs/design-system/DARK_MODE_ARCHITECTURE_AUDIT.md` §14,
/// `DARK_MODE_DESIGN_PROPOSAL.md` §3).
///
/// A [ThemeExtension], so the active theme decides the values and a widget
/// reads them with `context.palette` instead of a `const` class. Today there
/// is only [light]: every role reads its single light source in
/// [AppColors], the same constant the feature palettes now alias, so a
/// widget moved onto a role draws exactly what it drew before. A dark
/// palette is not defined here and must not be until the proposal's values
/// are approved (proposal §17).
///
/// Roles that mean different things stay separate even where they share a
/// light value ([accentSubtle], [infoFill], [calendarLesson]; [juniorCard],
/// [scheduleHeld]), because their dark values may differ. Light values that
/// differ are never merged ([border] vs [outline]; the text greys).
/// `app_palette_test.dart` holds every role to its legacy constant.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.pageBackground,
    required this.surfaceSubtle,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.surfaceTile,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTitle,
    required this.textStrong,
    required this.textSupporting,
    required this.textMuted,
    required this.textInactive,
    required this.textLocked,
    required this.iconInk,
    required this.wordmark,
    required this.border,
    required this.borderFocused,
    required this.divider,
    required this.outline,
    required this.outlineSubtle,
    required this.primary,
    required this.onPrimary,
    required this.primaryDepth,
    required this.accent,
    required this.accentText,
    required this.accentSubtle,
    required this.linkInk,
    required this.disabled,
    required this.disabledInk,
    required this.neutralDepth,
    required this.subtleDepth,
    required this.error,
    required this.errorInk,
    required this.errorFill,
    required this.errorOutline,
    required this.success,
    required this.successInk,
    required this.successFill,
    required this.successOutline,
    required this.successLabel,
    required this.successFillStrong,
    required this.warning,
    required this.warningFill,
    required this.warningOutline,
    required this.infoInk,
    required this.infoFill,
    required this.barrier,
    required this.sheetHandle,
    required this.shadow,
    required this.shadowSubtle,
    required this.accentOutline,
    required this.timelineConnector,
    required this.textFaint,
    required this.textDeep,
    required this.textStatLabel,
    required this.attendanceGradientStart,
    required this.attendanceGradientEnd,
    required this.surfaceTinted,
    required this.scrim,
    required this.juniorCard,
    required this.juniorCardBorder,
    required this.juniorMapSky,
    required this.calendarNeutral,
    required this.calendarLesson,
    required this.calendarMissed,
    required this.scheduleBand,
    required this.scheduleHeld,
    required this.scheduleHeldInk,
  });

  /// Today's app, unchanged.
  static const AppPalette light = AppPalette(
    pageBackground: AppColors.background,
    surfaceSubtle: AppColors.surfaceSubtle,
    surface: AppColors.surface,
    surfaceElevated: AppColors.surfaceElevated,
    surfaceMuted: AppColors.surfaceMuted,
    surfaceTile: AppColors.surfaceTile,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textTitle: AppColors.textTitle,
    textStrong: AppColors.textStrong,
    textSupporting: AppColors.textSupporting,
    textMuted: AppColors.textMuted,
    textInactive: AppColors.textInactive,
    textLocked: AppColors.textLocked,
    iconInk: AppColors.iconInk,
    wordmark: AppColors.wordmark,
    border: AppColors.border,
    borderFocused: AppColors.borderFocused,
    divider: AppColors.divider,
    outline: AppColors.outline,
    outlineSubtle: AppColors.outlineSubtle,
    primary: AppColors.blue,
    onPrimary: AppColors.onPrimary,
    primaryDepth: AppColors.primaryDepth,
    accent: AppColors.accent,
    accentText: AppColors.accentText,
    accentSubtle: AppColors.accentSubtle,
    linkInk: AppColors.linkInk,
    disabled: AppColors.disabled,
    disabledInk: AppColors.disabledInk,
    neutralDepth: AppColors.mutedDepth,
    subtleDepth: AppColors.subtleDepth,
    error: AppColors.error,
    errorInk: AppColors.errorInk,
    errorFill: AppColors.errorFill,
    errorOutline: AppColors.errorOutline,
    success: AppColors.success,
    successInk: AppColors.successInk,
    successFill: AppColors.successFill,
    successOutline: AppColors.successOutline,
    successLabel: AppColors.successLabel,
    successFillStrong: AppColors.successFillStrong,
    warning: AppColors.warning,
    warningFill: AppColors.warningFill,
    warningOutline: AppColors.warningOutline,
    infoInk: AppColors.infoInk,
    infoFill: AppColors.infoFill,
    barrier: AppColors.barrier,
    sheetHandle: AppColors.sheetHandle,
    shadow: AppColors.shadow,
    shadowSubtle: AppColors.shadowSubtle,
    accentOutline: AppColors.accentOutline,
    timelineConnector: AppColors.timelineConnector,
    textFaint: AppColors.textFaint,
    textDeep: AppColors.textDeep,
    textStatLabel: AppColors.textStatLabel,
    attendanceGradientStart: AppColors.attendanceGradientStart,
    attendanceGradientEnd: AppColors.attendanceGradientEnd,
    surfaceTinted: AppColors.surfaceTinted,
    scrim: AppColors.scrim,
    juniorCard: AppColors.juniorCard,
    juniorCardBorder: AppColors.juniorCardBorder,
    juniorMapSky: AppColors.juniorMapSky,
    calendarNeutral: AppColors.calendarNeutral,
    calendarLesson: AppColors.calendarLesson,
    calendarMissed: AppColors.calendarMissed,
    scheduleBand: AppColors.scheduleBand,
    scheduleHeld: AppColors.scheduleHeld,
    scheduleHeldInk: AppColors.scheduleHeldInk,
  );

  // --- Grounds ---------------------------------------------------------------

  /// The grey page behind white controls; Profile caption bands.
  final Color pageBackground;

  /// A ground barely off [surface] — lesson pages, icon tiles, muted pills.
  final Color surfaceSubtle;

  /// Cards, rows, white pages, the bottom bar.
  final Color surface;

  /// Sheets and dialogs. The same white as [surface] in light mode.
  final Color surfaceElevated;

  /// A field not accepting input.
  final Color surfaceMuted;

  /// The neutral tile behind a course-material or attachment glyph.
  final Color surfaceTile;

  // --- Text ------------------------------------------------------------------

  /// Body text (black @ 90 %).
  final Color textPrimary;

  /// Supporting text (black @ 50 %).
  final Color textSecondary;

  /// The opaque near-black titles of the later frames (`#191919`).
  final Color textTitle;

  /// The opaque near-black of labels and answers (`#1A1A1A`).
  final Color textStrong;

  /// The opaque grey of supporting lines in the later frames (`#7D7D7E`).
  final Color textSupporting;

  /// Lesson numbers, quiz explanations, Gradebook names (`#808080`).
  final Color textMuted;

  /// Text and glyphs already dealt with — a read notification, a weekday.
  final Color textInactive;

  /// A locked lesson's or module's title.
  final Color textLocked;

  // --- Lines -----------------------------------------------------------------

  /// The ink of the monochrome SVG icons (black), applied as a tint by
  /// `AppSvgIcon`.
  final Color iconInk;

  /// The "AI academy Asia" wordmark's colour (brand navy), applied as a tint.
  final Color wordmark;

  /// The resting edge of a field, an outlined button, the bottom card, and
  /// the Course and Cohort cards (`#E4E6EF`) — lighter than [outline]
  /// (`#D6DBE1`), which the later frames' cards and pills draw.
  final Color border;

  /// A focused field's edge and cursor — neutral, not blue.
  final Color borderFocused;

  /// The light rule between rows and under headers; light progress tracks.
  final Color divider;

  /// Card, pill and back-button outlines; darker progress tracks (`#D6DBE1`).
  final Color outline;

  /// Note and Mentor Feedback card outlines; Teacher's bar track.
  final Color outlineSubtle;

  // --- Brand -----------------------------------------------------------------

  /// Login's filled-button blue (`#296CFF`).
  final Color primary;

  /// Text and icons on a blue fill.
  final Color onPrimary;

  /// The 3D band under a blue pill.
  final Color primaryDepth;

  /// The blue of every frame after Login, as a fill (`#2970FF`).
  final Color accent;

  /// Blue used as text or thin ink. Equals [accent] in light mode.
  final Color accentText;

  /// The pale-blue fill behind [accent] ink.
  final Color accentSubtle;

  /// A selected MN/EN segment's label; the Gradebook link (`#1501A6`).
  final Color linkInk;

  // --- Controls --------------------------------------------------------------

  /// A control that cannot be used.
  final Color disabled;

  /// The label of a control that cannot be used.
  final Color disabledInk;

  /// The 3D band under a pill that cannot be pressed.
  final Color neutralDepth;

  /// The faint band under a white pill.
  final Color subtleDepth;

  // --- Status ----------------------------------------------------------------

  /// A field error's border, label and message.
  final Color error;

  /// Overdue and wrong-answer ink.
  final Color errorInk;

  /// The pale red behind an overdue state.
  final Color errorFill;

  /// Overdue and wrong-answer outline.
  final Color errorOutline;

  /// Completed and correct (`#22A06B`).
  final Color success;

  /// "Active" and correct-answer ink.
  final Color successInk;

  /// The pale green behind "Active".
  final Color successFill;

  /// "Active", correct-answer and running-cohort outline and ink.
  final Color successOutline;

  /// A status label drawn in its pill's outline green — the cohort card's
  /// "Open"/"Active". Text, so separate from [successOutline], which shares
  /// only its light value; the dark theme needs a legible ink here.
  final Color successLabel;

  /// The stronger green tile — payment success, a submitted assignment.
  final Color successFillStrong;

  /// A partial state; the quiz score.
  final Color warning;

  /// The pale amber behind the contract banner.
  final Color warningFill;

  /// The contract banner's outline.
  final Color warningOutline;

  /// The "Finished" / live blue, as ink and outline.
  final Color infoInk;

  /// The pale blue behind "Finished" / live.
  final Color infoFill;

  // --- Overlays --------------------------------------------------------------

  /// Behind a sheet or dialog.
  final Color barrier;

  /// A sheet's grab handle.
  final Color sheetHandle;

  /// The small lift under a switch knob or a header bar.
  final Color shadow;

  /// The faint lift under a small outlined control.
  final Color shadowSubtle;

  // --- Adult -----------------------------------------------------------------

  /// A deeper blue outline marking the current item (Payment's next installment).
  final Color accentOutline;

  /// The line joining a timeline's steps (Payment installments).
  final Color timelineConnector;

  /// Text further back than [textSecondary] — an upcoming installment.
  final Color textFaint;

  /// The deep navy-black of the payment flow's bank names.
  final Color textDeep;

  /// A statistic's caption on the Home cards (warm grey).
  final Color textStatLabel;

  /// The Attendance card's blue gradient, start.
  final Color attendanceGradientStart;

  /// The Attendance card's blue gradient, end.
  final Color attendanceGradientEnd;

  /// A white barely tinted blue — the cohort card.
  final Color surfaceTinted;

  /// Over camera video — the attendance scanner's scrim.
  final Color scrim;

  // --- Junior ----------------------------------------------------------------

  /// Junior's pale-blue course and progress cards.
  final Color juniorCard;

  /// Their outline.
  final Color juniorCardBorder;

  /// The map's sky field behind the illustration.
  final Color juniorMapSky;

  /// An attendance-calendar day with no lesson.
  final Color calendarNeutral;

  /// A day with a lesson.
  final Color calendarLesson;

  /// A missed day.
  final Color calendarMissed;

  // --- Teacher ---------------------------------------------------------------

  /// Teacher Schedule's header band.
  final Color scheduleBand;

  /// A held session's fill in the week grid.
  final Color scheduleHeld;

  /// A held session's ink.
  final Color scheduleHeldInk;

  @override
  AppPalette copyWith({
    Color? pageBackground,
    Color? surfaceSubtle,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceMuted,
    Color? surfaceTile,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTitle,
    Color? textStrong,
    Color? textSupporting,
    Color? textMuted,
    Color? textInactive,
    Color? textLocked,
    Color? iconInk,
    Color? wordmark,
    Color? border,
    Color? borderFocused,
    Color? divider,
    Color? outline,
    Color? outlineSubtle,
    Color? primary,
    Color? onPrimary,
    Color? primaryDepth,
    Color? accent,
    Color? accentText,
    Color? accentSubtle,
    Color? linkInk,
    Color? disabled,
    Color? disabledInk,
    Color? neutralDepth,
    Color? subtleDepth,
    Color? error,
    Color? errorInk,
    Color? errorFill,
    Color? errorOutline,
    Color? success,
    Color? successInk,
    Color? successFill,
    Color? successOutline,
    Color? successLabel,
    Color? successFillStrong,
    Color? warning,
    Color? warningFill,
    Color? warningOutline,
    Color? infoInk,
    Color? infoFill,
    Color? barrier,
    Color? sheetHandle,
    Color? shadow,
    Color? shadowSubtle,
    Color? accentOutline,
    Color? timelineConnector,
    Color? textFaint,
    Color? textDeep,
    Color? textStatLabel,
    Color? attendanceGradientStart,
    Color? attendanceGradientEnd,
    Color? surfaceTinted,
    Color? scrim,
    Color? juniorCard,
    Color? juniorCardBorder,
    Color? juniorMapSky,
    Color? calendarNeutral,
    Color? calendarLesson,
    Color? calendarMissed,
    Color? scheduleBand,
    Color? scheduleHeld,
    Color? scheduleHeldInk,
  }) => AppPalette(
    pageBackground: pageBackground ?? this.pageBackground,
    surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
    surface: surface ?? this.surface,
    surfaceElevated: surfaceElevated ?? this.surfaceElevated,
    surfaceMuted: surfaceMuted ?? this.surfaceMuted,
    surfaceTile: surfaceTile ?? this.surfaceTile,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textTitle: textTitle ?? this.textTitle,
    textStrong: textStrong ?? this.textStrong,
    textSupporting: textSupporting ?? this.textSupporting,
    textMuted: textMuted ?? this.textMuted,
    textInactive: textInactive ?? this.textInactive,
    textLocked: textLocked ?? this.textLocked,
    iconInk: iconInk ?? this.iconInk,
    wordmark: wordmark ?? this.wordmark,
    border: border ?? this.border,
    borderFocused: borderFocused ?? this.borderFocused,
    divider: divider ?? this.divider,
    outline: outline ?? this.outline,
    outlineSubtle: outlineSubtle ?? this.outlineSubtle,
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    primaryDepth: primaryDepth ?? this.primaryDepth,
    accent: accent ?? this.accent,
    accentText: accentText ?? this.accentText,
    accentSubtle: accentSubtle ?? this.accentSubtle,
    linkInk: linkInk ?? this.linkInk,
    disabled: disabled ?? this.disabled,
    disabledInk: disabledInk ?? this.disabledInk,
    neutralDepth: neutralDepth ?? this.neutralDepth,
    subtleDepth: subtleDepth ?? this.subtleDepth,
    error: error ?? this.error,
    errorInk: errorInk ?? this.errorInk,
    errorFill: errorFill ?? this.errorFill,
    errorOutline: errorOutline ?? this.errorOutline,
    success: success ?? this.success,
    successInk: successInk ?? this.successInk,
    successFill: successFill ?? this.successFill,
    successOutline: successOutline ?? this.successOutline,
    successLabel: successLabel ?? this.successLabel,
    successFillStrong: successFillStrong ?? this.successFillStrong,
    warning: warning ?? this.warning,
    warningFill: warningFill ?? this.warningFill,
    warningOutline: warningOutline ?? this.warningOutline,
    infoInk: infoInk ?? this.infoInk,
    infoFill: infoFill ?? this.infoFill,
    barrier: barrier ?? this.barrier,
    sheetHandle: sheetHandle ?? this.sheetHandle,
    shadow: shadow ?? this.shadow,
    shadowSubtle: shadowSubtle ?? this.shadowSubtle,
    accentOutline: accentOutline ?? this.accentOutline,
    timelineConnector: timelineConnector ?? this.timelineConnector,
    textFaint: textFaint ?? this.textFaint,
    textDeep: textDeep ?? this.textDeep,
    textStatLabel: textStatLabel ?? this.textStatLabel,
    attendanceGradientStart:
        attendanceGradientStart ?? this.attendanceGradientStart,
    attendanceGradientEnd: attendanceGradientEnd ?? this.attendanceGradientEnd,
    surfaceTinted: surfaceTinted ?? this.surfaceTinted,
    scrim: scrim ?? this.scrim,
    juniorCard: juniorCard ?? this.juniorCard,
    juniorCardBorder: juniorCardBorder ?? this.juniorCardBorder,
    juniorMapSky: juniorMapSky ?? this.juniorMapSky,
    calendarNeutral: calendarNeutral ?? this.calendarNeutral,
    calendarLesson: calendarLesson ?? this.calendarLesson,
    calendarMissed: calendarMissed ?? this.calendarMissed,
    scheduleBand: scheduleBand ?? this.scheduleBand,
    scheduleHeld: scheduleHeld ?? this.scheduleHeld,
    scheduleHeldInk: scheduleHeldInk ?? this.scheduleHeldInk,
  );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      pageBackground: mix(pageBackground, other.pageBackground),
      surfaceSubtle: mix(surfaceSubtle, other.surfaceSubtle),
      surface: mix(surface, other.surface),
      surfaceElevated: mix(surfaceElevated, other.surfaceElevated),
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      surfaceTile: mix(surfaceTile, other.surfaceTile),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTitle: mix(textTitle, other.textTitle),
      textStrong: mix(textStrong, other.textStrong),
      textSupporting: mix(textSupporting, other.textSupporting),
      textMuted: mix(textMuted, other.textMuted),
      textInactive: mix(textInactive, other.textInactive),
      textLocked: mix(textLocked, other.textLocked),
      iconInk: mix(iconInk, other.iconInk),
      wordmark: mix(wordmark, other.wordmark),
      border: mix(border, other.border),
      borderFocused: mix(borderFocused, other.borderFocused),
      divider: mix(divider, other.divider),
      outline: mix(outline, other.outline),
      outlineSubtle: mix(outlineSubtle, other.outlineSubtle),
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      primaryDepth: mix(primaryDepth, other.primaryDepth),
      accent: mix(accent, other.accent),
      accentText: mix(accentText, other.accentText),
      accentSubtle: mix(accentSubtle, other.accentSubtle),
      linkInk: mix(linkInk, other.linkInk),
      disabled: mix(disabled, other.disabled),
      disabledInk: mix(disabledInk, other.disabledInk),
      neutralDepth: mix(neutralDepth, other.neutralDepth),
      subtleDepth: mix(subtleDepth, other.subtleDepth),
      error: mix(error, other.error),
      errorInk: mix(errorInk, other.errorInk),
      errorFill: mix(errorFill, other.errorFill),
      errorOutline: mix(errorOutline, other.errorOutline),
      success: mix(success, other.success),
      successInk: mix(successInk, other.successInk),
      successFill: mix(successFill, other.successFill),
      successOutline: mix(successOutline, other.successOutline),
      successLabel: mix(successLabel, other.successLabel),
      successFillStrong: mix(successFillStrong, other.successFillStrong),
      warning: mix(warning, other.warning),
      warningFill: mix(warningFill, other.warningFill),
      warningOutline: mix(warningOutline, other.warningOutline),
      infoInk: mix(infoInk, other.infoInk),
      infoFill: mix(infoFill, other.infoFill),
      barrier: mix(barrier, other.barrier),
      sheetHandle: mix(sheetHandle, other.sheetHandle),
      shadow: mix(shadow, other.shadow),
      shadowSubtle: mix(shadowSubtle, other.shadowSubtle),
      accentOutline: mix(accentOutline, other.accentOutline),
      timelineConnector: mix(timelineConnector, other.timelineConnector),
      textFaint: mix(textFaint, other.textFaint),
      textDeep: mix(textDeep, other.textDeep),
      textStatLabel: mix(textStatLabel, other.textStatLabel),
      attendanceGradientStart: mix(
        attendanceGradientStart,
        other.attendanceGradientStart,
      ),
      attendanceGradientEnd: mix(
        attendanceGradientEnd,
        other.attendanceGradientEnd,
      ),
      surfaceTinted: mix(surfaceTinted, other.surfaceTinted),
      scrim: mix(scrim, other.scrim),
      juniorCard: mix(juniorCard, other.juniorCard),
      juniorCardBorder: mix(juniorCardBorder, other.juniorCardBorder),
      juniorMapSky: mix(juniorMapSky, other.juniorMapSky),
      calendarNeutral: mix(calendarNeutral, other.calendarNeutral),
      calendarLesson: mix(calendarLesson, other.calendarLesson),
      calendarMissed: mix(calendarMissed, other.calendarMissed),
      scheduleBand: mix(scheduleBand, other.scheduleBand),
      scheduleHeld: mix(scheduleHeld, other.scheduleHeld),
      scheduleHeldInk: mix(scheduleHeldInk, other.scheduleHeldInk),
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
