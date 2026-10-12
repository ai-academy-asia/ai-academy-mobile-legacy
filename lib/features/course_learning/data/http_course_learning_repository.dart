import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
import '../../../core/models/localized_text.dart';
import '../../auth/domain/auth_session_store.dart';
import '../domain/course_certificate.dart';
import '../domain/course_exercise.dart';
import '../domain/course_learning_failure.dart';
import '../domain/course_learning_path.dart';
import '../domain/course_learning_repository.dart';
import '../domain/course_module.dart';
import '../domain/course_quiz.dart';
import '../domain/file_size_label.dart';
import '../domain/lesson.dart';
import '../domain/lesson_completion.dart';
import '../domain/material_download.dart';
import '../domain/uploaded_file.dart';
import 'course_module_visuals.dart';
import '../../auth/data/authenticated_client.dart';

part 'http_course_learning/assignments.dart';
part 'http_course_learning/display_labels.dart';
part 'http_course_learning/json_fields.dart';
part 'http_course_learning/quiz.dart';

/// Reads one course's learning path — hero, progress, module list — one
/// module's lessons, and one lesson's content against the AI Academy API.
///
///     GET https://api.ai-academy.asia/me/courses/{course_slug}/learning
///     GET https://api.ai-academy.asia/me/modules/{module_id}/lessons
///     GET https://api.ai-academy.asia/me/lessons/{lesson_id}
///     PUT https://api.ai-academy.asia/me/lessons/{lesson_id}/note
///     GET https://api.ai-academy.asia/me/materials/{material_id}/download
///     POST https://api.ai-academy.asia/me/assignments/{assignment_id}/submissions
///     POST https://api.ai-academy.asia/me/files   (multipart/form-data)
///     POST https://api.ai-academy.asia/me/quizzes/{quiz_id}/attempts
///     POST https://api.ai-academy.asia/me/quiz-attempts/{attempt_id}/answers
///     POST https://api.ai-academy.asia/me/quiz-attempts/{attempt_id}/finish
///     GET https://api.ai-academy.asia/me/quiz-attempts/{attempt_id}
///     Authorization: Bearer <access_token>
///
/// The lessons shape is `course_learning_api_contract_v1.md` §2.2's, read in
/// full — see [Lesson]. The lesson-detail shape is §2.3's, read for the
/// content Exercise Detail draws — see [CourseExercise] for what is and is
/// not integrated.
///
/// The learning path's shape is the one §2.1 documents, and **only** the
/// fields with a slot in today's Figma-built UI
/// are read. What the contract also sends and this client deliberately
/// ignores, because no screen draws it: `course.id`,
/// `course.banner_image_url` (the design draws the bundled illustration, not
/// the real course image), `enrollment_id`, `cohort_id` and
/// `progress.completed_lessons`/`total_lessons` — the screen's progress row
/// draws `progress.percent` alone. Every one of them is a real field.
///
/// Each module's `lesson_count`/`completed_lessons` *are* modelled, on
/// [CourseModule], although no card draws them yet: they are the module's
/// own server-sent counts, kept with it rather than dropped at the parse.
///
/// `continue.lesson_id` and `certificate.status` *are* modelled, and were not
/// until Junior Home asked for them — that screen holds the server's continue
/// target whole and shows a certificate panel. They are read here rather than
/// in a second repository so one place still owns this endpoint's parsing.
///
/// A field the contract says the backend does *not* send stays client-side:
/// the per-module icon and accent (`course_module_visuals.dart`) and the hero
/// illustration, which has exactly one exported asset.
///
/// Parsing is strict in the same way `HttpCourseRepository`'s is, and for the
/// same reason: a required field that arrives in the wrong shape surfaces as
/// a named `server` failure rather than a silently wrong screen.
///
/// The token is the one `LoginScreen` saved into [AuthSessionStore]. With no
/// usable session the request is not sent at all — the guard
/// `HttpEnrolledCohortsRepository` and `HttpEnrollmentRepository` both apply.
class HttpCourseLearningRepository implements CourseLearningRepository {
  HttpCourseLearningRepository({
    http.Client? client,
    Uri? baseUrl,
    AuthSessionStore? sessionStore,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 15),
    this.uploadTimeout = const Duration(minutes: 3),
  }) : // The shared client that renews an expired session and retries
       // once (Issue #176). Injected in tests.
       _client = client ?? AuthenticatedClient.instance,
       _baseUrl = baseUrl ?? Uri.parse(defaultBaseUrl),
       _sessionStore = sessionStore ?? AuthSessionStore.instance,
       _clock = clock ?? DateTime.now;

  static const String defaultBaseUrl = 'https://api.ai-academy.asia';

  /// The one hero illustration the design has exported. The contract states
  /// `illustrationAsset` stays client-side, and there is no confirmed mapping
  /// from a course to a per-course drawing, so every course gets this one
  /// until the design ships more art. **BACKEND GAP / design gap** — a
  /// per-course illustration needs an asset set, not an API field.
  static const String heroIllustrationAsset =
      'assets/images/course_learning/how_ai_works.svg';

  final http.Client _client;
  final Uri _baseUrl;
  final AuthSessionStore _sessionStore;

  /// What "today" is when a note's timestamp is labelled. Injected in tests.
  final DateTime Function() _clock;

  final Duration timeout;

  /// How long [uploadFile] may take — its own budget, because [timeout] is
  /// sized for small JSON answers and §2.8 accepts files up to 20 MB. That
  /// is 160 Mbit: about 160 s over a slow ~1 Mbit/s mobile uplink, so three
  /// minutes lets the largest accepted file through on such a link, with a
  /// little margin, rather than failing it as a network error part-way.
  final Duration uploadTimeout;

  @override
  Future<CourseLearningPath> getCourseLearning(String courseSlug) async {
    // Encoded, not interpolated raw: a slug is server-supplied data, and
    // `Uri.resolve` would read a stray `/` or `?` in one as structure.
    final body = await _authorizedGet(
      '/me/courses/${Uri.encodeComponent(courseSlug)}/learning',
    );
    return _pathFromBody(body);
  }

  /// §2.2 `GET /me/modules/{module_id}/lessons` — one module's lessons, in
  /// the order the server sends them. See [_lessonsFromBody].
  ///
  /// 404 (`module_not_found`) reads as [CourseLearningFailureKind.notFound]
  /// and 403 (`not_enrolled`) as [CourseLearningFailureKind.notEnrolled],
  /// through the same [_failureForStatus] the learning path uses.
  @override
  Future<List<Lesson>> getLessons(int moduleId) async {
    final body = await _authorizedGet('/me/modules/$moduleId/lessons');
    return _lessonsFromBody(body);
  }

  /// §2.3 `GET /me/lessons/{lesson_id}` — one lesson's content. See
  /// [_exerciseFromBody].
  ///
  /// 404 (`lesson_not_found`) reads as [CourseLearningFailureKind.notFound],
  /// 403 (`not_enrolled`) as [CourseLearningFailureKind.notEnrolled] and 409
  /// (`lesson_locked`) as [CourseLearningFailureKind.locked].
  @override
  Future<CourseExercise> getExercise(int lessonId) async {
    final body = await _authorizedGet('/me/lessons/$lessonId');
    return _exerciseFromBody(body, now: _clock());
  }

  /// §2.5 `PUT /me/lessons/{lesson_id}/note` with `{"content": ...}` — the
  /// saved note, `201` on the first save and `200` after. See [_savedNoteFrom].
  ///
  /// 400 `content_required`/`content_too_long` read as their own
  /// [CourseLearningFailureKind]s; every other status maps as the reads' do.
  @override
  Future<CourseExerciseNote> saveNote(int lessonId, String content) async {
    final body = await _authorizedPut('/me/lessons/$lessonId/note', {
      'content': content,
    });
    return _savedNoteFrom(body, now: _clock());
  }

  /// §2.3 "Mark complete" — `POST /me/lessons/{lesson_id}/complete`, no
  /// body. See [_completionFromBody].
  ///
  /// The contract names no errors of its own for this call; it is a §2.3
  /// lesson path, so its 404 (`lesson_not_found`), 403 (`not_enrolled`) and
  /// 409 (`lesson_locked`) read as the lesson detail's do, through the same
  /// [_failureForStatus].
  @override
  Future<LessonCompletion> completeLesson(int lessonId) async {
    final body = await _authorizedPostWithoutBody(
      '/me/lessons/$lessonId/complete',
    );
    return _completionFromBody(body);
  }

  /// §2.4 `GET /me/materials/{material_id}/download` — a pre-signed link for
  /// one material. See [_downloadFromBody].
  ///
  /// 404 (`material_not_found`) reads as [CourseLearningFailureKind.notFound]
  /// and 503 (`storage_error`) as [CourseLearningFailureKind.server], through
  /// the same [_failureForStatus] every endpoint here uses.
  @override
  Future<MaterialDownload> getMaterialDownload(int materialId) async {
    final body = await _authorizedGet('/me/materials/$materialId/download');
    return _downloadFromBody(body);
  }

  /// §2.9 `GET /me/courses/{course_slug}/certificate` — the student's
  /// certificate status for one course, and the issued certificate when there
  /// is one. See [_certificateFromBody].
  ///
  /// Statuses map as every endpoint's here do, through [_failureForStatus].
  @override
  Future<CourseCertificate> getCourseCertificate(String courseSlug) async {
    final body = await _authorizedGet(
      '/me/courses/${Uri.encodeComponent(courseSlug)}/certificate',
    );
    return _certificateFromBody(body);
  }

  /// §2.9 `GET /me/certificates/{cert_number}/download` — `{url,
  /// expires_at}`, a pre-signed link to the certificate's file.
  @override
  Future<CertificateDownload> getCertificateDownload(String certNumber) async {
    final body = await _authorizedGet(
      '/me/certificates/${Uri.encodeComponent(certNumber)}/download',
    );
    final decoded = _decodeObject(body);
    final url = _requireHttpUrl(decoded, 'download.url');
    final rawExpiresAt = _requireString(decoded, 'download.expires_at');
    final expiresAt = DateTime.tryParse(rawExpiresAt);
    if (expiresAt == null) {
      throw CourseLearningFailure(
        CourseLearningFailureKind.server,
        detail: 'download.expires_at: not a timestamp ("$rawExpiresAt")',
      );
    }
    return CertificateDownload(url: url, expiresAt: expiresAt);
  }

  /// §2.6 `POST /me/assignments/{assignment_id}/submissions` with
  /// `{"link", "description", "file_id"}` — a submission, or a resubmission
  /// (the same call). All three keys are always sent, `null` for what the
  /// student left out; [fileId] is a §2.8 upload's id. `201` answers with
  /// the new latest submission, read by the same [_submissionFrom] the
  /// lesson detail uses.
  ///
  /// 400 `submission_empty`/`invalid_link`/`description_too_long` and 409
  /// `past_due` read as their own [CourseLearningFailureKind]s; every other
  /// status maps as the reads' do.
  @override
  Future<AssignmentSubmission> submitAssignment(
    int assignmentId, {
    String? link,
    String? description,
    int? fileId,
  }) async {
    final body = await _authorizedPost(
      '/me/assignments/$assignmentId/submissions',
      {'link': link, 'description': description, 'file_id': fileId},
    );
    return _submissionFromBody(body, now: _clock());
  }

  /// §2.8 `POST /me/files` — one `multipart/form-data` part named `file`,
  /// carrying [fileName] and [bytes]. `201` answers with the stored file;
  /// see [_uploadedFileFrom].
  ///
  /// 400 `unsupported_file_type` and 413 `file_too_large` read as their own
  /// [CourseLearningFailureKind]s, and 502/503 `storage_error` as
  /// [CourseLearningFailureKind.server]; every other status maps as the
  /// other endpoints' do. Sent under [uploadTimeout], not [timeout].
  @override
  Future<UploadedFile> uploadFile({
    required String fileName,
    required List<int> bytes,
  }) async {
    final body = await _authorizedRequest(
      '/me/files',
      (url, headers) => postMultipartRaw(
        client: _client,
        url: url,
        field: 'file',
        fileName: fileName,
        bytes: bytes,
        headers: headers,
        timeout: uploadTimeout,
      ),
    );
    return _uploadedFileFrom(body);
  }

  /// §2.7 `POST /me/quizzes/{quiz_id}/attempts`, no body — `201` with a new
  /// attempt, or `200` with the student's unfinished one (resume). Both are
  /// the same shape; see [_attemptFromBody].
  ///
  /// 409 `no_attempts_left` reads as its own [CourseLearningFailureKind];
  /// every other status maps as the other endpoints' do.
  @override
  Future<QuizAttempt> startQuizAttempt(int quizId) async {
    final body = await _authorizedPostWithoutBody(
      '/me/quizzes/$quizId/attempts',
    );
    return _attemptFromBody(body);
  }

  /// §2.7 `POST /me/quiz-attempts/{attempt_id}/answers` with
  /// `{"question_id", "option_id"}`. See [_answerFromBody].
  ///
  /// 409 `already_answered`/`attempt_finished` read as their own
  /// [CourseLearningFailureKind]s.
  @override
  Future<QuizAnswerResult> answerQuizQuestion(
    int attemptId, {
    required int questionId,
    required int optionId,
  }) async {
    final body = await _authorizedPost('/me/quiz-attempts/$attemptId/answers', {
      'question_id': questionId,
      'option_id': optionId,
    });
    return _answerFromBody(body);
  }

  /// §2.7 `POST /me/quiz-attempts/{attempt_id}/finish`, no body. See
  /// [_attemptResultFromBody].
  ///
  /// 409 `attempt_finished` reads as its own [CourseLearningFailureKind].
  @override
  Future<QuizAttemptResult> finishQuizAttempt(int attemptId) async {
    final body = await _authorizedPostWithoutBody(
      '/me/quiz-attempts/$attemptId/finish',
    );
    return _attemptResultFromBody(body);
  }

  /// §2.7 `GET /me/quiz-attempts/{attempt_id}` — a finished attempt's result
  /// again. §2.7 introduces it as the finish answer "also readable later", so
  /// it is read by the same [_attemptResultFromBody].
  @override
  Future<QuizAttemptResult> getQuizAttempt(int attemptId) async {
    final body = await _authorizedGet('/me/quiz-attempts/$attemptId');
    return _attemptResultFromBody(body);
  }

  Future<String> _authorizedGet(String path) => _authorizedRequest(
    path,
    (url, headers) =>
        getRaw(client: _client, url: url, headers: headers, timeout: timeout),
  );

  Future<String> _authorizedPut(String path, Map<String, Object?> body) =>
      _authorizedRequest(
        path,
        (url, headers) => putJsonRaw(
          client: _client,
          url: url,
          body: body,
          headers: headers,
          timeout: timeout,
        ),
      );

  Future<String> _authorizedPost(String path, Map<String, Object?> body) =>
      _authorizedRequest(
        path,
        (url, headers) => postJsonRaw(
          client: _client,
          url: url,
          body: body,
          headers: headers,
          timeout: timeout,
        ),
      );

  /// §2.7's start and finish and §2.3's mark-complete carry no body, so none
  /// is sent — the same transport `HttpEnrollmentRepository` uses for its
  /// body-less POST.
  Future<String> _authorizedPostWithoutBody(String path) => _authorizedRequest(
    path,
    (url, headers) => postWithoutBody(
      client: _client,
      url: url,
      headers: headers,
      timeout: timeout,
    ),
  );

  /// The session guard, request and status mapping every endpoint here
  /// shares, whatever [send] does on the wire. Returns the body of a 2xx;
  /// throws [CourseLearningFailure] otherwise.
  Future<String> _authorizedRequest(
    String path,
    Future<http.Response> Function(Uri url, Map<String, String> headers) send,
  ) async {
    if (!_sessionStore.isSignedIn) {
      throw const CourseLearningFailure(
        CourseLearningFailureKind.sessionExpired,
        detail: 'no session held',
      );
    }
    if (_sessionStore.isExpired()) {
      throw const CourseLearningFailure(
        CourseLearningFailureKind.sessionExpired,
        detail: 'session lifetime ran out',
      );
    }

    final http.Response response;
    try {
      response = await send(
        _baseUrl.resolve(path),
        _sessionStore.authorizationHeader,
      );
    } on ApiFailure catch (failure) {
      // The transport throws only for a request that never completed.
      throw CourseLearningFailure(
        CourseLearningFailureKind.network,
        detail: failure.detail,
      );
    }

    final failure = _failureForStatus(response.statusCode, response.body);
    if (failure != null) {
      // What the store asks of a token the backend has rejected: forget it,
      // so nothing goes on sending it.
      if (failure.kind == CourseLearningFailureKind.sessionExpired) {
        _sessionStore.clear();
      }
      throw failure;
    }

    return response.body;
  }
}

