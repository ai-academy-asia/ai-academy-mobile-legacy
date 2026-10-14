import '../../attendance/data/http_attendance_repository.dart';
import '../../attendance/domain/attendance_repository.dart';
import '../../attendance/domain/course_attendance.dart';
import '../../course_learning/data/http_course_learning_repository.dart';
import '../../course_learning/domain/course_learning_failure.dart';
import '../../course_learning/domain/course_learning_path.dart';
import '../../course_learning/domain/course_learning_repository.dart';
import '../../course_learning/domain/lesson.dart';
import '../../course_learning/domain/lesson_note_completion.dart';
import '../../home/data/enrolled_home_dashboard_repository.dart';
import '../../home/domain/home_dashboard.dart';
import '../../home/domain/home_dashboard_repository.dart';
import '../../home/domain/home_failure.dart';
import '../domain/junior_home_repository.dart';
import '../domain/junior_learning_map.dart';
import 'junior_home_content.dart';

/// Junior Home over the real API.
///
/// **Composed, not new.** This adds no transport and no parsing of its own —
/// both already exist and are reused whole:
///
///  * `HomeDashboardRepository` answers *which* course this student is on.
///    `EnrolledProgram.courseSlug` is the app's existing resolution of that
///    question (`/me/cohorts` + `/cohorts` + `/courses`), and it is why no
///    Junior slug is hardcoded here — there is no such constant in the
///    project, and inventing one would pin every kid to one course.
///  * `CourseLearningRepository` answers *what the course looks like*, over
///    `GET /me/courses/{course_slug}/learning` — the same call, the same
///    `HttpCourseLearningRepository`, that `CourseModuleListScreen` makes —
///    and, since the path is one node per lesson (Issue #410), each
///    module's lessons over `GET /me/modules/{module_id}/lessons`, the Lesson
///    List's own call: one request per module, made together.
///  * `AttendanceRepository` answers *whether today's lesson already has an
///    attendance record*, over `GET /me/attendance?course=` — the call the
///    attendance screens make — so the check-in node stops once recorded.
///    Read-only, and optional: if it cannot be read the map still loads.
///
/// So this file is a mapper: [CourseLearningPath] and its lessons in,
/// [JuniorLearningMap] out. Composing feature repositories this way is the established shape —
/// `EnrolledHomeDashboardRepository` already reaches across `auth`,
/// `cohorts`, `courses` and `enrollments` for the same reason.
///
/// **What the backend does not send stays client-side**, exactly as the
/// contract says: the certificate panel's artwork and its "Junior" label are
/// the design's. None of that is invented data — it is design the API was
/// never asked to carry.
class ApiJuniorHomeRepository implements JuniorHomeRepository {
  ApiJuniorHomeRepository({
    HomeDashboardRepository? dashboardRepository,
    CourseLearningRepository? courseLearningRepository,
    AttendanceRepository? attendanceRepository,
  }) : _dashboard = dashboardRepository ?? EnrolledHomeDashboardRepository(),
       _learning = courseLearningRepository ?? HttpCourseLearningRepository(),
       _attendance = attendanceRepository ?? HttpAttendanceRepository();

  final HomeDashboardRepository _dashboard;
  final CourseLearningRepository _learning;
  final AttendanceRepository _attendance;

  @override
  Future<JuniorLearningMap?> getLearningMap() async {
    final String slug;
    final NextLesson? nextLesson;
    try {
      final dashboard = await _dashboard.getDashboard();
      final program = dashboard.program;
      // Enrolled in nothing: an empty screen, not an error — the same
      // reading `HomeController.isEmpty` gives the adult dashboard.
      if (program == null) return null;
      slug = program.courseSlug;
      nextLesson = program.nextLesson;
    } on HomeFailure catch (failure) {
      throw CourseLearningFailure(
        _kindFor(failure.kind),
        detail: 'resolving the enrolled course: ${failure.detail}',
      );
    }

    // Attendance only matters for a next lesson's check-in; read it — when
    // there is one — alongside the path and lessons rather than after them.
    // It never throws (see [_attendanceOrNull]).
    final attendance = nextLesson == null
        ? Future<CourseAttendance?>.value()
        : _attendanceOrNull(slug);
    final path = await _learning.getCourseLearning(slug);
    // Every module's lessons (Issue #410), all at once: the lesson path is
    // one node per lesson. The same `GET /me/modules/{id}/lessons` the
    // Lesson List reads — which lists a locked module's lessons too, each
    // `locked`. A failure fails the map, as any course-learning read does.
    final lessons = await Future.wait([
      for (final module in path.modules) _learning.getLessons(module.id),
    ]);
    // Completion is a saved note (Issue #415): each unlocked lesson's note,
    // read back from the backend. A failed read fails the map — a lesson is
    // never shown completed, or not, on a guess.
    final completedByNote = await lessonsCompletedByNote(_learning, [
      for (final (i, module) in path.modules.indexed)
        for (final lesson in lessons[i])
          (id: lesson.id, locked: lesson.locked || module.locked),
    ]);
    return juniorMapFrom(
      path,
      lessons: {
        for (final (i, module) in path.modules.indexed) module.id: lessons[i],
      },
      completedByNote: completedByNote,
      nextLesson: nextLesson,
      attendanceRecorded: attendanceRecordedOn(await attendance, nextLesson),
    );
  }

  /// `GET /me/attendance` for the course, or null when it cannot be read:
  /// the map never fails over check-in's guard, and an unknown answer keeps
  /// check-in closed (`JuniorLearningMap.checkInOpenAt`; Issue #410).
  Future<CourseAttendance?> _attendanceOrNull(String slug) async {
    try {
      return await _attendance.getCourseAttendance(slug);
    } catch (_) {
      return null;
    }
  }
}

