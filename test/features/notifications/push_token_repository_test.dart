import 'dart:convert';
import 'dart:io';

import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/notifications/data/http_notification_repository.dart';
import 'package:aia_mobile/features/notifications/domain/notification_failure.dart';
import 'package:aia_mobile/features/notifications/domain/push_token_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// `POST` / `DELETE /me/push-tokens` (Issue #396) against the backend's own
/// source and tests (`app/routes/notifications.py`,
/// `tests/test_notifications_inbox.py`) — not yet seen live. The bodies below
/// are those shapes with test values. No live backend is called.
void main() {
  /// `push.token_dict` — what a registration answers.
  const registered = {
    'id': 7,
    'platform': 'android',
    'created_at': '2026-10-14T03:00:00+00:00',
    'last_seen_at': '2026-10-14T03:00:00+00:00',
  };

  late AuthSessionStore store;
  final requests = <http.Request>[];

  setUp(() {
    store = AuthSessionStore()..save(const AuthSession(accessToken: 'tok-123'));
    requests.clear();
  });

  PushTokenRepository answering(Object? body, [int status = 200]) =>
      HttpNotificationRepository(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response.bytes(
            utf8.encode(jsonEncode(body)),
            status,
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
            },
          );
        }),
        baseUrl: Uri.parse('https://api.test'),
        sessionStore: store,
      );

  Future<NotificationFailure> failureOf(Future<void> call) async {
    try {
      await call;
    } on NotificationFailure catch (failure) {
      return failure;
    }
    fail('expected a NotificationFailure');
  }

  group('registerPushToken', () {
    test(
      'POSTs the token and platform as JSON with the bearer token',
      () async {
        await answering(
          registered,
          201,
        ).registerPushToken(token: 'fcm-abc', platform: PushPlatform.android);

        final request = requests.single;
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://api.test/me/push-tokens');
        expect(request.headers['Authorization'], 'Bearer tok-123');
        expect(request.headers['Content-Type'], startsWith('application/json'));
        expect(jsonDecode(request.body), {
          'token': 'fcm-abc',
          'platform': 'android',
        });
      },
    );

    test('a known token (200) is a success too; iOS sends "ios"', () async {
      await answering({
        ...registered,
        'platform': 'ios',
      }).registerPushToken(token: 'apns-xyz', platform: PushPlatform.ios);
      expect(jsonDecode(requests.single.body)['platform'], 'ios');
    });
  });

  group('removePushToken', () {
    test('DELETEs with the token in a JSON body', () async {
      await answering({
        'status': 'deleted',
        'removed': 1,
      }).removePushToken('fcm-abc');

      final request = requests.single;
      expect(request.method, 'DELETE');
      expect(request.url.toString(), 'https://api.test/me/push-tokens');
      expect(request.headers['Authorization'], 'Bearer tok-123');
      expect(request.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(request.body), {'token': 'fcm-abc'});
    });

    test('idempotent: nothing removed is still a success', () async {
      await answering({
        'status': 'deleted',
        'removed': 0,
      }).removePushToken('unknown');
      expect(requests, hasLength(1));
    });
  });

  group('failures, as for the notification calls', () {
    final calls = <String, Future<void> Function(PushTokenRepository)>{
      'register': (r) =>
          r.registerPushToken(token: 'fcm-abc', platform: PushPlatform.android),
      'remove': (r) => r.removePushToken('fcm-abc'),
    };

    for (final MapEntry(key: name, value: call) in calls.entries) {
      test(
        '$name: no session is sessionExpired, and nothing is sent',
        () async {
          store.clear();
          final failure = await failureOf(call(answering(registered)));
          expect(failure.kind, NotificationFailureKind.sessionExpired);
          expect(requests, isEmpty);
        },
      );

      test('$name: a 401 ends the session', () async {
        final failure = await failureOf(
          call(answering({'error': 'unauthorized'}, 401)),
        );
        expect(failure.kind, NotificationFailureKind.sessionExpired);
        expect(store.isSignedIn, isFalse);
      });

      test('$name: a refused body (400) is unexpected', () async {
        final failure = await failureOf(
          call(answering({'error': 'token_required'}, 400)),
        );
        expect(failure.kind, NotificationFailureKind.unexpected);
      });

      test('$name: a 5xx is server', () async {
        final failure = await failureOf(call(answering({}, 503)));
        expect(failure.kind, NotificationFailureKind.server);
      });

      test('$name: a request that never completed is network', () async {
        final repository = HttpNotificationRepository(
          client: MockClient((_) async => throw http.ClientException('down')),
          baseUrl: Uri.parse('https://api.test'),
          sessionStore: store,
        );
        final failure = await failureOf(call(repository));
        expect(failure.kind, NotificationFailureKind.network);
      });
    }
  });
}