/// 401 is the session being refused, not the request; 403 and 404 are the two
/// errors §2.1 documents by name. Kept as this feature's own copy rather than
/// shared with the other repositories' mappings, the way `ApiFailure`'s,
/// `AuthFailure`'s and `EnrollmentFailure`'s are already kept apart.
///
/// [body] is read for a 400, a 409 and a 413 only: §2.5's, §2.6's and §2.8's
/// validation rules share the first, `lesson_locked`, `past_due` and §2.7's
/// attempt conflicts the second, §2.8 names the third's code — and §0 says
/// the app branches on the body's `error` code. §2.7's `400 invalid_option`
/// has no kind of its own: the client only ever sends an option the attempt
/// itself listed, so it reads as any other unexpected 4xx.
CourseLearningFailure? _failureForStatus(int statusCode, String body) {
  if (statusCode == 400) {
    final kind = switch (_errorCode(body)) {
      'content_required' => CourseLearningFailureKind.contentRequired,
      'content_too_long' => CourseLearningFailureKind.contentTooLong,
      'submission_empty' => CourseLearningFailureKind.submissionEmpty,
      'invalid_link' => CourseLearningFailureKind.invalidLink,
      'description_too_long' => CourseLearningFailureKind.descriptionTooLong,
      'unsupported_file_type' => CourseLearningFailureKind.unsupportedFileType,
      _ => CourseLearningFailureKind.unexpected,
    };
    return CourseLearningFailure(kind, detail: 'HTTP 400');
  }
  if (statusCode == 413) {
    // §2.8's one 413. Without its code it is any other 4xx: unexpected.
    return CourseLearningFailure(
      _errorCode(body) == 'file_too_large'
          ? CourseLearningFailureKind.fileTooLarge
          : CourseLearningFailureKind.unexpected,
      detail: 'HTTP 413',
    );
  }
  if (statusCode == 401) {
    return const CourseLearningFailure(
      CourseLearningFailureKind.sessionExpired,
      detail: 'HTTP 401',
    );
  }
  if (statusCode == 403) {
    return const CourseLearningFailure(
      CourseLearningFailureKind.notEnrolled,
      detail: 'HTTP 403',
    );
  }
  if (statusCode == 404) {
    return const CourseLearningFailure(
      CourseLearningFailureKind.notFound,
      detail: 'HTTP 404',
    );
  }
  if (statusCode == 409) {
    // `lesson_locked` — and any 409 without a code of its own — stays
    // [CourseLearningFailureKind.locked], as before.
    final kind = switch (_errorCode(body)) {
      'past_due' => CourseLearningFailureKind.pastDue,
      'no_attempts_left' => CourseLearningFailureKind.noAttemptsLeft,
      'attempt_finished' => CourseLearningFailureKind.attemptFinished,
      'already_answered' => CourseLearningFailureKind.alreadyAnswered,
      _ => CourseLearningFailureKind.locked,
    };
    return CourseLearningFailure(kind, detail: 'HTTP 409');
  }
  if (statusCode >= 500) {
    return CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'HTTP $statusCode',
    );
  }
  if (statusCode < 200 || statusCode >= 300) {
    return CourseLearningFailure(
      CourseLearningFailureKind.unexpected,
      detail: 'HTTP $statusCode',
    );
  }
  return null;
}

