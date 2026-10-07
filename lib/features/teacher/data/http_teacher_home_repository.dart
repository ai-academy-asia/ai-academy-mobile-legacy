import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
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
/// read by the same [cohortFromJson].
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
       _baseUrl = baseUrl ?? Uri.parse(defaultBaseUrl),
       _sessionStore = sessionStore ?? AuthSessionStore.instance,
       _currentUser =
           currentUser ??
           HttpCurrentUserRepository(
             sessionStore: sessionStore ?? AuthSessionStore.instance,
           ),
       _courses = courses ?? HttpCourseRepository();

  static const String defaultBaseUrl = 'https://api.ai-academy.asia';

  final http.Client _client;
  final Uri _baseUrl;
  final AuthSessionStore _sessionStore;
  final CurrentUserRepository _currentUser;
  final CourseRepository _courses;
  final Duration timeout;

  @override
  Future<List<TeacherClass>> getClasses() async {
    if (!_sessionStore.isSignedIn) {
      throw const TeacherFailure(
        TeacherFailureKind.sessionExpired,
        detail: 'no session held',
      );
    }
    if (_sessionStore.isExpired()) {
      throw const TeacherFailure(
        TeacherFailureKind.sessionExpired,
        detail: 'session lifetime ran out',
      );
    }

    final teacherId = await _teacherId();
    // The catalog is decoration; ask for it alongside, not after.
    final tracks = _tracksByCourseId();

    final http.Response response;
    try {
      response = await getRaw(
        client: _client,
        url: _baseUrl.resolve('/teachers/$teacherId/schedule'),
        headers: _sessionStore.authorizationHeader,
        timeout: timeout,
      );
    } on ApiFailure catch (failure) {
      // The transport throws only for a request that never completed.
      throw TeacherFailure(TeacherFailureKind.network, detail: failure.detail);
    }

    final failure = _failureForStatus(response.statusCode);
    if (failure != null) {
      // What the store asks of a token the backend has rejected: forget it.
      if (failure.kind == TeacherFailureKind.sessionExpired) {
        _sessionStore.clear();
      }
      throw failure;
    }

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

  /// `course.id` → `level`, or empty when the catalog cannot be read.
  Future<Map<int, String>> _tracksByCourseId() async {
    try {
      final courses = await _courses.getCourses();
      return {for (final course in courses) course.id: course.level};
    } catch (_) {
      return const {};
    }
  }
}

/// Same mapping every other authenticated GET keeps its own copy of.
TeacherFailure? _failureForStatus(int statusCode) {
  if (statusCode == 401) {
    return const TeacherFailure(
      TeacherFailureKind.sessionExpired,
      detail: 'HTTP 401',
    );
  }
  if (statusCode >= 500) {
    return TeacherFailure(
      TeacherFailureKind.server,
      detail: 'HTTP $statusCode',
    );
  }
  if (statusCode >= 400) {
    return TeacherFailure(
      TeacherFailureKind.rejected,
      detail: 'HTTP $statusCode',
    );
  }
  if (statusCode < 200 || statusCode >= 300) {
    return TeacherFailure(
      TeacherFailureKind.unexpected,
      detail: 'HTTP $statusCode',
    );
  }
  return null;
}

/// The schedule's `cohorts`, each read by [cohortFromJson]. A body that is
/// not that shape is the API misbehaving: a `server` failure.
List<Cohort> _cohortsFromBody(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (e) {
    throw TeacherFailure(
      TeacherFailureKind.server,
      detail: 'malformed JSON: ${e.message}',
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw const TeacherFailure(
      TeacherFailureKind.server,
      detail: 'response was not a JSON object',
    );
  }
  final cohorts = decoded['cohorts'];
  if (cohorts is! List) {
    throw TeacherFailure(
      TeacherFailureKind.server,
      detail: 'cohorts: expected a list, got ${cohorts.runtimeType}',
    );
  }
  try {
    return [for (final entry in cohorts) cohortFromJson(entry)];
  } on ApiFailure catch (failure) {
    throw TeacherFailure(TeacherFailureKind.server, detail: failure.detail);
  }
}
