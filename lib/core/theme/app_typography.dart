import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// The app's type scale: one Manrope style per semantic role (Issue #366).
///
/// **One role, one style, every screen.** A course's name is [cardTitle]
/// wherever it is drawn, a date is [dateTime], a button's label is
/// [buttonLabel] — so the same kind of text reads the same everywhere. Pick
/// the role, not a size: a local `copyWith` sets only the colour (always from
/// `context.palette`), and at most a role's documented variant (e.g. [tabLabel]
/// in bold when selected). A size or line height of its own is an exception,
/// and says why where it is made (`DESIGN_SYSTEM.md` §3 lists them).
///
/// **No colour is baked in.** Every use supplies one from the palette, so the
/// light and dark palettes both apply.
///
/// The sizes are Figma's own, a modest step up from the earlier scale, which
/// had been set ~15% below the measured Figma values. Line heights sit on a
/// 2pt grid and carry `TextLeadingDistribution.even`, so a line's box is
/// stable and its glyphs centred in it.
///
/// System text scaling multiplies all of these as usual; nothing here caps it.
abstract final class AppTypography {
  static const String fontFamily = 'Manrope';

  // --- Titles ---------------------------------------------------------------

  /// A large figure that is the point of its screen or card — a quiz score.
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// A top-level screen's heading: a tab ("Courses", "Profile"), Login.
  static const TextStyle screenTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    height: 34 / 26,
    fontWeight: FontWeight.w700,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// The centred title of a pushed screen's back header.
  static const TextStyle headerTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w700,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// A course's name — "AI for Corporate Leaders" — on every card and page
  /// that shows one; also a profile's name.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w700,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// A heading inside a screen or card: a module's or exercise's title, a
  /// quiz question, a panel's title.
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 26 / 18,
    fontWeight: FontWeight.w700,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// A list row's primary line: a module, lesson, notification, quiz or
  /// gradebook row, a person's name.
  static const TextStyle itemTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w700,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// A row's lighter primary line, where the row is content rather than a
  /// heading: a material's file name, a settings row, a quiz answer.
  static const TextStyle itemLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w500,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // --- Text -----------------------------------------------------------------

  /// Running text: a description, a notification's body, a message.
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// [body] in bold: a label leading a value ("Дараагийн хичээл:"), a
  /// statistic's or status's value.
  static const TextStyle bodyStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w700,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// A secondary line: progress ("35% complete"), a statistic's caption, a
  /// duration, a file size, an empty or error message.
  static const TextStyle supporting = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// A small line over or under a title: the cohort over a course's name,
  /// "Modules 5", a settings section's caption.
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// A date or time — a lesson's time, a notification's age. Tabular
  /// figures, so times line up and do not shift as they change.
  static const TextStyle dateTime = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
    leadingDistribution: TextLeadingDistribution.even,
  );

  // --- Controls -------------------------------------------------------------

  /// A button's label: primary and pill buttons.
  static const TextStyle buttonLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// A secondary control's label: a retry link, a filter or small pill.
  static const TextStyle buttonSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// A tab's label. The selected tab is drawn `w700`.
  static const TextStyle tabLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w500,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// A bottom-navigation item's label, for every role.
  static const TextStyle navLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// A label in a pill or capsule — a status, the MN/EN segment.
  static const TextStyle badge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w700,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // --- Fields ---------------------------------------------------------------

  /// What is typed into a field, and its placeholder.
  static const TextStyle fieldText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w500,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// A field's label once it has floated into the border.
  static const TextStyle fieldLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// The line under a field: its error, or a hint.
  static const TextStyle fieldHelper = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // --- Exceptions -----------------------------------------------------------

  /// "Adult" / "Junior" beside a track's logo: sized to the badge's own 16
  /// box, as the reference draws it, rather than a step of the scale — a
  /// container-sized exception (`DESIGN_SYSTEM.md` §3).
  static const TextStyle trackLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 1,
    fontWeight: FontWeight.w600,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // --- Legacy ---------------------------------------------------------------
  //
  // The scale before Issue #366, kept only for code deliberately left
  // unmigrated: Assignment-only widgets, screens nothing reaches, and the
  // debug-only payment preview. Do not use these in new code.

  /// Screen heading. Figma text box: 361 x 34.
  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    height: 34 / 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// "Намайг сануулах".
  static const TextStyle checkboxLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 20 / 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Supporting line in the bottom card.
  static const TextStyle cardSupporting = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    height: 16 / 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // --- Course catalog -------------------------------------------------------
  //
  // No Figma reference exists for this screen (unlike Login and Reset
  // Password, built against an exact frame), so these two styles are new
  // rather than reused — the same situation `AppColors.success`/`warning` were
  // added under: the first screen that needs something the login flow never
  // did. Kept inside the established scale (10-22, weights 500-700) rather
  // than picked freehand.

  /// A course card's title — one step up from [cardTitle], which reads too
  /// quiet as the primary line of a repeating list item.
  static const TextStyle cardHeading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// A small label inside a pill — a course's category, level, format or
  /// status.
  static const TextStyle badgeLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    height: 14 / 10,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// The card's title in the Figma "Course Catalog" frame — one step up from
  /// [cardHeading], which reads too small for that reference.
  static const TextStyle catalogTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    height: 22 / 17,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Label beside the track logo in the catalog card's top badge (e.g.
  /// "Junior", "Adult").
  static const TextStyle catalogTrackLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// The Open/Full status pill in the catalog card. Colour is set at the call
  /// site — white on either fill.
  static const TextStyle catalogStatusLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w700,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// A section caption in the catalog card ("Who is it for", "Duration").
  static const TextStyle catalogSectionLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// The value under a catalog card section caption. Colour is set at the
  /// call site — muted when the course is full.
  static const TextStyle catalogSectionValue = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// The catalog card's final price — the largest, boldest text on the card.
  /// Colour is set at the call site — muted when the course is full.
  static const TextStyle catalogPrice = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // --- Profile --------------------------------------------------------------

  /// A settings row's label ("Certificate", "Change password", …). Lighter
  /// than [cardHeading], which reads too heavy for a long list of rows.
  static const TextStyle settingsRowLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// The single line of red text under the checkbox.
  static const TextStyle fieldError = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    height: 16 / 10,
    fontWeight: FontWeight.w500,
    color: AppColors.error,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // --- Home dashboard --------------------------------------------------------

  /// A statistic's caption — "Дараанийн төлөлт", "Хичээлийн ирц", the cohort
  /// caption over the title. [catalogSectionLabel]'s 11pt reads too small
  /// beside the 15pt value under it on these cards.
  static const TextStyle statLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    leadingDistribution: TextLeadingDistribution.even,
  );
}
