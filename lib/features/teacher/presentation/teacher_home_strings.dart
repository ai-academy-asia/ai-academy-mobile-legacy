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
  static const String room = 'Анги';

  /// Accessibility label for a class's time.
  static const String time = 'Цаг';

  /// No class meets today. Not drawn by the reference — the Lesson List's
  /// wording for the same "nothing here yet" state.
  static const String empty = 'Одоогоор хичээл алга байна';

  static const String retry = HomeStrings.retry;

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

  static const String navHome = HomeStrings.navHome;
  static const String navSchedule = 'Хуваарь';
  static const String navGrades = 'Дүнгийн хуудас';
  static const String navProfile = HomeStrings.navProfile;
}
