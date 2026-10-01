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
  static const String navHome = 'Нүүр';
  static const String navProgress = 'Сурлагын явц';
  static const String navProfile = 'Профайл';

  /// The map as a whole, for a screen reader arriving at the scroll view.
  static const String learningMap = 'Learning map';

  // --- Loading, empty and failure ------------------------------------------
  //
  // Mongolian, unlike the design copy above: the Figma pack has no loading,
  // empty or error state for this screen, so rather than invent English
  // wording each line is the **verbatim** string the app already shows for
  // the same situation elsewhere (`HomeStrings`, `CohortListStrings`) — the
  // same fact should read the same wherever the student meets it.

  static const String retry = 'Дахин оролдох';

  /// Shown when the student is enrolled in nothing. `HomeStrings.empty`'s own
  /// wording, which the adult dashboard already uses for this exact case.
  static const String empty = 'Та одоогоор ямар нэг ангид бүртгүүлээгүй байна';

  static const String sessionExpired =
      'Нэвтрэх хугацаа дууссан. Дахин нэвтэрнэ үү';
  static const String networkError =
      'Сүлжээнд холбогдож чадсангүй. Дахин оролдоно уу';
  static const String serverError =
      'Серверт алдаа гарлаа. Түр хүлээгээд дахин оролдоно уу';
  static const String unexpectedError = 'Алдаа гарлаа. Дахин оролдоно уу';
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
  static const String nodeCurrent = 'current lesson';
  static const String nodeLocked = 'locked';

  static String nodeLabel(int number, JuniorNodeState state) =>
      'Lesson $number, ${switch (state) {
        JuniorNodeState.completed => nodeCompleted,
        JuniorNodeState.current => nodeCurrent,
        JuniorNodeState.locked => nodeLocked,
      }}';
}