/// §0's `{"error": "<code>", ...}`, or null when the body is not that shape —
/// an unreadable error body is still an error, just an unnamed one.
String? _errorCode(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic> && decoded['error'] is String) {
      return decoded['error'] as String;
    }
  } on FormatException {
    // Falls through to null.
  }
  return null;
}

// --- Body mapping ----------------------------------------------------------

CourseLearningPath _pathFromBody(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (e) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'malformed JSON: ${e.message}',
    );
  }

  if (decoded is! Map<String, dynamic>) {
    throw const CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'response was not a JSON object',
    );
  }

  final course = _requireObject(decoded, 'course');
  final progress = _requireObject(decoded, 'progress');

  final modules = decoded['modules'];
  if (modules is! List) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'modules: expected a list, got ${modules.runtimeType}',
    );
  }

  return CourseLearningPath(
    courseSlug: _requireString(course, 'course.slug'),
    courseTitle: _requireLocalized(course, 'course.title'),
    // Gentler than the title on purpose: a course with no description yet is
    // a content gap the screen can render around, while a course with no
    // title is a response this client cannot draw at all.
    description: _optionalLocalized(course, 'course.description') ?? '',
    illustrationAsset: HttpCourseLearningRepository.heroIllustrationAsset,
    percentComplete: _requirePercent(progress),
    continueModuleId: _continueId(decoded['continue'], 'module_id'),
    continueLessonId: _continueId(decoded['continue'], 'lesson_id'),
    certificateStatus: _certificateStatus(decoded['certificate']),
    modules: [for (final entry in modules) _moduleFrom(entry)],
  );
}

