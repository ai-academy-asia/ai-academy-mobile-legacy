import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
import '../../../core/models/localized_text.dart';
import '../../auth/domain/auth_session_store.dart';
import '../domain/course_exercise.dart';
import '../domain/course_learning_failure.dart';
import '../domain/course_learning_path.dart';
import '../domain/course_learning_repository.dart';
import '../domain/course_module.dart';
import '../domain/lesson.dart';
import 'course_module_visuals.dart';
import 'sample_course_learning_repository.dart';

/// Reads one course's learning path — hero, progress, module list — against
/// the AI Academy API.
///
///     GET https://api.ai-academy.asia/me/courses/{course_slug}/learning
///     Authorization: Bearer <access_token>
///
/// The response shape is the one `course_learning_api_contract_v1.md` §2.1
/// documents, and **only** the fields with a slot in today's Figma-built UI
/// are read. What the contract also sends and this client deliberately
/// ignores, because no screen draws it: `course.id`,
/// `course.banner_image_url` (the design draws the bundled illustration, not
/// the real course image), `enrollment_id`, `cohort_id`,
/// `progress.completed_lessons`/`total_lessons`, `continue.lesson_id` (this
/// app's module cards open an exercise, not a lesson — see §7 of the report
/// on `LessonListScreen`), `certificate.status`, and each module's
/// `lesson_count`/`completed_lessons`. Every one of them is a real field;
/// none is modelled, because widening a model for data nothing renders is
/// what `docs/ai/DATA_AND_API.md` §8.2 forbids.
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
    CourseLearningRepository? unintegrated,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? Uri.parse(defaultBaseUrl),
       _sessionStore = sessionStore ?? AuthSessionStore.instance,
       _unintegrated = unintegrated ?? SampleCourseLearningRepository();

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
  final CourseLearningRepository _unintegrated;
  final Duration timeout;

  @override
  Future<CourseLearningPath> getCourseLearning(String courseSlug) async {
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
      response = await getRaw(
        client: _client,
        // Encoded, not interpolated raw: a slug is server-supplied data, and
        // `Uri.resolve` would read a stray `/` or `?` in one as structure.
        url: _baseUrl.resolve(
          '/me/courses/${Uri.encodeComponent(courseSlug)}/learning',
        ),
        headers: _sessionStore.authorizationHeader,
        timeout: timeout,
      );
    } on ApiFailure catch (failure) {
      // The transport throws only for a request that never completed.
      throw CourseLearningFailure(
        CourseLearningFailureKind.network,
        detail: failure.detail,
      );
    }

    final failure = _failureForStatus(response.statusCode);
    if (failure != null) {
      // What the store asks of a token the backend has rejected: forget it,
      // so nothing goes on sending it.
      if (failure.kind == CourseLearningFailureKind.sessionExpired) {
        _sessionStore.clear();
      }
      throw failure;
    }

    return _pathFromBody(response.body);
  }

  /// §2.2 `GET /me/modules/{module_id}/lessons`.
  ///
  /// Documented by the contract but **not integrated**: this task's verified
  /// endpoint is §2.1 alone, and the rule against calling an unverified
  /// endpoint outranks the tidiness of having all three come from HTTP. Both
  /// this and [getExercise] therefore keep serving the sample content, so
  /// `LessonListScreen` and `CourseExerciseDetailScreen` — neither of which
  /// has an error state to show a failure in — go on working exactly as they
  /// did. Injectable so a test can prove the delegation rather than infer it.
  @override
  Future<List<Lesson>> getLessons(int moduleId) =>
      _unintegrated.getLessons(moduleId);

  /// §2.3 onwards. Unintegrated for the reason [getLessons] gives.
  @override
  Future<CourseExercise> getExercise(int moduleId) =>
      _unintegrated.getExercise(moduleId);
}

/// 401 is the session being refused, not the request; 403 and 404 are the two
/// errors §2.1 documents by name. Kept as this feature's own copy rather than
/// shared with the other repositories' mappings, the way `ApiFailure`'s,
/// `AuthFailure`'s and `EnrollmentFailure`'s are already kept apart.
CourseLearningFailure? _failureForStatus(int statusCode) {
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
    continueModuleId: _continueModuleId(decoded['continue']),
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
    // Server-sent, never derived — the contract is explicit that the client
    // must not compute either one.
    completed: _requireBool(entry, 'completed'),
    locked: _requireBool(entry, 'locked'),
  );
}

