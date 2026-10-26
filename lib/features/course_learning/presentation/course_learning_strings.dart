import '../../../core/locale/l10n.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../domain/course_learning_failure.dart';

/// Every word on the Course Learning screens.
///
/// English, not Mongolian-first like the rest of the app's strings files: the
/// Figma reference itself is captioned in English ("How AI works", "Continue
/// learning", "CERTIFICATION"), unlike Login/Course Catalog/Course Detail,
/// which were all built against Mongolian copy. Shown verbatim from the
/// reference rather than translated, since translating would be inventing
/// copy the design never specified.
///
/// The app's own lines — the failure and validation messages, and the
/// Exercise Detail and Quiz copy the reference drew in Mongolian — follow
/// the selected language (Issues #525, #539), read from `learning*` and
/// `quiz*` ARB keys. Messages a controller stores when they happen (a note
/// save's, a file's, a lesson completion's) keep their language until the
/// next action.
abstract final class CourseLearningStrings {
  /// The back control's label — [AppBackButton.label] (Issue #327), the
  /// shared `commonBack` (Issue #509).
  static String get back => AppBackButton.label;

  /// What a screen reader announces for the lesson video's play button:
  /// `Тоглуулах`, or `Play` in English (Issue #509).
  static String get play => L10n.current.videoPlay;

  /// What a screen reader announces for the quiz's close button: `Хаах`, or
  /// `Close` in English (Issue #509).
  static String get quizClose => L10n.current.quizClose;

  // --- Failures ----------------------------------------------------------
  //
  // Not design copy: the Figma pack has no error state for this screen, so
  // each Mongolian line is the **verbatim** string the app already shows for
  // the same failure elsewhere (`CohortListStrings`, `HomeStrings`,
  // `EnrollmentStrings`) — the same fact should read the same wherever the
  // student meets it. In the selected language (Issues #507, #525, #539).

  static String get retry => L10n.current.commonRetry;

  static String get sessionExpired => L10n.current.commonSessionExpired;
  static String get networkError => L10n.current.commonNetworkError;
  static String get serverError => L10n.current.commonServerError;
  static String get unexpectedError => L10n.current.commonUnexpectedError;

  /// The contract's `403 not_enrolled` — the student is signed in, but not on
  /// this course. Worded as its own case rather than folded into
  /// [unexpectedError]: retrying will not fix it, and the student can act on
  /// knowing which of the two it is.
  ///
  /// The same words Junior Home shows for the same endpoint's 403, so the
  /// same key (`learningNotEnrolled`, Issue #525).
  static String get notEnrolled => L10n.current.learningNotEnrolled;

  /// The contract's `404 course_not_found` — a slug that no longer resolves.
  ///
  /// Junior Home's key for it, as with [notEnrolled] (Issue #525).
  static String get notFound => L10n.current.learningNotFound;

  /// §2.4's `404 material_not_found` — worded after [notFound], which names
  /// the course rather than the file and so would read wrong under a
  /// material row.
  static String get materialNotFound => L10n.current.learningMaterialNotFound;

  /// §2.5's two note-save rules. The Figma pack has no copy for either, so
  /// both follow the Login screen's own validation wording
  /// (`LoginStrings.passwordRequired`, `LoginStrings.passwordTooShort`).
  static String get noteContentRequired => L10n.current.learningNoteRequired;
  static String get noteContentTooLong => L10n.current.learningNoteTooLong;

  /// §2.6's submission rules. No Figma copy exists for any of them either:
  /// the empty case repeats the link field's own placeholder, [linkPlaceholder],
  /// and the rest follow the note rules' wording above.
  static String get submissionEmpty => linkPlaceholder;
  static String get invalidLink => L10n.current.learningInvalidLink;
  static String get descriptionTooLong =>
      L10n.current.learningDescriptionTooLong;
  static String get pastDue => L10n.current.learningPastDue;

  /// §2.8's two upload rules. No Figma copy exists for either; both follow
  /// the wording of the other rules above.
  static String get unsupportedFileType =>
      L10n.current.learningUnsupportedFileType;
  static String get fileTooLarge => L10n.current.learningFileTooLarge;

