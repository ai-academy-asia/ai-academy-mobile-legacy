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

  /// Tick inside a checked checkbox.
  static const IconData check = IconData(0xe182, fontFamily: _family);

  /// Password visibility toggle, password currently shown.
  static const IconData eye = IconData(0xe220, fontFamily: _family);

  /// Password visibility toggle, password currently hidden — the closed eye
  /// the reference draws in the resting state.
  static const IconData eyeClosed = IconData(0xe222, fontFamily: _family);
}