/// `{"date": "2026-08-06", "start_time": "09:00"}` into the card's own
/// `"08/06 • Пү • 09:00"`.
///
/// The format is the one the Figma module card draws and the contract quotes
/// back — `MM/dd`, the weekday abbreviated in Mongolian, then the start time.
/// Only `"Да"` (Даваа) is confirmed by the design; the other six follow that
/// one's convention, the first two letters of the Mongolian day name. Kept in
/// `data/` beside the mapping rather than in `CourseLearningStrings` because
/// `scheduleLabel` is a pre-formatted model field, which is where
/// `SampleCourseLearningRepository` already writes its own copy of this label
/// — and because `data/` must not import `presentation/`.
///
/// Absent schedule means a self-paced module, which the contract says sends
/// `null`: the card then draws no date line. An empty string rather than a
/// nullable field, so the widget the Figma pass measured stays untouched.
String _scheduleLabel(Object? schedule) {
  if (schedule == null) return '';
  if (schedule is! Map<String, dynamic>) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail:
          'module.schedule: expected an object or null, got ${schedule.runtimeType}',
    );
  }

  final date = _requireString(schedule, 'module.schedule.date');
  final startTime = _requireString(schedule, 'module.schedule.start_time');

  final DateTime parsed;
  try {
    parsed = DateTime.parse(date);
  } on FormatException {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'module.schedule.date: not a date ("$date")',
    );
  }

  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  // `DateTime.weekday` is 1 = Monday … 7 = Sunday.
  final weekday = _mongolianWeekdays[parsed.weekday - 1];
  // Tolerates `"09:00:00"` as well as the contract's `"09:00"` — the card
  // draws hours and minutes either way.
  final time = startTime.length > 5 ? startTime.substring(0, 5) : startTime;

  return '$month/$day • $weekday • $time';
}

/// Даваа, Мягмар, Лхагва, Пүрэв, Баасан, Бямба, Ням — Monday-first, matching
/// `DateTime.weekday`.
const List<String> _mongolianWeekdays = [
  'Да',
  'Мя',
  'Лх',
  'Пү',
  'Ба',
  'Бя',
  'Ня',
];

/// `continue.module_id` — the module "Continue learning" opens.
///
/// Null when the response sends `continue: null` ("nothing is unlocked"), and
/// also when the object carries no usable `module_id`: the screen has its own
/// fallback for that, so a missing selection is not worth failing the whole
/// page over.
int? _continueModuleId(Object? value) {
  if (value is! Map<String, dynamic>) return null;
  final moduleId = value['module_id'];
  return moduleId is num ? moduleId.toInt() : null;
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

// --- Field readers ---------------------------------------------------------
//
// Named per-field like `HttpCourseRepository`'s, and for the same reason:
// "which field, on which module" is what makes a parse failure fixable.
//
// Each takes the field's dotted path exactly as the contract writes it —
// `course.slug`, `module.schedule.date` — reads the last segment as the key
// in the map it was handed, and reports the whole path. That way a parse
// failure names the response's own field rather than this file's variables,
// without every call site repeating the key twice.

Map<String, dynamic> _requireObject(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: '$key: expected a JSON object, got ${value.runtimeType}',
    );
  }
  return value;
}

String _requireString(Map<String, dynamic> json, String label) {
  final value = json[label.split('.').last];
  if (value is! String || value.isEmpty) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: '$label: expected a non-empty string, got ${value.runtimeType}',
    );
  }
  return value;
}

int _requireInt(Map<String, dynamic> json, String label) {
  final value = json[label.split('.').last];
  if (value is! num) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: '$label: expected a number, got ${value.runtimeType}',
    );
  }
  return value.toInt();
}

bool _requireBool(Map<String, dynamic> json, String label) {
  final value = json[label.split('.').last];
  if (value is! bool) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: '$label: expected a boolean, got ${value.runtimeType}',
    );
  }
  return value;
}

/// A `{"mn": ..., "en": ...}` field, resolved the way the rest of the app
/// resolves one: Mongolian first, English second — [LocalizedText.preferred].
String _requireLocalized(Map<String, dynamic> json, String label) {
  final text = _optionalLocalized(json, label);
  if (text == null) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: '$label: carried neither "mn" nor "en" text',
    );
  }
  return text;
}

String? _optionalLocalized(Map<String, dynamic> json, String label) {
  final key = label.split('.').last;
  final value = json[key];
  if (value == null) return null;
  if (value is! Map<String, dynamic>) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail:
          '$label: expected a {"mn", "en"} object, got ${value.runtimeType}',
    );
  }
  return LocalizedText(
    en: value['en'] is String ? value['en'] as String : null,
    mn: value['mn'] is String ? value['mn'] as String : null,
  ).preferred;
}
