import 'dart:async';

import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/auth/presentation/home_route.dart';
import 'package:aia_mobile/features/auth/presentation/sign_out.dart';
import 'package:aia_mobile/features/notifications/domain/notification_failure.dart';
import 'package:aia_mobile/features/notifications/domain/push_token_repository.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_center.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_detail_screen.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_screen.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_strings.dart';
import 'package:aia_mobile/features/notifications/push/push_messaging.dart';
import 'package:aia_mobile/features/notifications/push/push_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/fake_auth_repository.dart';
import 'fake_notification_repository.dart';
import 'fake_push.dart';

/// Push notifications (Issue #398) on a fake messaging layer: no Firebase,
/// no network, no device. The token rules, the permission prompt, sign-out
/// and what a received or tapped push opens.
void main() {
  late FakePushMessaging messaging;
  late FakePushTokens tokens;
  late FakePermissionMemory memory;
  late AuthSessionStore store;
  late FakeNotificationRepository notifications;
  late NotificationCenter center;
  late GlobalKey<NavigatorState> navigatorKey;
  late GlobalKey<ScaffoldMessengerState> messengerKey;
  late PushNotifications push;

  const session = AuthSession(accessToken: 'tok-a', refreshToken: 'ref-a');

  setUp(() {
    messaging = FakePushMessaging();
    tokens = FakePushTokens();
    memory = FakePermissionMemory();
    store = AuthSessionStore()..save(session);
    notifications = FakeNotificationRepository(
      notifications: [sampleNotification(id: 24, title: 'Шинэ даалгавар')],
    );
    center = NotificationCenter(repository: notifications);
    navigatorKey = GlobalKey<NavigatorState>();
    messengerKey = GlobalKey<ScaffoldMessengerState>();
    push = PushNotifications(
      tokens: tokens,
      sessionStore: store,
      permissionMemory: memory,
      center: center,
      platform: PushPlatform.android,
      removalTimeout: const Duration(milliseconds: 200),
    );
  });

  tearDown(() async {
    await push.detach();
    await messaging.close();
  });

  Future<void> attach() => push.attach(
    messaging,
    navigatorKey: navigatorKey,
    messengerKey: messengerKey,
  );

  /// The app's shape: Splash at `/`, then the adult home by name.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: messengerKey,
        navigatorObservers: [push.routeObserver],
        routes: {
          '/': (_) => const Scaffold(body: Text('splash')),
          HomeRoutes.adult: (_) => const Scaffold(body: Text('home')),
          '/login': (_) => const Scaffold(body: Text('login')),
        },
      ),
    );
  }

  Future<void> goHome(WidgetTester tester) async {
    navigatorKey.currentState!.pushReplacementNamed(HomeRoutes.adult);
    await tester.pumpAndSettle();
  }

  /// The app to the background and back, through the states the OS
  /// reports.
  void leaveAndReturn(WidgetTester tester) {
    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  group('push off', () {
    testWidgets('without messaging nothing is asked, registered or removed', (
      tester,
    ) async {
      await push.attach(null);
      await pumpApp(tester);
      await goHome(tester);
      await push.signOut();
      await push.sessionEnded();
      expect(push.enabled, isFalse);
      expect(messaging.calls, isEmpty);
      expect(tokens.registered, isEmpty);
      expect(tokens.removed, isEmpty);
    });
  });

  group('permission and registration', () {
    testWidgets('nothing happens on Splash; the home route asks once and '
        'registers the token for the session', (tester) async {
      messaging.status = PushPermission.notDetermined;
      await attach();
      await pumpApp(tester);
      await tester.pump();
      expect(messaging.calls, isNot(contains('requestPermission')));
      expect(tokens.registered, isEmpty);

      await goHome(tester);
      expect(
        messaging.calls.where((c) => c == 'requestPermission'),
        hasLength(1),
      );
      expect(memory.wasAsked, isTrue);
      expect(tokens.registered, [('fcm-1', PushPlatform.android)]);
      expect(push.registeredToken, 'fcm-1');
    });

    testWidgets('the same token is not registered twice in a session', (
      tester,
    ) async {
      await attach();
      await pumpApp(tester);
      await goHome(tester);
      await goHome(tester);
      await push.start();
      expect(tokens.registered, hasLength(1));
      expect(messaging.calls.where((c) => c == 'requestPermission'), isEmpty);
    });

    testWidgets('refused: nothing is registered, and a later launch does '
        'not ask again', (tester) async {
      messaging
        ..status = PushPermission.denied
        ..answer = PushPermission.denied;
      await attach();
      await pumpApp(tester);
      await goHome(tester);
      expect(
        messaging.calls.where((c) => c == 'requestPermission'),
        hasLength(1),
      );
      expect(tokens.registered, isEmpty);

      // The next launch: Android 13+ still says "denied" — not asked again.
      messaging.calls.clear();
      await push.start();
      expect(messaging.calls, isNot(contains('requestPermission')));
      expect(tokens.registered, isEmpty);
    });

    testWidgets('allowed later in the OS settings: registered without a '
        'prompt', (tester) async {
      memory.wasAsked = true;
      await attach();
      await pumpApp(tester);
      await goHome(tester);
      expect(messaging.calls, isNot(contains('requestPermission')));
      expect(tokens.registered, hasLength(1));
    });

    testWidgets('iOS after a reinstall: "not determined" is asked even though '
        'the Keychain still says "asked"', (tester) async {
      memory.wasAsked = true;
      messaging.status = PushPermission.notDetermined;
      await attach();
      await pumpApp(tester);
      await goHome(tester);
      expect(
        messaging.calls.where((c) => c == 'requestPermission'),
        hasLength(1),
      );
      expect(tokens.registered, hasLength(1));
    });

    testWidgets('a start still running for a session that ended does not '
        'swallow the next account\'s', (tester) async {
      final gateA = messaging.permissionGate = Completer<void>();
      await attach();
      await pumpApp(tester);
      navigatorKey.currentState!.pushReplacementNamed(HomeRoutes.adult);
      await tester.pump();
      expect(messaging.calls, ['permission']); // account A's start, held

      store.clear();
      store.save(const AuthSession(accessToken: 'tok-b'));
      messaging
        ..permissionGate = null
        ..nextToken = 'fcm-b';
      navigatorKey.currentState!.pushReplacementNamed(HomeRoutes.adult);
      await tester.pumpAndSettle();
      expect(push.registeredToken, 'fcm-b');

      // A's start, released late, registers nothing more.
      gateA.complete();
      await tester.pumpAndSettle();
      expect(tokens.registered.map((r) => r.$1), ['fcm-b']);
      expect(push.registeredToken, 'fcm-b');
    });

    testWidgets('no token yet (iOS before APNs): nothing is registered; '
        'resume tries again', (tester) async {
      messaging.nextToken = null;
      await attach();
      await pumpApp(tester);
      await goHome(tester);
      expect(tokens.registered, isEmpty);

      messaging.nextToken = 'fcm-late';
      leaveAndReturn(tester);
      await tester.pumpAndSettle();
      expect(tokens.registered, [('fcm-late', PushPlatform.android)]);
    });

    testWidgets('a failed registration is retried on resume, not in a '
        'loop', (tester) async {
      tokens.failure = const NotificationFailure(
        NotificationFailureKind.network,
      );
      await attach();
      await pumpApp(tester);
      await goHome(tester);
      expect(tokens.attempts, 1);
      expect(push.registeredToken, isNull);
      await tester.pump(const Duration(seconds: 5));
      expect(tokens.attempts, 1);

      tokens.failure = null;
      leaveAndReturn(tester);
      await tester.pumpAndSettle();
      expect(tokens.attempts, 2);
      expect(push.registeredToken, 'fcm-1');
    });

    testWidgets('a refreshed token is registered for the signed-in account', (
      tester,
    ) async {
      await attach();
      await pumpApp(tester);
      await goHome(tester);
      messaging.refresh('fcm-2');
      await tester.pumpAndSettle();
      expect(tokens.registered.map((r) => r.$1), ['fcm-1', 'fcm-2']);
      expect(push.registeredToken, 'fcm-2');
    });

    testWidgets('a refresh after sign-out registers nothing', (tester) async {
      await attach();
      await pumpApp(tester);
      await goHome(tester);
      store.clear();
      messaging.refresh('fcm-2');
      await tester.pumpAndSettle();
      expect(tokens.registered.map((r) => r.$1), ['fcm-1']);
    });

    testWidgets('signed out while the registration was out: it is not '
        'recorded for the next account', (tester) async {
      tokens.gate = Completer<void>();
      await attach();
      await pumpApp(tester);
      navigatorKey.currentState!.pushReplacementNamed(HomeRoutes.adult);
      await tester.pump();
      await tester.pump();
      expect(tokens.attempts, 1);

      store.clear();
      tokens.gate!.complete();
      await tester.pumpAndSettle();
      expect(push.registeredToken, isNull);

      // The next account registers its own, fresh.
      tokens.gate = null;
      store.save(const AuthSession(accessToken: 'tok-b'));
      messaging.nextToken = 'fcm-b';
      await goHome(tester);
      expect(push.registeredToken, 'fcm-b');
    });
  });

  group('leaving', () {
    testWidgets('sign-out removes the token while still signed in, then '
        'deletes it on the device', (tester) async {
      await attach();
      await pumpApp(tester);
      await goHome(tester);
      tokens.onRemove = () => expect(store.isSignedIn, isTrue);

      await push.signOut();
      expect(tokens.removed, ['fcm-1']);
      expect(messaging.calls.last, 'deleteToken');
      expect(push.registeredToken, isNull);
    });

    testWidgets('a failed or slow removal still deletes the device token '
        'and never throws', (tester) async {
      await attach();
      await pumpApp(tester);
      await goHome(tester);
      tokens.gate = Completer<void>(); // never completes: the timeout ends it

      await tester.runAsync(push.signOut);
      expect(tokens.removed, ['fcm-1']);
      expect(messaging.calls.last, 'deleteToken');
    });

    testWidgets('a session that ended deletes the device token only', (
      tester,
    ) async {
      await attach();
      await pumpApp(tester);
      await goHome(tester);
      await push.sessionEnded();
      expect(tokens.removed, isEmpty);
      expect(messaging.calls.last, 'deleteToken');
    });

    testWidgets('signOutToLogin removes the push token before it clears the '
        'session', (tester) async {
      await attach();
      await pumpApp(tester);
      await goHome(tester);
      final order = <String>[];
      tokens.onRemove = () => order.add(
        store.isSignedIn ? 'removed while signed in' : 'removed too late',
      );
      store.addListener(() {
        if (!store.isSignedIn) order.add('cleared');
      });

      await signOutToLogin(
        navigatorKey.currentState!,
        repository: FakeAuthRepository(),
        sessionStore: store,
        push: push,
      );
      await tester.pumpAndSettle();
      expect(order, ['removed while signed in', 'cleared']);
      expect(find.text('login'), findsOneWidget);
    });
  });

  group('messages', () {
    testWidgets('in the foreground: the bell refreshes and a SnackBar '
        'offers the notification', (tester) async {
      await attach();
      await pumpApp(tester);
      await goHome(tester);
      final loads = notifications.feedCalls;

      messaging.receive(
        const PushMessage(
          title: 'Шинэ даалгавар',
          data: {'kind': 'assignment', 'notification_id': '24'},
        ),
      );
      await tester.pumpAndSettle();
      expect(notifications.feedCalls, greaterThan(loads));
      expect(find.text('Шинэ даалгавар'), findsOneWidget);

      await tester.tap(find.text(NotificationStrings.pushOpen));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationDetailScreen), findsOneWidget);
    });

    testWidgets('a foreground push with no text still says something', (
      tester,
    ) async {
      await attach();
      await pumpApp(tester);
      await goHome(tester);
      messaging.receive(const PushMessage());
      await tester.pumpAndSettle();
      expect(find.text(NotificationStrings.pushReceived), findsOneWidget);
    });

    testWidgets('a tap from the background opens the notification over the '
        'Notification screen, marked read', (tester) async {
      await attach();
      await pumpApp(tester);
      await goHome(tester);

      messaging.tap(const PushMessage(data: {'notification_id': '24'}));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationDetailScreen), findsOneWidget);
      expect(notifications.markCalls, [24]);
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(NotificationScreen), findsOneWidget);
    });

    testWidgets('an id not in the list, or none: the Notification screen '
        'alone', (tester) async {
      await attach();
      await pumpApp(tester);
      await goHome(tester);
      messaging.tap(const PushMessage(data: {'notification_id': '999'}));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationScreen), findsOneWidget);
      expect(find.byType(NotificationDetailScreen), findsNothing);
    });

    testWidgets('a tap that launched the app waits for the home route — '
        'Splash cannot replace it', (tester) async {
      messaging.launchMessage = const PushMessage(
        data: {'notification_id': '24'},
      );
      await attach();
      await pumpApp(tester);
      await tester.pumpAndSettle();
      expect(find.byType(NotificationScreen), findsNothing);

      await goHome(tester);
      expect(find.byType(NotificationDetailScreen), findsOneWidget);
    });

    testWidgets('signed out, a tap opens nothing', (tester) async {
      await attach();
      await pumpApp(tester);
      await goHome(tester);
      store.clear();
      messaging.tap(const PushMessage(data: {'notification_id': '24'}));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationScreen), findsNothing);
    });
  });

  group('the Profile switch\'s permission state (Issue #429)', () {
    test('push off: no state, nothing read, nothing opened', () async {
      await push.attach(null);

      await push.refreshPermission();
      expect(push.permissionState.value, isNull);
      expect(await push.openNotificationSettings(), isFalse);
      expect(messaging.calls, isEmpty);
    });

    test('a refresh reads the OS permission without prompting', () async {
      await attach();
      for (final permission in PushPermission.values) {
        messaging.status = permission;
        await push.refreshPermission();
        expect(push.permissionState.value, permission);
      }
      expect(messaging.calls, isNot(contains('requestPermission')));
    });

    test(
      'opening the settings asks the OS, and reports what it answered',
      () async {
        await attach();

        expect(await push.openNotificationSettings(), isTrue);
        messaging.settingsOpen = false;
        expect(await push.openNotificationSettings(), isFalse);
        expect(
          messaging.calls.where((c) => c == 'openNotificationSettings'),
          hasLength(2),
        );
      },
    );

    test('settings that fail to open answer false and never throw', () async {
      await attach();
      messaging.settingsError = StateError('no activity');

      expect(await push.openNotificationSettings(), isFalse);
    });

    testWidgets('the start\'s own read keeps the state current', (
      tester,
    ) async {
      messaging.status = PushPermission.granted;
      await attach();
      await pumpApp(tester);
      await goHome(tester);

      expect(push.permissionState.value, PushPermission.granted);
    });

    testWidgets('allowed in the OS settings, the app registers on return — '
        'the existing path, once, with no prompt', (tester) async {
      // Android 13+: refused at the one prompt, so never asked again.
      messaging
        ..status = PushPermission.denied
        ..answer = PushPermission.denied;
      memory.wasAsked = true;
      await attach();
      await pumpApp(tester);
      await goHome(tester);
      expect(push.permissionState.value, PushPermission.denied);
      expect(tokens.registered, isEmpty);

      expect(await push.openNotificationSettings(), isTrue);
      messaging.status = PushPermission.granted;
      leaveAndReturn(tester);
      await tester.pumpAndSettle();

      expect(push.permissionState.value, PushPermission.granted);
      expect(tokens.registered, [('fcm-1', PushPlatform.android)]);
      expect(messaging.calls, isNot(contains('requestPermission')));

      leaveAndReturn(tester);
      await tester.pumpAndSettle();
      expect(tokens.registered, hasLength(1));
    });

    testWidgets('every resume re-reads it, signed in or not', (tester) async {
      store.clear();
      messaging.status = PushPermission.denied;
      await attach();
      await push.refreshPermission();
      expect(push.permissionState.value, PushPermission.denied);

      messaging.status = PushPermission.granted;
      leaveAndReturn(tester);
      await tester.pumpAndSettle();

      expect(push.permissionState.value, PushPermission.granted);
      expect(tokens.attempts, 0);
    });

    test('detaching clears the state', () async {
      await attach();
      await push.refreshPermission();
      expect(push.permissionState.value, PushPermission.granted);

      await push.detach();

      expect(push.permissionState.value, isNull);
    });
  });

  group('the push channel\'s blocked state (Issue #433)', () {
    test('push off: not blocked, and the channel is never asked', () async {
      await push.attach(null);

      await push.refreshPermission();

      expect(push.channelBlocked.value, isFalse);
      expect(messaging.calls, isEmpty);
    });

    test('a refresh reads the channel with the permission: granted and '
        'blocked, granted and unblocked, denied', () async {
      await attach();
      for (final (permission, blocked) in const [
        (PushPermission.granted, true),
        (PushPermission.granted, false),
        (PushPermission.denied, false),
        (PushPermission.denied, true),
      ]) {
        messaging
          ..status = permission
          ..channelBlocked = blocked;
        await push.refreshPermission();
        expect(push.permissionState.value, permission);
        expect(push.channelBlocked.value, blocked);
      }
      expect(messaging.calls, isNot(contains('requestPermission')));
    });

    test('a failed channel read counts as not blocked, and the permission is '
        'still read', () async {
      await attach();
      messaging
        ..channelBlocked = true
        ..channelError = StateError('no channel api');

      await push.refreshPermission();

      expect(push.channelBlocked.value, isFalse);
      expect(push.permissionState.value, PushPermission.granted);
    });

    testWidgets('unblocked in the OS settings, it is re-read on return', (
      tester,
    ) async {
      messaging.channelBlocked = true;
      await attach();
      await push.refreshPermission();
      expect(push.channelBlocked.value, isTrue);

      messaging.channelBlocked = false;
      leaveAndReturn(tester);
      await tester.pumpAndSettle();

      expect(push.channelBlocked.value, isFalse);
    });

    test('detaching clears it', () async {
      messaging.channelBlocked = true;
      await attach();
      await push.refreshPermission();
      expect(push.channelBlocked.value, isTrue);

      await push.detach();

      expect(push.channelBlocked.value, isFalse);
    });
  });

  group('the switch never flashes on for a blocked channel (Issue #433)', () {
    /// Every on/off the switch could show, recorded at every single change
    /// of either value — finer than any frame.
    List<bool> recordSwitch() {
      final seen = <bool>[];
      void record() => seen.add(
        push.permissionState.value == PushPermission.granted &&
            !push.channelBlocked.value,
      );
      push.permissionState.addListener(record);
      push.channelBlocked.addListener(record);
      addTearDown(() {
        push.permissionState.removeListener(record);
        push.channelBlocked.removeListener(record);
      });
      return seen;
    }

    testWidgets('cold start through sign-in, granted but blocked: never on, '
        'even while the channel read is still out', (tester) async {
      messaging
        ..status = PushPermission.granted
        ..channelBlocked = true
        ..channelGate = Completer<void>();
      await attach();
      final seen = recordSwitch();
      await pumpApp(tester);
      await goHome(tester);

      // The permission is known; the channel read is held open.
      expect(messaging.calls, contains('notificationChannelBlocked'));
      expect(seen, isNot(contains(true)));

      messaging.channelGate!.complete();
      await tester.pumpAndSettle();

      expect(seen, isNot(contains(true)));
      expect(seen, isNotEmpty);
      expect(push.permissionState.value, PushPermission.granted);
      expect(push.channelBlocked.value, isTrue);
      // A blocked channel does not stop the token being registered.
      expect(tokens.registered, [('fcm-1', PushPlatform.android)]);
    });

    testWidgets('cold start, granted and unblocked: on, once, and registered', (
      tester,
    ) async {
      await attach();
      final seen = recordSwitch();
      await pumpApp(tester);
      await goHome(tester);

      expect(seen, isNotEmpty);
      expect(seen.last, isTrue);
      expect(seen.where((on) => on), hasLength(1));
      expect(tokens.registered, [('fcm-1', PushPlatform.android)]);
    });

    test('a refresh, granted but blocked: never on while the channel read '
        'is still out', () async {
      messaging
        ..status = PushPermission.granted
        ..channelBlocked = true
        ..channelGate = Completer<void>();
      await attach();
      final seen = recordSwitch();

      final refresh = push.refreshPermission();
      await Future<void>.delayed(Duration.zero);
      expect(messaging.calls, contains('notificationChannelBlocked'));
      expect(seen, isEmpty); // nothing published until both are known

      messaging.channelGate!.complete();
      await refresh;

      expect(seen, isNot(contains(true)));
      expect(push.permissionState.value, PushPermission.granted);
      expect(push.channelBlocked.value, isTrue);
    });

    test(
      'blocked to unblocked after returning from Settings: off, then on',
      () async {
        messaging
          ..status = PushPermission.granted
          ..channelBlocked = true;
        await attach();
        await push.refreshPermission();
        final seen = recordSwitch();

        messaging.channelBlocked = false;
        await push.refreshPermission();

        expect(seen, [true]);
      },
    );

    test(
      'granted and unblocked to refused: never on on the way to off',
      () async {
        await attach();
        await push.refreshPermission();
        final seen = recordSwitch();

        messaging
          ..status = PushPermission.denied
          ..channelBlocked = true;
        await push.refreshPermission();

        expect(seen, isNot(contains(true)));
        expect(seen.last, isFalse);
      },
    );

    test(
      'detached while the channel read is out: nothing stale is published',
      () async {
        messaging
          ..status = PushPermission.granted
          ..channelGate = Completer<void>();
        await attach();
        final refresh = push.refreshPermission();
        await Future<void>.delayed(Duration.zero);

        await push.detach();
        final seen = recordSwitch();
        messaging.channelGate!.complete();
        await refresh;

        expect(seen, isEmpty);
        expect(push.permissionState.value, isNull);
        expect(push.channelBlocked.value, isFalse);
      },
    );
  });

  test('notification_id is read from a string or an int; anything else is '
      'none', () {
    expect(
      const PushMessage(data: {'notification_id': '24'}).notificationId,
      24,
    );
    expect(const PushMessage(data: {'notification_id': 24}).notificationId, 24);
    expect(
      const PushMessage(data: {'notification_id': 'x'}).notificationId,
      isNull,
    );
    expect(const PushMessage().notificationId, isNull);
  });
}
