part of '../http_course_learning_repository.dart';

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
