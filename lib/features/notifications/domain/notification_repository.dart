import 'app_notification.dart';

/// The signed-in account's in-app notifications (Issue #246) — the same
/// endpoints for students and teachers. Throws `NotificationFailure`.
abstract interface class NotificationRepository {
  /// The latest [limit] notifications and the unread total —
  /// `GET /me/notifications?limit=`. The contract has no cursor or page, so
  /// there is no "next".
  Future<NotificationFeed> getNotifications({int limit = 30});

  /// `POST /me/notifications/{id}/read`. Idempotent: an already-read
  /// notification answers as read again.
  Future<NotificationReadResult> markRead(int id);

  /// `POST /me/notifications/read-all`. Idempotent.
  Future<NotificationReadAllResult> markAllRead();
}