  /// §2.6's `404 assignment_not_found` — worded after [materialNotFound], for
  /// the same reason: [notFound] names the course.
  static String get assignmentNotFound =>
      L10n.current.learningAssignmentNotFound;

  /// §2.7's `404 quiz_not_found`/`attempt_not_found` — worded after
  /// [materialNotFound], for the same reason.
  static String get quizNotFound => L10n.current.quizNotFound;

  /// §2.7's `409 no_attempts_left`. No Figma copy exists; worded after
  /// [pastDue], the other "this can no longer be done" rule.
  static String get quizNoAttemptsLeft => L10n.current.quizNoAttemptsLeft;

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

  /// The label on Course Detail's lesson to continue with (Issue #437) —
  /// the product's own copy.
  ///
  /// In the selected language (Issue #525).
  static String get continueHere => L10n.current.learningContinueHere;

  // --- Lesson List -------------------------------------------------------

  /// A module whose lessons loaded but number none. No Figma frame or copy
  /// exists for it; Mongolian, like the failure lines above, and worded after
  /// the app's existing empty states (`CohortListStrings.empty`,
  /// `CourseCatalogStrings.empty`: "Одоогоор … алга байна").
  ///
  /// In the selected language (Issue #525).
  static String get lessonsEmpty => L10n.current.learningLessonsEmpty;

  static const String certificationLabel = 'CERTIFICATION';
  static const String certificationTitle = 'Earn a Certificate of completion';

  // --- Exercise Detail -------------------------------------------------
  //
  // Mixed English/Mongolian, not a translation inconsistency: the Figma
  // reference itself mixes them this way (English tab labels, Mongolian
  // field copy), and every string below is shown verbatim from it. The
  // Mongolian lines follow the selected language (Issue #539); the
  // reference's English ones stay as drawn.

  static const String readMore = 'Read more';
  static const String readLess = 'Read less';

  static const String assignmentTab = 'Assignment';
  static const String courseMaterialsTab = 'Course materials';
  static const String noteTab = 'Note';

  static String get linkPlaceholder => L10n.current.learningLinkPlaceholder;
  static String get descriptionFloatingLabel =>
      L10n.current.learningDescriptionLabel;
  static String get descriptionPlaceholder =>
      L10n.current.learningDescriptionPlaceholder;
  static const String submit = 'Submit';
  static const String submitted = 'Submitted';
  static const String resubmit = 'Resubmit';
  static const String assignmentSubmittedSuccess =
      'Assignment submitted successfully';

  static const String mentorFeedbackTitle = 'Mentor Feedback';
  static const String noFeedbackYet = 'No feedback yet';

  static String get editNote => L10n.current.learningEditNote;

  /// Shown centred over the video area when a recording is not up yet —
  /// the reference's own wording.
  static String get videoUnavailable => L10n.current.learningVideoUnavailable;

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
  static String get retakeQuiz => L10n.current.quizRetake;
  static String get yourScoreLabel => L10n.current.quizYourScore;

  static String quizQuestionCount(int count) =>
      count == 1 ? 'Total 1 question' : 'Total $count questions';

  // --- Quiz question screen -------------------------------------------------

  static String quizProgressCounter(int current, int total) =>
      '$current/$total';

  static String get quizContinue => L10n.current.quizContinue;
  static String get quizCorrectTitle => L10n.current.quizCorrectTitle;
  static String get quizWrongTitle => L10n.current.quizWrongTitle;

  static String quizCorrectAnswerIs(String letter) =>
      L10n.current.quizCorrectAnswerIs(letter);

  // --- Quiz result screen ----------------------------------------------------

  /// An English plural on [total] (Issue #539): "1 question" / "N questions".
  static String quizResultSummary(int total, int correct) =>
      L10n.current.quizResultSummary(total, correct);

  static String get quizResultQuestionLabel => L10n.current.quizResultQuestion;
  static String get quizFinish => L10n.current.quizFinish;
}
