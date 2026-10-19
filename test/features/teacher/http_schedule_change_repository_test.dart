import 'dart:convert';

import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/teacher/data/http_schedule_change_repository.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'http_teacher_home_repository_test.dart' show jsonResponse;

/// The schedule-change request over HTTP (Issue #449), against fake clients
/// only. The shapes are the backend's documented contract
/// (`ai-academy-backend` `docs/schedule_change_api_v1.md`, `c6e6ce0`), with
/// test values. No production call is made.

/// `GET /teacher/sessions/{id}/eligible-teachers`.
String eligibleBody({Object? sessionId = 41, List<Object?>? items}) =>
    jsonEncode({
      'session_id': sessionId,
      'items':
          items ??
          [
            {'id': 5, 'name': 'Болд Бат', 'photo_url': null},
            {'id': 8, 'name': 'Сараа Ганбат', 'photo_url': null},
          ],
    });

/// The request object a send answers (contract §3).
String requestBody({
  Object? id = 12,
  Object? sessionId = 41,
  Object? recipientId = 5,
  Object? status = 'pending',
}) => jsonEncode({
  'id': id,
  'session_id': sessionId,
  'session': {
    'id': sessionId,
    'cohort_id': 7,
    'cohort_name': 'CL-2026-10',
    'title': 'Corporate Leaders',
    'topic_id': null,
    'topic': null,
    'date': '2026-10-20',
    'start_time': '09:00',
    'end_time': '11:00',
    'room': 'Room 204',
  },
  'sender': {'id': 3, 'name': 'Анар Бат', 'photo_url': null},
  'recipient': {'id': recipientId, 'name': 'Болд Бат', 'photo_url': null},
  'status': status,
  'message': null,
  'reason': null,
  'created_at': '2026-10-19T01:00:00+00:00',
  'updated_at': '2026-10-19T01:00:00+00:00',
  'resolved_at': null,
  'resolved_by_teacher_id': null,
  'session_assignment': null,
});

http.Response errorResponse(int status, String code) =>
    jsonResponse(jsonEncode({'error': code}), status);

