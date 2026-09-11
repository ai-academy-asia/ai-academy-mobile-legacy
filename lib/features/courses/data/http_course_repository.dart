import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
import '../../../core/models/localized_text.dart';
import '../domain/course.dart';
import '../domain/course_repository.dart';

/// Reads the public course catalog against the AI Academy API.
///
/// Two endpoints, both confirmed:
///
///     GET https://api.ai-academy.asia/courses
///     -> { "courses": [ { "id": 4, "slug": "summer-bootcamp", ... } ] }
///
///     GET https://api.ai-academy.asia/courses/{slug}
///     -> { "id": 4, "slug": "summer-bootcamp", ..., "curriculum": ... }
///
/// The detail response has no envelope — confirmed by a captured Postman
/// response, not inferred: the course object is the response body itself,
/// the same way this backend's admin API answers `GET /admin/students/{id}`
/// ("the student object itself — no envelope").
///
/// No authentication — confirmed for both. This talks to the same host as the
/// auth repositories but shares no code with them beyond the host string: no
/// session, no token, and `ApiFailure` rather than `AuthFailure`, since none of
/// that type's cases describe a public endpoint misbehaving.
class HttpCourseRepository implements CourseRepository {
  HttpCourseRepository({
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
  Future<List<Course>> getCourses() async {
    final response = await getJson(
      client: _client,
      url: _baseUrl.resolve('/courses'),
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

    final courses = decoded['courses'];
    if (courses is! List) {
      throw ApiFailure(
        ApiFailureKind.server,
        detail: 'response carried no "courses" list (got ${courses.runtimeType})',
      );
    }

    return [for (final entry in courses) _courseFromJson(entry)];
  }

  @override
  Future<Course> getCourseDetail(String slug) async {
    final response = await getJson(
      client: _client,
      url: _baseUrl.resolve('/courses/${Uri.encodeComponent(slug)}'),
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

    return _courseDetailFromJson(decoded);
  }
}

Course _courseFromJson(Object? entry) {
  if (entry is! Map<String, dynamic>) {
    throw ApiFailure(
      ApiFailureKind.server,
      detail: 'a course entry was not a JSON object (got ${entry.runtimeType})',
    );
  }

  return Course(
    id: _requireInt(entry, 'id'),
    slug: _requireString(entry, 'slug'),
    title: _requireLocalizedText(entry, 'title'),
    tagline: _requireLocalizedText(entry, 'tagline'),
    category: _requireString(entry, 'category'),
    level: _requireString(entry, 'level'),
    format: _requireString(entry, 'format'),
    status: _requireString(entry, 'status'),
    ageMin: _requireInt(entry, 'age_min'),
    ageMax: _requireInt(entry, 'age_max'),
    durationWeeks: _requireInt(entry, 'duration_weeks'),
    startDate: _requireString(entry, 'start_date'),
    endDate: _requireString(entry, 'end_date'),
    priceAmount: _requireDouble(entry, 'price_amount'),
    finalPriceAmount: _requireDouble(entry, 'final_price_amount'),
    discountPercent: _requireInt(entry, 'discount_percent'),
    currency: _requireString(entry, 'currency'),
    durationLabel: _optionalString(entry, 'duration_label'),
    bannerImageUrl: _optionalString(entry, 'banner_image_url'),
    icon: _optionalString(entry, 'icon'),
    sortOrder: _optionalInt(entry, 'sort_order'),
    targetAudience: _optionalString(entry, 'target_audience'),
  );
}

/// Builds the full detail [Course]: the 22 fields the list endpoint already
/// confirms, read by the exact same function the list parser uses, plus the
/// 18 detail-only fields, read permissively — see the "soft readers" section
/// below.
Course _courseDetailFromJson(Object? entry) {
  if (entry is! Map<String, dynamic>) {
    throw ApiFailure(
      ApiFailureKind.server,
      detail: 'response was not a JSON object (got ${entry.runtimeType})',
    );
  }

  return _courseFromJson(entry).copyWithDetail(
    attendanceMethod: _softString(entry, 'attendance_method'),
    capacity: _softInt(entry, 'capacity'),
    certTemplateName: _softString(entry, 'cert_template_name'),
    contractTemplateName: _softString(entry, 'contract_template_name'),
    createdAt: _softString(entry, 'created_at'),
    curriculum: entry['curriculum'],
    description: entry['description'],
    finalProjectType: _softString(entry, 'final_project_type'),
    googleClassroomUrl: _softString(entry, 'google_classroom_url'),
    hasAttendance: _softBool(entry, 'has_attendance'),
    hasCertTemplate: _softBool(entry, 'has_cert_template'),
    hasContractTemplate: _softBool(entry, 'has_contract_template'),
    hasExam: _softBool(entry, 'has_exam'),
    hasFinalProject: _softBool(entry, 'has_final_project'),
    instructors: entry['instructors'],
    prerequisites: entry['prerequisites'],
    updatedAt: _softString(entry, 'updated_at'),
    whatsIncluded: entry['whats_included'],
  );
}

LocalizedText _requireLocalizedText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw ApiFailure(
      ApiFailureKind.server,
      detail: 'course.$key: expected a {"en", "mn"} object, got ${value.runtimeType}',
    );
  }
  return LocalizedText(
    en: _optionalString(value, 'en'),
    mn: _optionalString(value, 'mn'),
  );
}

// --- Field readers ---------------------------------------------------------
//
// Named per-field rather than one blanket try/catch: a course list is many
// records from a source this client does not control, and "which field, on
// which course" is exactly what makes a parse failure fixable instead of a
// stack trace to stare at. Each accepts JSON's `num` for numeric fields —
// `4` and `4.0` are both valid encodings of the same value — rather than
// assuming the wire always picks one.

int _requireInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  throw ApiFailure(
    ApiFailureKind.server,
    detail: 'course.$key: expected a number, got ${value.runtimeType}',
  );
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num) return value.toInt();
  throw ApiFailure(
    ApiFailureKind.server,
    detail: 'course.$key: expected a number or null, got ${value.runtimeType}',
  );
}

double _requireDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw ApiFailure(
    ApiFailureKind.server,
    detail: 'course.$key: expected a number, got ${value.runtimeType}',
  );
}

String _requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw ApiFailure(
    ApiFailureKind.server,
    detail: 'course.$key: expected a string, got ${value.runtimeType}',
  );
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw ApiFailure(
    ApiFailureKind.server,
    detail: 'course.$key: expected a string or null, got ${value.runtimeType}',
  );
}

// --- Soft readers, detail-only fields --------------------------------------
//
// Unlike `_optionalString`/`_optionalInt` above, these never throw. Those
// exist for fields a real response has already proven the shape of — a
// mismatch there means the *server* changed. Every field below has only a
// confirmed *name*; a mismatch here just as easily means this code guessed the
// type wrong, which is not a fault worth failing the whole detail fetch over.
// Read as null instead, and the screen shows less rather than nothing.

String? _softString(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String ? value : null;
}

int? _softInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is num ? value.toInt() : null;
}

bool? _softBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is bool ? value : null;
}
