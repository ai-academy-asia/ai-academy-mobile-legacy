part of '../http_course_learning_repository.dart';

/// §2.6's `assignment`, or null — the lesson has none.
///
/// Read: `id`, `submission` and `attachment`. `attachment` is "§2.4 material
/// object or null", so it is read by the same [_materialFrom] as the
/// lesson's `materials`, with the same rules: `null` is none, an
/// unrecognised `type` is left out, and anything malformed is a server
/// fault. Not read, because the screen has no place for them yet: `title`,
/// `instructions`, `due_date` and `max_score`.
CourseAssignment? _assignmentFrom(Object? assignment, {required DateTime now}) {
  if (assignment == null) return null;
  if (assignment is! Map<String, dynamic>) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail:
          'assignment: expected an object or null, got '
          '${assignment.runtimeType}',
    );
  }
  final attachment = assignment['attachment'];
  return CourseAssignment(
    id: _requireInt(assignment, 'assignment.id'),
    submission: _submissionFrom(assignment['submission'], now: now),
    attachment: attachment == null ? null : _materialFrom(attachment),
  );
}

/// §2.6's submit answer — the submission object itself, never `null`.
AssignmentSubmission _submissionFromBody(String body, {required DateTime now}) {
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
  return _submissionFrom(decoded, now: now)!;
}

/// §2.6's latest `submission`, or null — nothing submitted yet.
///
/// Read: `id`, `version`, `status`, `link`, `description`, `submitted_at`
/// and `feedback`. Not read: `file` (the tab's submitted state draws no
/// file, and this client has only ever seen it `null`) and `score` (the tab
/// draws none).
AssignmentSubmission? _submissionFrom(
  Object? submission, {
  required DateTime now,
}) {
  if (submission == null) return null;
  if (submission is! Map<String, dynamic>) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail:
          'assignment.submission: expected an object or null, got '
          '${submission.runtimeType}',
    );
  }
  return AssignmentSubmission(
    id: _requireInt(submission, 'assignment.submission.id'),
    version: _requireInt(submission, 'assignment.submission.version'),
    // Required, but tolerant of its value — see
    // `AssignmentSubmissionStatus.unknown`.
    status: AssignmentSubmissionStatus.fromApi(
      _requireString(submission, 'assignment.submission.status'),
    ),
    submittedAt: _requireTimestamp(
      submission,
      'assignment.submission.submitted_at',
    ),
    link: _optionalString(submission, 'assignment.submission.link'),
    description: _optionalString(
      submission,
      'assignment.submission.description',
    ),
    feedback: _feedbackFrom(submission['feedback'], now: now),
  );
}

/// §2.6's `feedback`, or null — not reviewed yet.
AssignmentMentorFeedback? _feedbackFrom(
  Object? feedback, {
  required DateTime now,
}) {
  if (feedback == null) return null;
  if (feedback is! Map<String, dynamic>) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail:
          'assignment.submission.feedback: expected an object or null, got '
          '${feedback.runtimeType}',
    );
  }
  final mentor = _requireObject(feedback, 'mentor');
  final role = _requireString(mentor, 'feedback.mentor.role');
  return AssignmentMentorFeedback(
    mentorInitials: _requireString(mentor, 'feedback.mentor.initials'),
    mentorName: _requireString(mentor, 'feedback.mentor.name'),
    mentorRole: role == 'teacher' ? _teacherRoleLabel : '',
    message: _requireString(feedback, 'feedback.message'),
    timestampLabel: _timestampLabel(
      _requireTimestamp(feedback, 'feedback.created_at').toLocal(),
      now: now,
    ),
  );
}

/// §2.8's upload answer — `{"id", "file_name", "content_type",
/// "size_bytes"}` — read in full.
UploadedFile _uploadedFileFrom(String body) {
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

  final sizeBytes = _requireInt(decoded, 'file.size_bytes');
  if (sizeBytes < 0) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'file.size_bytes: expected 0 or more, got $sizeBytes',
    );
  }

  return UploadedFile(
    id: _requireInt(decoded, 'file.id'),
    fileName: _requireString(decoded, 'file.file_name'),
    contentType: _requireString(decoded, 'file.content_type'),
    sizeBytes: sizeBytes,
  );
}
