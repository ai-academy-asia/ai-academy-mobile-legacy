import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Manrope type styles for the login screen.
///
/// The design runs smaller and lighter than a Material default would: 12/20
/// does most of the work, weights sit at 500–600, and only the heading goes
/// bold. [splashWordmark] is the one ExtraBold in the scale — the splash
/// screen's brand mark, not body copy, so it is held to the Figma reference's
/// own heavier weight rather than this scale's usual ceiling.
///
/// These sizes were set by eye against the Figma screenshot rather than by
/// measuring it. Measuring the reference put the heading nearer 26 and body
/// text nearer 13–14; side by side at full resolution that still read oversized,
/// so the scale was taken down about 15% on top of the measurement. If the
/// screen ever looks *too* small on a real handset, this is the paragraph to
/// come back to — the measured values were heading 26, body 13, small 11.
///
/// The *line heights* are deliberately held at the values the layout is built
/// on — 34 for the heading, 20 for a field line, 16 for a small label. Shrinking
/// glyphs without touching those keeps every box, gap and control exactly where
/// the geometry pass put it, so type can be tuned without re-verifying spacing.
abstract final class AppTypography {
  static const String fontFamily = 'Manrope';

  /// Screen heading. Figma text box: 361 x 34.
  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    height: 34 / 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Text the user has typed into a field.
  static const TextStyle fieldValue = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 20 / 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// The label at rest, sitting inside an empty field.
  static const TextStyle fieldPlaceholder = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 20 / 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// The label once it has risen into the border notch. Its colour is set at
  /// the call site — grey at rest, dark when focused, red on error.
  static const TextStyle fieldFloatingLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    height: 16 / 10,
    fontWeight: FontWeight.w500,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Label on either button. The colour comes from the variant.
  static const TextStyle buttonLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 20 / 12,
    fontWeight: FontWeight.w600,
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

  /// Title line in the bottom card.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 20 / 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
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

  /// The name in the profile header — the largest text on the screen after
  /// the heading itself.
  static const TextStyle profileName = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// The join date under the profile name. [cardSupporting]'s 10pt reads too
  /// small against the 17pt name beside it.
  static const TextStyle profileJoinedDate = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    leadingDistribution: TextLeadingDistribution.even,
  );

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

  /// The label on one half of the MN/EN segmented control. Colour is set at
  /// the call site — blue on the selected half, white on the other.
  static const TextStyle segmentLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w700,
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

  // --- Splash ---------------------------------------------------------------

  /// The "AI academy Asia" wordmark beside the logo mark on the splash
  /// screen. Coloured with [AppColors.navy] — the logo's own wordmark
  /// colour, documented there for exactly this use — rather than
  /// [AppColors.textPrimary], since this is the brand mark, not body copy.
  ///
  /// ExtraBold (800), a full step over [heading]'s Bold (700): the Figma
  /// reference's wordmark reads heavier than this scale's usual ceiling, and
  /// the weight is bundled already (`Manrope-ExtraBold.ttf`), so reaching for
  /// it costs nothing.
  static const TextStyle splashWordmark = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 24 / 20,
    fontWeight: FontWeight.w800,
    color: AppColors.navy,
    leadingDistribution: TextLeadingDistribution.even,
  );
}
