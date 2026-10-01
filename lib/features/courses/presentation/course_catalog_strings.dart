/// Every word on the course catalog screen.
///
/// No Figma reference exists for this screen — unlike Login and Reset
/// Password, which were built against an exact screenshot, this one follows
/// the established visual *system* (tokens, spacing, card language) without a
/// frame to match pixel-for-pixel. The copy below is written to fit that
/// system, not read off a design; the screen is the only caller, so wording it
/// differently is a single-file edit.
abstract final class CourseCatalogStrings {
  /// Screen heading.
  static const String heading = 'Хичээлүүд';

  // --- States ----------------------------------------------------------

  static const String empty = 'Одоогоор боломжтой хичээл алга байна';

  static const String retry = 'Дахин оролдох';

  static const String networkError = 'Сүлжээнд холбогдож чадсангүй. Дахин оролдоно уу';
  static const String serverError =
      'Серверт алдаа гарлаа. Түр хүлээгээд дахин оролдоно уу';
  static const String unexpectedError = 'Алдаа гарлаа. Дахин оролдоно уу';

  // --- Card content ------------------------------------------------------

  /// Unit suffix for an age range, e.g. "10-18 нас".
  static const String ageUnit = 'нас';

  /// A course's age range: "10-18 нас", or "18+ нас" when the course sends
  /// no upper bound (`age_max: null`). The open end is drawn, never filled in
  /// with a guessed upper age; "+" keeps the existing number-unit shape
  /// rather than adding new wording.
  static String ageRange(int min, int? max) =>
      max == null ? '$min+ $ageUnit' : '$min-$max $ageUnit';

  /// Unit suffix for a course length given only in weeks, e.g. "3 долоо хоног".
  /// Used only when the API sends no `duration_label` of its own.
  static const String weeksUnit = 'долоо хоног';

  /// Joins a course's start and end date.
  static String dateRange(String startDate, String endDate) => '$startDate – $endDate';

  /// Caption above a card's audience line.
  static const String whoIsItFor = 'Хэнд зориулагдсан';

  /// Caption above a card's duration line.
  static const String durationSectionLabel = 'Үргэлжлэх хугацаа';
}
