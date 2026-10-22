import '../../../core/locale/l10n.dart';
import '../../../core/locale/app_format.dart';
import '../../profile/presentation/profile_strings.dart';
import '../domain/notification_failure.dart';

/// Copy for the Notification Center (Issue #246) — English where the Figma
/// frame draws English, as the Profile and Certificate frames do.
abstract final class NotificationStrings {
  /// Read by a screen reader before an unread row's title, in place of the
  /// unread dot: `Шинэ`, or `Unread` in English (Issue #509).
  static String get unread => L10n.current.notificationUnread;

  /// The screen's title.
  static const String title = 'Notification';

  /// No notifications yet. No frame draws this state, so the line is the
  /// app's own plain wording (a `PRODUCT DECISION`).
  static String get empty => L10n.current.notificationEmpty;

  static String get retry => L10n.current.commonRetry;

  /// A mark-read for a notification the server no longer has.
  static String get notFound => L10n.current.notificationNotFound;

  static String messageFor(NotificationFailureKind kind) => switch (kind) {
    NotificationFailureKind.sessionExpired => ProfileStrings.sessionExpired,
    NotificationFailureKind.network => ProfileStrings.networkError,
    NotificationFailureKind.server => ProfileStrings.serverError,
    NotificationFailureKind.notFound => notFound,
    NotificationFailureKind.unexpected => ProfileStrings.unexpectedError,
  };

  /// A notification's age as the frame writes it: `1d`, `7d`. The frame
  /// shows days only; under a day reads `Nh`, under an hour `Nm` — the same
  /// short form, a `PRODUCT DECISION` until a frame shows those. The same in
  /// either language ([AppFormat.age], Issue #505).
  static String age(DateTime createdAt, DateTime now) =>
      AppFormat.age(createdAt, now);

  /// When a notification was sent, as Notification Detail writes it (Issue
  /// #248): `2026.10.08 · 15:18`, in local time, 24-hour. No frame draws the
  /// detail screen, so the format is the product brief's own example.
  /// English: `Oct 8, 2026 · 15:18` ([AppFormat], Issue #505).
  static String sentAt(DateTime createdAt) {
    final local = createdAt.toLocal();
    return '${AppFormat.dateWithYear(local, mongolianSeparator: '.')} '
        '· ${AppFormat.time(local)}';
  }

  // --- Push notifications (Issue #398) -----------------------------------

  /// A foreground push's SnackBar text when the push carries no title or
  /// body.
  static String get pushReceived => L10n.current.notificationPushReceived;

  /// The SnackBar action that opens the push's notification.
  static String get pushOpen => L10n.current.notificationPushOpen;
}
