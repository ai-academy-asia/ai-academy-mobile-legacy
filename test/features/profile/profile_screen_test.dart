import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:aia_mobile/core/theme/app_theme_controller.dart';
import 'package:aia_mobile/core/theme/theme_preference.dart';
import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/data/http_current_user_repository.dart';
import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/auth/domain/current_user_failure.dart';
import 'package:aia_mobile/features/auth/presentation/reset_password_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_learning_back_button.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/profile/presentation/profile_screen.dart';
import 'package:aia_mobile/features/profile/presentation/profile_strings.dart';
import 'package:aia_mobile/features/profile/presentation/widgets/profile_parts.dart';
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_current_user_repository.dart';

/// Loads the real Manrope face, the same reason the other screen tests do —
/// without it, text is measured in the fallback font.
Future<void> _loadFonts() async {
  final loader = FontLoader('Manrope')
    ..addFont(rootBundle.load('assets/fonts/Manrope-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Manrope-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Manrope-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Manrope-Bold.ttf'));
  await loader.load();
}

/// The design uses "Notification" for both a section caption and a row, so
/// `find.text` alone is ambiguous. These match on the style each role uses —
/// the public style with its role's colour applied (Issue #274).
Finder sectionCaption(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.data == label &&
      widget.style ==
          captionStyle.copyWith(color: AppPalette.light.textSecondary),
);

Finder rowLabel(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.data == label &&
      widget.style ==
          rowLabelStyle.copyWith(color: AppPalette.light.textPrimary),
);

