import '../../profile/presentation/profile_strings.dart';
import '../domain/notification_failure.dart';

/// Copy for the Notification Center (Issue #246) — English where the Figma
/// frame draws English, as the Profile and Certificate frames do.
abstract final class NotificationStrings {
  /// The screen's title.
  static const String title = 'Notification';

  /// No notifications yet. No frame draws this state, so the line is the
  /// app's own plain wording (a `PRODUCT DECISION`).
  static const String empty = 'Одоогоор мэдэгдэл алга байна';

  static const String retry = 'Дахин оролдох';

  /// A mark-read for a notification the server no longer has.
  static const String notFound = 'Мэдэгдэл олдсонгүй';

  static String messageFor(NotificationFailureKind kind) => switch (kind) {
    NotificationFailureKind.sessionExpired => ProfileStrings.sessionExpired,
    NotificationFailureKind.network => ProfileStrings.networkError,
    NotificationFailureKind.server => ProfileStrings.serverError,
    NotificationFailureKind.notFound => notFound,
    NotificationFailureKind.unexpected => ProfileStrings.unexpectedError,
  };

  /// A notification's age as the frame writes it: `1d`, `7d`. The frame
  /// shows days only; under a day reads `Nh`, under an hour `Nm` — the same
  /// short form, a `PRODUCT DECISION` until a frame shows those.
  static String age(DateTime createdAt, DateTime now) {
    final elapsed = now.difference(createdAt);
    if (elapsed.inDays >= 1) return '${elapsed.inDays}d';
    if (elapsed.inHours >= 1) return '${elapsed.inHours}h';
    final minutes = elapsed.inMinutes;
    return '${minutes < 1 ? 1 : minutes}m';
  }

  /// When a notification was sent, as Notification Detail writes it (Issue
  /// #248): `2026.10.01 12:57`, in local time, 24-hour. No frame draws the
  /// detail screen, so the format is the product brief's own example.
  static String sentAt(DateTime createdAt) {
    final local = createdAt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}.${two(local.month)}.${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
