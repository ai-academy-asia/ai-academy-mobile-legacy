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

/// `GET /teacher/submissions/{id}` with the confirmed fields. Test values;
/// `history` is confirmed but unread.
String submissionBody({
  Object? status = 'reviewed',
  Object? score = 85,
  Object? feedback = 'Сайн байна',
}) => jsonEncode({
  'status': status,
  'score': score,
  'feedback': feedback,
  'history': [],
});

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

  test('reads a reviewed submission, with the token', () async {
    late http.Request sent;
    final repo = repositoryReturning((request) async {
      sent = request;
      return jsonResponse(submissionBody(), 200);
    });

    final submission = await repo.getSubmission(17);

    expect(sent.method, 'GET');
    expect(sent.url.path, '/teacher/submissions/17');
    expect(sent.headers['Authorization'], 'Bearer tok-123');
    expect(submission.id, 17);
    expect(submission.status, 'reviewed');
    expect(submission.isReviewed, isTrue);
    expect(submission.score, 85);
    expect(submission.feedback, 'Сайн байна');
  });

  test('reads a pending submission with no score or feedback', () async {
    final repo = repositoryReturning(
      (_) async => jsonResponse(
        submissionBody(status: 'submitted', score: null, feedback: null),
        200,
      ),
    );

    final submission = await repo.getSubmission(17);

    expect(submission.isPending, isTrue);
    expect(submission.isReviewed, isFalse);
    expect(submission.score, isNull);
    expect(submission.feedback, isNull);
  });

  test('a body off the confirmed shape is a server failure', () async {
    for (final body in [
      submissionBody(status: null),
      submissionBody(score: '85'),
      submissionBody(feedback: 3),
      '[]',
      'not json',
    ]) {
      final repo = repositoryReturning((_) async => jsonResponse(body, 200));
      final failure = await failureOf(repo.getSubmission(17));
      expect(failure.kind, TeacherFailureKind.server, reason: body);
    }
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
        final failure = await failureOf(repo.getSubmission(17));
        expect(failure.kind, kind, reason: 'HTTP $status');
        expect(store.isSignedIn, status != 401, reason: 'HTTP $status');
      }
    },
  );

  test('sends nothing without a session', () async {
    var sent = false;
    final repo = repositoryReturning((_) async {
      sent = true;
      return jsonResponse(submissionBody(), 200);
    }, sessionStore: AuthSessionStore());

    final failure = await failureOf(repo.getSubmission(17));
    expect(failure.kind, TeacherFailureKind.sessionExpired);
    expect(sent, isFalse);
  });

  test('getClasses is Teacher Home\'s own read', () async {
    final repo = repositoryReturning((_) async => jsonResponse('{}', 500));
    final classes = await repo.getClasses();
    expect(classes.single.cohort.name, 'Cohort 01');
  });
}
