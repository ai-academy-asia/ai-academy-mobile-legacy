import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
import '../../../core/models/localized_text.dart';
import '../domain/cohort.dart';
import '../domain/cohort_repository.dart';

/// Reads the public cohort list against the AI Academy API.
///
///     GET https://api.ai-academy.asia/cohorts
///     -> { "cohorts": [ { "id": 1, "name": "...", "course": {...}, ... } ] }
///
/// Confirmed by a captured Postman response. Same transport and failure type
/// as `HttpCourseRepository`: no session, no token, `ApiFailure` rather than
/// `AuthFailure`.
class HttpCohortRepository implements CohortRepository {
  HttpCohortRepository({
    http.Client? client,
    Uri? baseUrl,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? Uri.parse(defaultBaseUrl);

  static const String defaultBaseUrl = 'https://api.ai-academy.asia';

  final http.Client _client;
  final Uri _baseUrl;
  final Duration timeout;

  @override
  Future<List<Cohort>> getCohorts() async {
    final response = await getJson(
      client: _client,
      url: _baseUrl.resolve('/cohorts'),
      timeout: timeout,
    );

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (e) {
      throw ApiFailure(ApiFailureKind.server, detail: 'malformed JSON: ${e.message}');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const ApiFailure(
        ApiFailureKind.server,
        detail: 'response was not a JSON object',
      );
    }

    final cohorts = decoded['cohorts'];
    if (cohorts is! List) {
      throw ApiFailure(
        ApiFailureKind.server,
        detail: 'response carried no "cohorts" list (got ${cohorts.runtimeType})',
      );
    }

    return [for (final entry in cohorts) _cohortFromJson(entry)];
  }
}

Cohort _cohortFromJson(Object? entry) {
  if (entry is! Map<String, dynamic>) {
    throw ApiFailure(
      ApiFailureKind.server,
      detail: 'a cohort entry was not a JSON object (got ${entry.runtimeType})',
    );
  }

  return Cohort(
    id: _requireInt(entry, 'id'),
    name: _requireString(entry, 'name'),
    courseId: _requireInt(entry, 'course_id'),
    course: _requireCohortCourse(entry, 'course'),
    classroom: _requireClassroom(entry, 'classroom'),
    teacher: _requireTeacher(entry, 'teacher'),
    capacity: _requireInt(entry, 'capacity'),
    enrolledCount: _requireInt(entry, 'enrolled_count'),
    seatsAvailable: _requireInt(entry, 'seats_available'),
    status: _requireString(entry, 'status'),
    startDate: _requireString(entry, 'start_date'),
    endDate: _requireString(entry, 'end_date'),
    startTime: _requireString(entry, 'start_time'),
    endTime: _requireString(entry, 'end_time'),
    graduationDate: _requireString(entry, 'graduation_date'),
    meetingDays: _requireStringList(entry, 'meeting_days'),
    parentCohortId: _optionalInt(entry, 'parent_cohort_id'),
    scheduleNote: _optionalString(entry, 'schedule_note'),
  );
}

CohortCourse _requireCohortCourse(Map<String, dynamic> json, String key) {
  final value = _requireObject(json, key);
  return CohortCourse(
    id: _requireInt(value, 'id'),
    slug: _requireString(value, 'slug'),
    title: LocalizedText(
      en: _optionalString(value, 'title_en'),
      mn: _optionalString(value, 'title_mn'),
    ),
  );
}

CohortClassroom _requireClassroom(Map<String, dynamic> json, String key) {
  final value = _requireObject(json, key);
  return CohortClassroom(
    id: _requireInt(value, 'id'),
    name: _requireString(value, 'name'),
    centerName: _requireString(value, 'center_name'),
  );
}

CohortTeacher _requireTeacher(Map<String, dynamic> json, String key) {
  final value = _requireObject(json, key);
  return CohortTeacher(id: _requireInt(value, 'id'), name: _requireString(value, 'name'));
}

// --- Field readers -----------------------------------------------------
//
// Same style as `http_course_repository.dart`: named per field so a parse
// failure says which field, on which cohort, rather than a bare stack trace.

Map<String, dynamic> _requireObject(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  throw ApiFailure(
    ApiFailureKind.server,
    detail: 'cohort.$key: expected an object, got ${value.runtimeType}',
  );
}

int _requireInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  throw ApiFailure(
    ApiFailureKind.server,
    detail: 'cohort.$key: expected a number, got ${value.runtimeType}',
  );
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num) return value.toInt();
  throw ApiFailure(
    ApiFailureKind.server,
    detail: 'cohort.$key: expected a number or null, got ${value.runtimeType}',
  );
}

String _requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw ApiFailure(
    ApiFailureKind.server,
    detail: 'cohort.$key: expected a string, got ${value.runtimeType}',
  );
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw ApiFailure(
    ApiFailureKind.server,
    detail: 'cohort.$key: expected a string or null, got ${value.runtimeType}',
  );
}

List<String> _requireStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw ApiFailure(
      ApiFailureKind.server,
      detail: 'cohort.$key: expected a list, got ${value.runtimeType}',
    );
  }
  return [
    for (final item in value)
      if (item is String)
        item
      else
        throw ApiFailure(
          ApiFailureKind.server,
          detail:
              'cohort.$key: expected a list of strings, got an item of '
              'type ${item.runtimeType}',
        ),
  ];
}
