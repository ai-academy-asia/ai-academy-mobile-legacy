import 'package:http/http.dart' as http;

import '../../../core/models/localized_text.dart';
import '../../auth/data/authenticated_client.dart';
import '../../auth/domain/auth_session_store.dart';
import '../domain/teacher_class.dart';
import '../domain/teacher_failure.dart';
import '../domain/teacher_gradebook_repository.dart';
import '../domain/teacher_home_repository.dart';
import '../domain/teacher_submission.dart';
import 'http_teacher_home_repository.dart';
import 'teacher_http.dart';

/// Reads Teacher Gradebook against the AI Academy API (Issue #233):
///
///     GET https://api.ai-academy.asia/teachers/{actor_id}/schedule
///     GET https://api.ai-academy.asia/teacher/cohorts/{cohort_id}/assignments
///     GET https://api.ai-academy.asia/teacher/assignments/{assignment_id}/submissions
///     GET https://api.ai-academy.asia/teacher/submissions/{submission_id}
///     Authorization: Bearer <access_token>
///
/// All confirmed by captured responses. The classes are Teacher Home's own
/// read ([HttpTeacherHomeRepository]). The submissions list answers
/// `{assignment_id, count, max_score, submissions: [...]}`, the latest
/// submission per student; a list entry and the detail are read by the one
/// [submissionFromJson].
///
/// Not called: `GET /teacher/cohorts/{id}/students` (confirmed, but the
/// Gradebook's rows are submissions, which carry their student),
/// `GET /teacher/submissions/{id}/file` (response not verified), and
/// `POST /teacher/submissions/{id}/review` (request `{score, feedback}`
/// confirmed; success and error responses not).
class HttpTeacherGradebookRepository implements TeacherGradebookRepository {
  HttpTeacherGradebookRepository({
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
  Future<List<TeacherAssignment>> getAssignments(int cohortId) async {
    final body = await _get('/teacher/cohorts/$cohortId/assignments');
    return assignmentsFromJson(teacherJsonObject(body));
  }

  @override
  Future<List<TeacherSubmission>> getSubmissions(int assignmentId) async {
    final body = await _get('/teacher/assignments/$assignmentId/submissions');
    final json = teacherJsonObject(body);
    final submissions = json['submissions'];
    if (submissions is! List) {
      throw _shape('submissions: expected a list');
    }
    return [
      for (final entry in submissions)
        if (entry is Map<String, dynamic>)
          submissionFromJson(entry, requireStudent: true)
        else
          throw _shape('submission: not an object'),
    ];
  }

  @override
  Future<TeacherSubmission> getSubmission(int submissionId) async {
    final body = await _get('/teacher/submissions/$submissionId');
    return submissionFromJson(teacherJsonObject(body), id: submissionId);
  }

  Future<String> _get(String path) async {
    ensureTeacherSession(_sessionStore);
    final response = await teacherGet(
      client: _client,
      url: _baseUrl.resolve(path),
      sessionStore: _sessionStore,
      timeout: timeout,
    );
    return response.body;
  }
}

/// The class's assignments — the confirmed `{assignments, cohort_id,
/// count}` envelope's `assignments` list. Anything else is a `server`
/// failure.
List<TeacherAssignment> assignmentsFromJson(Map<String, dynamic> json) {
  final list = json['assignments'];
  if (list is! List) throw _shape('assignments: expected a list');
  return [for (final entry in list) _assignment(entry)];
}

TeacherAssignment _assignment(Object? entry) {
  if (entry is! Map<String, dynamic>) throw _shape('assignment: not an object');
  final id = entry['id'];
  if (id is! int) throw _shape('assignment: id');
  return TeacherAssignment(
    id: id,
    title: LocalizedText(
      mn: _string(entry, 'title_mn') ?? _string(entry, 'title'),
      en: _string(entry, 'title_en') ?? _string(entry, 'title'),
    ),
  );
}

/// A submission — a list entry ([requireStudent]) or the detail. [id] is
/// the one asked for, used when the body carries no `id` of its own.
TeacherSubmission submissionFromJson(
  Map<String, dynamic> json, {
  int? id,
  bool requireStudent = false,
}) {
  final ownId = json['id'];
  final status = json['status'];
  final score = json['score'];
  final assignmentId = json['assignment_id'];
  final submittedAt = _string(json, 'submitted_at');
  if (status is! String) throw _shape('status: expected a string');
  if (score != null && score is! num) throw _shape('score: expected a number');
  if (assignmentId != null && assignmentId is! int) {
    throw _shape('assignment_id: expected an int');
  }
  final resolvedId = ownId is int ? ownId : id;
  if (resolvedId == null) throw _shape('id: expected an int');

  final student = _student(json['student']);
  if (requireStudent && student == null) throw _shape('student: missing');

  return TeacherSubmission(
    id: resolvedId,
    status: status,
    assignmentId: assignmentId as int?,
    student: student,
    score: score as num?,
    feedback: _feedback(json['feedback']),
    description: _string(json, 'description'),
    link: _string(json, 'link'),
    submittedAt: submittedAt == null
        ? null
        : DateTime.tryParse(submittedAt)?.toLocal(),
  );
}

SubmissionStudent? _student(Object? json) => switch (json) {
  null => null,
  {'id': final int id, 'name': final String name} => SubmissionStudent(
    id: id,
    name: name,
    initials: json['initials'] is String ? json['initials'] as String : null,
  ),
  _ => throw _shape('student: expected {id, name}'),
};

/// `feedback` is `{created_at, mentor, message}` (confirmed on the list),
/// or `null` before review. Only `message` is read.
String? _feedback(Object? json) => switch (json) {
  null => null,
  {'message': final String? message} => message,
  Map<String, dynamic>() => null,
  _ => throw _shape('feedback: expected an object'),
};

/// A nullable string field; a value of another type is a `server` failure.
String? _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw _shape('$key: expected a string');
  return value;
}

TeacherFailure _shape(String detail) =>
    TeacherFailure(TeacherFailureKind.server, detail: detail);
