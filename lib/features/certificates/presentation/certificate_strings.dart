import '../../../core/locale/app_format.dart';
import '../../cohorts/presentation/cohort_list_strings.dart';
import '../../course_learning/presentation/course_learning_strings.dart';

/// Copy for the Certificate screen (Issue #155) — English where the Figma
/// frame draws English, as the Profile and Course Learning frames do.
abstract final class CertificateStrings {
  /// The screen's title.
  static const String title = 'Certificate';

  /// The issued card's date label; the date itself is `issued_at`.
  static const String completedDate = 'Completed date:';

  /// The issued card's button.
  static const String download = 'Download';

  /// Enrolled in nothing — the Хичээл tab's own line for the same state.
  static const String empty = CohortListStrings.emptyMine;

  static String get retry => CourseLearningStrings.retry;

  /// `issued_at` as the frame draws it: `2026/07/21`, in local time;
  /// `Jul 21, 2026` in English ([AppFormat], Issue #505).
  static String date(DateTime when) =>
      AppFormat.dateWithYear(when.toLocal(), mongolianSeparator: '/');
}
