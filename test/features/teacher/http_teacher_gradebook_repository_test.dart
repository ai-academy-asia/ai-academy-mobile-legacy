import 'dart:convert';

import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/teacher/data/http_teacher_gradebook_repository.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_teacher_home_repository.dart';
import 'http_teacher_home_repository_test.dart' show jsonResponse;
import 'teacher_home_screen_test.dart' show sampleClass;

/// One `submissions[]` entry in the captured shape
/// (`GET /teacher/assignments/2/submissions`). Test values.
Map<String, Object?> submissionEntry({
  Object? id = 18,
  Object? status = 'reviewed',
  Object? score = 80,
  Object? feedback = const {
    'created_at': '2026-05-02T14:00:00+00:00',
    'mentor': {'id': 4, 'initials': 'БЭ', 'name': 'Mentor', 'role': 'teacher'},
    'message': 'Validation хэсэг дутуу байна.',
  },
  Object? student = const {'id': 13, 'initials': 'ХЦ', 'name': 'Student A'},
  Object? link = 'https://github.com/example/hw-2',
  Object? description = 'Засварласан хувилбар.',
}) => {
  'assignment_id': 2,
  'description': description,
  'feedback': feedback,
  'file': null,
  'graded_at': '2026-05-02T14:00:00+00:00',
  'id': id,
  'link': link,
  'score': score,
  'status': status,
  'student': student,
  'submitted_at': '2026-04-30T14:00:00+00:00',
  'version': 2,
  'version_count': 2,
};

/// The confirmed `GET /teacher/cohorts/{id}/assignments` envelope.
String assignmentsBody(List<Object?> assignments) => jsonEncode({
  'assignments': assignments,
  'cohort_id': 2,
  'count': assignments.length,
});

String submissionsBody(List<Object?> submissions) => jsonEncode({
  'assignment_id': 2,
  'count': submissions.length,
  'max_score': 100,
  'submissions': submissions,
});

/// One assignment with the confirmed fields. Test values.
Map<String, Object?> assignmentEntry({
  Object? id = 2,
  Object? titleMn = 'Даалгавар 2',
  Object? titleEn = 'Homework 2',
  Object? title = 'Даалгавар 2',
}) => {
  'id': id,
  'cohort_id': 2,
  'lesson_id': 5,
  'title': title,
  'title_mn': titleMn,
  'title_en': titleEn,
  'instructions': 'Loop ашиглан ...',
  'due_date': '2026-10-20',
  'max_score': 100,
  'submitted_students': 9,
  'teacher_id': 4,
  'is_active': true,
  'attachment': null,
  'attachment_material_id': null,
};

