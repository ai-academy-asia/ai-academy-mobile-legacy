import 'package:http/http.dart' as http;

import '../../../core/api/api_config.dart';
import '../../auth/data/authenticated_client.dart';
import '../../auth/data/http_current_user_repository.dart';
import '../../auth/domain/auth_session_store.dart';
import '../../auth/domain/current_user_failure.dart';
import '../../auth/domain/current_user_repository.dart';
import '../../cohorts/data/http_cohort_repository.dart';
import '../../cohorts/domain/cohort.dart';
import '../../courses/data/http_course_repository.dart';
import '../../courses/domain/course_repository.dart';
import '../domain/teacher_class.dart';
import '../domain/teacher_failure.dart';
import '../domain/teacher_home_repository.dart';
import 'teacher_http.dart';

/// Reads the signed-in teacher's classes against the AI Academy API
/// (Issue #229):
///
///     GET https://api.ai-academy.asia/auth/me
///     GET https://api.ai-academy.asia/teachers/{teacher_id}/schedule
///     Authorization: Bearer <access_token>
///
/// Both verified with the teacher test account. `teacher_id` is the
/// account's `/auth/me` `actor_id` — confirmed live three ways: the schedule
/// answers for it, every assignment's `teacher_id` carries it, and the public
/// `cohort.teacher.id` matches it. The schedule answers `{teacher_id,
/// cohorts: [...]}`, each cohort in exactly `GET /cohorts`'s shape, so it is
/// read by the same [cohortListingFromJson], row by row.
///
/// A track for each class comes from the public `GET /courses` catalog's
/// `level` — best-effort, as Adult Home treats its own catalog lookup: a
/// catalog that cannot be read leaves the badge off rather than failing the
/// screen.
///
/// The token is the one `LoginScreen` saved into [AuthSessionStore]. With no
/// usable session nothing is sent — the guard every authenticated repository
/// applies.
class HttpTeacherHomeRepository implements TeacherHomeRepository {
  HttpTeacherHomeRepository({
    http.Client? client,
    Uri? baseUrl,
    AuthSessionStore? sessionStore,
    CurrentUserRepository? currentUser,
    CourseRepository? courses,
    this.timeout = const Duration(seconds: 15),
  }) : // The shared client that renews an expired session and retries
       // once (Issue #176). Injected in tests.
       _client = client ?? AuthenticatedClient.instance,
       _baseUrl = baseUrl ?? ApiConfig.baseUrl,
       _sessionStore = sessionStore ?? AuthSessionStore.instance,
       _currentUser =
           currentUser ??
           HttpCurrentUserRepository(
             sessionStore: sessionStore ?? AuthSessionStore.instance,
           ),
       _courses = courses ?? HttpCourseRepository();

  final http.Client _client;
  final Uri _baseUrl;
  final AuthSessionStore _sessionStore;
  final CurrentUserRepository _currentUser;
  final CourseRepository _courses;
  final Duration timeout;

  @override
  Future<List<TeacherClass>> getClasses() async {
    ensureTeacherSession(_sessionStore);

    final teacherId = await _teacherId();
    // The catalog is decoration; ask for it alongside, not after.
    final tracks = _tracksByCourseId();

    final response = await teacherGet(
      client: _client,
      url: _baseUrl.resolve('/teachers/$teacherId/schedule'),
      sessionStore: _sessionStore,
      timeout: timeout,
    );

    final cohorts = _cohortsFromBody(response.body);
    final trackOf = await tracks;
    return [
      for (final cohort in cohorts)
        TeacherClass(cohort: cohort, track: trackOf[cohort.course.id]),
    ];
  }

  /// The signed-in account's `actor_id`, once `/auth/me` confirms it is a
  /// teacher. Any other actor's id would name someone else's schedule, so a
  /// non-teacher is refused here rather than sent.
  Future<int> _teacherId() async {
    try {
      final user = await _currentUser.getCurrentUser();
      if (user.actorType != 'teacher') {
        throw TeacherFailure(
          TeacherFailureKind.rejected,
          detail: 'actor_type is "${user.actorType}", not "teacher"',
        );
      }
      return user.actorId;
    } on CurrentUserFailure catch (failure) {
      throw TeacherFailure(switch (failure.kind) {
        CurrentUserFailureKind.sessionExpired =>
          TeacherFailureKind.sessionExpired,
        CurrentUserFailureKind.rejected => TeacherFailureKind.rejected,
        CurrentUserFailureKind.network => TeacherFailureKind.network,
        CurrentUserFailureKind.server => TeacherFailureKind.server,
        CurrentUserFailureKind.unexpected => TeacherFailureKind.unexpected,
      }, detail: 'GET /auth/me: ${failure.detail}');
    }
  }

  /// `course.id` → `level`, or empty when the catalog cannot be read. A
  /// course with no level (Issue #485) has no entry, so its class draws no
  /// track badge.
  Future<Map<int, String>> _tracksByCourseId() async {
    try {
      final courses = await _courses.getCourses();
      return {for (final course in courses) course.id: ?course.level};
    } catch (_) {
      return const {};
    }
  }
}

/// The schedule's `cohorts`, read row by row by [cohortListingFromJson]
/// (Issue #445). Every row is the teacher's own class, so a row that does
/// not parse fails closed: a `server` failure — as a body that is not the
/// envelope's shape is — never a list with that class silently missing.
/// Teacher Schedule, Teacher Programs and Teacher Home all read classes
/// here, and each shows its existing error with retry. The failure detail
/// names each skipped row's id and field, never a value.
List<Cohort> _cohortsFromBody(String body) {
  final decoded = teacherJsonObject(body);
  final cohorts = decoded['cohorts'];
  if (cohorts is! List) {
    throw TeacherFailure(
      TeacherFailureKind.server,
      detail: 'cohorts: expected a list, got ${cohorts.runtimeType}',
    );
  }
  final listing = cohortListingFromJson(cohorts);
  if (listing.skipped.isNotEmpty) {
    throw TeacherFailure(
      TeacherFailureKind.server,
      detail: 'unreadable cohort ${listing.describeSkipped()}',
    );
  }
  return listing.cohorts;
}
