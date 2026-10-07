import 'package:http/http.dart' as http;

import '../../auth/data/authenticated_client.dart';
import '../../auth/domain/auth_session_store.dart';
import '../../home/domain/lesson_schedule.dart';
import '../domain/teacher_class.dart';
import '../domain/teacher_failure.dart';
import '../domain/teacher_home_repository.dart';
import '../domain/teacher_schedule_repository.dart';
import '../domain/teacher_session.dart';
import 'http_teacher_home_repository.dart';
import 'teacher_http.dart';

/// Reads Teacher Schedule against the AI Academy API (Issue #231):
///
///     GET https://api.ai-academy.asia/teachers/{actor_id}/schedule
///     GET https://api.ai-academy.asia/teacher/cohorts/{cohort_id}/sessions
///         ?from=YYYY-MM-DD&to=YYYY-MM-DD
///     GET https://api.ai-academy.asia/teacher/sessions/{session_id}/attendance
///     Authorization: Bearer <access_token>
///
/// All three verified in backend reconnaissance. The classes are Teacher
/// Home's own read ([HttpTeacherHomeRepository]), so the two screens agree
/// on what a teacher teaches. Sessions answer `{cohort_id, sessions: [{id,
/// cohort_id, session_date, start_time, end_time, topic_id, created_at}]}`;
/// attendance answers `{session, counts: {present, late, absent, excused},
/// students}`, of which only `counts` is read.
///
/// Read-only. No session change, teacher request or attendance mark is sent
/// from here — none of those writes has a verified contract.
class HttpTeacherScheduleRepository implements TeacherScheduleRepository {
  HttpTeacherScheduleRepository({
    http.Client? client,
    Uri? baseUrl,
    AuthSessionStore? sessionStore,
    TeacherHomeRepository? classes,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? AuthenticatedClient.instance,
       _baseUrl = baseUrl ?? Uri.parse(defaultBaseUrl),
       _sessionStore = sessionStore ?? AuthSessionStore.instance,
       _classes =
           classes ??
           HttpTeacherHomeRepository(
             sessionStore: sessionStore ?? AuthSessionStore.instance,
           );

  static const String defaultBaseUrl = 'https://api.ai-academy.asia';

  final http.Client _client;
  final Uri _baseUrl;
  final AuthSessionStore _sessionStore;
  final TeacherHomeRepository _classes;
  final Duration timeout;

  @override
  Future<List<TeacherClass>> getClasses() => _classes.getClasses();

  @override
  Future<List<TeacherSession>> getSessions({
    required int cohortId,
    required DateTime from,
    required DateTime to,
  }) async {
    ensureTeacherSession(_sessionStore);
    final response = await teacherGet(
      client: _client,
      url: _baseUrl
          .resolve('/teacher/cohorts/$cohortId/sessions')
          .replace(queryParameters: {'from': _day(from), 'to': _day(to)}),
      sessionStore: _sessionStore,
      timeout: timeout,
    );
    return sessionsFromJson(teacherJsonObject(response.body));
  }

  @override
  Future<AttendanceCounts> getAttendance(int sessionId) async {
    ensureTeacherSession(_sessionStore);
    final response = await teacherGet(
      client: _client,
      url: _baseUrl.resolve('/teacher/sessions/$sessionId/attendance'),
      sessionStore: _sessionStore,
      timeout: timeout,
    );
    return attendanceCountsFromJson(teacherJsonObject(response.body));
  }
}

/// `YYYY-MM-DD`, the query's verified date form.
String _day(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// The `sessions` list of a sessions response. Anything off the verified
/// shape — a missing field, a date or time that does not parse — is a
/// `server` failure, as every teacher response treats it.
List<TeacherSession> sessionsFromJson(Map<String, dynamic> json) {
  final sessions = json['sessions'];
  if (sessions is! List) {
    throw _shape('sessions: expected a list, got ${sessions.runtimeType}');
  }
  return [for (final entry in sessions) _session(entry)];
}

TeacherSession _session(Object? entry) {
  if (entry is! Map<String, dynamic>) throw _shape('session: not an object');

  final id = entry['id'];
  final cohortId = entry['cohort_id'];
  final date = entry['session_date'];
  final start = entry['start_time'];
  final end = entry['end_time'];
  if (id is! int || cohortId is! int) throw _shape('session: id/cohort_id');
  if (date is! String || start is! String || end is! String) {
    throw _shape('session $id: session_date/start_time/end_time');
  }

  final parsedDate = DateTime.tryParse(date);
  final startTime = parseClockTime(start);
  final endTime = parseClockTime(end);
  if (parsedDate == null || startTime == null || endTime == null) {
    throw _shape('session $id: unreadable date or time');
  }

  return TeacherSession(
    id: id,
    cohortId: cohortId,
    date: dateOnly(parsedDate),
    start: startTime,
    end: endTime,
  );
}

/// The `counts` of an attendance response.
AttendanceCounts attendanceCountsFromJson(Map<String, dynamic> json) {
  final counts = json['counts'];
  if (counts is! Map<String, dynamic>) throw _shape('counts: not an object');

  int count(String key) {
    final value = counts[key];
    if (value is! int) throw _shape('counts.$key: expected an int');
    return value;
  }

  return AttendanceCounts(
    present: count('present'),
    late: count('late'),
    absent: count('absent'),
    excused: count('excused'),
  );
}

TeacherFailure _shape(String detail) =>
    TeacherFailure(TeacherFailureKind.server, detail: detail);