void main() {
  AuthSessionStore signedIn() =>
      AuthSessionStore()..save(const AuthSession(accessToken: 'tok-123'));

  HttpTeacherGradebookRepository repositoryReturning(
    Future<http.Response> Function(http.Request request) handler, {
    AuthSessionStore? sessionStore,
  }) => HttpTeacherGradebookRepository(
    client: MockClient(handler),
    sessionStore: sessionStore ?? signedIn(),
    classes: FakeTeacherHomeRepository(classes: [sampleClass()]),
  );

  Future<TeacherFailure> failureOf(Future<Object?> call) async {
    try {
      await call;
    } on TeacherFailure catch (failure) {
      return failure;
    }
    fail('expected a TeacherFailure');
  }

  group('getAssignments', () {
    test('asks the class\'s assignments and reads id and title', () async {
      late http.Request sent;
      final repo = repositoryReturning((request) async {
        sent = request;
        return jsonResponse(
          assignmentsBody([
            assignmentEntry(),
            assignmentEntry(id: 3, titleMn: null, title: 'Homework 3'),
          ]),
          200,
        );
      });

      final assignments = await repo.getAssignments(2);

      expect(sent.url.path, '/teacher/cohorts/2/assignments');
      expect(sent.headers['Authorization'], 'Bearer tok-123');
      expect([for (final a in assignments) a.id], [2, 3]);
      expect(assignments[0].displayTitle, 'Даалгавар 2');
      // No Mongolian title: `title` stands in.
      expect(assignments[1].displayTitle, 'Homework 3');
    });

    test('an empty class has no assignments', () async {
      final repo = repositoryReturning(
        (_) async => jsonResponse(assignmentsBody([]), 200),
      );
      expect(await repo.getAssignments(2), isEmpty);
    });

    test('anything else is a server failure', () async {
      for (final body in [
        // Off the confirmed envelope: no `assignments`, or a bare list.
        jsonEncode({'items': [], 'cohort_id': 2, 'count': 0}),
        jsonEncode([assignmentEntry()]),
        assignmentsBody([assignmentEntry(id: '2')]),
        assignmentsBody([assignmentEntry(titleMn: 5)]),
        'not json',
      ]) {
        final repo = repositoryReturning((_) async => jsonResponse(body, 200));
        final failure = await failureOf(repo.getAssignments(2));
        expect(failure.kind, TeacherFailureKind.server, reason: body);
      }
    });
  });

  group('getSubmissions', () {
    test('reads the latest submission per student', () async {
      late http.Request sent;
      final repo = repositoryReturning((request) async {
        sent = request;
        return jsonResponse(
          submissionsBody([
            submissionEntry(),
            submissionEntry(
              id: 19,
              status: 'submitted',
              score: null,
              feedback: null,
              link: null,
              student: {'id': 9, 'initials': 'АМ', 'name': 'Student B'},
            ),
          ]),
          200,
        );
      });

      final submissions = await repo.getSubmissions(2);

      expect(sent.url.path, '/teacher/assignments/2/submissions');
      expect(submissions, hasLength(2));
      final reviewed = submissions[0];
      expect(reviewed.id, 18);
      expect(reviewed.assignmentId, 2);
      expect(reviewed.student!.id, 13);
      expect(reviewed.student!.name, 'Student A');
      expect(reviewed.student!.initials, 'ХЦ');
      expect(reviewed.isReviewed, isTrue);
      expect(reviewed.score, 80);
      expect(reviewed.feedback, 'Validation хэсэг дутуу байна.');
      expect(reviewed.link, 'https://github.com/example/hw-2');
      expect(reviewed.description, 'Засварласан хувилбар.');
      expect(reviewed.submittedAt, DateTime.utc(2026, 4, 30, 14).toLocal());

      final pending = submissions[1];
      expect(pending.isPending, isTrue);
      expect(pending.score, isNull);
      expect(pending.feedback, isNull);
      expect(pending.link, isNull);
    });

    test('an entry off the confirmed shape is a server failure', () async {
      for (final entry in [
        submissionEntry(student: null),
        submissionEntry(student: {'id': 13}),
        submissionEntry(status: null),
        submissionEntry(score: '80'),
        submissionEntry(feedback: 'text'),
        submissionEntry(link: 3),
        submissionEntry(id: null),
      ]) {
        final repo = repositoryReturning(
          (_) async => jsonResponse(submissionsBody([entry]), 200),
        );
        final failure = await failureOf(repo.getSubmissions(2));
        expect(failure.kind, TeacherFailureKind.server, reason: '$entry');
      }
    });
  });

  group('getSubmission', () {
    test('reads the detail by the same rules, with the token', () async {
      late http.Request sent;
      final repo = repositoryReturning((request) async {
        sent = request;
        return jsonResponse(
          jsonEncode({...submissionEntry(), 'history': []}),
          200,
        );
      });

      final submission = await repo.getSubmission(18);

      expect(sent.method, 'GET');
      expect(sent.url.path, '/teacher/submissions/18');
      expect(sent.headers['Authorization'], 'Bearer tok-123');
      expect(submission.id, 18);
      expect(submission.isReviewed, isTrue);
      expect(submission.score, 80);
      expect(submission.feedback, 'Validation хэсэг дутуу байна.');
      expect(submission.description, 'Засварласан хувилбар.');
    });

    test('a pending detail has no score or feedback', () async {
      final repo = repositoryReturning(
        (_) async => jsonResponse(
          jsonEncode(
            submissionEntry(status: 'submitted', score: null, feedback: null),
          ),
          200,
        ),
      );
      final submission = await repo.getSubmission(18);
      expect(submission.isPending, isTrue);
      expect(submission.score, isNull);
      expect(submission.feedback, isNull);
    });

    test(
      'maps statuses to failure kinds, and a 401 clears the session',
      () async {
        for (final (status, kind) in [
          (401, TeacherFailureKind.sessionExpired),
          (403, TeacherFailureKind.rejected),
          (404, TeacherFailureKind.rejected),
          (502, TeacherFailureKind.server),
        ]) {
          final store = signedIn();
          final repo = repositoryReturning(
            (_) async => jsonResponse('{}', status),
            sessionStore: store,
          );
          final failure = await failureOf(repo.getSubmission(18));
          expect(failure.kind, kind, reason: 'HTTP $status');
          expect(store.isSignedIn, status != 401, reason: 'HTTP $status');
        }
      },
    );

    test('sends nothing without a session', () async {
      var sent = false;
      final repo = repositoryReturning((_) async {
        sent = true;
        return jsonResponse(jsonEncode(submissionEntry()), 200);
      }, sessionStore: AuthSessionStore());

      final failure = await failureOf(repo.getSubmission(18));
      expect(failure.kind, TeacherFailureKind.sessionExpired);
      expect(sent, isFalse);
    });
  });

  test('getClasses is Teacher Home\'s own read', () async {
    final repo = repositoryReturning((_) async => jsonResponse('{}', 500));
    final classes = await repo.getClasses();
    expect(classes.single.cohort.name, 'Cohort 01');
  });

  group('Programs additions (Issue #390)', () {
    test(
      'the roster: GET /teacher/cohorts/{id}/students, id and name only',
      () async {
        late http.Request sent;
        final repo = repositoryReturning((request) async {
          sent = request;
          return jsonResponse(
            jsonEncode({
              'cohort_id': 2,
              'students': [
                {
                  'student_id': 13,
                  'enrollment_id': 40,
                  'name': 'Student A',
                  'phone': '99112233',
                },
                {
                  'student_id': 9,
                  'enrollment_id': 41,
                  'name': 'Student B',
                  'phone': null,
                },
              ],
            }),
            200,
          );
        });
        final students = await repo.getStudents(2);
        expect(sent.method, 'GET');
        expect(sent.url.path, '/teacher/cohorts/2/students');
        expect(sent.headers['Authorization'], startsWith('Bearer '));
        expect(
          [for (final s in students) (s.id, s.name)],
          [(13, 'Student A'), (9, 'Student B')],
        );
      },
    );

    test('a roster entry without a student_id is a server failure', () async {
      final repo = repositoryReturning(
        (_) async => jsonResponse(
          jsonEncode({
            'students': [
              {'name': 'Student A'},
            ],
          }),
          200,
        ),
      );
      expect(
        (await failureOf(repo.getStudents(2))).kind,
        TeacherFailureKind.server,
      );
    });

    test('an assignment\'s max_score is read; a non-number is a server '
        'failure', () async {
      var body = assignmentsBody([
        {'id': 2, 'title_mn': 'Даалгавар 2', 'max_score': 100},
        {'id': 3, 'title_en': 'Assignment 3', 'max_score': null},
      ]);
      final repo = repositoryReturning((_) async => jsonResponse(body, 200));
      final list = await repo.getAssignments(2);
      expect(list.map((a) => a.maxScore), [100, null]);
      body = assignmentsBody([
        {'id': 2, 'title': 'x', 'max_score': '100'},
      ]);
      expect(
        (await failureOf(repo.getAssignments(2))).kind,
        TeacherFailureKind.server,
      );
    });

    test('feedback.created_at and feedback.mentor are read', () async {
      final repo = repositoryReturning(
        (_) async => jsonResponse(submissionsBody([submissionEntry()]), 200),
      );
      final submission = (await repo.getSubmissions(2)).single;
      expect(
        submission.feedbackAt,
        DateTime.parse('2026-05-02T14:00:00+00:00').toLocal(),
      );
      expect(submission.mentor?.name, 'Mentor');
      expect(submission.mentor?.id, 4);
      expect(submission.mentor?.initials, 'БЭ');
    });

    test('a review: POST {feedback, score}, and the stored submission comes '
        'back', () async {
      late http.Request sent;
      final repo = repositoryReturning((request) async {
        sent = request;
        return jsonResponse(
          jsonEncode(
            submissionEntry(
              id: 30,
              score: 85,
              feedback: const {
                'created_at': '2026-10-13T07:05:00+00:00',
                'mentor': {
                  'id': 4,
                  'initials': 'АБ',
                  'name': 'Анужин Болд',
                  'role': 'teacher',
                },
                'message': 'Сайн ажил.',
              },
            ),
          ),
          200,
        );
      });
      final saved = await repo.reviewSubmission(
        submissionId: 30,
        feedback: 'Сайн ажил.',
        score: 85,
      );
      expect(sent.method, 'POST');
      expect(sent.url.path, '/teacher/submissions/30/review');
      expect(sent.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(sent.body), {'feedback': 'Сайн ажил.', 'score': 85});
      expect(saved.id, 30);
      expect(saved.isReviewed, isTrue);
      expect(saved.feedback, 'Сайн ажил.');
      expect(saved.score, 85);
      expect(saved.mentor?.name, 'Анужин Болд');
    });

    test('a review without a score sends "score": null', () async {
      late http.Request sent;
      final repo = repositoryReturning((request) async {
        sent = request;
        return jsonResponse(
          jsonEncode(submissionEntry(id: 30, score: null)),
          200,
        );
      });
      await repo.reviewSubmission(submissionId: 30, feedback: 'OK');
      expect(jsonDecode(sent.body), {'feedback': 'OK', 'score': null});
    });

    for (final (status, code) in [
      (400, 'feedback_required'),
      (400, 'feedback_too_long'),
      (400, 'invalid_score'),
      (404, 'submission_not_found'),
    ]) {
      test('a refused review keeps $code', () async {
        final repo = repositoryReturning(
          (_) async => jsonResponse(jsonEncode({'error': code}), status),
        );
        final failure = await failureOf(
          repo.reviewSubmission(submissionId: 30, feedback: 'x', score: 1),
        );
        expect(failure.kind, TeacherFailureKind.rejected);
        expect(failure.code, code);
      });
    }

    test('nothing is sent without a session', () async {
      var sent = 0;
      final repo = repositoryReturning((_) async {
        sent++;
        return jsonResponse('{}', 200);
      }, sessionStore: AuthSessionStore());
      expect(
        (await failureOf(
          repo.reviewSubmission(submissionId: 30, feedback: 'x'),
        )).kind,
        TeacherFailureKind.sessionExpired,
      );
      expect(sent, 0);
    });
  });
}
