import 'teacher_home_strings.dart';

/// Every word on the Teacher Gradebook screens (Issue #233), read off the
/// `dungiin-huudas`, `angiin-students-list`, `student-detail` and `feedback`
/// references and carried through verbatim, mixed languages included.
abstract final class TeacherGradebookStrings {
  static const String title = 'Дүнгийн хуудас';

  /// No class to list. Not drawn by the reference — Teacher Home's wording.
  static const String empty = TeacherHomeStrings.empty;

  // --- Student list -------------------------------------------------------

  static const String filterAll = 'Бүгд';
  static const String filterPending = 'Хүлээгдэж буй';
  static const String filterGraded = 'Дүгнэгдсэн';

  /// What the student list shows in place of rows: no verified response
  /// lists a class's students or their submissions (BACKEND GAP). Not drawn
  /// by the reference — PRODUCT DECISION on the final wording.
  static const String studentsUnavailable =
      'Сурагчдын даалгаврын мэдээлэл удахгүй нэмэгдэнэ';

  /// A filter with no row under it.
  static const String noRows = 'Одоогоор даалгавар алга байна';

  // --- Student detail -----------------------------------------------------

  static const String attendance = 'Хичээлийн ирц';
  static const String examScore = 'Шалгалтын дүн';

  /// A figure no confirmed endpoint supplies (BACKEND GAP).
  static const String noFigure = '—';

  // --- Submission detail --------------------------------------------------

  static const String tabAssignment = 'Assignment';
  static const String tabNote = 'Note';
  static const String mentorFeedback = 'Mentor Feedback';

  /// The review's score, once reviewed.
  static String score(num score) =>
      'Оноо: ${score == score.roundToDouble() ? score.toInt() : score}';

  /// In place of the submitted file / link and its description: no
  /// confirmed field carries them (BACKEND GAP). PRODUCT DECISION on the
  /// wording.
  static const String contentUnavailable =
      'Илгээсэн файл болон тайлбар одоогоор харагдахгүй байна';

  /// The Note tab: no teacher note endpoint exists (BACKEND GAP).
  static const String noteUnavailable = 'Тэмдэглэл одоогоор боломжгүй байна';
}