void main() {
  AuthSessionStore signedIn() =>
      AuthSessionStore()..save(const AuthSession(accessToken: 'tok-123'));

  HttpScheduleChangeRepository repositoryReturning(
    Future<http.Response> Function(http.Request request) handler, {
    AuthSessionStore? sessionStore,
  }) => HttpScheduleChangeRepository(
    client: MockClient(handler),
    baseUrl: Uri.parse('https://api.example.test'),
    sessionStore: sessionStore ?? signedIn(),
  );

  Future<TeacherFailure> failureOf(Future<Object?> call) async {
    try {
      await call;
    } on TeacherFailure catch (failure) {
      return failure;
    }
    fail('expected a TeacherFailure');
  }

  group('eligible teachers', () {
    test('GETs the session\'s list with the token, and reads it in the '
        'server\'s order', () async {
      late http.Request sent;
      final repository = repositoryReturning((request) async {
        sent = request;
        return jsonResponse(eligibleBody(), 200);
      });

      final teachers = await repository.getEligibleTeachers(41);

      expect(sent.method, 'GET');
      expect(
        sent.url.toString(),
        'https://api.example.test/teacher/sessions/41/eligible-teachers',
      );
      expect(sent.headers['Authorization'], 'Bearer tok-123');
      expect([for (final t in teachers) t.id], [5, 8]);
      expect([for (final t in teachers) t.name], ['Болд Бат', 'Сараа Ганбат']);
    });

    test('an empty list is no teachers, not a failure', () async {
      final repository = repositoryReturning(
        (_) async => jsonResponse(eligibleBody(items: []), 200),
      );

      expect(await repository.getEligibleTeachers(41), isEmpty);
    });

    test('a photo_url string is accepted (the field is reserved)', () async {
      final repository = repositoryReturning(
        (_) async => jsonResponse(
          eligibleBody(
            items: [
              {'id': 5, 'name': 'Болд', 'photo_url': 'https://x.test/a.png'},
            ],
          ),
          200,
        ),
      );

      expect((await repository.getEligibleTeachers(41)).single.id, 5);
    });

    test('a body off the documented shape is a server failure', () async {
      final bodies = <String, String>{
        'not JSON': 'nope',
        'an array': '[]',
        'another session': eligibleBody(sessionId: 42),
        'no items': jsonEncode({'session_id': 41}),
        'items not a list': jsonEncode({'session_id': 41, 'items': 'x'}),
        'an item not an object': eligibleBody(items: ['Болд']),
        'a string id': eligibleBody(
          items: [
            {'id': '5', 'name': 'Болд', 'photo_url': null},
          ],
        ),
        'a blank name': eligibleBody(
          items: [
            {'id': 5, 'name': ' ', 'photo_url': null},
          ],
        ),
        'a numeric photo_url': eligibleBody(
          items: [
            {'id': 5, 'name': 'Болд', 'photo_url': 3},
          ],
        ),
      };
      for (final entry in bodies.entries) {
        final failure = await failureOf(
          repositoryReturning(
            (_) async => jsonResponse(entry.value, 200),
          ).getEligibleTeachers(41),
        );
        expect(failure.kind, TeacherFailureKind.server, reason: entry.key);
      }
    });

    test('the documented refusals keep their code', () async {
      for (final (status, code) in [
        (404, 'session_not_found'),
        (409, 'session_started'),
      ]) {
        final failure = await failureOf(
          repositoryReturning(
            (_) async => errorResponse(status, code),
          ).getEligibleTeachers(41),
        );
        expect(failure.kind, TeacherFailureKind.rejected, reason: code);
        expect(failure.code, code);
      }
    });

    test('a 404 with no code — a backend without this route — is a '
        'refusal with no code, never an empty list', () async {
      final failure = await failureOf(
        repositoryReturning(
          (_) async => http.Response('<html>Not Found</html>', 404),
        ).getEligibleTeachers(41),
      );

      expect(failure.kind, TeacherFailureKind.rejected);
      expect(failure.code, isNull);
    });

    test('401 clears the session; 5xx is a server failure; a request that '
        'never completes is a network failure', () async {
      final store = signedIn();
      final expired = await failureOf(
        repositoryReturning(
          (_) async => jsonResponse('{"error":"unauthorized"}', 401),
          sessionStore: store,
        ).getEligibleTeachers(41),
      );
      expect(expired.kind, TeacherFailureKind.sessionExpired);
      expect(store.isSignedIn, isFalse);

      final server = await failureOf(
        repositoryReturning(
          (_) async => http.Response('', 502),
        ).getEligibleTeachers(41),
      );
      expect(server.kind, TeacherFailureKind.server);

      final network = await failureOf(
        repositoryReturning(
          (_) async => throw http.ClientException('offline'),
        ).getEligibleTeachers(41),
      );
      expect(network.kind, TeacherFailureKind.network);
    });

    test('without a session nothing is sent', () async {
      var requests = 0;
      final failure = await failureOf(
        repositoryReturning((_) async {
          requests++;
          return jsonResponse(eligibleBody(), 200);
        }, sessionStore: AuthSessionStore()).getEligibleTeachers(41),
      );

      expect(failure.kind, TeacherFailureKind.sessionExpired);
      expect(requests, 0);
    });
  });

  group('send', () {
    test(
      'POSTs exactly session_id, recipient_teacher_id and message: null',
      () async {
        late http.Request sent;
        final repository = repositoryReturning((request) async {
          sent = request;
          return jsonResponse(requestBody(), 201);
        });

        await repository.sendRequest(sessionId: 41, recipientTeacherId: 5);

        expect(sent.method, 'POST');
        expect(
          sent.url.toString(),
          'https://api.example.test/teacher/schedule-change-requests',
        );
        expect(sent.headers['Authorization'], 'Bearer tok-123');
        final body = jsonDecode(sent.body) as Map<String, dynamic>;
        expect(body, {
          'session_id': 41,
          'recipient_teacher_id': 5,
          'message': null,
        });
        expect(body.containsKey('message'), isTrue);
      },
    );

    test('201 Created and 200 (an identical retry) are both a confirmed '
        'pending request', () async {
      for (final status in [201, 200]) {
        final sent = await repositoryReturning(
          (_) async => jsonResponse(requestBody(), status),
        ).sendRequest(sessionId: 41, recipientTeacherId: 5);

        expect(sent.id, 12, reason: '$status');
        expect(sent.recipientTeacherId, 5, reason: '$status');
        expect(sent.status, 'pending', reason: '$status');
      }
    });

    test('any other 2xx is not a confirmed send', () async {
      final failure = await failureOf(
        repositoryReturning(
          (_) async => jsonResponse(requestBody(), 202),
        ).sendRequest(sessionId: 41, recipientTeacherId: 5),
      );

      expect(failure.kind, TeacherFailureKind.unexpected);
    });

    test('an answer that does not match what was sent is a server failure, '
        'never a success', () async {
      final bodies = <String, String>{
        'another recipient': requestBody(recipientId: 8),
        'another session': requestBody(sessionId: 42),
        'not pending': requestBody(status: 'accepted'),
        'no id': requestBody(id: null),
        'not JSON': '<html></html>',
      };
      for (final entry in bodies.entries) {
        final failure = await failureOf(
          repositoryReturning(
            (_) async => jsonResponse(entry.value, 201),
          ).sendRequest(sessionId: 41, recipientTeacherId: 5),
        );
        expect(failure.kind, TeacherFailureKind.server, reason: entry.key);
      }
    });

    test('each documented 404 and 409 keeps its code', () async {
      for (final (status, code) in [
        (409, 'recipient_busy'),
        (409, 'request_pending'),
        (409, 'session_already_covered'),
        (409, 'session_started'),
        (404, 'session_not_found'),
        (404, 'recipient_not_found'),
      ]) {
        final failure = await failureOf(
          repositoryReturning(
            (_) async => errorResponse(status, code),
          ).sendRequest(sessionId: 41, recipientTeacherId: 5),
        );
        expect(failure.kind, TeacherFailureKind.rejected, reason: code);
        expect(failure.code, code);
      }
    });

    test('a 404 with no code is a refusal with no code', () async {
      final failure = await failureOf(
        repositoryReturning(
          (_) async => http.Response('<html>Not Found</html>', 404),
        ).sendRequest(sessionId: 41, recipientTeacherId: 5),
      );

      expect(failure.kind, TeacherFailureKind.rejected);
      expect(failure.code, isNull);
    });

    test('network and session failures', () async {
      final network = await failureOf(
        repositoryReturning(
          (_) async => throw http.ClientException('offline'),
        ).sendRequest(sessionId: 41, recipientTeacherId: 5),
      );
      expect(network.kind, TeacherFailureKind.network);

      var requests = 0;
      final noSession = await failureOf(
        repositoryReturning(
          (_) async {
            requests++;
            return jsonResponse(requestBody(), 201);
          },
          sessionStore: AuthSessionStore(),
        ).sendRequest(sessionId: 41, recipientTeacherId: 5),
      );
      expect(noSession.kind, TeacherFailureKind.sessionExpired);
      expect(requests, 0);
    });
  });
}
