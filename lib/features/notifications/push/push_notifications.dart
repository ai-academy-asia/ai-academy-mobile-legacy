import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../auth/domain/auth_session_store.dart';
import '../../auth/presentation/home_route.dart';
import '../data/http_notification_repository.dart';
import '../domain/push_token_repository.dart';
import '../presentation/notification_center.dart';
import '../presentation/notification_detail_screen.dart';
import '../presentation/notification_screen.dart';
import '../presentation/notification_strings.dart';
import 'push_messaging.dart';

/// Remembers, across launches, that the app has asked for notification
/// permission — Android 13+ reports "not asked" and "refused" alike, so
/// without it every launch would prompt again.
abstract interface class PushPermissionMemory {
  Future<bool> asked();
  Future<void> markAsked();
}

/// [PushPermissionMemory] in the device's secure storage, beside the
/// session.
class SecurePushPermissionMemory implements PushPermissionMemory {
  SecurePushPermissionMemory({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String key = 'aia.push.permission_asked';

  final FlutterSecureStorage _storage;

  @override
  Future<bool> asked() async {
    try {
      return await _storage.read(key: key) == '1';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> markAsked() async {
    try {
      await _storage.write(key: key, value: '1');
    } catch (_) {
      // Unwritable storage: at worst the prompt is offered again later.
    }
  }
}

/// Push notifications in the app (Issue #398): the device's FCM token kept
/// registered for the signed-in account, the permission prompt, and what a
/// received or tapped push does. Off — every method a no-op — until [attach]
/// is given a [PushMessaging], which `main` does only when Firebase starts.
///
/// **When.** Nothing happens on Splash or Login. The first time a signed-in
/// home route appears ([routeObserver] sees `HomeRoutes`) — a sign-in or a
/// restored session — the permission is checked and asked when undecided:
/// on iOS whenever the OS says "not determined" (a reinstall resets it), on
/// Android 13+ at most once per install ([PushPermissionMemory] — "denied"
/// there also means "not asked"). With it granted the token is registered (`POST /me/push-tokens`, the session's own bearer token, so
/// it is this account's). Refused, nothing is registered; the in-app
/// notifications work as before.
///
/// **Which account.** Each sign-out ends a session generation. A
/// registration still in flight when its generation ends is not recorded,
/// and a refreshed token is registered only for the generation that is
/// signed in — a token is never registered for an account that has left.
/// The same token is not registered twice in a generation, and a start
/// joins only a start of the same generation.
///
/// **Leaving.** [signOut] runs before the session is cleared: it removes the
/// token from the account (`DELETE /me/push-tokens`) and then deletes it on
/// the device, so the next account gets a new one and a removal that failed
/// still delivers nothing. [sessionEnded] — a session already gone, no
/// bearer token to remove with — deletes it on the device only; the backend
/// drops the dead token when FCM reports it (ai-academy-backend#2).
///
/// **Retries.** A failed registration is retried when the app resumes and
/// on the next token refresh or home route; never in a loop.
///
/// **Messages.** In the foreground the OS shows nothing, so a push refreshes
/// the bell ([NotificationCenter.load]) and shows a SnackBar with
/// "Харах". A tap — on that SnackBar, or on the system notification from
/// the background or a terminated launch — opens the Notification screen,
/// and over it the notification's detail when the payload's
/// `notification_id` is in the loaded list (marked read, as a tile tap
/// does). A launch tap waits for the home route, so Splash cannot replace
/// what it opened. No other deep link: the in-app list opens none either.
class PushNotifications {
  PushNotifications({
    PushTokenRepository? tokens,
    AuthSessionStore? sessionStore,
    PushPermissionMemory? permissionMemory,
    NotificationCenter? center,
    PushPlatform? platform,
    this._navigatorKey,
    this._messengerKey,
    this.removalTimeout = const Duration(seconds: 5),
  }) : _tokens = tokens ?? HttpNotificationRepository(),
       _store = sessionStore ?? AuthSessionStore.instance,
       _memory = permissionMemory ?? SecurePushPermissionMemory(),
       _center = center ?? NotificationCenter.instance,
       _platform = platform ?? _currentPlatform();

  /// The app's instance; `main` attaches its messaging and the app's keys.
  static final PushNotifications instance = PushNotifications();

  final PushTokenRepository _tokens;
  final AuthSessionStore _store;
  final PushPermissionMemory _memory;
  final NotificationCenter _center;
  final PushPlatform? _platform;

  /// Where a tapped push opens its screens.
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Where a foreground push shows its SnackBar.
  GlobalKey<ScaffoldMessengerState>? _messengerKey;

  /// How long sign-out waits for each of the token's removals.
  final Duration removalTimeout;

  PushMessaging? _messaging;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  AppLifecycleListener? _lifecycle;

  int _generation = 0;
  bool _wasSignedIn = false;
  bool _permitted = false;
  bool _homeShown = false;
  Future<void>? _starting;
  int? _startingGeneration;

  String? _registeredToken;
  int? _registeredGeneration;
  PushMessage? _pendingOpen;

  /// Whether push is on — Firebase started and messaging attached.
  bool get enabled => _messaging != null;

  /// The OS notification permission as last read, for the Profile switch
  /// (Issue #429): null while push is off, or before the first read.
  ValueListenable<PushPermission?> get permissionState => _permission;
  final ValueNotifier<PushPermission?> _permission = ValueNotifier(null);

  /// Whether the user blocked the channel pushes are shown in, as last read
  /// with the permission (Issue #433): granted plus blocked shows nothing.
  /// False while push is off, where there are no channels, and when the read
  /// fails — a failed read never turns the switch off.
  ValueListenable<bool> get channelBlocked => _channelBlocked;
  final ValueNotifier<bool> _channelBlocked = ValueNotifier(false);

  /// Reads the OS permission again, without prompting — when Profile opens,
  /// and on every resume, since it only changes in the OS's settings — and
  /// with it whether the push channel is blocked (Issue #433). A no-op while
  /// push is off. Never throws.
  Future<void> refreshPermission() async {
    final messaging = _messaging;
    if (messaging == null) {
      _permission.value = null;
      _channelBlocked.value = false;
      return;
    }
    PushPermission? permission;
    var permissionRead = false;
    try {
      permission = await messaging.permission();
      permissionRead = true;
    } catch (error) {
      debugPrint('Push: permission check failed (${error.runtimeType}).');
    }
    final blocked = await _channelBlockedOf(messaging);
    // Both read before either is shown: publishing the permission first let
    // the switch flash on for a blocked channel (Issue #433).
    if (!identical(messaging, _messaging)) return;
    _publish(permissionRead ? permission : _permission.value, blocked);
  }

  /// Whether [messaging]'s push channel is blocked. A failed read counts as
  /// not blocked — it never turns the switch off.
  Future<bool> _channelBlockedOf(PushMessaging messaging) async {
    try {
      return await messaging.notificationChannelBlocked();
    } catch (error) {
      debugPrint('Push: channel check failed (${error.runtimeType}).');
      return false;
    }
  }

  /// Publishes the permission and the channel state together (Issue #433),
  /// in the same synchronous turn, so no frame sees one without the other.
  /// Whichever value turns the switch off goes first — the channel when the
  /// permission is granted, the permission otherwise — so even a listener
  /// never sees it pass through on on its way to off.
  void _publish(PushPermission? permission, bool blocked) {
    if (permission == PushPermission.granted) {
      _channelBlocked.value = blocked;
      _permission.value = permission;
    } else {
      _permission.value = permission;
      _channelBlocked.value = blocked;
    }
  }

  /// Opens this app's notification settings in the OS — the switch cannot
  /// change the permission itself. False while push is off, or when nothing
  /// opened. Never throws. What the user chose there is read on return.
  Future<bool> openNotificationSettings() async {
    final messaging = _messaging;
    if (messaging == null) return false;
    try {
      return await messaging.openNotificationSettings();
    } catch (error) {
      debugPrint(
        'Push: opening notification settings failed '
        '(${error.runtimeType}).',
      );
      return false;
    }
  }

  /// The token registered for the signed-in account, if any. For tests and
  /// diagnostics; never logged.
  @visibleForTesting
  String? get registeredToken => _registeredToken;

  /// Sees the signed-in home routes appear; given to the app's navigator.
  late final NavigatorObserver routeObserver = _HomeRouteObserver(_onRoute);

  /// Turns push on with [messaging] (null keeps it off), opening tapped
  /// pushes on [navigatorKey] and showing foreground ones on
  /// [messengerKey]. Safe to call once.
  Future<void> attach(
    PushMessaging? messaging, {
    GlobalKey<NavigatorState>? navigatorKey,
    GlobalKey<ScaffoldMessengerState>? messengerKey,
  }) async {
    if (messaging == null || _messaging != null) return;
    _messaging = messaging;
    _navigatorKey = navigatorKey ?? _navigatorKey;
    _messengerKey = messengerKey ?? _messengerKey;
    _wasSignedIn = _store.isSignedIn;
    _store.addListener(_sessionChanged);
    _subscriptions
      ..add(messaging.tokenRefreshes.listen(_tokenRefreshed))
      ..add(messaging.foregroundMessages.listen(_received))
      ..add(messaging.openedMessages.listen(open));
    _lifecycle = AppLifecycleListener(onResume: _resumed);
    try {
      final initial = await messaging.initialMessage();
      if (initial != null) _pendingOpen = initial;
    } catch (_) {
      // No launch message to read: nothing to open.
    }
  }

  /// Stops listening. For tests.
  @visibleForTesting
  Future<void> detach() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    _lifecycle?.dispose();
    _lifecycle = null;
    _store.removeListener(_sessionChanged);
    _messaging = null;
    _permission.value = null;
    _channelBlocked.value = false;
  }

  void _onRoute(Route<Object?> route) {
    final name = route.settings.name;
    if (name == null || !_homeRoutes.contains(name)) return;
    _homeShown = true;
    unawaited(start());
    // The navigator is mid-change while it reports a route: open once that
    // change has finished.
    scheduleMicrotask(_openPending);
  }

  static const Set<String> _homeRoutes = {
    HomeRoutes.adult,
    HomeRoutes.junior,
    HomeRoutes.teacher,
  };

  /// Checks or asks the permission and registers the token for the
  /// signed-in account. Joins a start already running. Never throws.
  /// Joins only a start of the same session: one still running for a
  /// session that has since ended would abort without registering this one.
  Future<void> start() {
    final running = _starting;
    if (running != null && _startingGeneration == _generation) return running;
    final generation = _generation;
    _startingGeneration = generation;
    late final Future<void> started;
    started = _start().whenComplete(() {
      if (identical(_starting, started)) _starting = null;
    });
    return _starting = started;
  }

  Future<void> _start() async {
    final messaging = _messaging;
    if (messaging == null || _platform == null || !_store.isSignedIn) return;
    final generation = _generation;
    try {
      var permission = await messaging.permission();
      if (await _shouldAsk(permission)) {
        await _memory.markAsked();
        permission = await messaging.requestPermission();
      }
      if (generation != _generation) return;
      // Granted, the switch's on depends on the channel too: read it before
      // showing the permission (Issue #433). Refused, it is off either way.
      final blocked = permission == PushPermission.granted
          ? await _channelBlockedOf(messaging)
          : _channelBlocked.value;
      if (generation != _generation || !identical(messaging, _messaging)) {
        return;
      }
      _publish(permission, blocked);
      _permitted = permission == PushPermission.granted;
      if (!_permitted) return;
      final token = await messaging.token();
      if (token != null) await _register(token, generation);
    } catch (error) {
      debugPrint('Push: start failed (${error.runtimeType}).');
    }
  }

  /// Whether to prompt. `notDetermined` (iOS) always means never asked —
  /// the memory lives in the iOS Keychain, which outlives a reinstall while
  /// the OS's permission does not. `denied` is ambiguous only on Android
  /// 13+, so there the memory decides: asked once, never again.
  Future<bool> _shouldAsk(PushPermission permission) async =>
      switch (permission) {
        PushPermission.granted => false,
        PushPermission.notDetermined => true,
        PushPermission.denied => !await _memory.asked(),
      };

  Future<void> _register(String token, int generation) async {
    if (_registeredToken == token && _registeredGeneration == generation) {
      return;
    }
    final platform = _platform;
    if (platform == null || generation != _generation || !_store.isSignedIn) {
      return;
    }
    await _tokens.registerPushToken(token: token, platform: platform);
    // Signed out while the request was out: that sign-out has already run,
    // and deleted the token on the device; record nothing.
    if (generation != _generation) return;
    _registeredToken = token;
    _registeredGeneration = generation;
  }

  void _tokenRefreshed(String token) {
    if (!_permitted || !_store.isSignedIn) return;
    _register(token, _generation).catchError((Object error) {
      debugPrint('Push: refresh registration failed (${error.runtimeType}).');
    });
  }

  void _resumed() {
    // The permission may have changed in the OS's settings meanwhile — the
    // Profile switch's way out (Issue #429).
    unawaited(refreshPermission());
    // Granted there, an unregistered session registers now.
    if (_homeShown && _registeredToken == null && _store.isSignedIn) {
      unawaited(start());
    }
  }

  void _sessionChanged() {
    final signedIn = _store.isSignedIn;
    if (_wasSignedIn && !signedIn) {
      // A session ended, however it ended: the next is a new generation.
      _generation++;
      _registeredToken = null;
      _registeredGeneration = null;
      _permitted = false;
      _homeShown = false;
      _pendingOpen = null;
    }
    _wasSignedIn = signedIn;
  }

  /// Before an explicit sign-out clears the session: removes the token from
  /// the account, then deletes it on the device. Each step is bounded by
  /// [removalTimeout] and may fail without stopping the sign-out.
  Future<void> signOut() async {
    final messaging = _messaging;
    if (messaging == null) return;
    final token = _registeredToken;
    _registeredToken = null;
    _registeredGeneration = null;
    _permitted = false;
    if (token != null && _store.isSignedIn) {
      try {
        await _tokens.removePushToken(token).timeout(removalTimeout);
      } catch (error) {
        debugPrint('Push: token removal failed (${error.runtimeType}).');
      }
    }
    await _deleteOnDevice(messaging);
  }

  /// After a session ended without an explicit sign-out (it could not be
  /// renewed): no bearer token is left to remove with, so the token is only
  /// deleted on the device.
  Future<void> sessionEnded() async {
    final messaging = _messaging;
    if (messaging == null) return;
    _registeredToken = null;
    _registeredGeneration = null;
    await _deleteOnDevice(messaging);
  }

  Future<void> _deleteOnDevice(PushMessaging messaging) async {
    try {
      await messaging.deleteToken().timeout(removalTimeout);
    } catch (error) {
      debugPrint('Push: device token deletion failed (${error.runtimeType}).');
    }
  }

  void _received(PushMessage message) {
    if (!_store.isSignedIn) return;
    unawaited(_center.load());
    final messenger = _messengerKey?.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message.title ?? message.body ?? NotificationStrings.pushReceived,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        action: SnackBarAction(
          label: NotificationStrings.pushOpen,
          onPressed: () => open(message),
        ),
      ),
    );
  }

  /// Opens what a tapped push points at — now when a signed-in home has
  /// appeared, else when it does.
  void open(PushMessage message) {
    _pendingOpen = message;
    _openPending();
  }

  void _openPending() {
    final message = _pendingOpen;
    final navigator = _navigatorKey?.currentState;
    if (message == null || !_homeShown || navigator == null) return;
    _pendingOpen = null;
    if (!_store.isSignedIn) return;
    unawaited(_openFor(navigator, message));
  }

  Future<void> _openFor(NavigatorState navigator, PushMessage message) async {
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => NotificationScreen(center: _center),
        ),
      ),
    );
    final id = message.notificationId;
    if (id == null) return;
    await _center.load();
    if (!navigator.mounted || !_store.isSignedIn) return;
    final notification = _center.notifications
        .where((n) => n.id == id)
        .firstOrNull;
    if (notification == null) return;
    if (!notification.isRead) unawaited(_center.markRead(id));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => NotificationDetailScreen(notification: notification),
        ),
      ),
    );
  }

  static PushPlatform? _currentPlatform() => switch (defaultTargetPlatform) {
    TargetPlatform.android => PushPlatform.android,
    TargetPlatform.iOS => PushPlatform.ios,
    _ => null,
  };
}

class _HomeRouteObserver extends NavigatorObserver {
  _HomeRouteObserver(this._onRoute);

  final void Function(Route<Object?> route) _onRoute;

  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) =>
      _onRoute(route);

  @override
  void didReplace({Route<Object?>? newRoute, Route<Object?>? oldRoute}) {
    if (newRoute != null) _onRoute(newRoute);
  }
}
