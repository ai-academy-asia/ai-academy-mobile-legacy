import 'package:http/http.dart' as http;

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
///     GET https://api.ai-academy.asia/teacher/submissions/{submission_id}
///     Authorization: Bearer <access_token>
///
/// The classes are Teacher Home's own read ([HttpTeacherHomeRepository]).
/// The submission's confirmed fields are `status` (`submitted` /
/// `reviewed`), `score`, `feedback` and `history`; the first three are
/// read.
///
/// Not called, because their responses are not verified:
/// `GET /teacher/cohorts/{id}/students`, `GET /teacher/cohorts/{id}/assignments`,
/// `GET /teacher/assignments/{id}/submissions` (beyond `submissions[].id`),
/// `GET /teacher/submissions/{id}/file`, and
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
  Future<TeacherSubmission> getSubmission(int submissionId) async {
    ensureTeacherSession(_sessionStore);
    final response = await teacherGet(
      client: _client,
      url: _baseUrl.resolve('/teacher/submissions/$submissionId'),
      sessionStore: _sessionStore,
      timeout: timeout,
    );
    return submissionFromJson(
      teacherJsonObject(response.body),
      id: submissionId,
    );
  }
}

/// A submission detail's confirmed fields. [id] is the one asked for: the
/// body's own id field is not among the confirmed ones. A missing or
/// mistyped `status`, or a non-numeric `score` / non-string `feedback`, is
/// a `server` failure.
TeacherSubmission submissionFromJson(
  Map<String, dynamic> json, {
  required int id,
}) {
  final status = json['status'];
  final score = json['score'];
  final feedback = json['feedback'];
  if (status is! String) throw _shape('status: expected a string');
  if (score != null && score is! num) throw _shape('score: expected a number');
  if (feedback != null && feedback is! String) {
    throw _shape('feedback: expected a string');
  }
  return TeacherSubmission(
    id: id,
    status: status,
    score: score as num?,
    feedback: feedback as String?,
  );
}

TeacherFailure _shape(String detail) =>
    TeacherFailure(TeacherFailureKind.server, detail: detail);