/// Whether [nextLesson]'s day already has an attendance record (Issue
/// #410): its session's `status` is non-null — the backend leaves it null
/// until a record exists (`present`, `late`, `excused`, or the teacher's
/// `absent`). False when the day has no session listed; null when there is
/// no lesson to ask about or [attendance] could not be read.
bool? attendanceRecordedOn(
  CourseAttendance? attendance,
  NextLesson? nextLesson,
) {
  if (attendance == null || nextLesson == null) return null;
  final day = nextLesson.startsAt;
  final session = attendance.sessions
      .where(
        (s) =>
            s.date.year == day.year &&
            s.date.month == day.month &&
            s.date.day == day.day,
      )
      .firstOrNull;
  return session?.status != null;
}

/// `HomeFailureKind` into this screen's family.
///
/// Total and one-to-one: every kind the dashboard reports has the same
/// meaning in [CourseLearningFailureKind]. A separate `JuniorHomeFailure`
/// enum is deliberately not added — `docs/ai/DATA_AND_API.md` §4 keeps
/// failure families apart *per domain*, and Junior Home's domain is this
/// endpoint, whose failures are already modelled.
CourseLearningFailureKind _kindFor(HomeFailureKind kind) => switch (kind) {
  HomeFailureKind.sessionExpired => CourseLearningFailureKind.sessionExpired,
  HomeFailureKind.network => CourseLearningFailureKind.network,
  HomeFailureKind.server => CourseLearningFailureKind.server,
  HomeFailureKind.unexpected => CourseLearningFailureKind.unexpected,
};

/// One course's learning path, read as the Junior map.
///
/// Public so the mapping can be tested directly against a [CourseLearningPath]
/// built from a contract response, without standing up two repositories.
///
/// [lessons] are each module's lessons by module id — one node per lesson,
/// in course order: modules by `order`, then their lessons by `order`
/// (Issue #410), the resume lesson picked out ([withResumeLesson]). A
/// module with none listed adds no node. A lesson is completed when its id
/// is in [completedByNote] — it has a saved, non-empty note (Issue #415) —
/// never by the server's own `completed` flag. [nextLesson] is the
/// dashboard's, from the cohort's schedule, and [attendanceRecorded] today's
/// record — what the check-in node reads (Issues #202, #410).
JuniorLearningMap juniorMapFrom(
  CourseLearningPath path, {
  Map<int, List<Lesson>> lessons = const {},
  Set<int> completedByNote = const {},
  NextLesson? nextLesson,
  bool? attendanceRecorded,
}) => JuniorLearningMap(
  nextLesson: nextLesson,
  attendanceRecorded: attendanceRecorded,
  courseSlug: path.courseSlug,
  progress: JuniorCourseProgress(
    title: path.courseTitle,
    // Displayed, never derived: the contract computes this server-side from
    // lessons, which is why it does not match "completed modules / total".
    percentComplete: path.percentComplete,
  ),
  // Sorted on `order` rather than trusting either array, so the route's
  // order is the course's; then the resume lesson picked out (Issue #410).
  nodes: withResumeLesson(continueLessonId: path.continueLessonId, [
    for (final module
        in path.modules.toList()..sort((a, b) => a.order.compareTo(b.order)))
      for (final lesson
          in (lessons[module.id] ?? const <Lesson>[]).toList()
            ..sort((a, b) => a.order.compareTo(b.order)))
        JuniorMapNode(
          id: lesson.id,
          state: _stateFor(
            lesson,
            inLockedModule: module.locked,
            completed: completedByNote.contains(lesson.id),
          ),
          locked: lesson.locked || module.locked,
          title: lesson.title,
          moduleId: module.id,
          moduleOrder: module.order,
        ),
  ]),
  certificate: JuniorCertificate(
    track: JuniorHomeContent.track,
    // The one course name the contract carries. The Figma frame happens to
    // show a different placeholder here than in the progress card; both are
    // this field.
    courseName: path.courseTitle,
    description: JuniorHomeContent.certificateDescription,
    status: _certificateStatusFor(path.certificateStatus),
  ),
  continueModuleId: path.continueModuleId,
  continueLessonId: path.continueLessonId,
);

/// A lesson's look: [completed] — a saved note (Issue #415) — wins the look,
/// while whether it opens is [JuniorMapNode.locked]. Otherwise the server's
/// lock: a lesson in a locked module is locked — the backend lists such
/// lessons `locked` already (a lesson's lock *is* its module's), so this
/// only keeps a tap from ever reaching `409 lesson_locked`. "Open and
/// unfinished" is what is left — see [JuniorNodeState.open]. The server's
/// own `completed` flag is not read: completion is the note.
JuniorNodeState _stateFor(
  Lesson lesson, {
  required bool inLockedModule,
  required bool completed,
}) {
  if (completed) return JuniorNodeState.completed;
  if (lesson.locked || inLockedModule) return JuniorNodeState.locked;
  return JuniorNodeState.open;
}

/// The contract's three `certificate.status` values. Anything else — or
/// nothing — is null rather than a guessed fourth state.
JuniorCertificateStatus? _certificateStatusFor(String? status) =>
    switch (status) {
      'not_eligible' => JuniorCertificateStatus.notEligible,
      'eligible' => JuniorCertificateStatus.eligible,
      'issued' => JuniorCertificateStatus.issued,
      _ => null,
    };
