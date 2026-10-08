import 'package:flutter/widgets.dart';

/// Palette for the AI Academy Asia app.
///
/// The brand colours are exact — sampled from the logo exported from Figma
/// (`assets/images/ai_academy_logo.png`). The neutrals are the reference's:
/// a light grey page carrying white controls, with text in plain black at two
/// opacities rather than in the brand navy. Tinting body copy with the navy is
/// what made the first passes read heavy and purple next to the design.
abstract final class AppColors {
  // --- Brand, sampled from the Figma logo export ---------------------------

  /// Interaction and primary action: the filled button, a focused border, the
  /// cursor. The lighter of the logo's two blues.
  static const Color blue = Color(0xFF296CFF);

  /// The deeper blue of the logo mark. Not used for interaction.
  static const Color blueDeep = Color(0xFF0262F8);

  /// The flat band the design draws directly under a primary button — a
  /// darker blue, no blur, offset down. Every CTA in the Course Learning
  /// frames (Continue learning, Submit, Start quiz, Дахин quiz өгөх) sits on
  /// one of these; [mutedDepth] is the same band for the disabled variant.
  static const Color primaryDepth = Color(0xFF004FED);
  static const Color mutedDepth = Color(0xFFE0E0E0);

  /// Violet terminal of the logo gradient.
  static const Color violet = Color(0xFF4316FF);

  /// Wordmark navy. Belongs to the logo, not to body text.
  static const Color navy = Color(0xFF14053D);

  // --- Neutrals ------------------------------------------------------------

  /// The page. A light grey, which is what makes the white controls read as
  /// surfaces at all.
  static const Color background = Color(0xFFF4F5F7);

  /// Fields, buttons and the bottom card sit on this.
  static const Color surface = Color(0xFFFFFFFF);

  /// Fill of a field that is not accepting input.
  static const Color surfaceMuted = Color(0xFFEFF0F3);

  /// A content ground barely off white — lighter than [background], which
  /// reads as a distinct grey band behind a list of white rows.
  static const Color surfaceSubtle = Color(0xFFF9FAFB);

  /// Resting border of a field, the secondary button and the bottom card.
  static const Color border = Color(0xFFE4E6EF);

  /// Border, label and cursor of the field currently being typed into.
  ///
  /// Dark, not blue. Blue is the primary action's colour and nothing else —
  /// a blue focus ring is a Material habit, and the design does not use it.
  static const Color borderFocused = Color(0xE6000000);

  /// Headings, field values, the card title — rgba(0, 0, 0, 0.9).
  static const Color textPrimary = Color(0xE6000000);

  /// Placeholders, resting labels, the card's supporting line and the chevron —
  /// rgba(0, 0, 0, 0.5).
  static const Color textSecondary = Color(0x80000000);

  /// Error border, error label and the validation message. Also a password
  /// requirement the current password fails.
  static const Color error = Color(0xFFE5484D);

  /// A satisfied password requirement, and a full-strength meter.
  ///
  /// Read off the reset-password reference — the design has no green anywhere
  /// on the login screen, so this is the first place it appears.
  static const Color success = Color(0xFF22A06B);

  /// A partly-satisfied strength meter, between [error] and [success].
  static const Color warning = Color(0xFFF0A22E);

  /// Fill of a control that cannot be pressed.
  static const Color disabled = Color(0xFFC9CBDA);

  /// Foreground on filled buttons.
  static const Color onPrimary = Color(0xFFFFFFFF);

  // --- Role values shared across features (Dark Mode Phase 2, Issue #256) --
  //
  // Each is the single light-mode source of one `AppPalette` role. The
  // feature palettes (`HomePalette`, `JuniorPalette`, the Teacher and
  // Payment palettes) and the private constants that used to repeat these
  // literals now alias them, so a value is written once. Values are exactly
  // what shipped; roles that differ in meaning but share a light value (and
  // may not share a dark one — `DARK_MODE_DESIGN_PROPOSAL.md`) share a
  // private base here rather than a role.

  static const Color _blueTint = Color(0xFFE5F4FF);
  static const Color _blueWash = Color(0xFFEFF4FF);

  /// The blue of every frame after Login — selection, progress, the unread
  /// dot. Not [blue] (`#296CFF`): both blues are drawn.
  static const Color accent = Color(0xFF2970FF);

