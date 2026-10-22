import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/l10n.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/auth/presentation/home_route.dart';
import 'package:aia_mobile/features/auth/domain/current_user_failure.dart';
import 'package:aia_mobile/features/auth/presentation/login_screen.dart';
import 'package:aia_mobile/features/certificates/domain/certificate_entry.dart';
import 'package:aia_mobile/features/certificates/domain/certificate_list_repository.dart';
import 'package:aia_mobile/features/certificates/presentation/certificate_screen.dart';
import 'package:aia_mobile/features/certificates/presentation/certificate_strings.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_screen.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_strings.dart';
import 'package:aia_mobile/features/enrollments/domain/enrolled_cohorts_repository.dart';
import 'package:aia_mobile/features/notifications/domain/notification_failure.dart';
import 'package:aia_mobile/features/notifications/domain/push_token_repository.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_center.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_detail_screen.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_screen.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_strings.dart';
import 'package:aia_mobile/features/notifications/push/push_messaging.dart';
import 'package:aia_mobile/features/notifications/push/push_notifications.dart';
import 'package:aia_mobile/features/splash/presentation/splash_screen.dart';
import 'package:aia_mobile/features/splash/presentation/splash_strings.dart';
import 'package:aia_mobile/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/cohorts/fake_cohort_repository.dart';
import '../../features/courses/fake_course_repository.dart';
import '../../features/enrollments/fake_enrolled_cohorts_repository.dart';
import '../../features/enrollments/fake_enrollment_repository.dart';
import '../../features/notifications/fake_notification_repository.dart';
import '../../features/notifications/fake_push.dart';
import '../../features/profile/fake_current_user_repository.dart';
import '../../features/teacher/fake_schedule_change_repository.dart';
import '../../support/screenshot.dart';

