/// Every word on the cohort list screen. No Figma reference exists for this
/// screen — same situation as `CourseCatalogStrings`. The screen is the only
/// caller, so wording it differently later is a single-file edit.
abstract final class CohortListStrings {
  static const String heading = 'Ангиуд';

  static const String empty = 'Одоогоор товлогдсон анги алга байна';

  /// Empty state for the student's own list — they are enrolled in nothing.
  static const String emptyMine =
      'Та одоогоор ямар ч ангид бүртгүүлээгүй байна';

  /// Same wording Home's program card uses for the same figure.
  static String percentComplete(int percent) => '$percent% complete';

  static const String retry = 'Дахин оролдох';

  static const String networkError =
      'Сүлжээнд холбогдож чадсангүй. Дахин оролдоно уу';
  static const String serverError =
      'Серверт алдаа гарлаа. Түр хүлээгээд дахин оролдоно уу';
  static const String unexpectedError = 'Алдаа гарлаа. Дахин оролдоно уу';

  /// Suffix after a seat count, e.g. "20 сул суудал".
  static const String seatsAvailableUnit = 'сул суудал';

  static String dateRange(String startDate, String endDate) =>
      '$startDate – $endDate';

  static String timeRange(String startTime, String endTime) =>
      '$startTime–$endTime';

  // --- Bottom navigation -------------------------------------------------

  static const String navHome = 'Нүүр';
  static const String navCourses = 'Хичээл';
  static const String navProfile = 'Профайл';
}
