import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'notification_settings_opener.dart';
import 'push_messaging.dart';

/// The iOS app's Firebase options, given at build time (Issue #398):
///
///     flutter build ios \
///       --dart-define=FIREBASE_IOS_API_KEY=… \
///       --dart-define=FIREBASE_IOS_APP_ID=… \
///       --dart-define=FIREBASE_MESSAGING_SENDER_ID=… \
///       --dart-define=FIREBASE_PROJECT_ID=…
///
/// They are the `API_KEY`, `GOOGLE_APP_ID`, `GCM_SENDER_ID` and `PROJECT_ID`
/// of the Firebase project's `GoogleService-Info.plist` for
/// `com.aiacademyasia.aiaMobile`. Given in Dart, so no plist has to be
/// added to the protected Xcode project. Missing any of them, push is off.
/// Android reads `android/app/google-services.json` natively instead.
abstract final class FirebasePushConfig {
  static const String _apiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const String _appId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const String _senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );

  /// The options, or null when any value is missing.
  static FirebaseOptions? get iosOptions =>
      [_apiKey, _appId, _senderId, _projectId].any((v) => v.isEmpty)
      ? null
      : const FirebaseOptions(
          apiKey: _apiKey,
          appId: _appId,
          messagingSenderId: _senderId,
          projectId: _projectId,
          iosBundleId: 'com.aiacademyasia.aiaMobile',
        );
}

/// Starts Firebase and answers the app's [PushMessaging] — or null, push
/// off, on an unsupported platform, without the Firebase configuration, or
/// when Firebase fails to start. Never throws: the app runs as before
/// without push. Logs the reason in debug builds, never a value.
Future<PushMessaging?> startFirebasePush() async {
  if (kIsWeb) return null;
  try {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // The native default app, from google-services.json; throws
        // without it.
        await Firebase.initializeApp();
      case TargetPlatform.iOS:
        final options = FirebasePushConfig.iosOptions;
        if (options == null) {
          debugPrint('Push off: no iOS Firebase options (Issue #398).');
          return null;
        }
        await Firebase.initializeApp(options: options);
      default:
        return null;
    }
  } catch (error) {
    debugPrint('Push off: Firebase did not start (${error.runtimeType}).');
    return null;
  }
  return FirebasePushMessaging(FirebaseMessaging.instance);
}

/// [PushMessaging] on `firebase_messaging`.
class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<PushPermission> permission() async => _permission(
    (await _messaging.getNotificationSettings()).authorizationStatus,
  );

  @override
  Future<PushPermission> requestPermission() async =>
      _permission((await _messaging.requestPermission()).authorizationStatus);

  @override
  Future<bool> openNotificationSettings() => openAppNotificationSettings();

  @override
  Future<String?> token() async {
    // iOS: FCM needs the APNs token first; until APNs has issued it (or
    // without the Push capability) there is no FCM token to have.
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await _messaging.getAPNSToken() == null) {
      return null;
    }
    return _messaging.getToken();
  }

  @override
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  @override
  Future<void> deleteToken() => _messaging.deleteToken();

  @override
  Stream<PushMessage> get foregroundMessages =>
      FirebaseMessaging.onMessage.map(_message);

  @override
  Stream<PushMessage> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp.map(_message);

  @override
  Future<PushMessage?> initialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _message(message);
  }

  static PushMessage _message(RemoteMessage message) => PushMessage(
    title: message.notification?.title,
    body: message.notification?.body,
    data: message.data,
  );

  static PushPermission _permission(AuthorizationStatus status) =>
      switch (status) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => PushPermission.granted,
        AuthorizationStatus.denied ||
        AuthorizationStatus.deniedPermanently => PushPermission.denied,
        AuthorizationStatus.notDetermined => PushPermission.notDetermined,
      };
}