CourseModule _moduleFrom(Object? entry) {
  if (entry is! Map<String, dynamic>) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'a module entry was not a JSON object (got ${entry.runtimeType})',
    );
  }

  final order = _requireInt(entry, 'order');
  final visuals = moduleVisualsFor(order);

  return CourseModule(
    id: _requireInt(entry, 'id'),
    order: order,
    title: _requireLocalized(entry, 'title'),
    scheduleLabel: _scheduleLabel(entry['schedule']),
    iconAsset: visuals.iconAsset,
    accentColor: visuals.accentColor,
    lessonCount: _requireInt(entry, 'module.lesson_count'),
    completedLessons: _requireInt(entry, 'module.completed_lessons'),
    // Server-sent, never derived — the contract is explicit that the client
    // must not compute either one.
    completed: _requireBool(entry, 'completed'),
    locked: _requireBool(entry, 'locked'),
  );
}

/// §2.2's body — `{"module": {...}, "lessons": [...]}` — into [Lesson]s.
///
/// Both halves of the envelope are required: `module` for the id every
/// lesson is tagged with, `lessons` for the list. The list keeps the order
/// the server sent it in; `order` is carried on each lesson but never sorted
/// on, so the screen shows exactly the sequence the backend chose.
List<Lesson> _lessonsFromBody(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (e) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'malformed JSON: ${e.message}',
    );
  }

  if (decoded is! Map<String, dynamic>) {
    throw const CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'response was not a JSON object',
    );
  }

  final moduleId = _requireInt(_requireObject(decoded, 'module'), 'module.id');

  final lessons = decoded['lessons'];
  if (lessons is! List) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'lessons: expected a list, got ${lessons.runtimeType}',
    );
  }

  return [for (final entry in lessons) _lessonFrom(entry, moduleId)];
}

