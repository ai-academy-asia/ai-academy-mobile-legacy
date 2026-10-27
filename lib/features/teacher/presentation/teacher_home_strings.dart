import '../../../core/locale/l10n.dart';
import '../../home/presentation/home_strings.dart';
import '../domain/teacher_failure.dart';

/// Every word on Teacher Home (Issue #229).
///
/// Read off the `teacher-homepage` reference, which mixes languages the way
/// the student Home frames do — "24 Students" in English under a Mongolian
/// title — and is carried through verbatim, the policy `HomeStrings`
/// follows. The states the reference does not draw reuse the student Home's
/// wording, so the two homes say the same thing for the same failure.
abstract final class TeacherHomeStrings {
  static const String title = 'Өнөөдрийн хичээл';

  /// The capsule in a class card's top-right: the cohort's `enrolled_count`.
  static String students(int count) => '$count Students';

  /// Accessibility label for a class's room.
  static String get room => L10n.current.teacherClassRoom;

  /// Accessibility label for a class's time.
  static String get time => L10n.current.teacherClassTime;

  /// No class meets today. Not drawn by the reference — the Lesson List's
  /// wording for the same "nothing here yet" state. In the selected language
  /// since Issue #547, with Room and Time above: Teacher Schedule shares them
  /// (and Gradebook this line).
  static String get empty => L10n.current.teacherHomeEmpty;

  static String get retry => HomeStrings.retry;

  /// One fixed string per [TeacherFailureKind]. A `rejected` request has no
  /// wording of its own on the student Home, so it reads as the generic
  /// failure.
  static String messageFor(TeacherFailureKind kind) => switch (kind) {
    TeacherFailureKind.sessionExpired => HomeStrings.sessionExpired,
    TeacherFailureKind.network => HomeStrings.networkError,
    TeacherFailureKind.server => HomeStrings.serverError,
    TeacherFailureKind.rejected ||
    TeacherFailureKind.unexpected => HomeStrings.unexpectedError,
  };

  // --- Bottom navigation ----------------------------------------------------
  //
  // In the selected language (Issue #511): Хуваарь / Schedule, Хөтөлбөрүүд /
  // Programs, Профайл / Profile.

  static String get navSchedule => L10n.current.navSchedule;

  /// Хөтөлбөрүүд — formerly "Дүнгийн хуудас" (Issue #390).
  static String get navGrades => L10n.current.navPrograms;
  static String get navProfile => HomeStrings.navProfile;
}