/// Issue #523: the Notification Center, the push fallback, the Хичээл tab's
/// empty state and Splash's network error in the selected language.
/// Mongolian reads exactly as before; a push's own title and body are the
/// server's and are never translated.
void main() {
  setUpAll(loadAppFonts);
  final locale = AppLocaleController.instance;
  tearDown(() => locale.setPreference(LocalePreference.mongolian));

  const copy = <String, ({String mongolian, String english})>{
    'notificationEmpty': (
      mongolian: 'Одоогоор мэдэгдэл алга байна',
      english: 'No notifications yet',
    ),
    'notificationNotFound': (
      mongolian: 'Мэдэгдэл олдсонгүй',
      english: 'Notification not found',
    ),
    'notificationPushReceived': (
      mongolian: 'Шинэ мэдэгдэл ирлээ',
      english: 'You have a new notification',
    ),
    'notificationPushOpen': (mongolian: 'Харах', english: 'View'),
    'cohortEmptyMine': (
      mongolian: 'Та одоогоор ямар ч ангид бүртгүүлээгүй байна',
      english: 'You are not enrolled in any class yet',
    ),
    'splashNetworkError': (
      mongolian: 'Интернэт холболтоо шалгаад дахин оролдоно уу.',
      english: 'Check your internet connection and try again.',
    ),
    'commonRetry': (mongolian: 'Дахин оролдох', english: 'Try again.'),
  };

  String text(String key, LocalePreference language) =>
      language == LocalePreference.mongolian
      ? copy[key]!.mongolian
      : copy[key]!.english;

  String en(String key) => text(key, LocalePreference.english);
  String mn(String key) => text(key, LocalePreference.mongolian);

  group('the keys', () {
    for (final language in LocalePreference.values) {
      test(language.name, () {
        final s = L10n.of(language);
        expect(
          {
            'notificationEmpty': s.notificationEmpty,
            'notificationNotFound': s.notificationNotFound,
            'notificationPushReceived': s.notificationPushReceived,
            'notificationPushOpen': s.notificationPushOpen,
            'cohortEmptyMine': s.cohortEmptyMine,
            'splashNetworkError': s.splashNetworkError,
            'commonRetry': s.commonRetry,
          },
          {for (final key in copy.keys) key: text(key, language)},
        );
      });
    }

    // Its own key, not Home's: the Mongolian differs by a word ("ямар ч" /
    // "ямар нэг"); the approved English happens to be the same sentence.
    test('the Хичээл empty line is its own key, not Home\'s', () {
      final mongolian = L10n.of(LocalePreference.mongolian);
      expect(mongolian.cohortEmptyMine, isNot(mongolian.homeEmpty));
      expect(
        L10n.of(LocalePreference.english).homeEmpty,
        en('cohortEmptyMine'),
      );
    });

    for (final language in LocalePreference.values) {
      test('the strings classes in ${language.name}', () async {
        await locale.setPreference(language);
        expect(NotificationStrings.empty, text('notificationEmpty', language));
        expect(
          NotificationStrings.notFound,
          text('notificationNotFound', language),
        );
        expect(
          NotificationStrings.messageFor(NotificationFailureKind.notFound),
          text('notificationNotFound', language),
        );
        expect(
          NotificationStrings.pushReceived,
          text('notificationPushReceived', language),
        );
        expect(
          NotificationStrings.pushOpen,
          text('notificationPushOpen', language),
        );
        expect(NotificationStrings.retry, text('commonRetry', language));
        expect(CohortListStrings.emptyMine, text('cohortEmptyMine', language));
        // The Certificate screen's empty line is the same words.
        expect(CertificateStrings.empty, text('cohortEmptyMine', language));
        expect(
          SplashStrings.networkError,
          text('splashNetworkError', language),
        );
        expect(SplashStrings.retry, text('commonRetry', language));
      });
    }
  });

  // --- Notification Center --------------------------------------------------

  late FakeNotificationRepository notifications;
  late NotificationCenter center;

  setUp(() {
    notifications = FakeNotificationRepository(
      notifications: [sampleNotification(id: 24, title: 'Шинэ даалгавар')],
    );
    center = NotificationCenter(repository: notifications);
  });

  Future<void> pumpNotifications(
    WidgetTester tester, {
    Size size = const Size(393, 875),
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      L10nRebuildScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: NotificationScreen(
            center: center,
            scheduleChangeRepository: FakeScheduleChangeRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Notification Center in English', () {
    setUp(() => locale.setEnglish(true));

    testWidgets('empty says so in English', (tester) async {
      notifications.notifications = [];
      await pumpNotifications(tester);

      expect(find.text(en('notificationEmpty')), findsOneWidget);
      expect(find.text(mn('notificationEmpty')), findsNothing);
    });

    testWidgets('a feed 404 reads "Notification not found" with Try again., '
        'which loads again', (tester) async {
      notifications.feedFailure = const NotificationFailure(
        NotificationFailureKind.notFound,
      );
      await pumpNotifications(tester);

      expect(find.text(en('notificationNotFound')), findsOneWidget);
      expect(find.text(mn('notificationNotFound')), findsNothing);
      final retry = find.widgetWithText(TextButton, en('commonRetry'));
      expect(retry, findsOneWidget);
      expect(find.text(mn('commonRetry')), findsNothing);

      final calls = notifications.feedCalls;
      notifications.feedFailure = null;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(notifications.feedCalls, calls + 1);
      expect(find.text('Шинэ даалгавар'), findsOneWidget);
      expect(find.text(en('notificationNotFound')), findsNothing);
    });

    testWidgets('a notification gone when marked read: the SnackBar says '
        '"Notification not found"', (tester) async {
      await pumpNotifications(tester);
      notifications.markFailure = const NotificationFailure(
        NotificationFailureKind.notFound,
      );

      await tester.tap(find.text('Шинэ даалгавар'));
      await tester.pumpAndSettle();

      expect(notifications.markCalls, [24]);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(en('notificationNotFound')),
        ),
        findsOneWidget,
      );
      expect(find.text(mn('notificationNotFound')), findsNothing);
    });
  });

  testWidgets('switching language on the empty Notification screen: the line '
      'changes, the screen stays and nothing is fetched again', (tester) async {
    notifications.notifications = [];
    await pumpNotifications(tester);
    expect(find.text(mn('notificationEmpty')), findsOneWidget);
    final state = tester.state(find.byType(NotificationScreen));
    final calls = notifications.feedCalls;

    await locale.setEnglish(true);
    await tester.pump();

    expect(find.text(en('notificationEmpty')), findsOneWidget);
    expect(find.text(mn('notificationEmpty')), findsNothing);
    expect(tester.state(find.byType(NotificationScreen)), same(state));
    expect(notifications.feedCalls, calls);

    await locale.setPreference(LocalePreference.mongolian);
    await tester.pump();
    expect(find.text(mn('notificationEmpty')), findsOneWidget);
  });

  // --- Push fallback --------------------------------------------------------

  group('a foreground push in English', () {
    late FakePushMessaging messaging;
    late PushNotifications push;
    late GlobalKey<NavigatorState> navigatorKey;
    late GlobalKey<ScaffoldMessengerState> messengerKey;

    setUp(() async {
      await locale.setEnglish(true);
      messaging = FakePushMessaging();
      navigatorKey = GlobalKey<NavigatorState>();
      messengerKey = GlobalKey<ScaffoldMessengerState>();
      push = PushNotifications(
        tokens: FakePushTokens(),
        sessionStore: AuthSessionStore()
          ..save(const AuthSession(accessToken: 'tok-a', refreshToken: 'r')),
        permissionMemory: FakePermissionMemory(),
        center: center,
        platform: PushPlatform.android,
        removalTimeout: const Duration(milliseconds: 200),
      );
    });

    tearDown(() async {
      await push.detach();
      await messaging.close();
    });

    Future<void> pumpHome(
      WidgetTester tester, {
      Size size = const Size(393, 852),
    }) async {
      useLogicalViewport(tester, size, padding: iPhonePadding);
      await push.attach(
        messaging,
        navigatorKey: navigatorKey,
        messengerKey: messengerKey,
      );
      await tester.pumpWidget(
        L10nRebuildScope(
          child: MaterialApp(
            theme: AppTheme.light,
            navigatorKey: navigatorKey,
            scaffoldMessengerKey: messengerKey,
            navigatorObservers: [push.routeObserver],
            routes: {
              '/': (_) => const Scaffold(body: Text('splash')),
              HomeRoutes.adult: (_) => const Scaffold(body: Text('home')),
            },
          ),
        ),
      );
      navigatorKey.currentState!.pushReplacementNamed(HomeRoutes.adult);
      await tester.pumpAndSettle();
    }

    final snackBar = find.byType(SnackBar);
    Finder inSnackBar(String label) =>
        find.descendant(of: snackBar, matching: find.text(label));

    testWidgets('with no text: "You have a new notification", and View still '
        'opens the notification', (tester) async {
      await pumpHome(tester);

      messaging.receive(
        const PushMessage(
          data: {'kind': 'assignment', 'notification_id': '24'},
        ),
      );
      await tester.pumpAndSettle();

      expect(inSnackBar(en('notificationPushReceived')), findsOneWidget);
      expect(inSnackBar(en('notificationPushOpen')), findsOneWidget);
      expect(find.text(mn('notificationPushReceived')), findsNothing);
      expect(find.text(mn('notificationPushOpen')), findsNothing);

      await tester.tap(inSnackBar(en('notificationPushOpen')));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationDetailScreen), findsOneWidget);
    });

    testWidgets('the payload\'s own title is shown as sent, untranslated', (
      tester,
    ) async {
      await pumpHome(tester);

      messaging.receive(
        const PushMessage(
          title: 'Шинэ даалгавар',
          body: 'Даалгаврын тайлбар',
          data: {'notification_id': '24'},
        ),
      );
      await tester.pumpAndSettle();

      expect(inSnackBar('Шинэ даалгавар'), findsOneWidget);
      expect(inSnackBar(en('notificationPushReceived')), findsNothing);
      expect(inSnackBar(en('notificationPushOpen')), findsOneWidget);
    });

    testWidgets('English at 2.0× text on a 320 pt phone: the SnackBar has no '
        'overflow, every line inside the screen, nothing cut short that '
        'Mongolian is not', (tester) async {
      Future<Set<String>> cutShort(LocalePreference language) async {
        await locale.setPreference(language);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(const SizedBox());
        await pumpHome(tester, size: const Size(320, 568));
        messaging.receive(const PushMessage(data: {'notification_id': '24'}));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final cut = <String>{};
        for (final key in [
          'notificationPushReceived',
          'notificationPushOpen',
        ]) {
          cut.addAll(
            _measure(tester, inSnackBar(text(key, language)), key, 320, 568),
          );
        }
        messengerKey.currentState!.removeCurrentSnackBar();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        return cut;
      }

      final mongolian = await cutShort(LocalePreference.mongolian);
      final english = await cutShort(LocalePreference.english);
      expect(english.difference(mongolian), isEmpty);
    });
  });

  // --- The Хичээл tab and Certificates -------------------------------------

  Future<void> pumpCourses(
    WidgetTester tester, {
    FakeCohortRepository? repository,
    Size size = const Size(393, 852),
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      L10nRebuildScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: CohortListScreen(
            repository:
                repository ??
                FakeCohortRepository(
                  cohorts: [sampleCohort(id: 1, name: 'Cohort 01')],
                ),
            courseRepository: FakeCourseRepository(),
            enrollmentRepository: FakeEnrollmentRepository(),
            enrolledCohortsRepository: FakeEnrolledCohortsRepository(
              enrolledCohorts: const <EnrolledCohortSummary>[],
            ),
            enrolledOnly: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the Adult Courses tab, enrolled in nothing, says so in English',
    (tester) async {
      await locale.setEnglish(true);
      await pumpCourses(tester);

      expect(find.text(en('cohortEmptyMine')), findsOneWidget);
      expect(find.text(mn('cohortEmptyMine')), findsNothing);
    },
  );

  testWidgets('switching language on the empty Courses tab: the line changes, '
      'the screen stays and nothing is fetched again', (tester) async {
    final repository = FakeCohortRepository(
      cohorts: [sampleCohort(id: 1, name: 'Cohort 01')],
    );
    await pumpCourses(tester, repository: repository);
    expect(find.text(mn('cohortEmptyMine')), findsOneWidget);
    final state = tester.state(find.byType(CohortListScreen));
    final calls = repository.callCount;

    await locale.setEnglish(true);
    await tester.pump();

    expect(find.text(en('cohortEmptyMine')), findsOneWidget);
    expect(find.text(mn('cohortEmptyMine')), findsNothing);
    expect(tester.state(find.byType(CohortListScreen)), same(state));
    expect(repository.callCount, calls);
  });

  testWidgets('the Certificate screen, with nothing to show, reads the same '
      'line in English', (tester) async {
    await locale.setEnglish(true);
    useLogicalViewport(tester, const Size(393, 960), padding: iPhonePadding);
    await tester.pumpWidget(
      L10nRebuildScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: CertificateScreen(repository: _NoCertificates()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(en('cohortEmptyMine')), findsOneWidget);
    expect(find.text(mn('cohortEmptyMine')), findsNothing);
  });

  // --- Splash -----------------------------------------------------------------

  Future<void> pumpSplashOffline(
    WidgetTester tester, {
    Size size = const Size(393, 852),
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      L10nRebuildScope(
        child: MaterialApp(
          theme: AppTheme.light,
          routes: {
            '/': (_) => SplashScreen(
              sessionStore: AuthSessionStore()
                ..save(const AuthSession(accessToken: 'tok')),
              currentUserRepository: FakeCurrentUserRepository(
                failure: const CurrentUserFailure(
                  CurrentUserFailureKind.network,
                ),
              ),
            ),
            SplashScreen.nextRoute: (_) => const LoginScreen(),
          },
        ),
      ),
    );
    await tester.pump(Duration.zero);
    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();
  }

  testWidgets('Splash offline, in English: the network line and Try again.; '
      'Login never opens', (tester) async {
    await locale.setEnglish(true);
    await pumpSplashOffline(tester);

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text(en('splashNetworkError')), findsOneWidget);
    expect(find.text(mn('splashNetworkError')), findsNothing);
    expect(find.widgetWithText(AppButton, en('commonRetry')), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  // --- Large text -------------------------------------------------------------

  /// Each screen at 2.0× text on a 320 pt phone, with the keys it shows.
  final screens =
      <
        ({
          String name,
          List<String> keys,
          Future<void> Function(WidgetTester) pump,
        })
      >[
        (
          name: 'empty Notification screen',
          keys: ['notificationEmpty'],
          pump: (tester) async {
            notifications.notifications = [];
            await pumpNotifications(tester, size: const Size(320, 568));
          },
        ),
        (
          name: 'Notification screen, feed 404',
          keys: ['notificationNotFound', 'commonRetry'],
          pump: (tester) async {
            notifications.feedFailure = const NotificationFailure(
              NotificationFailureKind.notFound,
            );
            await pumpNotifications(tester, size: const Size(320, 568));
          },
        ),
        (
          name: 'empty Courses tab',
          keys: ['cohortEmptyMine'],
          pump: (tester) => pumpCourses(tester, size: const Size(320, 568)),
        ),
        (
          name: 'Splash offline',
          keys: ['splashNetworkError', 'commonRetry'],
          pump: (tester) =>
              pumpSplashOffline(tester, size: const Size(320, 568)),
        ),
      ];

  for (final screen in screens) {
    testWidgets('${screen.name}: English at 2.0× text on a 320 pt phone has '
        'no overflow, every line inside the screen, nothing cut short that '
        'Mongolian is not', (tester) async {
      Future<Set<String>> cutShort(LocalePreference language) async {
        await locale.setPreference(language);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await screen.pump(tester);
        expect(tester.takeException(), isNull);

        final cut = <String>{};
        for (final key in screen.keys) {
          cut.addAll(
            _measure(tester, find.text(text(key, language)), key, 320, 568),
          );
        }
        expect(tester.takeException(), isNull);
        return cut;
      }

      final mongolian = await cutShort(LocalePreference.mongolian);
      final english = await cutShort(LocalePreference.english);
      expect(english.difference(mongolian), isEmpty);
    });
  }
}

/// [label] is drawn once, wholly inside a [width]×[height] screen; returns
/// `{key}` when its paragraph was cut short.
Set<String> _measure(
  WidgetTester tester,
  Finder label,
  String key,
  double width,
  double height,
) {
  expect(label, findsOneWidget, reason: key);
  final rect = tester.getRect(label);
  expect(rect.left, greaterThanOrEqualTo(0), reason: key);
  expect(rect.right, lessThanOrEqualTo(width), reason: key);
  expect(rect.top, greaterThanOrEqualTo(0), reason: key);
  expect(rect.bottom, lessThanOrEqualTo(height), reason: key);
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: label, matching: find.byType(RichText)).first,
  );
  return {if (paragraph.didExceedMaxLines) key};
}

/// No certificates: the screen's empty state.
class _NoCertificates implements CertificateListRepository {
  @override
  Future<List<CertificateEntry>> getCertificates() async => const [];
}