void main() {
  setUpAll(_loadFonts);

  Future<void> pumpProfile(
    WidgetTester tester, {
    Size size = const Size(393, 852),
    FakeCurrentUserRepository? repository,
    ThemeData? theme,
    AppThemeController? themeController,
  }) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = size * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        home: ProfileScreen(
          repository:
              repository ??
              FakeCurrentUserRepository(
                failure: const CurrentUserFailure(
                  CurrentUserFailureKind.sessionExpired,
                ),
              ),
          themeController: themeController,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('layout', () {
    testWidgets('shows the heading and every section caption', (tester) async {
      await pumpProfile(tester);

      expect(find.text(ProfileStrings.heading), findsOneWidget);
      expect(sectionCaption(ProfileStrings.accountSection), findsOneWidget);
      expect(sectionCaption(ProfileStrings.appSettingsSection), findsOneWidget);
      expect(
        sectionCaption(ProfileStrings.notificationSection),
        findsOneWidget,
      );
      expect(sectionCaption(ProfileStrings.contactSection), findsOneWidget);
    });

    testWidgets('shows no placeholder person and no invented account data when '
        '/auth/me fails (Issue #223)', (tester) async {
      await pumpProfile(tester);

      for (final invented in _inventedValues) {
        expect(find.text(invented), findsNothing, reason: invented);
      }
    });

    testWidgets('shows every settings row', (tester) async {
      await pumpProfile(tester);

      for (final label in [
        ProfileStrings.eContract,
        ProfileStrings.certificate,
        ProfileStrings.transactionHistory,
        ProfileStrings.language,
        ProfileStrings.lightMode,
        ProfileStrings.changePassword,
        ProfileStrings.notification,
      ]) {
        expect(rowLabel(label), findsOneWidget, reason: 'missing row: $label');
      }

      // The contact group sits below the fold on a phone viewport.
      await tester.dragUntilVisible(
        rowLabel(ProfileStrings.privacyPolicy),
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(rowLabel(ProfileStrings.helpCenter), findsOneWidget);
      expect(rowLabel(ProfileStrings.termsOfService), findsOneWidget);
      expect(rowLabel(ProfileStrings.privacyPolicy), findsOneWidget);
    });

    testWidgets('the E-Contract row shows no invented status or count — no '
        'endpoint reports either (Issue #223)', (tester) async {
      await pumpProfile(tester);

      expect(rowLabel(ProfileStrings.eContract), findsOneWidget);
      expect(find.text('Гэрээ байгуулаагүй байна'), findsNothing);
      expect(find.text('1/2'), findsNothing);
    });

    testWidgets('shows the log out button below the rows, and no invented '
        'version line (Issue #223)', (tester) async {
      await pumpProfile(tester);

      await tester.dragUntilVisible(
        find.text(ProfileStrings.logOut),
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(find.text(ProfileStrings.logOut), findsOneWidget);
      expect(find.textContaining('Version'), findsNothing);
    });

    testWidgets('stays within a phone-width column on a desktop window', (
      tester,
    ) async {
      await pumpProfile(tester, size: const Size(1200, 900));

      final heading = tester.getRect(find.text(ProfileStrings.heading));
      expect(heading.width, lessThanOrEqualTo(480));
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow on a short viewport', (tester) async {
      await pumpProfile(tester, size: const Size(393, 420));

      expect(tester.takeException(), isNull);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('/auth/me header', () {
    testWidgets('shows no placeholder name while the fetch is in flight — the '
        'name line stays empty (Issue #223)', (tester) async {
      final repository = FakeCurrentUserRepository(hold: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ProfileScreen(repository: repository),
        ),
      );
      await tester.pump();

      expect(find.text('Болд Батаа'), findsNothing);
      expect(find.text('CRUD TestStudent'), findsNothing);

      repository.release();
      await tester.pumpAndSettle();
      expect(find.text('CRUD TestStudent'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('shows the fetched full name once /auth/me succeeds', (
      tester,
    ) async {
      await pumpProfile(tester, repository: FakeCurrentUserRepository());

      expect(find.text('CRUD TestStudent'), findsOneWidget);
      // The join date has no confirmed source, so none is drawn.
      for (final invented in _inventedValues) {
        expect(find.text(invented), findsNothing, reason: invented);
      }
    });

    testWidgets('shows the real name when /auth/me has a null ui_mode', (
      tester,
    ) async {
      // Issue #168: the production response for the adult `corp.s01` account,
      // through the real parser. It used to fail as a whole over `ui_mode`,
      // leaving the placeholder name up.
      final client = MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'actor_id': 25,
              'actor_type': 'student',
              'email': 'corp.s01@test.ai-academy.asia',
              'id': 25,
              'is_active': true,
              'must_change_password': false,
              'profile': {
                'first_name': 'Ганбат',
                'id': 25,
                'last_name': 'Должин',
                'phone': '99000000',
                'ui_mode': null,
              },
              'role': 'student',
              'user_type': 'adult',
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      final store = AuthSessionStore()
        ..save(const AuthSession(accessToken: 'token'));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ProfileScreen(
            repository: HttpCurrentUserRepository(
              client: client,
              sessionStore: store,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ганбат Должин'), findsOneWidget);
      expect(find.text('Болд Батаа'), findsNothing);
    });
  });

  group('scrolling', () {
    testWidgets('one fling reaches the end of the content', (tester) async {
      await pumpProfile(tester);

      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      expect(position.maxScrollExtent, greaterThan(0));

      await tester.fling(
        find.byType(SingleChildScrollView),
        const Offset(0, -1200),
        2000,
      );
      await tester.pumpAndSettle();

      // A lazily-built list only estimates its extent, so a single fling used
      // to stop short of the end. Laid out in full, it goes all the way.
      expect(position.pixels, position.maxScrollExtent);
      expect(rowLabel(ProfileStrings.helpCenter), findsOneWidget);
      expect(find.text(ProfileStrings.logOut), findsOneWidget);
    });

    testWidgets('the bottom navigation stays fixed while the content scrolls', (
      tester,
    ) async {
      await pumpProfile(tester);
      final before = tester.getRect(find.byType(AppBottomNav));

      await tester.fling(
        find.byType(SingleChildScrollView),
        const Offset(0, -1200),
        2000,
      );
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byType(AppBottomNav)), before);
    });
  });

  group('rows', () {
    testWidgets('every row draws its exported SVG, not a stock icon', (
      tester,
    ) async {
      await pumpProfile(tester);
      await tester.fling(
        find.byType(SingleChildScrollView),
        const Offset(0, -1200),
        2000,
      );
      await tester.pumpAndSettle();

      final assets = tester
          .widgetList<SvgPicture>(find.byType(SvgPicture))
          .map((svg) => (svg.bytesLoader as SvgAssetLoader).assetName)
          .toSet();

      expect(
        assets,
        containsAll(<String>{
          ProfileIcons.edit,
          ProfileIcons.eContract,
          ProfileIcons.certificate,
          ProfileIcons.transactionHistory,
          ProfileIcons.language,
          ProfileIcons.lightMode,
          ProfileIcons.changePassword,
          ProfileIcons.notification,
          ProfileIcons.helpCenter,
          ProfileIcons.termsOfService,
          ProfileIcons.privacyPolicy,
        }),
      );
    });

    testWidgets('draws no chevrons — the reference has none', (tester) async {
      await pumpProfile(tester);

      expect(find.byIcon(AppIcons.caretRight), findsNothing);

      await tester.fling(
        find.byType(SingleChildScrollView),
        const Offset(0, -1200),
        2000,
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(AppIcons.caretRight), findsNothing);
    });
  });

  group('language toggle', () {
    testWidgets('starts on MN and switches to EN when tapped', (tester) async {
      await pumpProfile(tester);

      final mn = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.text(ProfileStrings.languageMn),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(mn.properties.selected, isTrue);

      await tester.tap(find.text(ProfileStrings.languageEn));
      await tester.pumpAndSettle();

      final en = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.text(ProfileStrings.languageEn),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(en.properties.selected, isTrue);
    });
  });

  group('toggles', () {
    // Each switch carries its row's label; `.last` is the switch, not the
    // row's own text.
    bool toggled(WidgetTester tester, String label) =>
        tester
            .getSemantics(find.bySemanticsLabel(label).last)
            .flagsCollection
            .isToggled ==
        Tristate.isTrue;

    testWidgets('the notification switch starts off and flips on tap', (
      tester,
    ) async {
      await pumpProfile(tester);

      expect(toggled(tester, ProfileStrings.notification), isFalse);
      await tester.tap(find.bySemanticsLabel(ProfileStrings.notification).last);
      await tester.pumpAndSettle();
      expect(toggled(tester, ProfileStrings.notification), isTrue);
    });

    group('light mode (Issue #252)', () {
      testWidgets('reads on in the light app — the theme it is really in', (
        tester,
      ) async {
        await pumpProfile(tester);

        expect(toggled(tester, ProfileStrings.lightMode), isTrue);
      });

      Finder lightSwitch() => find.byWidgetPredicate(
        (w) =>
            w is ProfileSwitch && w.semanticLabel == ProfileStrings.lightMode,
      );

      testWidgets('Light → Dark → Light on tap (Issue #282): the one '
          'preference changes at once and is saved each time', (tester) async {
        final storage = _MemoryThemeStorage(null);
        final controller = AppThemeController();
        await controller.restore(storage);
        await pumpProfile(tester, themeController: controller);

        expect(
          tester.widget<ProfileSwitch>(lightSwitch()).onChanged,
          isNotNull,
        );

        await tester.tap(lightSwitch());
        await tester.pumpAndSettle();
        expect(toggled(tester, ProfileStrings.lightMode), isFalse);
        expect(controller.preference, ThemePreference.dark);
        expect(controller.mode, ThemeMode.dark);
        expect(storage.writes, ['dark']);

        await tester.tap(lightSwitch());
        await tester.pumpAndSettle();
        expect(toggled(tester, ProfileStrings.lightMode), isTrue);
        expect(controller.preference, ThemePreference.light);
        expect(controller.mode, ThemeMode.light);
        expect(storage.writes, ['dark', 'light']);
      });

      testWidgets('shows the one saved preference (Issue #278): a stored '
          'Dark reads off, a stored Light on', (tester) async {
        for (final (stored, on) in [('dark', false), ('light', true)]) {
          final controller = AppThemeController();
          await controller.restore(_MemoryThemeStorage(stored));
          await pumpProfile(tester, themeController: controller);
          expect(toggled(tester, ProfileStrings.lightMode), on, reason: stored);
        }
      });
    });
  });

  group('change password', () {
    testWidgets('tapping the row pushes the existing change-password screen', (
      tester,
    ) async {
      await pumpProfile(tester);

      await tester.tap(rowLabel(ProfileStrings.changePassword));
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordScreen), findsOneWidget);
    });

    testWidgets('the pushed screen shows a back control that returns to '
        'Profile (Issue #227)', (tester) async {
      await pumpProfile(tester);

      await tester.tap(rowLabel(ProfileStrings.changePassword));
      await tester.pumpAndSettle();
      expect(find.byType(CourseLearningBackButton), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(CourseLearningStrings.back));
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordScreen), findsNothing);
      expect(find.text(ProfileStrings.heading), findsOneWidget);
    });

    testWidgets(
      'a successful change pops back to Profile, not to whatever pushed it',
      (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigatorKey,
            theme: AppTheme.light,
            home: const Scaffold(body: Text('previous screen')),
          ),
        );
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => ProfileScreen(
              repository: FakeCurrentUserRepository(
                failure: const CurrentUserFailure(
                  CurrentUserFailureKind.sessionExpired,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The test window is 800 x 600; the row sits below its fold, as it
        // does on a short phone, so scroll it into view first.
        await tester.ensureVisible(rowLabel(ProfileStrings.changePassword));
        await tester.pumpAndSettle();
        await tester.tap(rowLabel(ProfileStrings.changePassword));
        await tester.pumpAndSettle();
        expect(find.byType(ResetPasswordScreen), findsOneWidget);

        // `ResetPasswordScreen`'s own suite covers a real submission; here it
        // only matters that popping this route (as its default `onCompleted`
        // does on success) lands back on Profile, not on "previous screen" —
        // proving Change Password was pushed, not used to replace the route.
        navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();

        expect(find.text(ProfileStrings.heading), findsOneWidget);
        expect(find.text('previous screen'), findsNothing);
      },
    );
  });

  group('bottom navigation', () {
    testWidgets('marks the profile tab as the current one', (tester) async {
      await pumpProfile(tester);

      final nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
      expect(nav.currentIndex, 2);
      expect(nav.items.map((item) => item.label), [
        HomeStrings.navHome,
        HomeStrings.navCourses,
        HomeStrings.navProfile,
      ]);

      // The shared adult bar, unmodified — the geometry is the same on every
      // adult tab screen (Issue #188).
      const shared = AppBottomNav(items: [], currentIndex: 0);
      expect(nav.iconSize, shared.iconSize);
      expect(nav.labelSize, shared.labelSize);
      expect(nav.horizontalPadding, shared.horizontalPadding);
      expect(nav.selectedColor, shared.selectedColor);
    });

    testWidgets('the courses tab opens the student\'s cohorts in its place', (
      tester,
    ) async {
      // Profile opened straight from Home: a pop would land back on Home,
      // which is not the tab that was tapped.
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          theme: AppTheme.light,
          initialRoute: '/home',
          routes: {
            '/home': (_) => const Scaffold(body: Text('home route')),
            '/my-cohorts': (_) => const Scaffold(body: Text('my cohorts')),
          },
        ),
      );

      navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text(ProfileStrings.heading), findsOneWidget);

      await tester.tap(find.byIcon(AppIcons.bookOpenText));
      await tester.pumpAndSettle();

      expect(find.text('my cohorts'), findsOneWidget);
      expect(find.text(ProfileStrings.heading), findsNothing);

      // Replaced, not stacked: one pop is Home.
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('home route'), findsOneWidget);
    });

    testWidgets('the home tab returns to the Home route', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          theme: AppTheme.light,
          initialRoute: '/home',
          routes: {'/home': (_) => const Scaffold(body: Text('home route'))},
        ),
      );

      navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text(ProfileStrings.heading), findsOneWidget);

      await tester.tap(find.byIcon(AppIcons.house));
      await tester.pumpAndSettle();

      expect(find.text('home route'), findsOneWidget);
      expect(find.text(ProfileStrings.heading), findsNothing);
    });

    testWidgets('the home tab returns to Home even from several screens deep', (
      tester,
    ) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          theme: AppTheme.light,
          initialRoute: '/home',
          routes: {'/home': (_) => const Scaffold(body: Text('home route'))},
        ),
      );

      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('intermediate screen')),
        ),
      );
      await tester.pumpAndSettle();

      navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(AppIcons.house));
      await tester.pumpAndSettle();

      expect(find.text('home route'), findsOneWidget);
      expect(find.text('intermediate screen'), findsNothing);
      expect(find.text(ProfileStrings.heading), findsNothing);
    });
  });
}

/// The design's placeholder account data that must never reach a student
/// (Issue #223): another person's name, a join date, a contract status and
/// count, and a version, none of which any confirmed response carries.
const List<String> _inventedValues = [
  'Болд Батаа',
  'Joined Oct 2026',
  'Гэрээ байгуулаагүй байна',
  '1/2',
  'Version 1.2.4 (2025)',
];

/// A [ThemePreferencePersistence] in memory, recording what is written.
class _MemoryThemeStorage implements ThemePreferencePersistence {
  _MemoryThemeStorage(this.value);

  String? value;
  final List<String> writes = [];

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    writes.add(value);
    this.value = value;
  }
}