Lesson _lessonFrom(Object? entry, int moduleId) {
  if (entry is! Map<String, dynamic>) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'a lesson entry was not a JSON object (got ${entry.runtimeType})',
    );
  }

  return Lesson(
    id: _requireInt(entry, 'lesson.id'),
    moduleId: moduleId,
    order: _requireInt(entry, 'lesson.order'),
    title: _requireLocalized(entry, 'lesson.title'),
    // Required, but tolerant of its value: an unrecognised string is
    // `LessonType.unknown`, not a failure — see that enum.
    type: LessonType.fromApi(_requireString(entry, 'lesson.type')),
    durationLabel: _durationLabel(
      _requireInt(entry, 'lesson.duration_seconds'),
    ),
    // Server-sent, never derived — `locked` included, although the contract
    // says it follows the module's.
    completed: _requireBool(entry, 'lesson.completed'),
    locked: _requireBool(entry, 'lesson.locked'),
  );
}

/// §2.3's body into a [CourseExercise].
///
/// Read: `id`, `module.id`/`module.order`, `title`, `type`,
/// `duration_seconds`, `video`, `summary`, `sections`, `completed`,
/// `materials`, `note`, `assignment` (see [_assignmentFrom]) and `quiz` (see
/// [_quizFrom], which also reads `module.title`). Not read, because nothing
/// here is integrated with them: `order` (the screen shows no lesson number)
/// and the video's `embed_url` (no player yet — only whether a video
/// exists). Every list keeps the server's order.
CourseExercise _exerciseFromBody(String body, {required DateTime now}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (e) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'malformed JSON: ${e.message}',
    );
  }

  if (decoded is! Map<String, dynamic>) {
    throw const CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'response was not a JSON object',
    );
  }

  final module = _requireObject(decoded, 'module');
  final type = LessonType.fromApi(_requireString(decoded, 'lesson.type'));

  return CourseExercise(
    lessonId: _requireInt(decoded, 'lesson.id'),
    moduleId: _requireInt(module, 'module.id'),
    // "Modules N", the caption `CourseModuleCard` draws — built from
    // `module.order` on the client, as §2.3 says.
    moduleCaption: 'Modules ${_requireInt(module, 'module.order')}',
    title: _requireLocalized(decoded, 'lesson.title'),
    type: type,
    durationLabel: _durationLabel(
      _requireInt(decoded, 'lesson.duration_seconds'),
    ),
    recordingBadgeLabel: type == LessonType.recording
        ? _recordingBadgeLabel
        : '',
    hasVideo: _hasVideo(decoded),
    // Required, but an empty summary is a content gap the screen renders
    // around rather than a response it cannot draw.
    summary: _localizedOrEmpty(decoded, 'lesson.summary'),
    extraSections: [
      for (final entry in _requireList(decoded, 'lesson.sections'))
        _sectionFrom(entry),
    ],
    materials: [
      for (final entry in _requireList(decoded, 'lesson.materials'))
        ?_materialFrom(entry),
    ],
    completed: _requireBool(decoded, 'lesson.completed'),
    // A backend lesson's writes are real — see
    // `CourseExercise.simulatesWrites`.
    simulatesWrites: false,
    note: _noteFrom(decoded['note'], now: now),
    assignment: _assignmentFrom(decoded['assignment'], now: now),
    quiz: _quizFrom(decoded['quiz'], module: module),
  );
}

