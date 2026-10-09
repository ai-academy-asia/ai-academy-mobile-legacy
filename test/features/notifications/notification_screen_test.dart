import 'dart:async';

import 'package:aia_mobile/core/theme/app_colors.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/auth/presentation/sign_out.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/home/presentation/widgets/home_header.dart';
import 'package:aia_mobile/features/notifications/domain/notification_failure.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_center.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_detail_screen.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_screen.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../auth/fake_auth_repository.dart';
import '../teacher/fake_teacher_schedule_repository.dart';
import '../teacher/teacher_home_screen_test.dart' show tuesday;
import 'fake_notification_repository.dart';

/// The Notification Center screen and its entry points (Issue #246).
void main() {
  setUpAll(loadAppFonts);

  late FakeNotificationRepository repository;
  late NotificationCenter center;

  setUp(() {
    final now = DateTime.now();
    repository = FakeNotificationRepository(
      notifications: [
        sampleNotification(
          id: 3,
          title: 'Unread title',
          body: 'Unread body',
          createdAt: now.subtract(const Duration(days: 1, minutes: 1)),
        ),
        sampleNotification(
          id: 2,
          title: 'Read title',
          body: 'Read body',
          createdAt: now.subtract(const Duration(days: 7, minutes: 1)),
          readAt: now.subtract(const Duration(days: 6)),
        ),
      ],
    );
    center = NotificationCenter(repository: repository);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    useLogicalViewport(tester, const Size(393, 875), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: NotificationScreen(center: center),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder tileOf(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byType(NotificationTile),
  );

  Finder dotIn(Finder tile) => find.descendant(
    of: tile,
    matching: find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).shape == BoxShape.circle,
    ),
  );

  group('states', () {
    testWidgets('a spinner while the first load runs', (tester) async {
      repository.feedGate = Completer<void>();
      useLogicalViewport(tester, const Size(393, 875), padding: iPhonePadding);
      await tester.pumpWidget(
        MaterialApp(home: NotificationScreen(center: center)),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repository.feedGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(NotificationTile), findsNWidgets(2));
    });

    testWidgets('empty says so', (tester) async {
      repository.notifications = [];
      await pumpScreen(tester);

      expect(find.text(NotificationStrings.empty), findsOneWidget);
      expect(find.byType(NotificationTile), findsNothing);
    });

    testWidgets('a failure says why, and retry loads again', (tester) async {
      repository.feedFailure = const NotificationFailure(
        NotificationFailureKind.server,
      );
      await pumpScreen(tester);

      expect(
        find.text(
          NotificationStrings.messageFor(NotificationFailureKind.server),
        ),
        findsOneWidget,
      );

      repository.feedFailure = null;
      await tester.tap(find.text(NotificationStrings.retry));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationTile), findsNWidgets(2));
    });

    testWidgets('pull to refresh asks again', (tester) async {
      await pumpScreen(tester);
      final before = repository.feedCalls;

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(repository.feedCalls, before + 1);
    });
  });

  group('rows', () {
    testWidgets('the header: back button and "Notification"', (tester) async {
      await pumpScreen(tester);

      expect(find.text(NotificationStrings.title), findsOneWidget);
    });

    testWidgets('unread: blue glyph, dark title, grey body, the dot', (
      tester,
    ) async {
      await pumpScreen(tester);
      final tile = tileOf('Unread title');

      expect(
        tester.widget<Text>(find.text('Unread title')).style?.color,
        AppColors.textPrimary,
      );
      expect(
        tester.widget<Text>(find.text('Unread body')).style?.color,
        AppColors.textSecondary,
      );
      final glyph = tester.widget<SvgPicture>(
        find.descendant(of: tile, matching: find.byType(SvgPicture)),
      );
      expect(
        glyph.colorFilter,
        const ColorFilter.mode(Color(0xFF2970FF), BlendMode.srcIn),
      );
      expect(dotIn(tile), findsOneWidget);
      expect(find.descendant(of: tile, matching: find.text('1d')), findsOne);
    });

    testWidgets('read: all grey, no dot, the age still grey', (tester) async {
      await pumpScreen(tester);
      final tile = tileOf('Read title');
      const readInk = Color(0xFFB2B2B2);

      expect(
        tester.widget<Text>(find.text('Read title')).style?.color,
        readInk,
      );
      expect(tester.widget<Text>(find.text('Read body')).style?.color, readInk);
      expect(dotIn(tile), findsNothing);
      expect(
        tester.widget<Text>(find.text('7d')).style?.color,
        AppColors.textSecondary,
      );
    });

    testWidgets('rows are 72 including their rule, in a mixed list', (
      tester,
    ) async {
      await pumpScreen(tester);

      final first = tester.getRect(tileOf('Unread title'));
      final second = tester.getRect(tileOf('Read title'));
      expect(first.height, 72);
      expect(second.top, first.bottom);
      expect(first.top, 44 + 52 + 12);
    });

    testWidgets('long title and body hold one line each, without overflow', (
      tester,
    ) async {
      repository.notifications = [
        sampleNotification(
          id: 9,
          title: 'A very long notification title ' * 6,
          body: 'A very long notification body that keeps going ' * 6,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];
      await pumpScreen(tester);

      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byType(NotificationTile)).height, 72);
      expect(find.text('2h'), findsOneWidget);
    });
  });

  group('reading', () {
    Finder detail() => find.byType(NotificationDetailScreen);

    Future<void> back(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel(CourseLearningStrings.back));
      await tester.pumpAndSettle();
    }

    testWidgets('tapping an unread row opens the detail and marks it read', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(tileOf('Unread title'));
      await tester.pumpAndSettle();

      expect(detail(), findsOneWidget);
      expect(
        find.descendant(
          of: detail(),
          matching: find.text(bindShortLastWords('Unread body')),
        ),
        findsOneWidget,
      );
      expect(repository.markCalls, [3]);
      expect(center.unreadCount, 0);
    });

    testWidgets('tapping a read row opens the detail and sends nothing', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(tileOf('Read title'));
      await tester.pumpAndSettle();

      expect(detail(), findsOneWidget);
      expect(
        find.descendant(
          of: detail(),
          matching: find.text(bindShortLastWords('Read body')),
        ),
        findsOneWidget,
      );
      expect(repository.markCalls, isEmpty);
    });

    testWidgets('the detail opens without waiting for the mark', (
      tester,
    ) async {
      final gate = Completer<void>();
      repository.markGate = gate;
      await pumpScreen(tester);

      await tester.tap(tileOf('Unread title'));
      await tester.pumpAndSettle();

      expect(detail(), findsOneWidget);
      expect(repository.markCalls, [3]);
      expect(center.unreadCount, 0, reason: 'optimistic');

      gate.complete();
      await tester.pumpAndSettle();
      expect(center.unreadCount, 0);
    });

    testWidgets('back returns to the list, the row now read', (tester) async {
      await pumpScreen(tester);

      await tester.tap(tileOf('Unread title'));
      await tester.pumpAndSettle();
      await back(tester);

      expect(detail(), findsNothing);
      expect(find.byType(NotificationScreen), findsOneWidget);
      expect(dotIn(tileOf('Unread title')), findsNothing);

      // Read now: opening it again sends nothing more.
      await tester.tap(tileOf('Unread title'));
      await tester.pumpAndSettle();
      expect(detail(), findsOneWidget);
      expect(repository.markCalls, [3]);
    });

    testWidgets('a failed mark still opens the detail, says why, and rolls '
        'the row back', (tester) async {
      repository.markFailure = const NotificationFailure(
        NotificationFailureKind.network,
      );
      await pumpScreen(tester);

      await tester.tap(tileOf('Unread title'));
      await tester.pumpAndSettle();

      expect(detail(), findsOneWidget);
      expect(
        find.text(
          NotificationStrings.messageFor(NotificationFailureKind.network),
        ),
        findsOneWidget,
      );

      await back(tester);
      expect(dotIn(tileOf('Unread title')), findsOneWidget);
      expect(center.unreadCount, 1);
    });
  });

  group('entry points', () {
    Future<void> pumpHeader(WidgetTester tester) async {
      useLogicalViewport(tester, const Size(393, 875), padding: iPhonePadding);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HomeHeader(notifications: center)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the Home bell shows the unread dot and opens the screen', (
      tester,
    ) async {
      await pumpHeader(tester);

      expect(find.byKey(HomeHeader.unreadBadgeKey), findsOneWidget);

      await tester.tap(
        find.bySemanticsLabel(RegExp(HomeStrings.notifications)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NotificationScreen), findsOneWidget);
    });

    testWidgets('returning to the foreground refreshes the bell (Issue '
        '#291): a notification sent meanwhile shows its dot', (tester) async {
      repository.notifications = [
        sampleNotification(id: 1, readAt: DateTime.utc(2026, 10, 2)),
      ];
      await pumpHeader(tester);
      expect(repository.feedCalls, 1);
      expect(find.byKey(HomeHeader.unreadBadgeKey), findsNothing);

      // Backgrounded; a notification arrives; back to the foreground.
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      expect(repository.feedCalls, 1, reason: 'no request while away');
      repository.notifications = [
        sampleNotification(id: 2),
        ...repository.notifications,
      ];
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();

      expect(repository.feedCalls, 2);
      expect(center.unreadCount, 1);
      expect(find.byKey(HomeHeader.unreadBadgeKey), findsOneWidget);
    });

    testWidgets('a bell that is gone no longer refreshes on resume', (
      tester,
    ) async {
      await pumpHeader(tester);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final before = repository.feedCalls;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repository.feedCalls, before);
    });

    testWidgets('no unread, no dot', (tester) async {
      repository.notifications = [
        sampleNotification(id: 1, readAt: DateTime.utc(2026, 10, 2)),
      ];
      await pumpHeader(tester);

      expect(find.byKey(HomeHeader.unreadBadgeKey), findsNothing);
    });

    testWidgets('reading the last unread clears the bell\'s dot', (
      tester,
    ) async {
      await pumpHeader(tester);
      await tester.tap(
        find.bySemanticsLabel(RegExp(HomeStrings.notifications)),
      );
      await tester.pumpAndSettle();

      await tester.tap(tileOf('Unread title'));
      await tester.pumpAndSettle();
      // Back from the detail, then from the list.
      final navigator = Navigator.of(
        tester.element(find.byType(NotificationDetailScreen)),
      );
      navigator.pop();
      await tester.pumpAndSettle();
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.byType(HomeHeader), findsOneWidget);
      expect(find.byKey(HomeHeader.unreadBadgeKey), findsNothing);
    });

    testWidgets('the Teacher Schedule bell opens the same screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: TeacherScheduleScreen(
            repository: FakeTeacherScheduleRepository(),
            clock: tuesday,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsLabel(TeacherScheduleStrings.notifications),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NotificationScreen), findsOneWidget);
    });
  });

  testWidgets('signing out resets the shared notification state', (
    tester,
  ) async {
    final shared = NotificationCenter.instance;
    await shared.loadIfNeeded();
    expect(shared.hasLoadedOnce, isTrue);

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        routes: {
          '/': (_) => const Text('home'),
          loginRoute: (_) => const Text('login'),
        },
      ),
    );
    await signOutToLogin(
      navigatorKey.currentState!,
      repository: FakeAuthRepository(),
      sessionStore: AuthSessionStore()
        ..save(const AuthSession(accessToken: 'a', refreshToken: 'r')),
    );
    await tester.pumpAndSettle();

    expect(shared.hasLoadedOnce, isFalse);
    expect(shared.notifications, isEmpty);
    expect(shared.unreadCount, 0);
  });
}
