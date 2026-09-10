/// Measurements taken from the Figma frame `Sign in - 1` (node `31019:13426`,
/// section "Login", page "📱 - App UI").
///
/// Every value here was read from the frame's node geometry, so the layout is
/// reproduced at the sizes the designer actually set. The design frame is
/// 393 x 852 (iPhone 14/15 logical size); values are logical pixels and are
/// used directly, not scaled, so the screen keeps its proportions on other
/// devices while the 16pt gutters stay put.
///
/// The corner radii are the exception — a node's radius is not part of the
/// geometry dump, so those are marked as estimates.
abstract final class AppDimens {
  /// Width of the Figma artboard.
  static const double designWidth = 393;

  /// Left/right gutter: content frames sit at x=16 inside the 393pt artboard.
  static const double screenPadding = 16;

  /// 393 - (2 * 16). Every block on the screen is this wide.
  static const double contentWidth = 361;

  /// Ceiling on the content column.
  ///
  /// The design is a phone layout, and on a phone the column simply fills the
  /// width behind its 16pt gutters. On anything wider — a tablet, or the macOS
  /// build used to check the screen — letting it fill would stretch the fields
  /// and buttons into desktop-width bars that look nothing like the design, so
  /// the column stops here and centres instead.
  static const double maxContentWidth = 480;

  /// Gap between the top of the content area and the heading.
  static const double headingTop = 88;

  /// Heading text box height.
  static const double headingHeight = 34;

  /// Heading bottom (88 + 34 = 122) to the form block at y=146.
  static const double headingToForm = 24;

  /// Height of one input field.
  static const double fieldHeight = 56;

  /// Field 1 sits at y=0, field 2 at y=68 — a 12pt gap between them.
  static const double fieldGap = 12;

  /// The checkbox row sits at y=136, 12pt under the second field.
  static const double fieldsToCheckbox = 12;

  /// Height of the checkbox row.
  static const double checkboxRowHeight = 20;

  /// The box itself is 18 inside that 20pt row.
  static const double checkboxSize = 18;

  /// The checkbox instance is inset 8pt from the content edge.
  static const double checkboxInset = 8;

  /// Fields block ends at y=156; the button block starts at y=196.
  static const double formToButtons = 40;

  /// Height of a button.
  static const double buttonHeight = 44;

  /// Primary button at y=0, secondary at y=56 — a 12pt gap.
  static const double buttonGap = 12;

  /// Height of the "contact your manager" card.
  static const double cardHeight = 80;

  /// The card's inner content frame is inset 16pt on every side.
  static const double cardPadding = 16;

  /// Size of the trailing caret in the card. Subtle, per the reference.
  static const double caretSize = 18;

  /// Supporting line height inside the card.
  static const double cardSupportingHeight = 20;

  /// Title line height inside the card.
  static const double cardTitleHeight = 24;

  /// The card's inner frame is 48 tall for a 20pt line over a 24pt line, so
  /// the two sit 4pt apart: 16 + 20 + 4 + 24 + 16 = the card's 80.
  static const double cardLineGap = 4;

  // --- Reset password ------------------------------------------------------

  /// Gap above the title on the reset screen.
  ///
  /// Not login's 88: that screen leaves a deliberately empty band above its
  /// heading, while this one carries three fields and a requirements panel and
  /// starts much closer to the status bar.
  static const double resetHeadingTop = 32;

  /// Title to its supporting line.
  static const double titleToSupporting = 6;

  /// Height of the password strength meter.
  static const double strengthBarHeight = 6;

  /// One requirement row, sized to its 16pt icon and text line.
  static const double requirementRowHeight = 20;

  /// Gap between requirement rows.
  static const double requirementRowGap = 6;

  /// Icon leading a requirement row.
  static const double requirementIconSize = 16;

  // --- Radii and strokes, read off the Figma reference render -------------

  /// Input field corner radius.
  static const double fieldRadius = 12;

  /// Buttons are pills in the reference — noticeably rounder than the fields,
  /// with the curve running the full half-height.
  static const double buttonRadius = buttonHeight / 2;

  /// Bottom card corner radius. Matches the fields, not the buttons.
  static const double cardRadius = 12;

  /// Checkbox corner radius.
  static const double checkboxRadius = 4;

  /// Resting border of a field, the secondary button and the bottom card.
  static const double borderWidth = 1;

  /// Border of a focused or errored field, which the reference draws heavier.
  static const double borderWidthEmphasis = 1.5;
}