/// §2.3's mark-complete answer: `completed` and `progress.percent`, read as
/// strictly as the learning path reads the same progress object.
LessonCompletion _completionFromBody(String body) {
  final decoded = _decodeObject(body);
  return LessonCompletion(
    completed: _requireBool(decoded, 'completion.completed'),
    percentComplete: _requirePercent(_requireObject(decoded, 'progress')),
  );
}

/// `video` is `{embed_url}` or `null`; only its presence is read.
bool _hasVideo(Map<String, dynamic> json) {
  if (!json.containsKey('video')) {
    throw const CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'lesson.video: missing (expected an object or null)',
    );
  }
  final video = json['video'];
  if (video == null) return false;
  if (video is Map<String, dynamic>) return true;
  throw CourseLearningFailure(
    CourseLearningFailureKind.server,
    detail:
        'lesson.video: expected an object or null, got ${video.runtimeType}',
  );
}

CourseExerciseSection _sectionFrom(Object? entry) {
  if (entry is! Map<String, dynamic>) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'a section was not a JSON object (got ${entry.runtimeType})',
    );
  }
  return CourseExerciseSection(
    title: _requireLocalized(entry, 'section.title'),
    body: _localizedOrEmpty(entry, 'section.body'),
    bullets: [
      for (final bullet in _requireList(entry, 'section.bullets'))
        _bulletText(bullet),
    ],
  );
}

