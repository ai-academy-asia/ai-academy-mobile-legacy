/// Every word on the cohort list screen. No Figma reference exists for this
/// screen — same situation as `CourseCatalogStrings`. The screen is the only
/// caller, so wording it differently later is a single-file edit.
abstract final class CohortListStrings {
  static const String heading = 'Ангиуд';

  /// Accessibility label for the header's back action.
  static const String back = 'Буцах';

  static const String empty = 'Одоогоор товлогдсон анги алга байна';

  static const String retry = 'Дахин оролдох';

  static const String networkError = 'Сүлжээнд холбогдож чадсангүй. Дахин оролдоно уу';
  static const String serverError =
      'Серверт алдаа гарлаа. Түр хүлээгээд дахин оролдоно уу';
  static const String unexpectedError = 'Алдаа гарлаа. Дахин оролдоно уу';

  /// Suffix after a seat count, e.g. "20 сул суудал".
  static const String seatsAvailableUnit = 'сул суудал';

  static String dateRange(String startDate, String endDate) => '$startDate – $endDate';

  static String timeRange(String startTime, String endTime) => '$startTime–$endTime';

  // --- Bottom navigation -------------------------------------------------

  static const String navHome = 'Нүүр';
  static const String navCourses = 'Хичээл';
  static const String navProfile = 'Профайл';
}
