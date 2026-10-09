import 'dart:ui' show Tristate;

import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/domain/current_user.dart';
import 'package:aia_mobile/features/auth/domain/current_user_failure.dart';
import 'package:aia_mobile/features/auth/presentation/reset_password_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_learning_back_button.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_strings.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_profile_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_profile_strings.dart';
import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/features/profile/presentation/profile_strings.dart';
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../profile/fake_current_user_repository.dart';

/// Junior Profile — the "Kids - Profile" frame.
void main() {
  setUpAll(loadAppFonts);

  Future<void> pumpScreen(
    WidgetTester tester, {
    FakeCurrentUserRepository? repository,
    Size size = const Size(393, 1274),
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: JuniorProfileScreen(
          repository: repository ?? FakeCurrentUserRepository(hold: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('draws every line of the frame\'s copy except its placeholder '
      'account data (Issue #223)', (tester) async {
    await pumpScreen(tester);

    for (final text in [
      'Profile',
      'Account',
      'E-Contract',
      'Certificate',
      'Transaction history',
      'Payment receipt',
      'App settings',
      'Хэл / Language',
      'MN',
      'EN',
      'Change password',
      'Contact',
      'Help center',
      'Term of Service',
      'Privacy Policy',
      'Log out',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    // The section caption and the row under it.
    expect(find.text('Notification'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('is not the adult Profile: four Account rows, no extras', (
    tester,
  ) async {
    await pumpScreen(tester);

    // The adult frame's light-mode row and edit control are not in the junior
    // frame.
    expect(find.text(ProfileStrings.lightMode), findsNothing);
    expect(find.text(ProfileStrings.editProfile), findsNothing);

    // Account runs E-Contract, Certificate, Transaction history, Payment
    // receipt — in that order, top to bottom, before App settings.
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    final order = [
      JuniorProfileStrings.accountSection,
      JuniorProfileStrings.eContract,
      JuniorProfileStrings.certificate,
      JuniorProfileStrings.transactionHistory,
      JuniorProfileStrings.paymentReceipt,
      JuniorProfileStrings.appSettingsSection,
    ].map(top).toList();
    for (var i = 1; i < order.length; i++) {
      expect(order[i], greaterThan(order[i - 1]));
    }
  });

  group('name', () {
    testWidgets('shows no placeholder person while /auth/me loads, or any '
        'invented account data (Issue #223)', (tester) async {
      await pumpScreen(tester);

      for (final invented in _inventedValues) {
        expect(find.text(invented), findsNothing, reason: invented);
      }
    });

    testWidgets('shows the signed-in student\'s own name once loaded', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        repository: FakeCurrentUserRepository(
          user: const CurrentUser(
            id: 1,
            actorId: 1,
            actorType: 'student',
            email: 'kid@example.mn',
            role: 'student',
            isActive: true,
            mustChangePassword: false,
            profile: UserProfile(
              id: 1,
              firstName: 'Тэмүүлэн',
              lastName: 'Б',
              phone: '',
              uiMode: 'child',
            ),
          ),
        ),
      );

      expect(find.textContaining('Тэмүүлэн'), findsOneWidget);
      expect(find.text('Хулан'), findsNothing);
    });

    testWidgets('shows no placeholder person when /auth/me fails', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        repository: FakeCurrentUserRepository(
          failure: const CurrentUserFailure(CurrentUserFailureKind.network),
        ),
      );

      expect(find.text('Хулан'), findsNothing);
    });
  });

  group('controls', () {
    testWidgets('MN starts selected and EN can be picked', (tester) async {
      await pumpScreen(tester);

      bool selected(String label) =>
          tester
              .getSemantics(find.bySemanticsLabel(label))
              .flagsCollection
              .isSelected ==
          Tristate.isTrue;
      expect(selected('MN'), isTrue);
      expect(selected('EN'), isFalse);

      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();

      expect(selected('MN'), isFalse);
      expect(selected('EN'), isTrue);
    });

    testWidgets('the notification switch starts off and flips on tap', (
      tester,
    ) async {
      await pumpScreen(tester);

      bool toggled() =>
          tester
              .getSemantics(
                find.bySemanticsLabel(JuniorProfileStrings.notification).last,
              )
              .flagsCollection
              .isToggled ==
          Tristate.isTrue;
      expect(toggled(), isFalse);

      await tester.tap(
        find.bySemanticsLabel(JuniorProfileStrings.notification).last,
      );
      await tester.pumpAndSettle();

      expect(toggled(), isTrue);
    });

    testWidgets('Change password opens the existing change-password screen', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text(JuniorProfileStrings.changePassword));
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      // A voluntary change can go back (Issue #227).
      expect(find.byType(CourseLearningBackButton), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(CourseLearningStrings.back));
      await tester.pumpAndSettle();
      expect(find.byType(ResetPasswordScreen), findsNothing);
      expect(find.text(JuniorProfileStrings.changePassword), findsOneWidget);
    });
  });

  group('supplied artwork', () {
    Iterable<String> svgAssets(WidgetTester tester, Finder within) => tester
        .widgetList<SvgPicture>(
          find.descendant(of: within, matching: find.byType(SvgPicture)),
        )
        .map((svg) => (svg.bytesLoader as SvgAssetLoader).assetName);

    testWidgets('Payment receipt draws the frame\'s receipt SVG', (
      tester,
    ) async {
      await pumpScreen(tester);

      final row = find.ancestor(
        of: find.text(JuniorProfileStrings.paymentReceipt),
        matching: find.byType(Row),
      );
      expect(
        svgAssets(tester, row.first),
        contains('assets/icons/payment_receipt.svg'),
      );
      expect(
        find.descendant(of: row.first, matching: find.byType(Icon)),
        findsNothing,
      );
    });

    testWidgets('the current Профайл tab draws the frame\'s user SVG', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(svgAssets(tester, find.byType(AppBottomNav)), [
        'assets/icons/nav_profile_selected.svg',
      ]);
    });

    testWidgets('the language control keeps the frame\'s geometry', (
      tester,
    ) async {
      await pumpScreen(tester);

      final mn = find.ancestor(
        of: find.text(JuniorProfileStrings.languageMn),
        matching: find.byType(Container),
      );
      final control = find
          .ancestor(of: mn.first, matching: find.byType(Container))
          .first;
      expect(tester.getSize(control), const Size(93, 35));
      expect(tester.getSize(mn.first), const Size(44, 27));
    });
  });

  testWidgets('Профайл is the selected tab', (tester) async {
    await pumpScreen(tester);

    final nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
    expect(nav.currentIndex, 2);
    expect(nav.items.map((item) => item.label), [
      JuniorHomeStrings.navHome,
      JuniorHomeStrings.navProgress,
      JuniorHomeStrings.navProfile,
    ]);
    expect(nav.items[2].onTap, isNull);
    expect(nav.items[0].onTap, isNotNull);
    expect(nav.items[1].onTap, isNotNull);
    expect(
      tester.widget<Text>(find.text(JuniorHomeStrings.navProfile)).style!.color,
      AppPalette.light.accentText,
    );
  });

  testWidgets('scrolls to its end on a phone viewport', (tester) async {
    await pumpScreen(tester, size: const Size(393, 852));

    await tester.scrollUntilVisible(
      find.text(JuniorProfileStrings.logOut),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(JuniorProfileStrings.logOut), findsOneWidget);
    // No invented version line under it (Issue #223).
    expect(find.textContaining('Version'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

/// The frame's placeholder account data that must never reach a student
/// (Issue #223): another person's name, a join date, a contract status and a
/// version, none of which any confirmed response carries.
const List<String> _inventedValues = [
  'Хулан',
  'Joined Oct 2026',
  'Гэрээ хийгдээгүй байна',
  'Version 1.2.4 (2025)',
];
