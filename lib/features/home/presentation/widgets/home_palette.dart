import 'package:flutter/painting.dart';

/// The Adult Home frames' colours, sampled from the four references at 1:1.
///
/// Screen-local rather than added to [AppColors], for the reason
/// `JuniorPalette` gives: these are one screen's palette, and the shared
/// tokens are sampled from the Login frame — moving them to match this screen
/// would repaint every other one. The neutrals (`#D6DBE1`, `#EAEDF0`) are the
/// same values `CohortCard` and `CourseModuleListScreen` already keep as their
/// own constants; nothing below is new to the app except the contract,
/// overdue and attendance fills, which only Home draws.
abstract final class HomePalette {
  /// Every card outline on the screen, the cohort card's divider, the
  /// progress track and the notification circle.
  static const Color border = Color(0xFFD6DBE1);

  /// The rule under the header — the bottom bar's own top rule.
  static const Color headerRule = Color(0xFFEAEDF0);

  /// The frames' own blue — four points off [AppColors.blue] (`#296CFF`),
  /// the same `#2970FF` `CourseModuleListScreen` and `JuniorPalette` keep.
  static const Color accent = Color(0xFF2970FF);

  /// The "Active"/"Open" pill. The ink is a shade darker than the outline.
  static const Color activeOutline = Color(0xFF14AE5C);
  static const Color activeFill = Color(0xFFEBFFEE);
  static const Color activeInk = Color(0xFF009951);

  /// The "Live" pill: `CohortCard`'s "Finished" outline and fill, with the
  /// label in [accent].
  static const Color liveOutline = Color(0xFF0D99FF);
  static const Color liveFill = Color(0xFFE5F4FF);

  /// A statistic's caption — "Дараанийн төлөлт", "Хичээлийн ирц". A warm
  /// grey, not [AppColors.textSecondary]: it reads `#726D6D` on white where
  /// the half-black token reads `#808080`.
  static const Color statLabel = Color(0xFF726D6D);

  /// The icon tile beside a full-width statistic row.
  static const Color iconTileFill = Color(0xFFF9FAFB);

  /// "Хичээлийн ирц" as a tile: a left-to-right blue gradient.
  static const Color attendanceStart = Color(0xFF175FEF);
  static const Color attendanceEnd = Color(0xFF518BFF);

  /// An overdue payment tile, its status line, and its outline.
  static const Color overdueFill = Color(0xFFFFF5F5);
  static const Color overdueOutline = Color(0xFFEF4444);
  static const Color overdueInk = Color(0xFFDC3412);

  /// The unsigned-contract banner.
  static const Color contractFill = Color(0xFFFFFAE5);
  static const Color contractOutline = Color(0xFFEBA611);

  /// A disabled action: fill, outline and label. The same three
  /// `ExerciseSubmitButton` samples for its muted pill.
  static const Color mutedFill = Color(0xFFF9FAFB);
  static const Color mutedOutline = Color(0xFFEAEDF0);
  static const Color mutedInk = Color(0xFFAEAFB0);

  /// The faint band under a secondary (white) pill — 4% black, flat, 1.5 deep.
  static const Color secondaryDepth = Color(0x0A000000);
}
