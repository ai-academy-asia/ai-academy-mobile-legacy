import 'dart:async';

import 'package:aia_mobile/features/notifications/domain/notification_failure.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_center.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_notification_repository.dart';

/// The shared notification state (Issue #246): the list, the server's
/// unread count, optimistic reads with rollback, and reset.
void main() {
  late FakeNotificationRepository repository;
  late NotificationCenter center;
  final now = DateTime.utc(2026, 10, 8, 7);

  setUp(() {
    repository = FakeNotificationRepository(
      notifications: [
        sampleNotification(id: 3),
        sampleNotification(id: 2, readAt: DateTime.utc(2026, 10, 2)),
        sampleNotification(id: 1),
      ],
    );
    center = NotificationCenter(repository: repository, clock: () => now);
  });

  group('load', () {
    test('reads the list and the server\'s unread count', () async {
      await center.load();

      expect([for (final n in center.notifications) n.id], [3, 2, 1]);
      expect(center.unreadCount, 2);
      expect(center.hasLoadedOnce, isTrue);
      expect(center.errorMessage, isNull);
    });

    test('a failure says why and keeps nothing invented', () async {
      repository.feedFailure = const NotificationFailure(
        NotificationFailureKind.network,
      );

      await center.load();

      expect(center.notifications, isEmpty);
      expect(
        center.errorMessage,
        NotificationStrings.messageFor(NotificationFailureKind.network),
      );
    });

    test('an empty list is a loaded, empty state', () async {
      repository.notifications = [];

      await center.load();

      expect(center.notifications, isEmpty);
      expect(center.unreadCount, 0);
      expect(center.errorMessage, isNull);
    });

    test('two loads at once make one request', () async {
      repository.feedGate = Completer<void>();

      final a = center.load();
      final b = center.load();
      repository.feedGate!.complete();
      await Future.wait([a, b]);

      expect(repository.feedCalls, 1);
    });

    test('loadIfNeeded loads once per session', () async {
      await center.loadIfNeeded();
      await center.loadIfNeeded();

      expect(repository.feedCalls, 1);
    });
  });

  group('markRead', () {
    setUp(() => center.load());

    test('reads at once, then takes the server\'s answer', () async {
      repository.markGate = Completer<void>();

      final pending = center.markRead(3);
      expect(center.notifications.first.isRead, isTrue);
      expect(center.unreadCount, 1);
      expect(center.isMarking(3), isTrue);

      repository.markGate!.complete();
      expect(await pending, isNull);
      expect(center.notifications.first.readAt, repository.readStamp);
      expect(center.unreadCount, 1);
      expect(center.isMarking(3), isFalse);
    });

    test('a failure rolls the row and the count back', () async {
      repository.markFailure = const NotificationFailure(
        NotificationFailureKind.server,
      );

      final message = await center.markRead(3);

      expect(
        message,
        NotificationStrings.messageFor(NotificationFailureKind.server),
      );
      expect(center.notifications.first.isRead, isFalse);
      expect(center.unreadCount, 2);
    });

    test('404 notification_not_found drops the row and reloads', () async {
      repository.notifications.removeWhere((n) => n.id == 3);
      final feedCallsBefore = repository.feedCalls;

      final message = await center.markRead(3);
      await pumpEventQueue();

      expect(message, NotificationStrings.notFound);
      expect(center.notifications.any((n) => n.id == 3), isFalse);
      expect(repository.feedCalls, feedCallsBefore + 1);
      expect(center.unreadCount, 1);
    });

    test('a second tap while one is in flight sends nothing', () async {
      repository.markGate = Completer<void>();

      final first = center.markRead(3);
      final second = await center.markRead(3);
      repository.markGate!.complete();
      await first;

      expect(second, isNull);
      expect(repository.markCalls, [3]);
    });

    test('an already-read row sends nothing', () async {
      expect(await center.markRead(2), isNull);
      expect(repository.markCalls, isEmpty);
    });

    test('a refresh that lands mid-mark keeps the row read', () async {
      repository.markGate = Completer<void>();
      final mark = center.markRead(3);

      await center.load();
      expect(center.notifications.first.isRead, isTrue);
      expect(center.unreadCount, 1);

      repository.markGate!.complete();
      await mark;
      expect(center.unreadCount, 1);
    });
  });

  group('markAllRead', () {
    setUp(() => center.load());

    test('reads every row at once, then takes the server\'s count', () async {
      repository.markAllGate = Completer<void>();

      final pending = center.markAllRead();
      expect(center.notifications.every((n) => n.isRead), isTrue);
      expect(center.unreadCount, 0);

      repository.markAllGate!.complete();
      expect(await pending, isNull);
      expect(center.unreadCount, 0);
      expect(repository.markAllCalls, 1);
    });

    test('a failure puts every row and the count back', () async {
      repository.markAllFailure = const NotificationFailure(
        NotificationFailureKind.network,
      );

      final message = await center.markAllRead();

      expect(message, isNotNull);
      expect(
        [for (final n in center.notifications) n.isRead],
        [false, true, false],
      );
      expect(center.unreadCount, 2);
    });

    test(
      'a second call while one runs sends nothing; again later is fine',
      () async {
        repository.markAllGate = Completer<void>();
        final first = center.markAllRead();
        expect(await center.markAllRead(), isNull);
        repository.markAllGate!.complete();
        await first;
        expect(repository.markAllCalls, 1);

        repository.markAllGate = null;
        expect(await center.markAllRead(), isNull);
        expect(repository.markAllCalls, 2);
        expect(center.unreadCount, 0);
      },
    );
  });

  group('reset', () {
    test('forgets everything, and an answer after it is ignored', () async {
      await center.load();
      repository.feedGate = Completer<void>();
      final lateLoad = center.load();

      center.reset();
      repository.feedGate!.complete();
      await lateLoad;

      expect(center.notifications, isEmpty);
      expect(center.unreadCount, 0);
      expect(center.hasLoadedOnce, isFalse);
    });

    test('a mark answering after reset changes nothing', () async {
      await center.load();
      repository.markGate = Completer<void>();
      final mark = center.markRead(3);

      center.reset();
      repository.markGate!.complete();
      await mark;

      expect(center.notifications, isEmpty);
      expect(center.unreadCount, 0);
    });
  });

  group('age', () {
    final created = DateTime.utc(2026, 10, 1, 12);

    test('days, as the frame writes them', () {
      expect(
        NotificationStrings.age(created, created.add(const Duration(days: 1))),
        '1d',
      );
      expect(
        NotificationStrings.age(
          created,
          created.add(const Duration(days: 7, hours: 5)),
        ),
        '7d',
      );
    });

    test('hours and minutes under a day, never zero', () {
      expect(
        NotificationStrings.age(created, created.add(const Duration(hours: 3))),
        '3h',
      );
      expect(
        NotificationStrings.age(
          created,
          created.add(const Duration(minutes: 12)),
        ),
        '12m',
      );
      expect(
        NotificationStrings.age(
          created,
          created.add(const Duration(seconds: 5)),
        ),
        '1m',
      );
    });
  });
}