String _bulletText(Object? bullet) {
  if (bullet is! Map<String, dynamic>) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail:
          'section.bullets: expected {"mn", "en"} objects, got '
          '${bullet.runtimeType}',
    );
  }
  return _requireLocalized({'bullet': bullet}, 'section.bullet');
}

/// A §2.4 material — the two kinds the contract names, each drawn as a
/// materials-tab row. Read for a lesson's `materials` and for its
/// assignment's `attachment` alike (§2.4: "the same material object").
///
/// Read for a `file`: `id`, `title` and `size_bytes`. Read for a `link`:
/// `id`, `title` and `url` — §2.4: "external URL — then `url` is included and
/// there is nothing to download", so it has no size. Not read for either:
/// `file_name` and `content_type`, which the row has no place for (the
/// Figma row draws a name and a size only).
///
/// An unrecognised `type` has no known shape, so it is left out rather than
/// drawn with a control that cannot work for it, and does not fail the
/// lesson. A known type missing a field it needs is a server fault, like any
/// other malformed part of the lesson.
CourseExerciseMaterial? _materialFrom(Object? entry) {
  if (entry is! Map<String, dynamic>) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'a material was not a JSON object (got ${entry.runtimeType})',
    );
  }

  return switch (_requireString(entry, 'material.type')) {
    'file' => CourseExerciseMaterial(
      id: _requireInt(entry, 'material.id'),
      name: _requireString(entry, 'material.title'),
      sizeLabel: _sizeLabel(_requireInt(entry, 'material.size_bytes')),
    ),
    'link' => CourseExerciseMaterial(
      id: _requireInt(entry, 'material.id'),
      name: _requireString(entry, 'material.title'),
      sizeLabel: '',
      url: _requireHttpUrl(entry, 'material.url'),
    ),
    _ => null,
  };
}

/// `size_bytes` as the material row draws it — see [fileSizeLabel]. A
/// negative size is a server fault.
String _sizeLabel(int bytes) {
  if (bytes < 0) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'material.size_bytes: expected 0 or more, got $bytes',
    );
  }
  return fileSizeLabel(bytes);
}

/// §2.5's `PUT` answer — the note object itself, never `null`.
CourseExerciseNote _savedNoteFrom(String body, {required DateTime now}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (e) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'malformed JSON: ${e.message}',
    );
  }

  if (decoded is! Map<String, dynamic>) {
    throw const CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'response was not a JSON object',
    );
  }
  return _noteFrom(decoded, now: now)!;
}

/// §2.4's download answer — `{"url", "expires_at", "file_name",
/// "size_bytes"}` — read in full.
///
/// `url` must be an absolute `http(s)` URL: it is handed straight to the OS
/// to open, so anything else is a server fault rather than something to try.
MaterialDownload _downloadFromBody(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (e) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'malformed JSON: ${e.message}',
    );
  }

  if (decoded is! Map<String, dynamic>) {
    throw const CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'response was not a JSON object',
    );
  }

  final url = _requireHttpUrl(decoded, 'download.url');

  final rawExpiresAt = _requireString(decoded, 'download.expires_at');
  final expiresAt = DateTime.tryParse(rawExpiresAt);
  if (expiresAt == null) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'download.expires_at: not a timestamp ("$rawExpiresAt")',
    );
  }

  final sizeBytes = _requireInt(decoded, 'download.size_bytes');
  if (sizeBytes < 0) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'download.size_bytes: expected 0 or more, got $sizeBytes',
    );
  }

  return MaterialDownload(
    url: url,
    expiresAt: expiresAt,
    fileName: _requireString(decoded, 'download.file_name'),
    sizeBytes: sizeBytes,
  );
}

