/// The platform a device push token belongs to — the backend's `platform`
/// (`PUSH_PLATFORMS`: `ios`, `android`, `web`; this app sends the first
/// two). The wire value is the enum's [name].
enum PushPlatform { ios, android }

/// The signed-in account's device push tokens (Issues #293, #396) —
/// `POST` / `DELETE /me/push-tokens`, the same for students and teachers.
/// Throws `NotificationFailure`.
///
/// The data layer only: nothing calls it until the Firebase Messaging
/// setup that supplies a token is approved (#293).
abstract interface class PushTokenRepository {
  /// `POST /me/push-tokens` `{token, platform}`. An upsert: registering a
  /// known token again refreshes it, and a token another account had moves
  /// to this one.
  Future<void> registerPushToken({
    required String token,
    required PushPlatform platform,
  });

  /// `DELETE /me/push-tokens` `{token}`. Removes only this account's own
  /// token; idempotent — an unknown or another account's token removes
  /// nothing and still succeeds. Called before the session ends, so the next
  /// account on the device never receives this one's pushes.
  Future<void> removePushToken(String token);
}
