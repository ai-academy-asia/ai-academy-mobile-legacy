import '../domain/course_learning_failure.dart';

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

  // --- Failures ----------------------------------------------------------
  //
  // Mongolian, unlike the rest of this file: these are not design copy. The
  // Figma pack has no error state for this screen, so rather than invent
  // English wording for one, each line is the **verbatim** string the app
  // already shows for the same failure elsewhere (`CohortListStrings`,
  // `HomeStrings`, `EnrollmentStrings`) — the same fact should read the same
  // wherever the student meets it.

  static const String retry = 'Дахин оролдох';

  static const String sessionExpired =
      'Нэвтрэх хугацаа дууссан. Дахин нэвтэрнэ үү';
  static const String networkError =
      'Сүлжээнд холбогдож чадсангүй. Дахин оролдоно уу';
  static const String serverError =
      'Серверт алдаа гарлаа. Түр хүлээгээд дахин оролдоно уу';
  static const String unexpectedError = 'Алдаа гарлаа. Дахин оролдоно уу';

  /// The contract's `403 not_enrolled` — the student is signed in, but not on
  /// this course. Worded as its own case rather than folded into
  /// [unexpectedError]: retrying will not fix it, and the student can act on
  /// knowing which of the two it is.
  static const String notEnrolled = 'Та энэ хөтөлбөрт бүртгэлгүй байна';

  /// The contract's `404 course_not_found` — a slug that no longer resolves.
  static const String notFound = 'Хөтөлбөр олдсонгүй';

  /// §2.4's `404 material_not_found` — worded after [notFound], which names
  /// the course rather than the file and so would read wrong under a
  /// material row.
  static const String materialNotFound = 'Файл олдсонгүй';

  /// §2.5's two note-save rules. The Figma pack has no copy for either, so
  /// both follow the Login screen's own validation wording
  /// (`LoginStrings.passwordRequired`, `LoginStrings.passwordTooShort`).
  static const String noteContentRequired = 'Тэмдэглэлээ оруулна уу';
  static const String noteContentTooLong =
      'Тэмдэглэл 5000 тэмдэгтээс ихгүй байх ёстой';

  /// §2.6's submission rules. No Figma copy exists for any of them either:
  /// the empty case repeats the link field's own placeholder, [linkPlaceholder],
  /// and the rest follow the note rules' wording above.
  static const String submissionEmpty = linkPlaceholder;
  static const String invalidLink = 'Зөв link оруулна уу';
  static const String descriptionTooLong =
      'Тайлбар 5000 тэмдэгтээс ихгүй байх ёстой';
  static const String pastDue = 'Даалгавар илгээх хугацаа дууссан';

  /// §2.8's two upload rules. No Figma copy exists for either; both follow
  /// the wording of the other rules above.
  static const String unsupportedFileType =
      'Энэ төрлийн файл оруулах боломжгүй';
  static const String fileTooLarge = 'Файлын хэмжээ 20 MB-аас ихгүй байх ёстой';

  /// §2.6's `404 assignment_not_found` — worded after [materialNotFound], for
  /// the same reason: [notFound] names the course.
  static const String assignmentNotFound = 'Даалгавар олдсонгүй';

  /// §2.7's `404 quiz_not_found`/`attempt_not_found` — worded after
  /// [materialNotFound], for the same reason.
  static const String quizNotFound = 'Quiz олдсонгүй';

  /// §2.7's `409 no_attempts_left`. No Figma copy exists; worded after
  /// [pastDue], the other "this can no longer be done" rule.
  static const String quizNoAttemptsLeft = 'Quiz өгөх оролдлого дууссан';

  /// One fixed string per [CourseLearningFailureKind], the same shape
  /// `HomeStrings.messageFor` and `EnrollmentStrings.messageFor` use.
  static String messageFor(CourseLearningFailureKind kind) => switch (kind) {
    CourseLearningFailureKind.sessionExpired => sessionExpired,
    CourseLearningFailureKind.notEnrolled => notEnrolled,
    CourseLearningFailureKind.notFound => notFound,
    // No copy exists for a locked lesson yet; the generic line stands in
    // rather than inventing one. Normal navigation never opens one.
    CourseLearningFailureKind.locked => unexpectedError,
    CourseLearningFailureKind.contentRequired => noteContentRequired,
    CourseLearningFailureKind.contentTooLong => noteContentTooLong,
    CourseLearningFailureKind.submissionEmpty => submissionEmpty,
    CourseLearningFailureKind.invalidLink => invalidLink,
    CourseLearningFailureKind.descriptionTooLong => descriptionTooLong,
    CourseLearningFailureKind.pastDue => pastDue,
    CourseLearningFailureKind.noAttemptsLeft => quizNoAttemptsLeft,
    // Both are state conflicts the quiz screen recovers from by re-reading
    // the attempt (§0: "409 → refresh the screen state"), so neither is
    // normally shown; the generic line stands in if one ever is.
    CourseLearningFailureKind.attemptFinished => unexpectedError,
    CourseLearningFailureKind.alreadyAnswered => unexpectedError,
    CourseLearningFailureKind.unsupportedFileType => unsupportedFileType,
    CourseLearningFailureKind.fileTooLarge => fileTooLarge,
    CourseLearningFailureKind.network => networkError,
    CourseLearningFailureKind.server => serverError,
    CourseLearningFailureKind.unexpected => unexpectedError,
  };

  /// Matches `HomeStrings.percentComplete`/`CohortListStrings.percentComplete`
  /// verbatim — the same fact, the same wording, on a card this feature does
  /// not share code with.
  static String percentComplete(int percent) => '$percent% complete';

  static const String continueLearning = 'Continue learning';

  static const String moduleCaption = 'Modules';

  // --- Lesson List -------------------------------------------------------

  static const String lessonsLabel = 'LESSONS';
  static const String lessonCaption = 'Lesson';

  /// A module whose lessons loaded but number none. No Figma frame or copy
  /// exists for it; Mongolian, like the failure lines above, and worded after
  /// the app's existing empty states (`CohortListStrings.empty`,
  /// `CourseCatalogStrings.empty`: "Одоогоор … алга байна").
  static const String lessonsEmpty = 'Одоогоор хичээл алга байна';

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
  static const String assignmentSubmittedSuccess =
      'Assignment submitted successfully';

  static const String mentorFeedbackTitle = 'Mentor Feedback';
  static const String noFeedbackYet = 'No feedback yet';

  static const String editNote = 'Засах';

  /// Shown centred over the video area when a recording is not up yet —
  /// the reference's own wording.
  static const String videoUnavailable = 'Бичлэг хараахан оруугүй байна';

  // --- Assignment attachment ---------------------------------------------

  /// The dashed drop area shown before a file is attached, and the accepted
  /// types under it — both transcribed from the reference frames verbatim,
  /// including the frame's own spacing inside the type list.
  static const String uploadFile = 'Upload File';
  static const String uploadFileTypes = 'File type:pdf, pkl,csv,ipynb, json';

  static const String downloadAttachment = 'Download';
  static const String downloadedAttachment = 'Downloaded';
  static const String removeAttachment = 'Remove';
  static const String cancelDownload = 'Cancel';
  static const String downloadStarted = 'Your download has started.';
  static const String downloadingAttachment = 'Downloading...';

  /// The same card's two lines while a student's own file uploads. The
  /// reference draws this state once, worded for a download ("Your download
  /// has started." / "Downloading...") under an area labelled "Upload File";
  /// for a real upload that wording is wrong, so — as with the frame's
  /// "Compelete" — the design's intent is kept and the word corrected.
  static const String uploadStarted = 'Your upload has started.';
  static const String uploadingFile = 'Uploading...';
  static const String cancelUpload = 'Cancel';
  static const String attachmentComplete = 'Complete';

  /// e.g. "1 MB, PDF" — the reference shows a file type alongside the size
  /// once a download finishes; there is no confirmed source for a real file
  /// type, so this is fixed the same way `CourseExerciseMaterial.sizeLabel`
  /// is a pre-formatted display string rather than raw data.
  static String attachmentTypeLabel(String sizeLabel) => '$sizeLabel, PDF';

  /// The same "1 MB, PDF" line for a file the student really uploaded: the
  /// type is [fileName]'s own extension, upper-cased the way the reference
  /// writes it. A name with no extension has no type to show, so the line is
  /// the size alone.
  static String uploadedFileLabel(String sizeLabel, String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) return sizeLabel;
    return '$sizeLabel, ${fileName.substring(dot + 1).toUpperCase()}';
  }

  // --- Quiz preview/result card (Exercise Detail) ---------------------------

  static const String startQuiz = 'Start quiz';
  static const String retakeQuiz = 'Дахин quiz өгөх';
  static const String yourScoreLabel = 'Таны оноо';

  static String quizQuestionCount(int count) =>
      count == 1 ? 'Total 1 question' : 'Total $count questions';

  // --- Quiz question screen -------------------------------------------------

  static String quizProgressCounter(int current, int total) =>
      '$current/$total';

  static const String quizContinue = 'Үргэлжлүүлэх';
  static const String quizCorrectTitle = 'Хариул зөв байна.';
  static const String quizWrongTitle = 'Хариулт буруу байна.';

  static String quizCorrectAnswerIs(String letter) =>
      "Зөв хариулт нь '$letter'.";

  // --- Quiz result screen ----------------------------------------------------

  static String quizResultSummary(int total, int correct) =>
      'Та $total асуултаас $correct-д зөв хариуллаа';

  static const String quizResultQuestionLabel = 'Асуулт';
  static const String quizFinish = 'Дуусгах';
}