/// §2.5's note, or null — inside the lesson detail, and as the whole body of
/// a note save.
CourseExerciseNote? _noteFrom(Object? note, {required DateTime now}) {
  if (note == null) return null;
  if (note is! Map<String, dynamic>) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'note: expected an object or null, got ${note.runtimeType}',
    );
  }
  final author = _requireObject(note, 'author');
  final updatedAt = _requireString(note, 'note.updated_at');
  final parsed = DateTime.tryParse(updatedAt);
  if (parsed == null) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'note.updated_at: not a timestamp ("$updatedAt")',
    );
  }

  return CourseExerciseNote(
    authorInitials: _requireString(author, 'note.author.initials'),
    authorName: _requireString(author, 'note.author.name'),
    authorLabel: _noteAuthorLabel,
    message: _requireString(note, 'note.content'),
    timestampLabel: _timestampLabel(parsed.toLocal(), now: now),
  );
}

/// One id out of `continue` — `module_id`, the module "Continue learning"
/// opens, or `lesson_id`, the lesson inside it.
///
/// Null when the response sends `continue: null` ("nothing is unlocked"), and
/// also when the object carries no usable id: the screen has its own fallback
/// for that, so a missing selection is not worth failing the whole page over.
int? _continueId(Object? value, String key) {
  if (value is! Map<String, dynamic>) return null;
  final id = value[key];
  return id is num ? id.toInt() : null;
}

/// §2.9's certificate response: `status` (required), and the issued
/// `certificate` object's `cert_number` and `issued_at` when it is present.
/// `has_file` is read inside `certificate` first, then at the top level — its
/// place is not documented (Issue #296); anything but a boolean is unknown.
///
/// A status this build does not know reads as [CertificateStatus.unknown],
/// never as issued. An issued status without a readable `certificate`
/// object keeps [CourseCertificate.issued] null — the screen then has no
/// number to download with. `requirements` and `verify_url` are not read.
CourseCertificate _certificateFromBody(String body) {
  final decoded = _decodeObject(body);
  final status = decoded['status'];
  if (status is! String || status.isEmpty) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail:
          'certificate.status: expected a non-empty string, '
          'got ${status.runtimeType}',
    );
  }

  final certificate = decoded['certificate'];
  IssuedCertificate? issued;
  bool? hasFile;
  if (certificate is Map<String, dynamic>) {
    if (certificate['has_file'] case final bool value) hasFile = value;
    final certNumber = certificate['cert_number'];
    final issuedAt = certificate['issued_at'];
    if (certNumber is String && certNumber.isNotEmpty) {
      issued = IssuedCertificate(
        certNumber: certNumber,
        issuedAt: issuedAt is String ? DateTime.tryParse(issuedAt) : null,
      );
    }
  }

  if (decoded['has_file'] case final bool value) hasFile ??= value;

  return CourseCertificate(
    status: CertificateStatus.fromApi(status),
    issued: issued,
    hasFile: hasFile,
  );
}

/// `certificate.status`, passed through as the wire string.
///
/// Not validated against the contract's three values here: a status this
/// client does not recognise is the caller's to handle, and failing the whole
/// learning path over the certificate summary would take down a screen whose
/// main content parsed fine. Null when the object or the field is absent.
String? _certificateStatus(Object? value) {
  if (value is! Map<String, dynamic>) return null;
  final status = value['status'];
  return status is String && status.isNotEmpty ? status : null;
}

/// `progress.percent`, clamped to the 0–100 the model promises.
///
/// The contract has the server compute it as
/// `floor(completed_lessons / total_lessons × 100)`, so a figure outside that
/// range would be a server bug — but `LinearProgressIndicator` asserts on a
/// value above 1, so clamping keeps one wrong number from taking the screen
/// down with it.
int _requirePercent(Map<String, dynamic> progress) {
  final percent = progress['percent'];
  if (percent is! num) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'progress.percent: expected a number, got ${percent.runtimeType}',
    );
  }
  return percent.toInt().clamp(0, 100);
}
