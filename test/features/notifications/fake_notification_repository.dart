import 'dart:async';

import 'package:aia_mobile/features/notifications/domain/app_notification.dart';
import 'package:aia_mobile/features/notifications/domain/notification_failure.dart';
import 'package:aia_mobile/features/notifications/domain/notification_repository.dart';

/// A notification. Test values only, in the verified Phase 0 shape.
AppNotification sampleNotification({
  int id = 24,
  String title = 'Test title',
  String body = 'Test body',
  String kind = 'general',
  DateTime? createdAt,
  DateTime? readAt,
  Map<String, Object?>? data,
}) => AppNotification(
  id: id,
  title: title,
  body: body,
  kind: kind,
  createdAt: createdAt ?? DateTime.utc(2026, 10, 1, 3),
  readAt: readAt,
  data: data,
);

/// A repository the tests drive by hand: answers [feed] (or throws
/// [feedFailure]); marks read on the server side of [feed]; and can hold any
/// call in flight with a gate.
class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository({List<AppNotification>? notifications})
    : notifications = notifications ?? [];

  /// The server's notifications; marking read updates them.
  List<AppNotification> notifications;

  NotificationFailure? feedFailure;
  NotificationFailure? markFailure;
  NotificationFailure? markAllFailure;

  Completer<void>? feedGate;
  Completer<void>? markGate;
  Completer<void>? markAllGate;

  int feedCalls = 0;
  final List<int> markCalls = [];
  int markAllCalls = 0;

  /// The time the "server" stamps on a read.
  DateTime readStamp = DateTime.utc(2026, 10, 8, 6, 53);

  int get _unread => notifications.where((n) => !n.isRead).length;

  @override
  Future<NotificationFeed> getNotifications({int limit = 30}) async {
    feedCalls++;
    if (feedGate case final gate?) await gate.future;
    if (feedFailure case final failure?) throw failure;
    return NotificationFeed(
      notifications: notifications.take(limit).toList(),
      unreadCount: _unread,
    );
  }

  @override
  Future<NotificationReadResult> markRead(int id) async {
    markCalls.add(id);
    if (markGate case final gate?) await gate.future;
    if (markFailure case final failure?) throw failure;
    final index = notifications.indexWhere((n) => n.id == id);
    if (index < 0) {
      throw const NotificationFailure(NotificationFailureKind.notFound);
    }
    final current = notifications[index];
    final read = current.isRead ? current : current.copyWith(readAt: readStamp);
    notifications[index] = read;
    return NotificationReadResult(notification: read, unreadCount: _unread);
  }

  @override
  Future<NotificationReadAllResult> markAllRead() async {
    markAllCalls++;
    if (markAllGate case final gate?) await gate.future;
    if (markAllFailure case final failure?) throw failure;
    final updated = _unread;
    notifications = [
      for (final n in notifications)
        n.isRead ? n : n.copyWith(readAt: readStamp),
    ];
    return NotificationReadAllResult(updated: updated, unreadCount: 0);
  }
}
