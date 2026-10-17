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
import '../../attendance/domain/continue_attendance.dart';
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
    DateTime Function()? clock,
  }) : _dashboard = dashboardRepository ?? EnrolledHomeDashboardRepository(),
       _learning = courseLearningRepository ?? HttpCourseLearningRepository(),
       _attendance = attendanceRepository ?? HttpAttendanceRepository(),
       _clock = clock ?? DateTime.now;

  final HomeDashboardRepository _dashboard;
  final CourseLearningRepository _learning;
  final AttendanceRepository _attendance;

  /// The time attendance is judged at (Issue #443). Injected in tests.
  final DateTime Function() _clock;

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

    // Attendance: the check-in's, and what confirms the lesson to continue
    // with (Issue #443) — read even with no next lesson, so a course whose
    // last class has passed still counts its attendance. Alongside the path
    // and lessons rather than after them; it never throws (see
    // [_attendanceOrNull]).
    final attendance = _attendanceOrNull(slug);
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
      attendanceConfirmed: continueAttendanceConfirmedBy(
        await attendance,
        now: _clock(),
      ),
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

/// Whether the student's attendance at [nextLesson]'s class is already
/// confirmed — that day's session counts as attended, `present` or `late`
/// ([AttendanceSession.countsAsAttended]) — which closes the check-in
/// (Issues #410, #443). Any other status keeps it offered: the backend
/// reports today's session `absent` from midnight until a record exists, so
/// `absent` is not proof the student already checked in, and a check-in
/// over an existing record (a teacher's `absent` or `excused`) is safe — it
/// returns that record untouched (`check_in`: "a repeat scan returns the
/// first record untouched"). False when the day has no session listed; null
/// when there is no lesson to ask about or [attendance] could not be read —
/// check-in then stays closed.
bool? attendanceRecordedOn(
  CourseAttendance? attendance,
  NextLesson? nextLesson,
) {
  if (attendance == null || nextLesson == null) return null;
  return _sessionOn(attendance, nextLesson)?.countsAsAttended ?? false;
}

/// [attendance]'s session on [nextLesson]'s day, if it lists one.
AttendanceSession? _sessionOn(
  CourseAttendance attendance,
  NextLesson nextLesson,
) {
  final day = nextLesson.startsAt;
  return attendance.sessions
      .where(
        (s) =>
            s.date.year == day.year &&
            s.date.month == day.month &&
            s.date.day == day.day,
      )
      .firstOrNull;
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
/// dashboard's, from the cohort's schedule, and [attendanceRecorded] whether
/// that class's attendance is already confirmed — what the check-in node
/// reads (Issues #202, #410, #443).
///
/// [attendanceConfirmed] — the most recent class counts as attended
/// ([continueAttendanceConfirmedBy], Issue #443) — gives the lesson to
/// continue with ATTENDANCE_COMPLETED (Issue #441), by the same
/// [lessonPathStateFor] every lesson state comes from: attended, but not
/// completed by the lesson list's own rule. No other lesson's attendance is
/// known — the backend sends none per lesson (#414).
JuniorLearningMap juniorMapFrom(
  CourseLearningPath path, {
  Map<int, List<Lesson>> lessons = const {},
  Set<int> completedByNote = const {},
  NextLesson? nextLesson,
  bool? attendanceRecorded,
  bool? attendanceConfirmed,
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
  nodes: _withAttendance(
    attendanceConfirmed: attendanceConfirmed,
    completedByNote: completedByNote,
    withResumeLesson(continueLessonId: path.continueLessonId, [
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
  ),
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

/// [nodes] with the lesson to continue with — the check-in's lesson — in the
/// state [lessonPathStateFor] gives it once its attendance is confirmed
/// (Issue #441): ATTENDANCE_COMPLETED while the lesson list's own rule
/// ([completedByNote], `noteCompletesLesson`) does not complete it. Every
/// other node, and every node while attendance is not confirmed, as is.
List<JuniorMapNode> _withAttendance(
  List<JuniorMapNode> nodes, {
  required bool? attendanceConfirmed,
  required Set<int> completedByNote,
}) {
  if (attendanceConfirmed != true) return nodes;
  return [
    for (final node in nodes)
      if (node.state == JuniorNodeState.current)
        JuniorMapNode(
          id: node.id,
          state: juniorNodeStateOf(
            lessonPathStateFor(
              hasSavedNote: completedByNote.contains(node.id),
              attendanceConfirmed: true,
              classDateArrived: null,
              checkInActive: null,
            ),
          ),
          locked: node.locked,
          title: node.title,
          moduleId: node.moduleId,
          moduleOrder: node.moduleOrder,
        )
      else
        node,
  ];
}

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
