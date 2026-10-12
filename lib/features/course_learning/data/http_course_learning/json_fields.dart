part of '../http_course_learning_repository.dart';

/// A 2xx body that must be one JSON object — the shape every §2.7 answer
/// has. Anything else is the API misbehaving: a `server` failure.
Map<String, dynamic> _decodeObject(String body) {
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
  return decoded;
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

/// A localised field that must be present — as an object or `null` — but
/// whose text may be empty: `""` when neither language carries any.
String _localizedOrEmpty(Map<String, dynamic> json, String label) {
  final key = label.split('.').last;
  if (!json.containsKey(key)) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: '$label: missing',
    );
  }
  return _optionalLocalized(json, label) ?? '';
}

List<Object?> _requireList(Map<String, dynamic> json, String label) {
  final value = json[label.split('.').last];
  if (value is! List) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: '$label: expected a list, got ${value.runtimeType}',
    );
  }
  return value;
}

/// An ISO-8601 timestamp field — §0's "with offset" — that must be present.
DateTime _requireTimestamp(Map<String, dynamic> json, String label) {
  final raw = _requireString(json, label);
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: '$label: not a timestamp ("$raw")',
    );
  }
  return parsed;
}

/// A URL field that must be an absolute `http`/`https` URL with a host —
/// something the OS can open outside the app (`https://` alone parses, but
/// names nowhere). Parsed, never rebuilt: the URL opened is the one the
/// server sent. Anything else is a server fault.
Uri _requireHttpUrl(Map<String, dynamic> json, String label) {
  final raw = _requireString(json, label);
  final url = Uri.tryParse(raw);
  if (url == null ||
      url.host.isEmpty ||
      (url.scheme != 'https' && url.scheme != 'http')) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: '$label: not an http(s) URL ("$raw")',
    );
  }
  return url;
}

/// A number field that may be `null` or absent — §2.7's `attempts_left`
/// (null = unlimited) and `open_attempt_id` (null = none open). Present, it
/// must be a number.
int? _optionalInt(Map<String, dynamic> json, String label) {
  final value = json[label.split('.').last];
  if (value == null) return null;
  if (value is! num) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: '$label: expected a number or null, got ${value.runtimeType}',
    );
  }
  return value.toInt();
}

/// A string field that may be `null` or absent. Present, it must be a
/// string; an empty one reads as null, the way an absent one does.
String? _optionalString(Map<String, dynamic> json, String label) {
  final value = json[label.split('.').last];
  if (value == null) return null;
  if (value is! String) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: '$label: expected a string or null, got ${value.runtimeType}',
    );
  }
  return value.isEmpty ? null : value;
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
