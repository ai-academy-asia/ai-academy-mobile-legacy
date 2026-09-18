import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/core/theme/app_typography.dart';
import 'package:aia_mobile/features/auth/domain/current_user_failure.dart';
import 'package:aia_mobile/features/profile/presentation/profile_screen.dart';
import 'package:aia_mobile/features/profile/presentation/profile_strings.dart';
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:aia_mobile/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

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
/// `find.text` alone is ambiguous. These match on the style each role uses.
Finder sectionCaption(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.data == label &&
      widget.style == AppTypography.catalogSectionLabel,
);

Finder rowLabel(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.data == label &&
      widget.style == AppTypography.settingsRowLabel,
);

void main() {
  setUpAll(_loadFonts);

  Future<void> pumpProfile(
    WidgetTester tester, {
    Size size = const Size(393, 852),
    FakeCurrentUserRepository? repository,
  }) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = size * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ProfileScreen(
          repository:
              repository ??
              FakeCurrentUserRepository(
                failure: const CurrentUserFailure(CurrentUserFailureKind.sessionExpired),
              ),
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

    testWidgets('shows the placeholder name and join date when /auth/me fails', (
      tester,
    ) async {
      await pumpProfile(tester);

      expect(find.text(ProfileStrings.name), findsOneWidget);
      expect(find.text(ProfileStrings.joinedDate), findsOneWidget);
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

    testWidgets('shows the E-Contract status badge and count', (tester) async {
      await pumpProfile(tester);

      expect(find.text(ProfileStrings.eContractStatus), findsOneWidget);
      expect(find.text(ProfileStrings.eContractCount), findsOneWidget);
    });

    testWidgets('shows the log out button and version, below the rows', (
      tester,
    ) async {
      await pumpProfile(tester);

      await tester.dragUntilVisible(
        find.text(ProfileStrings.version),
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(AppButton, ProfileStrings.logOut),
        findsOneWidget,
      );
      expect(find.text(ProfileStrings.version), findsOneWidget);
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
    testWidgets('shows the placeholder name while the fetch is in flight', (
      tester,
    ) async {
      final repository = FakeCurrentUserRepository(hold: true);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: ProfileScreen(repository: repository)),
      );
      await tester.pump();

      expect(find.text(ProfileStrings.name), findsOneWidget);

      repository.release();
      await tester.pumpAndSettle();
    });

    testWidgets('shows the fetched full name once /auth/me succeeds', (
      tester,
    ) async {
      await pumpProfile(tester, repository: FakeCurrentUserRepository());

      expect(find.text('CRUD TestStudent'), findsOneWidget);
      expect(find.text(ProfileStrings.name), findsNothing);
      // The join date has no confirmed source in the contract yet.
      expect(find.text(ProfileStrings.joinedDate), findsOneWidget);
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
      expect(
        find.widgetWithText(AppButton, ProfileStrings.logOut),
        findsOneWidget,
      );
      expect(find.text(ProfileStrings.version), findsOneWidget);
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
    testWidgets(
      'light mode and notification switches start off and flip on tap',
      (tester) async {
        await pumpProfile(tester);

        final switches = find.byType(Switch);
        expect(switches, findsNWidgets(2));
        expect(
          tester.widgetList<Switch>(switches).map((s) => s.value),
          everyElement(isFalse),
        );

        await tester.tap(switches.first);
        await tester.pumpAndSettle();

        expect(
          tester.widgetList<Switch>(find.byType(Switch)).first.value,
          isTrue,
        );
      },
    );
  });

  group('bottom navigation', () {
    testWidgets('marks the profile tab as the current one', (tester) async {
      await pumpProfile(tester);

      final nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
      expect(nav.currentIndex, 2);
      expect(nav.items.map((item) => item.label), [
        ProfileStrings.navHome,
        ProfileStrings.navCourses,
        ProfileStrings.navProfile,
      ]);
    });

    testWidgets('the courses tab pops back to whatever pushed Profile', (
      tester,
    ) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          theme: AppTheme.light,
          home: const Scaffold(body: Text('previous screen')),
        ),
      );

      navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text(ProfileStrings.heading), findsOneWidget);

      await tester.tap(find.byIcon(AppIcons.bookOpenText));
      await tester.pumpAndSettle();

      expect(find.text('previous screen'), findsOneWidget);
      expect(find.text(ProfileStrings.heading), findsNothing);
    });
  });
}
