import 'dart:convert';
import 'dart:io';

import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/notifications/data/http_notification_repository.dart';
import 'package:aia_mobile/features/notifications/domain/notification_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The in-app notification endpoints (Issue #246) against the Phase 0 live
/// responses — the bodies below are those, with the text shortened. No live
/// backend is called.
void main() {
  /// The verified `GET /me/notifications` response.
  const verifiedFeed = {
    'notifications': [
      {
        'body': 'Demo day body',
        'created_at': '2026-10-01T03:57:37.132850+00:00',
        'data': null,
        'id': 25,
        'kind': 'general',
        'read_at': '2026-09-28T01:00:00+00:00',
        'title': 'Demo day-ийн огноо',
      },
      {
        'body': '«1 минутын AI видео» — 10/07 хүртэл илгээнэ үү.',
        'created_at': '2026-10-01T03:57:37.131102+00:00',
        'data': {'assignment_id': 18},
        'id': 24,
        'kind': 'assignment',
        'read_at': null,
        'title': 'Шинэ даалгавар',
      },
    ],
    'unread_count': 1,
  };

  late AuthSessionStore store;
  final requests = <http.Request>[];

  setUp(() {
    store = AuthSessionStore()..save(const AuthSession(accessToken: 'tok-123'));
    requests.clear();
  });

  HttpNotificationRepository repositoryAnswering(
    Object? body, [
    int status = 200,
  ]) => HttpNotificationRepository(
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
    sessionStore: store,
  );

  Future<NotificationFailure> failureOf(Future<Object?> call) async {
    try {
      await call;
    } on NotificationFailure catch (failure) {
      return failure;
    }
    fail('expected a NotificationFailure');
  }

  group('getNotifications', () {
    test('asks for the latest 30, authenticated', () async {
      await repositoryAnswering(verifiedFeed).getNotifications();

      expect(requests.single.method, 'GET');
      expect(
        requests.single.url.toString(),
        'https://api.ai-academy.asia/me/notifications?limit=30',
      );
      expect(requests.single.headers['Authorization'], 'Bearer tok-123');
    });

    test('reads the verified items, kind, data and unread_count', () async {
      final feed = await repositoryAnswering(verifiedFeed).getNotifications();

      expect(feed.unreadCount, 1);
      expect(feed.skipped, 0);
      final [read, unread] = feed.notifications;

      expect(read.id, 25);
      expect(read.kind, 'general');
      expect(read.data, isNull);
      expect(read.isRead, isTrue);
      expect(read.readAt, DateTime.utc(2026, 9, 28, 1));
      expect(read.assignmentId, isNull);

      expect(unread.id, 24);
      expect(unread.title, 'Шинэ даалгавар');
      expect(unread.kind, 'assignment');
      expect(unread.readAt, isNull);
      expect(unread.isRead, isFalse);
      expect(unread.data, {'assignment_id': 18});
      expect(unread.assignmentId, 18);
      expect(
        unread.createdAt,
        DateTime.parse('2026-10-01T03:57:37.131102+00:00'),
      );
    });

    test('an empty list is fine', () async {
      final feed = await repositoryAnswering({
        'notifications': [],
        'unread_count': 0,
      }).getNotifications();

      expect(feed.notifications, isEmpty);
      expect(feed.unreadCount, 0);
    });

    test(
      'a malformed item is skipped and counted; the rest still read',
      () async {
        final feed = await repositoryAnswering({
          'notifications': [
            {'id': 1, 'title': 'no body or kind'},
            'not an object',
            {
              'id': 2,
              'title': 't',
              'body': 'b',
              'kind': 'general',
              'created_at': 'not a time',
              'read_at': null,
              'data': null,
            },
            {
              'id': 3,
              'title': 't',
              'body': 'b',
              'kind': 'general',
              'created_at': '2026-10-01T00:00:00Z',
              'read_at': null,
              'data': 'not an object',
            },
            ...(verifiedFeed['notifications']! as List),
          ],
          'unread_count': 1,
        }).getNotifications();

        expect(feed.skipped, 4);
        expect([for (final n in feed.notifications) n.id], [25, 24]);
      },
    );

    test('a broken envelope is the server\'s fault', () async {
      for (final body in [
        {'unread_count': 0},
        {'notifications': {}, 'unread_count': 0},
        {'notifications': []},
        {'notifications': [], 'unread_count': -1},
        ['not', 'an', 'object'],
      ]) {
        final failure = await failureOf(
          repositoryAnswering(body).getNotifications(),
        );
        expect(failure.kind, NotificationFailureKind.server, reason: '$body');
      }
    });
  });

  group('markRead', () {
    const readItem = {
      'body': 'b',
      'created_at': '2026-10-01T03:57:37.131102+00:00',
      'data': {'assignment_id': 18},
      'id': 24,
      'kind': 'assignment',
      'read_at': '2026-10-08T06:53:25.126389+00:00',
      'title': 't',
    };

    test('posts to the notification and reads it back as read', () async {
      final result = await repositoryAnswering({
        ...readItem,
        'unread_count': 0,
      }).markRead(24);

      expect(requests.single.method, 'POST');
      expect(
        requests.single.url.toString(),
        'https://api.ai-academy.asia/me/notifications/24/read',
      );
      expect(requests.single.body, isEmpty);
      expect(result.notification.id, 24);
      expect(result.notification.isRead, isTrue);
      expect(
        result.notification.readAt,
        DateTime.parse('2026-10-08T06:53:25.126389+00:00'),
      );
      expect(result.unreadCount, 0);
    });

    test('also reads the notification when it is wrapped', () async {
      final result = await repositoryAnswering({
        'notification': readItem,
        'unread_count': 0,
      }).markRead(24);

      expect(result.notification.isRead, isTrue);
    });

    test('already read: the same read answer again (idempotent)', () async {
      final repository = repositoryAnswering({...readItem, 'unread_count': 0});

      final first = await repository.markRead(24);
      final second = await repository.markRead(24);

      expect(second.notification.readAt, first.notification.readAt);
      expect(second.unreadCount, 0);
    });

    test('404 notification_not_found is notFound', () async {
      final failure = await failureOf(
        repositoryAnswering({
          'error': 'notification_not_found',
        }, 404).markRead(999999999),
      );

      expect(failure.kind, NotificationFailureKind.notFound);
      expect(failure.detail, contains('notification_not_found'));
    });
  });

  group('markAllRead', () {
    test('posts read-all and reads unread_count and updated', () async {
      final result = await repositoryAnswering({
        'unread_count': 0,
        'updated': 3,
      }).markAllRead();

      expect(requests.single.method, 'POST');
      expect(
        requests.single.url.toString(),
        'https://api.ai-academy.asia/me/notifications/read-all',
      );
      expect(result.updated, 3);
      expect(result.unreadCount, 0);
    });

    test('repeated: nothing left to update (idempotent)', () async {
      final repository = repositoryAnswering({'unread_count': 0, 'updated': 0});

      await repository.markAllRead();
      final again = await repository.markAllRead();

      expect(again.updated, 0);
      expect(again.unreadCount, 0);
    });
  });

  group('failures', () {
    test('no session sends nothing', () async {
      store.clear();

      final failure = await failureOf(
        repositoryAnswering(verifiedFeed).getNotifications(),
      );

      expect(failure.kind, NotificationFailureKind.sessionExpired);
      expect(requests, isEmpty);
    });

    test('a 401 that survives renewal ends the session', () async {
      final failure = await failureOf(
        repositoryAnswering({'error': 'invalid_token'}, 401).getNotifications(),
      );

      expect(failure.kind, NotificationFailureKind.sessionExpired);
      expect(store.isSignedIn, isFalse);
    });

    test('a 5xx is the server; another 4xx is unexpected', () async {
      expect(
        (await failureOf(
          repositoryAnswering(const {}, 503).getNotifications(),
        )).kind,
        NotificationFailureKind.server,
      );
      expect(
        (await failureOf(
          repositoryAnswering(const {}, 400).markAllRead(),
        )).kind,
        NotificationFailureKind.unexpected,
      );
    });

    test('a request that never completes is the network', () async {
      final repository = HttpNotificationRepository(
        client: MockClient((_) async => throw const SocketException('down')),
        sessionStore: store,
      );

      final failure = await failureOf(repository.getNotifications());

      expect(failure.kind, NotificationFailureKind.network);
    });
  });
}
