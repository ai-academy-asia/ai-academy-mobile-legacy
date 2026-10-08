/// One in-app notification — an item of `GET /me/notifications` (Issue
/// #246), exactly the fields verified live in Phase 0: `id`, `title`,
/// `body`, `kind`, `created_at`, `read_at` (nullable) and `data`
/// (nullable).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.createdAt,
    this.readAt,
    this.data,
  });

  final int id;
  final String title;
  final String body;

  /// The backend's category, as sent — `general` and `assignment` are the
  /// two seen. Kept as a string: the set is not known to be closed, and no
  /// screen branches on it yet.
  final String kind;

  final DateTime createdAt;

  /// When it was read; null while unread — the contract's only read flag.
  final DateTime? readAt;

  /// Kind-specific extras, opaque except where a key is verified — see
  /// [assignmentId]. Null when the backend sent none.
  final Map<String, Object?>? data;

  bool get isRead => readAt != null;

  /// `data.assignment_id` on an `assignment` notification — the one
  /// kind-specific key verified. Nothing navigates with it yet: no deep-link
  /// behaviour is defined.
  int? get assignmentId {
    if (kind != 'assignment') return null;
    final value = data?['assignment_id'];
    return value is int ? value : null;
  }

  AppNotification copyWith({DateTime? readAt}) => AppNotification(
    id: id,
    title: title,
    body: body,
    kind: kind,
    createdAt: createdAt,
    readAt: readAt ?? this.readAt,
    data: data,
  );
}

/// `GET /me/notifications`: the latest notifications and the server's
/// unread total.
class NotificationFeed {
  const NotificationFeed({
    required this.notifications,
    required this.unreadCount,
    this.skipped = 0,
  });

  /// Newest first, as the server orders them.
  final List<AppNotification> notifications;

  /// The server's count of unread notifications — not recomputed from
  /// [notifications], which holds only the latest page.
  final int unreadCount;

  /// Items in the response that could not be read and were left out — see
  /// `HttpNotificationRepository`. Kept so the gap is visible, not silent.
  final int skipped;
}

/// `POST /me/notifications/{id}/read`: the notification as now stored, and
/// the server's new unread total.
class NotificationReadResult {
  const NotificationReadResult({
    required this.notification,
    required this.unreadCount,
  });

  final AppNotification notification;
  final int unreadCount;
}

/// `POST /me/notifications/read-all`: how many were marked, and the new
/// unread total.
class NotificationReadAllResult {
  const NotificationReadAllResult({
    required this.updated,
    required this.unreadCount,
  });

  final int updated;
  final int unreadCount;
}
