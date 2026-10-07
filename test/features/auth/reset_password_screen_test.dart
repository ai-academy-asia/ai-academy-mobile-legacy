import 'package:aia_mobile/core/theme/app_colors.dart';
import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/domain/auth_failure.dart';
import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/auth/presentation/login_screen.dart';
import 'package:aia_mobile/features/auth/presentation/login_strings.dart';
import 'package:aia_mobile/features/auth/presentation/reset_password_screen.dart';
import 'package:aia_mobile/features/auth/presentation/reset_password_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_learning_back_button.dart';
import 'package:aia_mobile/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';
import 'fake_password_repository.dart';

/// Real font metrics, for the same reason as the login screen's tests.
Future<void> _loadFonts() async {
  const families = <String, List<String>>{
    'Manrope': [
      'assets/fonts/Manrope-Regular.ttf',
      'assets/fonts/Manrope-Medium.ttf',
      'assets/fonts/Manrope-SemiBold.ttf',
      'assets/fonts/Manrope-Bold.ttf',
      'assets/fonts/Manrope-ExtraBold.ttf',
    ],
    'Phosphor': ['assets/fonts/Phosphor.ttf'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(_loadFonts);

  /// A password clearing all five rules.
  const good = 'Nuutsug1!';

  Future<void> pumpReset(
    WidgetTester tester,
    FakePasswordRepository repository, {
    VoidCallback? onCompleted,
    Size size = const Size(393, 852),
  }) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = size * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ResetPasswordScreen(
          repository: repository,
          onCompleted: onCompleted,
        ),
      ),
    );
  }

  Finder fieldAt(int index) => find.byType(TextField).at(index);

  InputDecoration decorationAt(WidgetTester tester, int index) =>
      tester.widget<TextField>(fieldAt(index)).decoration!;

  Color restingBorderAt(WidgetTester tester, int index) =>
      (decorationAt(tester, index).enabledBorder! as OutlineInputBorder)
          .borderSide
          .color;

  Color focusedBorderAt(WidgetTester tester, int index) =>
      (decorationAt(tester, index).focusedBorder! as OutlineInputBorder)
          .borderSide
          .color;

  Color floatingLabelColourAt(WidgetTester tester, int index) =>
      decorationAt(tester, index).floatingLabelStyle!.color!;

  Finder submitButton() =>
      find.widgetWithText(AppButton, ResetPasswordStrings.submit);

  /// The requirement rows, in the design's order.
  Iterable<Color> requirementColours(WidgetTester tester) => tester
      .widgetList<Icon>(
        find.byWidgetPredicate(
          (w) =>
              w is Icon &&
              (w.icon == AppIcons.checkCircle || w.icon == AppIcons.xCircle),
        ),
      )
      .map((icon) => icon.color!);

  group('Sign in - 6, the resting state', () {
    testWidgets('renders the design\'s copy and three fields', (tester) async {
      await pumpReset(tester, FakePasswordRepository());

      expect(find.text(ResetPasswordStrings.title), findsOneWidget);
      expect(find.text(ResetPasswordStrings.supporting), findsOneWidget);
      expect(find.text(ResetPasswordStrings.requirementsTitle), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(3));

      expect(
        decorationAt(tester, 0).labelText,
        ResetPasswordStrings.currentPassword,
      );
      expect(
        decorationAt(tester, 1).labelText,
        ResetPasswordStrings.newPassword,
      );
      expect(
        decorationAt(tester, 2).labelText,
        ResetPasswordStrings.confirmPassword,
      );
    });

    testWidgets('lists all five requirements, neutral and unjudged', (
      tester,
    ) async {
      await pumpReset(tester, FakePasswordRepository());

      expect(find.byIcon(AppIcons.checkCircle), findsNWidgets(5));
      expect(find.byIcon(AppIcons.xCircle), findsNothing);
      expect(
        requirementColours(tester),
        everyElement(AppColors.textSecondary),
        reason: 'an untouched form should not open covered in red',
      );
    });

    testWidgets('hides all three passwords behind closed eyes', (tester) async {
      await pumpReset(tester, FakePasswordRepository());

      for (var i = 0; i < 3; i++) {
        expect(tester.widget<TextField>(fieldAt(i)).obscureText, isTrue);
      }
      expect(find.byIcon(AppIcons.eyeClosed), findsNWidgets(3));
    });

    testWidgets('shows no error anywhere', (tester) async {
      await pumpReset(tester, FakePasswordRepository());

      for (var i = 0; i < 3; i++) {
        expect(restingBorderAt(tester, i), AppColors.border);
      }
    });
  });

  group('Sign in - 7, the current password focused', () {
    testWidgets('takes a dark border and label, never the button blue', (
      tester,
    ) async {
      await pumpReset(tester, FakePasswordRepository());

      await tester.tap(fieldAt(0));
      await tester.pump();

      expect(focusedBorderAt(tester, 0), AppColors.borderFocused);
      expect(focusedBorderAt(tester, 0), isNot(AppColors.blue));
      expect(floatingLabelColourAt(tester, 0), AppColors.borderFocused);
    });
  });

  group('Sign in - 8, the new password focused and partly valid', () {
    testWidgets('marks passing rules green and failing rules red', (
      tester,
    ) async {
      await pumpReset(tester, FakePasswordRepository());

      // Eight characters with both cases, but no digit and no symbol.
      await tester.enterText(fieldAt(1), 'Abcdefgh');
      await tester.pump();

      final colours = requirementColours(tester).toList();
      expect(colours.take(3), everyElement(AppColors.success));
      expect(colours.skip(3), everyElement(AppColors.error));
      expect(find.byIcon(AppIcons.xCircle), findsNWidgets(2));
    });

    testWidgets('the meter tracks the rules as they pass', (tester) async {
      await pumpReset(tester, FakePasswordRepository());

      double meter() => tester
          .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .widthFactor!;

      await tester.enterText(fieldAt(1), 'Abcdefgh');
      await tester.pump();
      expect(meter(), closeTo(0.6, 0.001));

      await tester.enterText(fieldAt(1), good);
      await tester.pumpAndSettle();
      expect(meter(), 1.0);
    });
  });

  group('Sign in - 9, every requirement satisfied', () {
    testWidgets('turns the whole list green', (tester) async {
      await pumpReset(tester, FakePasswordRepository());

      await tester.enterText(fieldAt(1), good);
      await tester.pump();

      expect(find.byIcon(AppIcons.checkCircle), findsNWidgets(5));
      expect(find.byIcon(AppIcons.xCircle), findsNothing);
      expect(requirementColours(tester), everyElement(AppColors.success));
    });
  });

  group('Sign in - 10, the confirmation does not match', () {
    testWidgets('reddens only the confirm field and names the reason', (
      tester,
    ) async {
      final repository = FakePasswordRepository();
      await pumpReset(tester, repository);

      await tester.enterText(fieldAt(0), 'Huuchin1!');
      await tester.enterText(fieldAt(1), good);
      await tester.enterText(fieldAt(2), 'Nuutsug2!');
      await tester.pump();
      await tester.tap(submitButton());
      await tester.pump();

      expect(restingBorderAt(tester, 2), AppColors.error);
      expect(floatingLabelColourAt(tester, 2), AppColors.error);
      expect(
        restingBorderAt(tester, 1),
        AppColors.border,
        reason: 'the new password itself is fine',
      );
      expect(
        find.text(ResetPasswordStrings.confirmPasswordMismatch),
        findsOneWidget,
      );
      expect(repository.calls, isEmpty);
    });

    testWidgets('a matching confirmation clears the error', (tester) async {
      await pumpReset(tester, FakePasswordRepository(), onCompleted: () {});

      await tester.enterText(fieldAt(0), 'Huuchin1!');
      await tester.enterText(fieldAt(1), good);
      await tester.enterText(fieldAt(2), 'Nuutsug2!');
      await tester.pump();
      await tester.tap(submitButton());
      await tester.pump();
      expect(restingBorderAt(tester, 2), AppColors.error);

      await tester.enterText(fieldAt(2), good);
      await tester.pump();

      expect(restingBorderAt(tester, 2), AppColors.border);
      expect(
        find.text(ResetPasswordStrings.confirmPasswordMismatch),
        findsNothing,
      );
    });
  });

  group('submission', () {
    testWidgets('toggles one password without revealing the others', (
      tester,
    ) async {
      await pumpReset(tester, FakePasswordRepository());

      await tester.tap(find.byIcon(AppIcons.eyeClosed).at(1));
      await tester.pump();

      expect(tester.widget<TextField>(fieldAt(0)).obscureText, isTrue);
      expect(tester.widget<TextField>(fieldAt(1)).obscureText, isFalse);
      expect(tester.widget<TextField>(fieldAt(2)).obscureText, isTrue);
      expect(find.byIcon(AppIcons.eye), findsOneWidget);
    });

    testWidgets('shows a spinner and blocks the fields while saving', (
      tester,
    ) async {
      final repository = FakePasswordRepository(hold: true);
      await pumpReset(tester, repository, onCompleted: () {});

      await tester.enterText(fieldAt(0), 'Huuchin1!');
      await tester.enterText(fieldAt(1), good);
      await tester.enterText(fieldAt(2), good);
      await tester.pump();
      await tester.tap(submitButton());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<TextField>(fieldAt(0)).enabled, isFalse);

      repository.release();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('signals completion once the password is changed', (
      tester,
    ) async {
      var completed = false;
      final repository = FakePasswordRepository();
      await pumpReset(tester, repository, onCompleted: () => completed = true);

      await tester.enterText(fieldAt(0), 'Huuchin1!');
      await tester.enterText(fieldAt(1), good);
      await tester.enterText(fieldAt(2), good);
      await tester.pump();
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(repository.calls, hasLength(1));
    });

    testWidgets('a rejected current password reddens that field', (
      tester,
    ) async {
      final repository = FakePasswordRepository(
        failure: const AuthFailure(AuthFailureKind.invalidCredentials),
      );
      await pumpReset(tester, repository);

      await tester.enterText(fieldAt(0), 'Buruu1!aa');
      await tester.enterText(fieldAt(1), good);
      await tester.enterText(fieldAt(2), good);
      await tester.pump();
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(restingBorderAt(tester, 0), AppColors.error);
      expect(
        find.text(ResetPasswordStrings.invalidCurrentPassword),
        findsOneWidget,
      );
    });

    testWidgets('a network failure reads under the form', (tester) async {
      final repository = FakePasswordRepository(
        failure: const AuthFailure(AuthFailureKind.network),
      );
      await pumpReset(tester, repository);

      await tester.enterText(fieldAt(0), 'Huuchin1!');
      await tester.enterText(fieldAt(1), good);
      await tester.enterText(fieldAt(2), good);
      await tester.pump();
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(find.text(ResetPasswordStrings.networkError), findsOneWidget);
    });
  });

  group('back control (Issue #227)', () {
    Finder backControl() => find.byType(CourseLearningBackButton);

    /// The screen pushed over a page, as Profile pushes it.
    Future<void> pushVoluntary(
      WidgetTester tester,
      FakePasswordRepository repository,
    ) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(393, 852) * 3;
      addTearDown(tester.view.reset);
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          theme: AppTheme.light,
          home: const Scaffold(body: Text('previous screen')),
        ),
      );
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ResetPasswordScreen(repository: repository, showBackButton: true),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('off by default: the required change draws none', (
      tester,
    ) async {
      await pumpReset(tester, FakePasswordRepository());

      expect(backControl(), findsNothing);
      expect(find.text(ResetPasswordStrings.title), findsOneWidget);
    });

    testWidgets('a voluntary change draws it above the unchanged form', (
      tester,
    ) async {
      await pushVoluntary(tester, FakePasswordRepository());

      expect(backControl(), findsOneWidget);
      expect(
        tester.getRect(find.text(ResetPasswordStrings.title)).top,
        greaterThan(tester.getRect(backControl()).bottom),
      );
      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets('tapping it pops back without sending anything', (
      tester,
    ) async {
      final repository = FakePasswordRepository();
      await pushVoluntary(tester, repository);
      await tester.enterText(fieldAt(0), 'Huuchin1!');

      await tester.tap(find.bySemanticsLabel(CourseLearningStrings.back));
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordScreen), findsNothing);
      expect(find.text('previous screen'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets('with it shown, the form still validates and submits, then '
        'pops back as before', (tester) async {
      final repository = FakePasswordRepository();
      await pushVoluntary(tester, repository);

      await tester.enterText(fieldAt(0), 'Huuchin1!');
      await tester.enterText(fieldAt(1), good);
      await tester.enterText(fieldAt(2), 'Nuutsug2!');
      await tester.pump();
      await tester.tap(submitButton());
      await tester.pump();
      // The same validation as without the back control: nothing is sent.
      expect(
        find.text(ResetPasswordStrings.confirmPasswordMismatch),
        findsOneWidget,
      );
      expect(repository.calls, isEmpty);

      await tester.enterText(fieldAt(2), good);
      await tester.pump();
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(repository.calls, hasLength(1));
      expect(find.text('previous screen'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('reuses login\'s field and button geometry', (tester) async {
      await pumpReset(tester, FakePasswordRepository());

      for (var i = 0; i < 3; i++) {
        final rect = tester.getRect(fieldAt(i));
        expect(rect.height, 56, reason: 'field $i height');
        expect(rect.left, 16, reason: 'field $i gutter');
        expect(rect.width, 361, reason: 'field $i width');
      }

      // The reference sets the current password apart from the new pair:
      // 24pt above, 12pt between the new password and its confirmation.
      expect(
        tester.getRect(fieldAt(1)).top - tester.getRect(fieldAt(0)).bottom,
        24,
      );
      expect(
        tester.getRect(fieldAt(2)).top - tester.getRect(fieldAt(1)).bottom,
        12,
      );

      final button = tester.getRect(
        find.descendant(of: submitButton(), matching: find.byType(Ink)).first,
      );
      expect(button.height, 44);
      expect(button.width, 361);
    });

    testWidgets('the mismatch error leaves all three fields where they were', (
      tester,
    ) async {
      await pumpReset(tester, FakePasswordRepository());

      final before = [for (var i = 0; i < 3; i++) tester.getRect(fieldAt(i))];

      await tester.enterText(fieldAt(0), 'Huuchin1!');
      await tester.enterText(fieldAt(1), good);
      await tester.enterText(fieldAt(2), 'Nuutsug2!');
      await tester.pump();
      await tester.tap(submitButton());
      await tester.pump();

      // The error is showing...
      expect(
        find.text(ResetPasswordStrings.confirmPasswordMismatch),
        findsOneWidget,
      );
      // ...and not one of the fields has moved.
      for (var i = 0; i < 3; i++) {
        expect(tester.getRect(fieldAt(i)), before[i], reason: 'field $i moved');
      }
    });

    testWidgets('the strength meter is the reference 353 x 8 at x=20', (
      tester,
    ) async {
      await pumpReset(tester, FakePasswordRepository());

      final bar = tester.getRect(
        find
            .ancestor(
              of: find.byType(FractionallySizedBox),
              matching: find.byType(ClipRRect),
            )
            .first,
      );
      // Inset 4pt inside the 361pt field column, which starts at x=16.
      expect(bar.height, 8);
      expect(bar.left, 20);
      expect(bar.width, 353);
    });

    testWidgets('the page is the reference fill, fields stay white', (
      tester,
    ) async {
      await pumpReset(tester, FakePasswordRepository());

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.surfaceSubtle);
      expect(AppColors.surfaceSubtle, const Color(0xFFF9FAFB));
      expect(decorationAt(tester, 0).fillColor, AppColors.surface);
    });

    testWidgets('all three fields take the ordinary alphanumeric keyboard', (
      tester,
    ) async {
      await pumpReset(tester, FakePasswordRepository());

      // The reference draws a full QWERTY under every one of these.
      for (var i = 0; i < 3; i++) {
        expect(
          tester.widget<TextField>(fieldAt(i)).keyboardType,
          TextInputType.text,
          reason: 'field $i',
        );
        expect(tester.widget<TextField>(fieldAt(i)).obscureText, isTrue);
      }
    });

    testWidgets('the keyboard covers the page instead of moving the fields', (
      tester,
    ) async {
      await pumpReset(tester, FakePasswordRepository());
      final before = [for (var i = 0; i < 3; i++) tester.getRect(fieldAt(i))];

      // A keyboard's worth of bottom inset, as the reference's states 2-4 show.
      tester.view.viewInsets = FakeViewPadding(
        bottom: 336 * tester.view.devicePixelRatio,
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        expect(
          tester.getRect(fieldAt(i)),
          before[i],
          reason: 'field $i moved when the keyboard appeared',
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives a keyboard-height viewport without overflowing', (
      tester,
    ) async {
      await pumpReset(
        tester,
        FakePasswordRepository(),
        size: const Size(393, 420),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('navigation from login', () {
    testWidgets('with a live session held, the reset button opens the reset '
        'screen', (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          // Only a held session can change a password; signed out, the
          // button opens the manager contact instead (Issue #184) — covered
          // in `login_screen_test.dart`.
          home: LoginScreen(
            repository: FakeAuthRepository(),
            sessionStore: AuthSessionStore()
              ..save(const AuthSession(accessToken: 'tok')),
          ),
          routes: {
            '/reset-password': (_) =>
                ResetPasswordScreen(repository: FakePasswordRepository()),
          },
        ),
      );

      expect(find.text(ResetPasswordStrings.title), findsNothing);

      await tester.tap(
        find.widgetWithText(AppButton, LoginStrings.resetPassword),
      );
      await tester.pumpAndSettle();

      expect(find.text(ResetPasswordStrings.title), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(3));
    });
  });
}
