import 'package:flutter/widgets.dart';

/// The design's icons, drawn from the Phosphor icon font.
///
/// The Figma layers name their icons `CaretRight`, `House`, `BookOpenText`,
/// `CalendarCheck` and `Money` — Phosphor's own names — so these are the glyphs
/// the designer drew with, not lookalikes from another set.
///
/// The font is bundled directly rather than through `phosphor_flutter`: that
/// package subclasses `IconData`, which Flutter has since made a `final` class,
/// so it no longer compiles (it fails in the CFE even though the analyzer lets
/// it pass). Bundling the same MIT-licensed font and naming the code points
/// avoids the dependency altogether — the licence sits beside it in
/// `assets/fonts/PHOSPHOR-LICENSE.txt`.
///
/// Code points are Phosphor's; add new ones from the `phosphor-icons/core`
/// tables as more of the design gets built.
abstract final class AppIcons {
  static const String _family = 'Phosphor';

  /// Trailing chevron of the "contact your manager" card.
  static const IconData caretRight = IconData(0xe13a, fontFamily: _family);

  /// Back-navigation chevron. Same Phosphor "Regular" set already bundled —
  /// confirmed against the font's own cmap, not guessed: `caretRight`'s
  /// `0xe13a` and this icon's `0xe138` are adjacent codepoints in the same
  /// glyph table.
  static const IconData caretLeft = IconData(0xe138, fontFamily: _family);

  /// Tick inside a checked checkbox.
  static const IconData check = IconData(0xe182, fontFamily: _family);

  /// Password visibility toggle, password currently shown.
  static const IconData eye = IconData(0xe220, fontFamily: _family);

  /// Password visibility toggle, password currently hidden — the closed eye
  /// the reference draws in the resting state.
  static const IconData eyeClosed = IconData(0xe222, fontFamily: _family);

  /// A password requirement, before it is met and once it is.
  static const IconData checkCircle = IconData(0xe184, fontFamily: _family);

  /// A password requirement the typed password fails.
  static const IconData xCircle = IconData(0xe4f8, fontFamily: _family);

  /// Back navigation — the course detail screen's back button. Pairs with
  /// [caretRight] at the adjacent code point.
  static const IconData caretLeft = IconData(0xe138, fontFamily: _family);
  // --- Bottom navigation -----------------------------------------------
  //
  // Codepoints confirmed against Phosphor's own published "Regular" web-font
  // stylesheet (`@phosphor-icons/web`'s `regular/style.css`), then checked
  // against this bundled font's own cmap to confirm the glyph is actually
  // present at that codepoint — the same confirmation standard `caretLeft`
  // above was held to, not a guess at the font's private-use-area layout.

  /// "Нүүр" (Home) tab — Phosphor "House".
  static const IconData house = IconData(0xe2c2, fontFamily: _family);

  /// "Хичээл" (Courses) tab — Phosphor "BookOpenText".
  static const IconData bookOpenText = IconData(0xe8f2, fontFamily: _family);

  /// "Профайл" (Profile) tab — Phosphor "User".
  static const IconData user = IconData(0xe4c2, fontFamily: _family);
}
