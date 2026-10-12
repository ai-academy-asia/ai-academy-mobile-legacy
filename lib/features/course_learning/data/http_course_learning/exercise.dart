part of '../http_course_learning_repository.dart';

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
