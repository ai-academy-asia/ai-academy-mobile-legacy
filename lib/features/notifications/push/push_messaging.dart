/// Whether the OS lets this app show notifications.
enum PushPermission {
  /// Allowed — fully or provisionally (iOS quiet delivery).
  granted,

  /// Refused. On Android 13+ this also covers "not asked yet": the OS does
  /// not tell the two apart, so the app remembers whether it asked.
  denied,

  /// Not asked yet (iOS).
  notDetermined,
}

/// One push as the app uses it: the visible text and the `data` payload.
///
/// The backend sends `data.kind` and the recipient's own
/// `data.notification_id` — the in-app notification the push announces
/// (ai-academy-backend#2) — plus that notification's own `data` keys, all as
/// strings.
class PushMessage {
  const PushMessage({this.title, this.body, this.data = const {}});

  final String? title;
  final String? body;
  final Map<String, Object?> data;

  /// The in-app notification this push announces, when the payload names
  /// one. A malformed value reads as none.
  int? get notificationId => switch (data['notification_id']) {
    final int id => id,
    final String id => int.tryParse(id),
    _ => null,
  };
}

/// The FCM operations the app uses, behind an interface so the token,
/// permission and tap rules are tested without Firebase (Issue #398).
/// `FirebasePushMessaging` is the app's implementation.
abstract interface class PushMessaging {
  /// The current permission, without prompting.
  Future<PushPermission> permission();

  /// Prompts for permission (the OS may decline to show the prompt again).
  Future<PushPermission> requestPermission();

  /// This device's FCM registration token, or null while one cannot be had
  /// yet — on iOS before APNs has issued its token.
  Future<String?> token();

  /// A new token, whenever FCM rotates it.
  Stream<String> get tokenRefreshes;

  /// Invalidates this device's token, so nothing sent to it arrives; the
  /// next [token] is a new one.
  Future<void> deleteToken();

  /// Pushes received while the app is in the foreground — the OS shows
  /// nothing for them.
  Stream<PushMessage> get foregroundMessages;

  /// Pushes tapped while the app was in the background.
  Stream<PushMessage> get openedMessages;

  /// The push whose tap launched the app from terminated, once.
  Future<PushMessage?> initialMessage();
}
