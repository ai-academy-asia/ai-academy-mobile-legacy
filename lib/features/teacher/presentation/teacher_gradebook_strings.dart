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

  /// No submission under the selected filter — or none in the class. Not
  /// drawn by the reference.
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

  /// The outlined box around the student's description, as the reference
  /// labels it.
  static const String description = 'Тайлбар';

  /// A submission with neither a link nor a description. Its `file` is not
  /// read: its download is not verified (BACKEND GAP). PRODUCT DECISION on
  /// the wording.
  static const String contentUnavailable =
      'Илгээсэн файл одоогоор харагдахгүй байна';

  /// The Note tab: no teacher note endpoint exists (BACKEND GAP).
  static const String noteUnavailable = 'Тэмдэглэл одоогоор боломжгүй байна';
}
