import '../../../core/locale/l10n.dart';
import '../../course_learning/domain/course_learning_failure.dart';
import '../domain/junior_learning_map.dart';

/// Every word on the Junior Home screen.
///
/// The tab labels are Mongolian, verbatim from the frame. Two things to know
/// about the middle one:
///
/// * It is not the adult app's "Хичээл" — the Junior design names that tab
///   differently, so this feature carries its own copy rather than reusing
///   `HomeStrings`.
/// * The frame spells it **"Сурлагын явц"**. Issue #98's written description
///   says "Сургалтын явц". The export is the stated source of truth and
///   `DEVELOPMENT_RULES.md` §6 asks for copy verbatim from the design, so the
///   frame's spelling is what ships; the difference is flagged for review
///   because the two words are not synonyms.
///
/// The card, node and certificate copy the reference draws in English is left
/// in English for the same reason `CourseLearningStrings` does: translating it
/// would be inventing wording the design never specified.
abstract final class JuniorHomeStrings {
  /// The bottom navigation, in the selected language (Issue #511): Нүүр /
  /// Home, Сурлагын явц / Progress, Профайл / Profile — the adult bar's own
  /// Home and Profile keys.
  static String get navHome => L10n.current.navHome;
  static String get navProgress => L10n.current.navProgress;
  static String get navProfile => L10n.current.navProfile;

  /// The map as a whole, for a screen reader arriving at the scroll view.
  static const String learningMap = 'Learning map';

  // --- Loading, empty and failure ------------------------------------------
  //
  // Mongolian, unlike the design copy above: the Figma pack has no loading,
  // empty or error state for this screen, so rather than invent English
  // wording each line is the **verbatim** string the app already shows for
  // the same situation elsewhere (`HomeStrings`, `CohortListStrings`) — the
  // same fact should read the same wherever the student meets it.

  static String get retry => L10n.current.commonRetry;

  /// Shown when the student is enrolled in nothing. `HomeStrings.empty`'s own
  /// wording, which the adult dashboard already uses for this exact case.
  static const String empty = 'Та одоогоор ямар нэг ангид бүртгүүлээгүй байна';

  static String get sessionExpired => L10n.current.commonSessionExpired;
  static String get networkError => L10n.current.commonNetworkError;
  static String get serverError => L10n.current.commonServerError;
  static String get unexpectedError => L10n.current.commonUnexpectedError;
  static const String notEnrolled = 'Та энэ хөтөлбөрт бүртгэлгүй байна';
  static const String notFound = 'Хөтөлбөр олдсонгүй';

  /// One fixed string per [CourseLearningFailureKind] — the family this
  /// screen's repository reports, because it reads the Course Learning
  /// endpoint. Same shape as `HomeStrings.messageFor`.
  static String messageFor(CourseLearningFailureKind kind) => switch (kind) {
    CourseLearningFailureKind.sessionExpired => sessionExpired,
    CourseLearningFailureKind.notEnrolled => notEnrolled,
    CourseLearningFailureKind.notFound => notFound,
    // `locked` is §2.3's lesson-detail 409, which the learning path this
    // screen reads never answers with; the switch just has to be total.
    CourseLearningFailureKind.locked => unexpectedError,
    // The note save's 400s — never answered by the learning path either.
    CourseLearningFailureKind.contentRequired => unexpectedError,
    CourseLearningFailureKind.contentTooLong => unexpectedError,
    // The assignment submission's 400s and 409 — likewise never answered by
    // the learning path.
    CourseLearningFailureKind.submissionEmpty => unexpectedError,
    CourseLearningFailureKind.invalidLink => unexpectedError,
    CourseLearningFailureKind.descriptionTooLong => unexpectedError,
    CourseLearningFailureKind.pastDue => unexpectedError,
    // The quiz attempt's 409s — likewise never answered by the learning
    // path.
    CourseLearningFailureKind.noAttemptsLeft => unexpectedError,
    CourseLearningFailureKind.attemptFinished => unexpectedError,
    CourseLearningFailureKind.alreadyAnswered => unexpectedError,
    // The file upload's 400 and 413 — likewise never answered by the
    // learning path.
    CourseLearningFailureKind.unsupportedFileType => unexpectedError,
    CourseLearningFailureKind.fileTooLarge => unexpectedError,
    CourseLearningFailureKind.network => networkError,
    CourseLearningFailureKind.server => serverError,
    CourseLearningFailureKind.unexpected => unexpectedError,
  };

  // --- Node accessibility --------------------------------------------------
  //
  // The nodes draw no text at all — a tick, a scan mark, a padlock — so
  // without these a screen reader would find five unlabelled boxes.

  static const String nodeCompleted = 'completed';
  static const String nodeAttended = 'attendance recorded';
  static const String nodeOpen = 'not yet available';
  static const String nodeLocked = 'locked';

  static const String checkInOpen = 'attendance check-in open';

  /// Lesson [number] of the path (1-based, course order) and its [title]
  /// when it has one (Issue #410).
  static String _lesson(int number, String title) =>
      title.isEmpty ? 'Lesson $number' : 'Lesson $number: $title';

  /// A lesson node: the lesson, then its state.
  static String nodeLabel(int number, String title, JuniorNodeState state) =>
      '${_lesson(number, title)}, ${switch (state) {
        JuniorNodeState.completed => nodeCompleted,
        JuniorNodeState.attendanceCompleted => nodeAttended,
        // Locked until attendance is confirmed (Issue #443).
        JuniorNodeState.current => nodeLocked,
        JuniorNodeState.open => nodeOpen,
        JuniorNodeState.locked => nodeLocked,
      }}';

  /// The check-in node while check-in is open (Issues #202, #410).
  static String checkInNodeLabel(int number, String title) =>
      '${_lesson(number, title)}, $checkInOpen';
}
