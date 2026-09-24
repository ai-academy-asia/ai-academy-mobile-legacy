/// Every word on the Course Learning screens.
///
/// English, not Mongolian-first like the rest of the app's strings files: the
/// Figma reference itself is captioned in English ("How AI works", "Continue
/// learning", "CERTIFICATION"), unlike Login/Course Catalog/Course Detail,
/// which were all built against Mongolian copy. Shown verbatim from the
/// reference rather than translated, since translating would be inventing
/// copy the design never specified.
abstract final class CourseLearningStrings {
  static const String back = 'Back';

  /// Matches `HomeStrings.percentComplete`/`CohortListStrings.percentComplete`
  /// verbatim — the same fact, the same wording, on a card this feature does
  /// not share code with.
  static String percentComplete(int percent) => '$percent% complete';

  static const String continueLearning = 'Continue learning';

  static const String moduleCaption = 'Modules';

  static const String certificationLabel = 'CERTIFICATION';
  static const String certificationTitle = 'Earn a Certificate of completion';
}
