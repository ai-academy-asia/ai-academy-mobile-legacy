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

  // --- Lesson List -------------------------------------------------------

  static const String lessonsLabel = 'LESSONS';
  static const String lessonCaption = 'Lesson';

  static const String certificationLabel = 'CERTIFICATION';
  static const String certificationTitle = 'Earn a Certificate of completion';

  // --- Exercise Detail -------------------------------------------------
  //
  // Mixed English/Mongolian, not a translation inconsistency: the Figma
  // reference itself mixes them this way (English tab labels, Mongolian
  // field copy), and every string below is shown verbatim from it.

  static const String readMore = 'Read more';
  static const String readLess = 'Read less';

  static const String assignmentTab = 'Assignment';
  static const String courseMaterialsTab = 'Course materials';
  static const String noteTab = 'Note';

  static const String linkPlaceholder = 'Link оруулна уу';
  static const String descriptionFloatingLabel = 'Тайлбар';
  static const String descriptionPlaceholder = 'Энд бичнэ үү...';
  static const String submit = 'Submit';
  static const String submitted = 'Submitted';
  static const String resubmit = 'Resubmit';

  static const String mentorFeedbackTitle = 'Mentor Feedback';
  static const String noFeedbackYet = 'No feedback yet';

  static const String editNote = 'Засах';

  /// [CourseExerciseNote.authorLabel] for a note the student just left —
  /// matches the one pre-existing sample note's own wording verbatim.
  static const String noteAuthorMe = 'Me';

  /// [CourseExerciseNote.timestampLabel] for a note the student just
  /// left or just edited — see `NoteTab`'s own doc comment on why this,
  /// not a fabricated date/time.
  static const String noteJustNow = 'Just now';
}
