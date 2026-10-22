import '../../../core/locale/l10n.dart';

/// Every word on the course detail screen.
///
/// No Figma reference exists for this screen either — same situation as
/// `CourseCatalogStrings`. The screen is the only caller, so wording it
/// differently is a single-file edit.
abstract final class CourseDetailStrings {
  static const String back = 'Буцах';

  /// Opens the Course Learning overview (modules, progress, certification).
  static const String openCourseLearning = 'Сургалт үзэх';

  // --- Section titles ------------------------------------------------------

  static const String descriptionTitle = 'Тухай';
  static const String curriculumTitle = 'Хөтөлбөр';
  static const String instructorsTitle = 'Багш нар';
  static const String prerequisitesTitle = 'Шаардлага';
  static const String whatsIncludedTitle = 'Багтсан зүйлс';

  // --- States ----------------------------------------------------------

  static const String notFound = 'Энэ хичээл олдсонгүй';
  static String get retry => L10n.current.commonRetry;

  static String get networkError => L10n.current.commonNetworkError;
  static String get serverError => L10n.current.commonServerError;
  static String get unexpectedError => L10n.current.commonUnexpectedError;

  // The age/duration/date units are `CourseCatalogStrings.ageUnit`,
  // `.weeksUnit` and `.dateRange(...)` — reused directly rather than repeated
  // here, since this screen shows the same scheduling facts the catalog
  // card's meta row already does.
}
