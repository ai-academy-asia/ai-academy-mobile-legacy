/// Every word on the course detail screen.
///
/// No Figma reference exists for this screen either — same situation as
/// `CourseCatalogStrings`. The screen is the only caller, so wording it
/// differently is a single-file edit.
abstract final class CourseDetailStrings {
  static const String back = 'Буцах';

  // --- Section titles ------------------------------------------------------

  static const String descriptionTitle = 'Тухай';
  static const String curriculumTitle = 'Хөтөлбөр';
  static const String instructorsTitle = 'Багш нар';
  static const String prerequisitesTitle = 'Шаардлага';
  static const String whatsIncludedTitle = 'Багтсан зүйлс';

  // --- States ----------------------------------------------------------

  static const String notFound = 'Энэ хичээл олдсонгүй';
  static const String retry = 'Дахин оролдох';

  static const String networkError = 'Сүлжээнд холбогдож чадсангүй. Дахин оролдоно уу';
  static const String serverError =
      'Серверт алдаа гарлаа. Түр хүлээгээд дахин оролдоно уу';
  static const String unexpectedError = 'Алдаа гарлаа. Дахин оролдоно уу';

  // The age/duration/date units are `CourseCatalogStrings.ageUnit`,
  // `.weeksUnit` and `.dateRange(...)` — reused directly rather than repeated
  // here, since this screen shows the same scheduling facts the catalog
  // card's meta row already does.
}
