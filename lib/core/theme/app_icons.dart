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

  /// Back arrow (←) — the Adult attendance frame's back control. The bundled
  /// font names its glyphs only `uniXXXX`, so this was confirmed by rendering
  /// `0xe058` from `assets/fonts/Phosphor.ttf` beside [caretLeft]: it draws
  /// Phosphor's "arrow-left".
  static const IconData arrowLeft = IconData(0xe058, fontFamily: _family);

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

  // --- Home dashboard ----------------------------------------------------
  //
  // Same confirmation standard as the tab-bar glyphs above: codepoints from
  // Phosphor's "Regular" stylesheet, each rendered from this bundled font to
  // check the glyph is the one the Figma layer names.

  /// "Дараанийн төлөлт" card — Phosphor "Money".
  static const IconData money = IconData(0xe588, fontFamily: _family);

  /// "Хичээлийн ирц" card — Phosphor "CalendarCheck".
  static const IconData calendarCheck = IconData(0xe712, fontFamily: _family);

  /// The attendance action's leading glyph — Phosphor "QrCode".
  static const IconData qrCode = IconData(0xe3e6, fontFamily: _family);

  // --- Teacher Home (Issue #229) ------------------------------------------
  //
  // Same standard: codepoints from Phosphor's "Regular" stylesheet
  // (`@phosphor-icons/web` 2.1.1, whose `house`, `qr-code`, `caret-left` and
  // `check` match the codepoints above), each rendered from this bundled
  // font beside the reference's own glyph.

  /// "Хуваарь" (Schedule) tab — Phosphor "Calendar" (the "12" page).
  static const IconData calendar = IconData(0xe108, fontFamily: _family);

  /// "Дүнгийн хуудас" (Gradebook) tab — Phosphor "Exam" (the "A+" sheet).
  static const IconData exam = IconData(0xe742, fontFamily: _family);

  /// A class's room — Phosphor "MapPin".
  static const IconData mapPin = IconData(0xe316, fontFamily: _family);

  /// A class's time — Phosphor "Clock".
  static const IconData clock = IconData(0xe19a, fontFamily: _family);

  /// Teacher Schedule's header date control (Issue #231) — Phosphor
  /// "CaretDown", the sibling of [caretLeft] / [caretRight] in the same
  /// stylesheet, rendered from this font beside the reference's caret.
  static const IconData caretDown = IconData(0xe136, fontFamily: _family);

  /// A submitted link on Teacher Gradebook (Issue #233) — Phosphor "Link",
  /// rendered from this font beside the `feedback` reference's glyph.
  static const IconData link = IconData(0xe2e2, fontFamily: _family);

  // --- Manager contact sheet (Issue #186) --------------------------------
  //
  // Phosphor's own "Regular" codepoints (`phosphor_flutter` 2.1.0's
  // `PhosphorIconsRegular.phone` / `.envelope`), confirmed present in this
  // bundled font's cmap and rendered from it beside [caretRight] and [house]
  // to check each draws the named glyph.

  /// "Утасдах" — Phosphor "Phone".
  static const IconData phone = IconData(0xe3b8, fontFamily: _family);

  /// "Email бичих" — Phosphor "Envelope".
  static const IconData envelope = IconData(0xe214, fontFamily: _family);

  /// The manager contact sheet's header cue (Issue #239) — Phosphor
  /// "ChatCircleDots", confirmed by rendering `0xe16c` from the bundled font
  /// among its chat-bubble neighbours.
  static const IconData chatCircleDots = IconData(0xe16c, fontFamily: _family);

  /// The Profile "Dark mode" row (Issue #288) — Phosphor "Moon", `0xe330` in
  /// the same `@phosphor-icons/web` 2.1.1 "Regular" stylesheet, rendered from
  /// this bundled font to confirm it draws the crescent. The exported Profile
  /// SVGs are Phosphor too, but no moon was exported.
  static const IconData moon = IconData(0xe330, fontFamily: _family);
}
