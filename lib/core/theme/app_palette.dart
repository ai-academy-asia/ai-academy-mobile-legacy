import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The app's colours by **role** — what a colour is for, not what it looks
/// like — for every experience (Adult, Junior, Teacher) at once (Issue
/// #252; roles completed in Phase 2, Issue #256, icon roles in Phase 3, #258 —
/// `docs/design-system/DARK_MODE_ARCHITECTURE_AUDIT.md` §14,
/// `DARK_MODE_DESIGN_PROPOSAL.md` §3).
///
/// A [ThemeExtension], so the active theme decides the values and a widget
/// reads them with `context.palette` instead of a `const` class. [light] is
/// today's app: every role reads its single light source in [AppColors],
/// the same constant the feature palettes now alias, so a widget moved onto
/// a role draws exactly what it drew before.
///
/// [dark] is a **candidate, not approved** (Dark Mode Phase 9, Issue #276):
/// the proposal's values, unreachable until they are approved (proposal
/// §17) and a Phase 10 switch exists. See [dark].
///
/// Roles that mean different things stay separate even where they share a
/// light value ([accentSubtle], [infoFill], [calendarLesson]; [juniorCard],
/// [scheduleHeld]; [divider], [cardDepth], [outlineFaint], [juniorMutedFill],
/// [avatarPlaceholder]; [surface], [mediaControl], [onMedia],
/// [onJuniorMapSky]; [textPrimary], [onMediaControl]; [border],
/// [progressTrack], [juniorHeaderRule]; [outline], [mediaControlOutline],
/// [teacherSheetRule]; [errorInk], [dangerOutline]; [disabledInk],
/// [avatarPlaceholderInk]), because their dark values may differ. Light
/// values that differ are never merged ([border] vs [outline]; the text
/// greys).
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
    required this.accentSubtleOutline,
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
    required this.warningInk,
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
    required this.learningHeroTint,
    required this.surfaceLocked,
    required this.cardDepth,
    required this.outlineFaint,
    required this.videoSurface,
    required this.mediaControl,
    required this.onMediaControl,
    required this.mediaControlOutline,
    required this.onMedia,
    required this.progressTrack,
    required this.textAnswerLetter,
    required this.juniorCard,
    required this.juniorCardBorder,
    required this.juniorMapSky,
    required this.calendarNeutral,
    required this.calendarLesson,
    required this.calendarMissed,
    required this.juniorMutedFill,
    required this.juniorHeaderRule,
    required this.onJuniorMapSky,
    required this.scheduleBand,
    required this.scheduleHeld,
    required this.scheduleHeldInk,
    required this.teacherTitle,
    required this.teacherNameInk,
    required this.teacherRoleInk,
    required this.teacherDetailInk,
    required this.teacherCaptionInk,
    required this.teacherSheetRule,
    required this.dangerOutline,
    required this.avatarPlaceholder,
    required this.avatarPlaceholderInk,
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
    accentSubtleOutline: AppColors.accentSubtleOutline,
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
    warningInk: AppColors.warningInk,
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
    learningHeroTint: AppColors.learningHeroTint,
    surfaceLocked: AppColors.surfaceLocked,
    cardDepth: AppColors.cardDepth,
    outlineFaint: AppColors.outlineFaint,
    videoSurface: AppColors.videoSurface,
    mediaControl: AppColors.mediaControl,
    onMediaControl: AppColors.onMediaControl,
    mediaControlOutline: AppColors.mediaControlOutline,
    onMedia: AppColors.onMedia,
    progressTrack: AppColors.progressTrack,
    textAnswerLetter: AppColors.textAnswerLetter,
    juniorCard: AppColors.juniorCard,
    juniorCardBorder: AppColors.juniorCardBorder,
    juniorMapSky: AppColors.juniorMapSky,
    calendarNeutral: AppColors.calendarNeutral,
    calendarLesson: AppColors.calendarLesson,
    calendarMissed: AppColors.calendarMissed,
    juniorMutedFill: AppColors.juniorMutedFill,
    juniorHeaderRule: AppColors.juniorHeaderRule,
    onJuniorMapSky: AppColors.onJuniorMapSky,
    scheduleBand: AppColors.scheduleBand,
    scheduleHeld: AppColors.scheduleHeld,
    scheduleHeldInk: AppColors.scheduleHeldInk,
    teacherTitle: AppColors.teacherTitle,
    teacherNameInk: AppColors.teacherNameInk,
    teacherRoleInk: AppColors.teacherRoleInk,
    teacherDetailInk: AppColors.teacherDetailInk,
    teacherCaptionInk: AppColors.teacherCaptionInk,
    teacherSheetRule: AppColors.teacherSheetRule,
    dangerOutline: AppColors.dangerOutline,
    avatarPlaceholder: AppColors.avatarPlaceholder,
    avatarPlaceholderInk: AppColors.avatarPlaceholderInk,
  );

  /// The **candidate** dark palette (Dark Mode Phase 9, Issue #276). **Not
  /// approved design** — `DARK_MODE_DESIGN_PROPOSAL.md` §17 is unchecked —
  /// and unreachable: `AppTheme.dark` carries it, but `AppThemeController`
  /// stays [ThemeMode.light] and nothing sets another mode until Phase 10.
  ///
  /// Each role says where its value comes from:
  ///  * **PROPOSED** — the value in the proposal's tables (§4, §11, §12);
  ///  * **DERIVED** — follows a rule the proposal states (a fold, "unchanged",
  ///    "no shadow"), or the role's own documented "same in every theme";
  ///  * **UNRESOLVED** — the proposal gives nothing: a stand-in, named in the
  ///    comment, until design decides.
  ///
  /// `app_palette_dark_test.dart` pins every value and its status.
  static const AppPalette dark = AppPalette(
    // PROPOSED: §4.1
    pageBackground: _Dark.page,
    // PROPOSED: §4.1
    surfaceSubtle: _Dark.surfaceSubtle,
    // PROPOSED: §4.1
    surface: _Dark.surface,
    // PROPOSED: §4.1
    surfaceElevated: _Dark.elevated,
    // PROPOSED: §4.1
    surfaceMuted: _Dark.muted,
    // DERIVED: §3 lists icon tiles under surfaceSubtle
    surfaceTile: _Dark.surfaceSubtle,
    // PROPOSED: §4.2
    textPrimary: _Dark.ink,
    // PROPOSED: §4.2
    textSecondary: _Dark.secondary,
    // PROPOSED: §4.2
    textTitle: _Dark.title,
    // DERIVED: §3 folds #1A1A1A into textPrimary
    textStrong: _Dark.ink,
    // DERIVED: §3 folds #7D7D7E into textSecondary
    textSupporting: _Dark.secondary,
    // DERIVED: §3 folds #808080 into textSecondary
    textMuted: _Dark.secondary,
    // PROPOSED: §4.2
    textInactive: _Dark.inactive,
    // DERIVED: §3: locked lesson ink is textInactive
    textLocked: _Dark.inactive,
    // DERIVED: §7: iconInk as textPrimary
    iconInk: _Dark.ink,
    // DERIVED: §7: tint the wordmark with textTitle
    wordmark: _Dark.title,
    // PROPOSED: §4.3
    border: _Dark.border,
    // PROPOSED: §4.3
    borderFocused: _Dark.ink,
    // PROPOSED: §4.3
    divider: _Dark.divider,
    // DERIVED: §4.3: border covers #D6DBE1
    outline: _Dark.border,
    // DERIVED: §12: the bar track #E5E7EB → divider
    outlineSubtle: _Dark.divider,
    // PROPOSED: §4.4 unchanged
    primary: AppColors.blue,
    // PROPOSED: §4.4 unchanged
    onPrimary: AppColors.onPrimary,
    // PROPOSED: §4.4
    primaryDepth: _Dark.primaryDepth,
    // PROPOSED: §4.4 unchanged
    accent: AppColors.accent,
    // PROPOSED: §4.4
    accentText: _Dark.accentText,
    // PROPOSED: §4.4
    accentSubtle: _Dark.accentSubtle,
    // UNRESOLVED: no value; the info outline of the same pale-blue family
    accentSubtleOutline: _Dark.infoOutline,
    // DERIVED: §3: #1501A6 → accentText (pending §16.5)
    linkInk: _Dark.accentText,
    // UNRESOLVED: §4.2 gives only disabledInk; surfaceMuted ("set back") stands in
    disabled: _Dark.muted,
    // PROPOSED: §4.2
    disabledInk: _Dark.inactive,
    // PROPOSED: §4.4
    neutralDepth: _Dark.depth,
    // DERIVED: §3: neutralDepth folds secondaryDepth
    subtleDepth: _Dark.depth,
    // PROPOSED: §4.5 error as field text
    error: _Dark.errorInk,
    // PROPOSED: §4.5
    errorInk: _Dark.errorInk,
    // PROPOSED: §4.5
    errorFill: _Dark.errorFill,
    // PROPOSED: §4.5
    errorOutline: _Dark.errorOutline,
    // DERIVED: §4.5 success ink
    success: _Dark.successInk,
    // PROPOSED: §4.5
    successInk: _Dark.successInk,
    // PROPOSED: §4.5
    successFill: _Dark.successFill,
    // PROPOSED: §4.5
    successOutline: _Dark.successOutline,
    // DERIVED: text: the §4.5 success ink, as #262 required
    successLabel: _Dark.successInk,
    // UNRESOLVED: no value; the §4.5 success fill stands in
    successFillStrong: _Dark.successFill,
    // DERIVED: §4.5 warning ink (partial state, preview score)
    warning: _Dark.warningInk,
    // PROPOSED: §4.5
    warningFill: _Dark.warningFill,
    // PROPOSED: §4.5
    warningOutline: _Dark.warningOutline,
    // PROPOSED: §4.5 (#DD940E is in its ink set)
    warningInk: _Dark.warningInk,
    // PROPOSED: §4.5
    infoInk: _Dark.infoInk,
    // PROPOSED: §4.5
    infoFill: _Dark.infoFill,
    // PROPOSED: §4.6 black @ 70 %
    barrier: _Dark.barrier,
    // PROPOSED: §4.6
    sheetHandle: _Dark.handle,
    // PROPOSED: §4.6 no shadow
    shadow: _Dark.none,
    // DERIVED: §4.6: shadows vanish on dark
    shadowSubtle: _Dark.none,
    // UNRESOLVED: no value; the unchanged accent blue stands in
    accentOutline: AppColors.accent,
    // UNRESOLVED: no value; the border line stands in
    timelineConnector: _Dark.border,
    // DERIVED: §5: greys fold into textInactive
    textFaint: _Dark.inactive,
    // DERIVED: §3 folds #101828 into textPrimary
    textDeep: _Dark.ink,
    // DERIVED: §3 folds statLabel into textSecondary
    textStatLabel: _Dark.secondary,
    // PROPOSED: §6 unchanged
    attendanceGradientStart: AppColors.attendanceGradientStart,
    // PROPOSED: §6 unchanged
    attendanceGradientEnd: AppColors.attendanceGradientEnd,
    // DERIVED: §6: cards → surface
    surfaceTinted: _Dark.surface,
    // PROPOSED: §4.6 unchanged
    scrim: AppColors.scrim,
    // UNRESOLVED: no value; the blue-tinted accentSubtle stands in
    learningHeroTint: _Dark.accentSubtle,
    // UNRESOLVED: no value; surfaceMuted ("set back") stands in
    surfaceLocked: _Dark.muted,
    // DERIVED: §4.4: depth darker than the page
    cardDepth: _Dark.depth,
    // UNRESOLVED: no value; the quieter divider line stands in
    outlineFaint: _Dark.divider,
    // PROPOSED: §6 video header unchanged
    videoSurface: AppColors.videoSurface,
    // DERIVED: the role: same in every theme
    mediaControl: AppColors.mediaControl,
    // DERIVED: the role: same in every theme
    onMediaControl: AppColors.onMediaControl,
    // DERIVED: the role: same in every theme
    mediaControlOutline: AppColors.mediaControlOutline,
    // DERIVED: the role: same in every theme
    onMedia: AppColors.onMedia,
    // DERIVED: §12: tracks → divider
    progressTrack: _Dark.divider,
    // DERIVED: §5: greys fold into textSecondary
    textAnswerLetter: _Dark.secondary,
    // PROPOSED: §11
    juniorCard: _Dark.juniorCard,
    // PROPOSED: §11
    juniorCardBorder: _Dark.juniorCardBorder,
    // PROPOSED: §11 dusk sky
    juniorMapSky: _Dark.sky,
    // PROPOSED: §11 #20252E
    calendarNeutral: _Dark.muted,
    // PROPOSED: §11 #1A2A47
    calendarLesson: _Dark.accentSubtle,
    // PROPOSED: §11
    calendarMissed: _Dark.calendarMissed,
    // UNRESOLVED: §11 nodes are open; surfaceMuted stands in (see §18)
    juniorMutedFill: _Dark.muted,
    // DERIVED: a header rule; every other is divider
    juniorHeaderRule: _Dark.divider,
    // DERIVED: white reads on the dusk sky
    onJuniorMapSky: AppColors.onJuniorMapSky,
    // PROPOSED: §12 #1F4FC9
    scheduleBand: _Dark.band,
    // PROPOSED: §12 #1A2A47
    scheduleHeld: _Dark.accentSubtle,
    // PROPOSED: §12 #A3ACB9
    scheduleHeldInk: _Dark.secondary,
    // DERIVED: §3 folds #0B1230 into textPrimary
    teacherTitle: _Dark.ink,
    // DERIVED: §12: name → textPrimary
    teacherNameInk: _Dark.ink,
    // DERIVED: §12: role → textSecondary
    teacherRoleInk: _Dark.secondary,
    // DERIVED: §12: Teacher greys → textSecondary
    teacherDetailInk: _Dark.secondary,
    // DERIVED: §12: caption ink → textSecondary
    teacherCaptionInk: _Dark.secondary,
    // DERIVED: a rule → divider
    teacherSheetRule: _Dark.divider,
    // DERIVED: §4.5 error outline
    dangerOutline: _Dark.errorOutline,
    // UNRESOLVED: no value; surfaceMuted stands in
    avatarPlaceholder: _Dark.muted,
    // UNRESOLVED: no value; textInactive stands in
    avatarPlaceholderInk: _Dark.inactive,
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

  /// Card, pill and back-button outlines, and Exercise Detail's field and
  /// drop-area edges; darker progress tracks (`#D6DBE1`).
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

  /// The pale-blue fill behind [accent] ink — Junior's attendance summary
  /// badge included.
  final Color accentSubtle;

  /// The outline of an [accentSubtle] pill: the attendance summary badge
  /// (Junior Learning Progress and Adult attendance). Not [accentOutline], a
  /// deep blue marking the current item.
  final Color accentSubtleOutline;

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

  /// A partial state; the quiz preview card's score.
  final Color warning;

  /// The pale amber behind the contract banner.
  final Color warningFill;

  /// The contract banner's outline.
  final Color warningOutline;

  /// Amber as text — the quiz result's score. Not [warning], a fill (and
  /// the preview card's score) a step lighter.
  final Color warningInk;

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

  // --- Learning Flow (shared by Adult and Junior) ----------------------------

  /// The pale-blue wash at the top of Course Module List, clearing to the
  /// page. Not [accentSubtle] (`#E5F4FF`), a fill behind blue ink.
  final Color learningHeroTint;

  /// A locked module's icon tile — the flat grey behind its padlock.
  final Color surfaceLocked;

  /// The flat 3D band under a lifted Learning Flow card (module, lesson and
  /// unanswered quiz-answer cards). It must stay a step *below* the card in every theme, so it is
  /// not [divider], which only shares its light value.
  final Color cardDepth;

  /// The faint edge of those lifted cards, of Course Module List's
  /// certification panel, Exercise Detail's tab card and the quiz feedback
  /// card — lighter than [outlineSubtle]. An edge, so not [divider] (a rule)
  /// or [cardDepth] (a band), which share its light value.
  final Color outlineFaint;

  /// Exercise Detail's video header: a persistent dark media surface, dark
  /// in every theme — not a page or card surface.
  final Color videoSurface;

  /// The white discs of the video's back and play controls. Not [surface]:
  /// a dark theme's surface would turn the discs dark on the dark video.
  final Color mediaControl;

  /// The glyph on a [mediaControl] disc. Not [textPrimary]: a dark theme's
  /// light text would vanish on the white disc.
  final Color onMediaControl;

  /// The ring around a [mediaControl] disc — the video's back control. Not
  /// [outline], a page role that only shares its light value: the disc and
  /// the video it sits on stay the same in every theme, so its ring must too.
  final Color mediaControlOutline;

  /// Text on [videoSurface], and its translucent pill. Not [onPrimary]: the
  /// video is not a primary-blue surface.
  final Color onMedia;

  /// The unfilled track of an upload or download ring and bar. Not
  /// [border] (a field's edge), which only shares its light value; not
  /// [outline] or [divider], the other tracks' values.
  final Color progressTrack;

  // --- Quiz ------------------------------------------------------------------

  /// The A/B/C/D letter of a quiz answer, grey in every state. Close in
  /// meaning to [textMuted] (an enumerator), but a lighter `#8A8A8A`.
  final Color textAnswerLetter;

  // --- Junior ----------------------------------------------------------------

  /// Junior's pale-blue course and progress cards, and a completed map
  /// node's fill.
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

  /// The flat grey of a Junior map element not yet reached: a locked (or
  /// closed check-in) node, and the certificate panel at the path's end. A
  /// fill — so not [divider], [cardDepth] or [outlineFaint], which only
  /// share its light value; not [surfaceLocked] (`#EFEFEF`), Course Learning's
  /// locked tile.
  final Color juniorMutedFill;

  /// The rule under Junior Home's header (`#E4E6EF`). Every other header
  /// rule, Junior Learning Progress's included, is [divider] (`#EAEDF0`);
  /// whether this one should be too is a design decision (Issue #272). Not
  /// [border], a field's edge that only shares its light value.
  final Color juniorHeaderRule;

  /// A glyph drawn straight on [juniorMapSky] — the map's loading spinner.
  /// Not [onPrimary] (the sky is not a primary surface) or [surface].
  final Color onJuniorMapSky;

  // --- Teacher ---------------------------------------------------------------

  /// Teacher Schedule's header band.
  final Color scheduleBand;

  /// A held session's fill in the week grid.
  final Color scheduleHeld;

  /// A held session's ink.
  final Color scheduleHeldInk;

  /// The near-black navy of Teacher Home's and the Gradebook's titles and
  /// the class card titles (`#0B1230`). Not [textTitle] (`#191919`); proposal
  /// §12 folds it into [textPrimary] in dark, which only a role allows.
  final Color teacherTitle;

  /// A teacher's name on the Request screen (navy `#0C226E`).
  final Color teacherNameInk;

  /// That teacher's role line (`#6371A2`).
  final Color teacherRoleInk;

  /// Teacher's cool-grey detail text (`#9CA3AF`): the Profile's email and
  /// phone, and the session sheet's "/ total".
  final Color teacherDetailInk;

  /// The session sheet's attendance caption (`#4B5563`).
  final Color teacherCaptionInk;

  /// The rule across the session sheet. A rule, so not [outline] or
  /// [mediaControlOutline], which only share its light value.
  final Color teacherSheetRule;

  /// A destructive pill's outline, drawn in its label's red. Not
  /// [errorOutline] (`#EF4444`), a lighter red; not [errorInk], which is the
  /// label and only shares the light value.
  final Color dangerOutline;

  /// The Gradebook's placeholder avatar disc. A fill, so not [divider] or
  /// the other roles that only share its light value.
  final Color avatarPlaceholder;

  /// The person glyph on a placeholder avatar (Gradebook and Request). Not
  /// [disabledInk], a disabled control's label that only shares its value.
  final Color avatarPlaceholderInk;

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
    Color? accentSubtleOutline,
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
    Color? warningInk,
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
    Color? learningHeroTint,
    Color? surfaceLocked,
    Color? cardDepth,
    Color? outlineFaint,
    Color? videoSurface,
    Color? mediaControl,
    Color? onMediaControl,
    Color? mediaControlOutline,
    Color? onMedia,
    Color? progressTrack,
    Color? textAnswerLetter,
    Color? juniorCard,
    Color? juniorCardBorder,
    Color? juniorMapSky,
    Color? calendarNeutral,
    Color? calendarLesson,
    Color? calendarMissed,
    Color? juniorMutedFill,
    Color? juniorHeaderRule,
    Color? onJuniorMapSky,
    Color? scheduleBand,
    Color? scheduleHeld,
    Color? scheduleHeldInk,
    Color? teacherTitle,
    Color? teacherNameInk,
    Color? teacherRoleInk,
    Color? teacherDetailInk,
    Color? teacherCaptionInk,
    Color? teacherSheetRule,
    Color? dangerOutline,
    Color? avatarPlaceholder,
    Color? avatarPlaceholderInk,
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
    accentSubtleOutline: accentSubtleOutline ?? this.accentSubtleOutline,
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
    warningInk: warningInk ?? this.warningInk,
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
    learningHeroTint: learningHeroTint ?? this.learningHeroTint,
    surfaceLocked: surfaceLocked ?? this.surfaceLocked,
    cardDepth: cardDepth ?? this.cardDepth,
    outlineFaint: outlineFaint ?? this.outlineFaint,
    videoSurface: videoSurface ?? this.videoSurface,
    mediaControl: mediaControl ?? this.mediaControl,
    onMediaControl: onMediaControl ?? this.onMediaControl,
    mediaControlOutline: mediaControlOutline ?? this.mediaControlOutline,
    onMedia: onMedia ?? this.onMedia,
    progressTrack: progressTrack ?? this.progressTrack,
    textAnswerLetter: textAnswerLetter ?? this.textAnswerLetter,
    juniorCard: juniorCard ?? this.juniorCard,
    juniorCardBorder: juniorCardBorder ?? this.juniorCardBorder,
    juniorMapSky: juniorMapSky ?? this.juniorMapSky,
    calendarNeutral: calendarNeutral ?? this.calendarNeutral,
    calendarLesson: calendarLesson ?? this.calendarLesson,
    calendarMissed: calendarMissed ?? this.calendarMissed,
    juniorMutedFill: juniorMutedFill ?? this.juniorMutedFill,
    juniorHeaderRule: juniorHeaderRule ?? this.juniorHeaderRule,
    onJuniorMapSky: onJuniorMapSky ?? this.onJuniorMapSky,
    scheduleBand: scheduleBand ?? this.scheduleBand,
    scheduleHeld: scheduleHeld ?? this.scheduleHeld,
    scheduleHeldInk: scheduleHeldInk ?? this.scheduleHeldInk,
    teacherTitle: teacherTitle ?? this.teacherTitle,
    teacherNameInk: teacherNameInk ?? this.teacherNameInk,
    teacherRoleInk: teacherRoleInk ?? this.teacherRoleInk,
    teacherDetailInk: teacherDetailInk ?? this.teacherDetailInk,
    teacherCaptionInk: teacherCaptionInk ?? this.teacherCaptionInk,
    teacherSheetRule: teacherSheetRule ?? this.teacherSheetRule,
    dangerOutline: dangerOutline ?? this.dangerOutline,
    avatarPlaceholder: avatarPlaceholder ?? this.avatarPlaceholder,
    avatarPlaceholderInk: avatarPlaceholderInk ?? this.avatarPlaceholderInk,
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
      accentSubtleOutline: mix(accentSubtleOutline, other.accentSubtleOutline),
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
      warningInk: mix(warningInk, other.warningInk),
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
      learningHeroTint: mix(learningHeroTint, other.learningHeroTint),
      surfaceLocked: mix(surfaceLocked, other.surfaceLocked),
      cardDepth: mix(cardDepth, other.cardDepth),
      outlineFaint: mix(outlineFaint, other.outlineFaint),
      videoSurface: mix(videoSurface, other.videoSurface),
      mediaControl: mix(mediaControl, other.mediaControl),
      onMediaControl: mix(onMediaControl, other.onMediaControl),
      mediaControlOutline: mix(mediaControlOutline, other.mediaControlOutline),
      onMedia: mix(onMedia, other.onMedia),
      progressTrack: mix(progressTrack, other.progressTrack),
      textAnswerLetter: mix(textAnswerLetter, other.textAnswerLetter),
      juniorCard: mix(juniorCard, other.juniorCard),
      juniorCardBorder: mix(juniorCardBorder, other.juniorCardBorder),
      juniorMapSky: mix(juniorMapSky, other.juniorMapSky),
      calendarNeutral: mix(calendarNeutral, other.calendarNeutral),
      calendarLesson: mix(calendarLesson, other.calendarLesson),
      calendarMissed: mix(calendarMissed, other.calendarMissed),
      juniorMutedFill: mix(juniorMutedFill, other.juniorMutedFill),
      juniorHeaderRule: mix(juniorHeaderRule, other.juniorHeaderRule),
      onJuniorMapSky: mix(onJuniorMapSky, other.onJuniorMapSky),
      scheduleBand: mix(scheduleBand, other.scheduleBand),
      scheduleHeld: mix(scheduleHeld, other.scheduleHeld),
      scheduleHeldInk: mix(scheduleHeldInk, other.scheduleHeldInk),
      teacherTitle: mix(teacherTitle, other.teacherTitle),
      teacherNameInk: mix(teacherNameInk, other.teacherNameInk),
      teacherRoleInk: mix(teacherRoleInk, other.teacherRoleInk),
      teacherDetailInk: mix(teacherDetailInk, other.teacherDetailInk),
      teacherCaptionInk: mix(teacherCaptionInk, other.teacherCaptionInk),
      teacherSheetRule: mix(teacherSheetRule, other.teacherSheetRule),
      dangerOutline: mix(dangerOutline, other.dangerOutline),
      avatarPlaceholder: mix(avatarPlaceholder, other.avatarPlaceholder),
      avatarPlaceholderInk: mix(
        avatarPlaceholderInk,
        other.avatarPlaceholderInk,
      ),
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

/// The candidate dark values (Issue #276), each written once. PROPOSED in
/// `DARK_MODE_DESIGN_PROPOSAL.md` §4, §11 and §12 — **not approved**. A dark
/// value equal to its light one is not repeated here: [AppPalette.dark]
/// reads the light constant, which is what "unchanged" means.
abstract final class _Dark {
  static const Color page = Color(0xFF0F1217);
  static const Color surfaceSubtle = Color(0xFF14181E);
  static const Color surface = Color(0xFF1A1F27);
  static const Color elevated = Color(0xFF232934);
  static const Color muted = Color(0xFF20252E);
  static const Color ink = Color(0xFFECEFF3);
  static const Color title = Color(0xFFF5F7FA);
  static const Color secondary = Color(0xFFA3ACB9);
  static const Color inactive = Color(0xFF6E7682);
  static const Color divider = Color(0xFF2A303A);
  static const Color border = Color(0xFF3A424E);
  static const Color primaryDepth = Color(0xFF1D4FC4);
  static const Color accentText = Color(0xFF6E9BFF);
  static const Color accentSubtle = Color(0xFF1A2A47);
  static const Color depth = Color(0xFF0B0E12);
  static const Color errorInk = Color(0xFFFF7A70);
  static const Color errorFill = Color(0xFF341A1C);
  static const Color errorOutline = Color(0xFFC2453F);
  static const Color successInk = Color(0xFF45D18C);
  static const Color successFill = Color(0xFF0F2E20);
  static const Color successOutline = Color(0xFF2E8F5E);
  static const Color warningInk = Color(0xFFF5B547);
  static const Color warningFill = Color(0xFF33280F);
  static const Color warningOutline = Color(0xFFA87A1E);
  static const Color infoInk = Color(0xFF5CB8FF);
  static const Color infoFill = Color(0xFF132A42);
  static const Color infoOutline = Color(0xFF2A78B8);
  static const Color barrier = Color(0xB3000000);
  static const Color none = Color(0x00000000);
  static const Color handle = Color(0xFF4A525E);
  static const Color juniorCard = Color(0xFF1A2235);
  static const Color juniorCardBorder = Color(0xFF2E3A5C);
  static const Color sky = Color(0xFF2A4A73);
  static const Color calendarMissed = Color(0xFF3A1F22);
  static const Color band = Color(0xFF1F4FC9);
}
