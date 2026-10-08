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

  static const String retry = CourseLearningStrings.retry;

  /// `issued_at` as the frame draws it: `2026/07/21`, in local time.
  static String date(DateTime when) {
    final local = when.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}/${two(local.month)}/${two(local.day)}';
  }
}