  /// Blue used as text or thin ink — links, dates, a selected tab's label.
  /// The same as [accent] in light mode.
  static const Color accentText = accent;

  /// The pale-blue fill behind [accent] ink.
  static const Color accentSubtle = _blueTint;

  /// The deep violet-blue of a selected MN/EN segment and the Gradebook link.
  static const Color linkInk = Color(0xFF1501A6);

  /// A sheet or dialog — the same white as [surface] in light mode.
  static const Color surfaceElevated = surface;

  /// The neutral tile behind a course-material or attachment glyph.
  static const Color surfaceTile = Color(0xFFF5F5F5);

  /// The light rule between rows, under headers and as a progress track.
  static const Color divider = Color(0xFFEAEDF0);

  /// The outline of cards, pills, the back button's ring and progress
  /// tracks — darker than [divider], and not [border] (`#E4E6EF`, fields).
  static const Color outline = Color(0xFFD6DBE1);

  /// The outline of the Note and Mentor Feedback cards; Teacher's bar track.
  static const Color outlineSubtle = Color(0xFFE5E7EB);

  /// The opaque near-black titles of the later Figma frames.
  static const Color textTitle = Color(0xFF191919);

  /// The opaque near-black of labels and answers (Course Learning, Teacher
  /// pills) — a hair lighter than [textTitle].
  static const Color textStrong = Color(0xFF1A1A1A);

  /// The opaque grey of supporting lines in the later frames.
  static const Color textSupporting = Color(0xFF7D7D7E);

  /// The opaque mid grey of lesson numbers, quiz explanations and Gradebook
  /// names.
  static const Color textMuted = Color(0xFF808080);

  /// Text and glyphs already dealt with — a read notification, a weekday.
  static const Color textInactive = Color(0xFFB2B2B2);

  /// A locked lesson's or module's title.
  static const Color textLocked = Color(0xFFB5B5B5);

  /// The label of a control that cannot be used.
  static const Color disabledInk = Color(0xFFAEAFB0);

  /// The ink of the monochrome SVG icons — the bell, the Profile row icons
  /// — which are drawn `stroke="black"`. A tint of this exact colour paints
  /// them as they always were (Phase 3, Issue #258).
  static const Color iconInk = Color(0xFF000000);

  /// The "AI academy Asia" wordmark — the brand [navy] it is drawn in.
  static const Color wordmark = navy;

  /// The faint band under a white pill (`HomePillButton`'s secondary).
  static const Color subtleDepth = Color(0x0A000000);

  static const Color successInk = Color(0xFF009951);
  static const Color successFill = Color(0xFFEBFFEE);
  static const Color successOutline = Color(0xFF14AE5C);

  /// The stronger green tile — payment success, a submitted assignment.
  static const Color successFillStrong = Color(0xFFCCEBDC);

  static const Color errorInk = Color(0xFFDC3412);
  static const Color errorFill = Color(0xFFFFF5F5);
  static const Color errorOutline = Color(0xFFEF4444);

  static const Color warningFill = Color(0xFFFFFAE5);
  static const Color warningOutline = Color(0xFFEBA611);

  /// The "Finished" / live blue, as ink and outline.
  static const Color infoInk = Color(0xFF0D99FF);
  static const Color infoFill = _blueTint;

  /// Behind a sheet or dialog.
  static const Color barrier = Color(0x99000000);

  /// A sheet's grab handle.
  static const Color sheetHandle = Color(0xFFDBDBDC);

  /// The small lift under a switch knob or a header bar.
  static const Color shadow = Color(0x1A000000);

  /// The faint lift under a small outlined control.
  static const Color shadowSubtle = Color(0x14000000);

  // Junior.
  static const Color juniorCard = _blueWash;
  static const Color juniorCardBorder = Color(0xFFD1D3F5);
  static const Color juniorMapSky = Color(0xFFBFD9F8);
  static const Color calendarNeutral = Color(0xFFF2F2F3);
  static const Color calendarLesson = _blueTint;
  static const Color calendarMissed = Color(0xFFFFE7E7);

  // Teacher.
  static const Color scheduleBand = accent;
  static const Color scheduleHeld = _blueWash;
  static const Color scheduleHeldInk = Color(0xFF787A80);
}
