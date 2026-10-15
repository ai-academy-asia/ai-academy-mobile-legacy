import 'dart:async';

import 'package:aia_mobile/features/notifications/domain/notification_failure.dart';
import 'package:aia_mobile/features/notifications/domain/push_token_repository.dart';
import 'package:aia_mobile/features/notifications/push/push_messaging.dart';
import 'package:aia_mobile/features/notifications/push/push_notifications.dart';

/// The push layer's fakes (Issues #398, #429): no Firebase, no network, no
/// device. Shared by the push tests and the Profile switch tests.
class FakePushMessaging implements PushMessaging {
  PushPermission status = PushPermission.granted;

  /// What the prompt answers.
  PushPermission answer = PushPermission.granted;
  String? nextToken = 'fcm-1';
  PushMessage? launchMessage;
  final List<String> calls = [];

  /// When set, [permission] waits on it — a start held mid-way.
  Completer<void>? permissionGate;

  final _refreshes = StreamController<String>.broadcast();
  final _foreground = StreamController<PushMessage>.broadcast();
  final _opened = StreamController<PushMessage>.broadcast();

  void refresh(String token) => _refreshes.add(token);
  void receive(PushMessage message) => _foreground.add(message);
  void tap(PushMessage message) => _opened.add(message);

  Future<void> close() async {
    await _refreshes.close();
    await _foreground.close();
    await _opened.close();
  }

  @override
  Future<PushPermission> permission() async {
    calls.add('permission');
    if (permissionGate case final gate?) await gate.future;
    return status;
  }

  @override
  Future<PushPermission> requestPermission() async {
    calls.add('requestPermission');
    return status = answer;
  }

  /// What opening the OS notification settings answers (Issue #429); an
  /// error to throw instead, when set.
  bool settingsOpen = true;
  Object? settingsError;

  @override
  Future<bool> openNotificationSettings() async {
    calls.add('openNotificationSettings');
    if (settingsError case final error?) throw error;
    return settingsOpen;
  }

  /// Whether the push channel reads blocked (Issue #433); an error to throw
  /// instead, when set.
  bool channelBlocked = false;
  Object? channelError;

  /// When set, [notificationChannelBlocked] waits on it — a read held open,
  /// so a test can look inside the window before it answers.
  Completer<void>? channelGate;

  @override
  Future<bool> notificationChannelBlocked() async {
    calls.add('notificationChannelBlocked');
    if (channelGate case final gate?) await gate.future;
    if (channelError case final error?) throw error;
    return channelBlocked;
  }

  @override
  Future<String?> token() async {
    calls.add('token');
    return nextToken;
  }

  @override
  Future<void> deleteToken() async => calls.add('deleteToken');

  @override
  Stream<String> get tokenRefreshes => _refreshes.stream;

  @override
  Stream<PushMessage> get foregroundMessages => _foreground.stream;

  @override
  Stream<PushMessage> get openedMessages => _opened.stream;

  @override
  Future<PushMessage?> initialMessage() async => launchMessage;
}

class FakePushTokens implements PushTokenRepository {
  final List<(String, PushPlatform)> registered = [];
  final List<String> removed = [];
  int attempts = 0;
  NotificationFailure? failure;
  Completer<void>? gate;
  void Function()? onRemove;

  @override
  Future<void> registerPushToken({
    required String token,
    required PushPlatform platform,
  }) async {
    attempts++;
    if (gate case final gate?) await gate.future;
    if (failure case final failure?) throw failure;
    registered.add((token, platform));
  }

  @override
  Future<void> removePushToken(String token) async {
    removed.add(token);
    onRemove?.call();
    if (gate case final gate?) await gate.future;
  }
}

class FakePermissionMemory implements PushPermissionMemory {
  bool wasAsked = false;

  @override
  Future<bool> asked() async => wasAsked;

  @override
  Future<void> markAsked() async => wasAsked = true;
}
