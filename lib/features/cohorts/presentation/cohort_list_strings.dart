import '../../../core/locale/l10n.dart';

/// Every word on the cohort list screen. The screen is the only caller, so
/// wording it differently later is a single-file edit.
abstract final class CohortListStrings {
  /// Verbatim from the Figma "Course Catalog" frame, which titles this screen
  /// in English while its own bottom bar stays Mongolian ("Хичээл") — the same
  /// mixed-language treatment the Exercise Detail frames use. Not translated
  /// to match the tab, because the reference does not.
  static const String heading = 'Courses';

  static const String empty = 'Одоогоор товлогдсон анги алга байна';

  /// Empty state for the student's own list — they are enrolled in nothing.
  static String get emptyMine => L10n.current.cohortEmptyMine;

  /// Same wording Home's program card uses for the same figure.
  static String percentComplete(int percent) => '$percent% complete';

  static String get retry => L10n.current.commonRetry;

  static String get networkError => L10n.current.commonNetworkError;
  static String get serverError => L10n.current.commonServerError;
  static String get unexpectedError => L10n.current.commonUnexpectedError;

  /// Suffix after a seat count, e.g. "20 сул суудал".
  static const String seatsAvailableUnit = 'сул суудал';

  static String dateRange(String startDate, String endDate) =>
      '$startDate – $endDate';

  static String timeRange(String startTime, String endTime) =>
      '$startTime–$endTime';
}
