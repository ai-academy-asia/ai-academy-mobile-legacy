import 'package:aia_mobile/core/theme/app_colors.dart';
import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/domain/auth_failure.dart';
import 'package:aia_mobile/features/auth/presentation/login_screen.dart';
import 'package:aia_mobile/features/auth/presentation/login_strings.dart';
import 'package:aia_mobile/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';

/// Loads the real Manrope and Phosphor faces.
///
/// Without this a widget test measures text in Flutter's fallback font, whose
/// glyphs are a fixed, wider box — so anything asserting that a line fits, or
/// how wide it is, would be testing the wrong typeface.
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

  /// Pumps the screen at the design's own viewport (393 x 852), so the layout
  /// under test is the one the design describes rather than the 800 x 600
  /// default — at which the buttons fall below the fold and taps silently miss.
  Future<void> pumpLogin(
    WidgetTester tester,
    FakeAuthRepository repository, {
    VoidCallback? onSignedIn,
    Size size = const Size(393, 852),
  }) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = size * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LoginScreen(repository: repository, onSignedIn: onSignedIn),
      ),
    );
  }

  Finder fieldAt(int index) => find.byType(TextField).at(index);

  // "Нэвтрэх" is both the heading and the primary button's label, so anything
  // aimed at the button has to be scoped to it rather than found by text.
  Finder signInButton() => find.widgetWithText(AppButton, LoginStrings.signIn);
  Finder resetButton() => find.widgetWithText(AppButton, LoginStrings.resetPassword);

  InkWell inkOf(WidgetTester tester, Finder button) => tester.widget<InkWell>(
    find.descendant(of: button, matching: find.byType(InkWell)).first,
  );

  InputDecoration decorationAt(WidgetTester tester, int index) =>
      tester.widget<TextField>(fieldAt(index)).decoration!;

  /// The colour of the box the field draws when it is not focused — which is
  /// where the error state shows, since an errored field is usually not the
  /// one under the cursor.
  Color restingBorderAt(WidgetTester tester, int index) =>
      (decorationAt(tester, index).enabledBorder! as OutlineInputBorder).borderSide.color;

  Color focusedBorderAt(WidgetTester tester, int index) =>
      (decorationAt(tester, index).focusedBorder! as OutlineInputBorder).borderSide.color;

  Color floatingLabelColourAt(WidgetTester tester, int index) =>
      decorationAt(tester, index).floatingLabelStyle!.color!;

  String labelTextAt(WidgetTester tester, int index) =>
      decorationAt(tester, index).labelText!;

  group('Sign in - 1, the resting state', () {
    testWidgets('shows the design\'s copy', (tester) async {
      await pumpLogin(tester, FakeAuthRepository());

      // The heading and the primary button share the word "Нэвтрэх".
      expect(find.text(LoginStrings.heading), findsNWidgets(2));
      expect(find.text(LoginStrings.rememberMe), findsOneWidget);
      expect(signInButton(), findsOneWidget);
      expect(find.text(LoginStrings.resetPassword), findsOneWidget);
      expect(find.text(LoginStrings.contactSupporting), findsOneWidget);
      expect(find.text(LoginStrings.contactManager), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('rests the long placeholder inside the first field', (tester) async {
      await pumpLogin(tester, FakeAuthRepository());

      expect(labelTextAt(tester, 0), LoginStrings.identifierPlaceholder);
      expect(labelTextAt(tester, 1), LoginStrings.passwordLabel);
    });

    testWidgets('carries no logo', (tester) async {
      await pumpLogin(tester, FakeAuthRepository());

      expect(find.byType(Image), findsNothing);
    });

    testWidgets('shows no error of any kind', (tester) async {
      await pumpLogin(tester, FakeAuthRepository());

      expect(restingBorderAt(tester, 0), AppColors.border);
      expect(restingBorderAt(tester, 1), AppColors.border);
      expect(find.text(LoginStrings.invalidCredentials), findsNothing);
      expect(find.text(LoginStrings.identifierInvalid), findsNothing);
    });

    testWidgets('hides the password behind a closed eye', (tester) async {
      await pumpLogin(tester, FakeAuthRepository());

      expect(tester.widget<TextField>(fieldAt(1)).obscureText, isTrue);
      expect(find.byIcon(AppIcons.eyeClosed), findsOneWidget);
    });
  });

  group('Sign in - 2, the identifier focused', () {
    testWidgets('lifts the shortened label out of the field', (tester) async {
      await pumpLogin(tester, FakeAuthRepository());

      await tester.tap(fieldAt(0));
      await tester.pump();

      expect(labelTextAt(tester, 0), LoginStrings.identifierLabel);
      expect(floatingLabelColourAt(tester, 0), AppColors.borderFocused);
    });

    testWidgets('focuses with a dark border, never the button blue', (tester) async {
      await pumpLogin(tester, FakeAuthRepository());

      await tester.tap(fieldAt(0));
      await tester.pump();

      // A blue focus ring is Material's habit, not this design's.
      expect(focusedBorderAt(tester, 0), AppColors.borderFocused);
      expect(focusedBorderAt(tester, 0), isNot(AppColors.blue));
      expect(floatingLabelColourAt(tester, 0), isNot(AppColors.blue));
    });

    testWidgets('keeps the label lifted once a number is typed', (tester) async {
      await pumpLogin(tester, FakeAuthRepository());

      await tester.enterText(fieldAt(0), '99112233');
      await tester.pump();
      // Focus moves away; the label stays up because the field has content.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(labelTextAt(tester, 0), LoginStrings.identifierLabel);
    });
  });

  group('Sign in - 3, the password focused', () {
    testWidgets('lifts the password label and keeps the value masked', (tester) async {
      await pumpLogin(tester, FakeAuthRepository());

      await tester.enterText(fieldAt(0), '99112233');
      await tester.tap(fieldAt(1));
      await tester.enterText(fieldAt(1), 'nuutsug123');
      await tester.pump();

      expect(labelTextAt(tester, 1), LoginStrings.passwordLabel);
      expect(floatingLabelColourAt(tester, 1), AppColors.borderFocused);
      expect(tester.widget<TextField>(fieldAt(1)).obscureText, isTrue);
    });

    testWidgets('reveals and re-hides the password', (tester) async {
      await pumpLogin(tester, FakeAuthRepository());

      await tester.tap(find.byIcon(AppIcons.eyeClosed));
      await tester.pump();

      expect(tester.widget<TextField>(fieldAt(1)).obscureText, isFalse);
      expect(find.byIcon(AppIcons.eye), findsOneWidget);

      await tester.tap(find.byIcon(AppIcons.eye));
      await tester.pump();

      expect(tester.widget<TextField>(fieldAt(1)).obscureText, isTrue);
    });
  });

  group('Sign in - 4, the identifier in error', () {
    testWidgets('reddens only the offending field', (tester) async {
      final repository = FakeAuthRepository();
      await pumpLogin(tester, repository);

      await tester.enterText(fieldAt(0), '9911');
      await tester.enterText(fieldAt(1), 'nuutsug123');
      await tester.pump();
      await tester.tap(signInButton());
      await tester.pump();

      expect(restingBorderAt(tester, 0), AppColors.error);
      expect(floatingLabelColourAt(tester, 0), AppColors.error);
      expect(
        restingBorderAt(tester, 1),
        AppColors.border,
        reason: 'the password is fine and must stay neutral',
      );
      expect(repository.calls, isEmpty);
    });

    testWidgets('says why, without a banner', (tester) async {
      await pumpLogin(tester, FakeAuthRepository());

      await tester.enterText(fieldAt(0), '9911');
      await tester.enterText(fieldAt(1), 'nuutsug123');
      await tester.pump();
      await tester.tap(signInButton());
      await tester.pump();

      expect(find.text(LoginStrings.identifierInvalid), findsOneWidget);
      // The message rides inside the gap the design already leaves, so the
      // buttons stay where the reference puts them.
      expect(find.byType(Card), findsNothing);
    });
  });

  group('Sign in - 5, the password in error', () {
    testWidgets('reddens only the password field', (tester) async {
      await pumpLogin(tester, FakeAuthRepository());

      await tester.enterText(fieldAt(0), '99112233');
      await tester.enterText(fieldAt(1), '123');
      await tester.pump();
      await tester.tap(signInButton());
      await tester.pump();

      expect(restingBorderAt(tester, 1), AppColors.error);
      expect(floatingLabelColourAt(tester, 1), AppColors.error);
      expect(
        restingBorderAt(tester, 0),
        AppColors.border,
        reason: 'the number is fine and must stay neutral',
      );
      expect(find.text(LoginStrings.passwordTooShort), findsOneWidget);
    });
  });

  group('the error states leave the layout alone', () {
    testWidgets('the buttons do not move when a field errors', (tester) async {
      await pumpLogin(tester, FakeAuthRepository());

      final before = tester.getTopLeft(signInButton());

      await tester.enterText(fieldAt(0), '9911');
      await tester.enterText(fieldAt(1), '123');
      await tester.pump();
      await tester.tap(signInButton());
      await tester.pump();

      expect(tester.getTopLeft(signInButton()), before);
    });
  });

  group('submission', () {
    testWidgets('both buttons are drawn live, as the reference shows them', (
      tester,
    ) async {
      await pumpLogin(tester, FakeAuthRepository());

      // Neither is greyed in Sign in - 1, even with the form untouched.
      expect(inkOf(tester, signInButton()).onTap, isNotNull);
      expect(inkOf(tester, resetButton()).onTap, isNotNull);

      final fill = tester
          .widget<Material>(
            find.descendant(of: signInButton(), matching: find.byType(Material)).first,
          )
          .color;
      expect(fill, AppColors.blue, reason: 'primary is brand blue at rest');
    });

    testWidgets('pressing an empty form flags both fields', (tester) async {
      final repository = FakeAuthRepository();
      await pumpLogin(tester, repository);

      await tester.tap(signInButton());
      await tester.pump();

      expect(restingBorderAt(tester, 0), AppColors.error);
      expect(restingBorderAt(tester, 1), AppColors.error);
      expect(repository.calls, isEmpty);
    });

    testWidgets('shows a spinner and blocks the fields while signing in', (tester) async {
      final repository = FakeAuthRepository(hold: true);
      await pumpLogin(tester, repository, onSignedIn: () {});

      await tester.enterText(fieldAt(0), '99112233');
      await tester.enterText(fieldAt(1), 'nuutsug123');
      await tester.pump();
      await tester.tap(signInButton());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.descendant(of: signInButton(), matching: find.text(LoginStrings.signIn)),
        findsNothing,
        reason: 'label swapped for the spinner',
      );
      expect(tester.widget<TextField>(fieldAt(0)).enabled, isFalse);

      // Loading must not look like a dead control: the button keeps its brand
      // fill while the request runs, and only greys out when it is unpressable.
      final loadingFill = tester
          .widget<Material>(
            find
                .ancestor(
                  of: find.byType(CircularProgressIndicator),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color;
      expect(loadingFill, AppColors.blue);

      repository.release();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('surfaces an API rejection in the message band', (tester) async {
      final repository = FakeAuthRepository(
        failure: const AuthFailure(AuthFailureKind.invalidCredentials),
      );
      await pumpLogin(tester, repository);

      await tester.enterText(fieldAt(0), '99112233');
      await tester.enterText(fieldAt(1), 'buruu-nuutsug');
      await tester.pump();
      await tester.tap(signInButton());
      await tester.pumpAndSettle();

      expect(find.text(LoginStrings.invalidCredentials), findsOneWidget);
      expect(repository.calls, hasLength(1));
    });

    testWidgets('a network failure reads differently from a rejection', (tester) async {
      final repository = FakeAuthRepository(
        failure: const AuthFailure(AuthFailureKind.network),
      );
      await pumpLogin(tester, repository);

      await tester.enterText(fieldAt(0), '99112233');
      await tester.enterText(fieldAt(1), 'nuutsug123');
      await tester.pump();
      await tester.tap(signInButton());
      await tester.pumpAndSettle();

      expect(find.text(LoginStrings.networkError), findsOneWidget);
    });

    testWidgets('signals success once the API returns a token', (tester) async {
      var signedIn = false;
      final repository = FakeAuthRepository();
      await pumpLogin(tester, repository, onSignedIn: () => signedIn = true);

      await tester.enterText(fieldAt(0), '99112233');
      await tester.enterText(fieldAt(1), 'nuutsug123');
      await tester.pump();
      await tester.tap(signInButton());
      await tester.pumpAndSettle();

      expect(signedIn, isTrue);
    });
  });

  group('visual weight', () {
    // These kept drifting heavy across passes, so they are pinned: the design
    // is small, light and neutral, and body text is black at an opacity — not
    // the brand navy.
    testWidgets('the heading is 22/34 bold and neutral, not ExtraBold navy', (
      tester,
    ) async {
      await pumpLogin(tester, FakeAuthRepository());

      final style = tester
          .widget<Text>(
            find
                .descendant(
                  of: find.byType(LoginScreen),
                  matching: find.text(LoginStrings.heading),
                )
                .first,
          )
          .style!;

      expect(style.fontSize, 22);
      expect(style.height! * style.fontSize!, 34);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.color, AppColors.textPrimary);
      expect(style.fontFamily, 'Manrope');
    });

    testWidgets('button labels are 12/20 semibold', (tester) async {
      await pumpLogin(tester, FakeAuthRepository());

      for (final finder in [signInButton(), resetButton()]) {
        final style = tester
            .widget<Text>(find.descendant(of: finder, matching: find.byType(Text)).first)
            .style!;
        expect(style.fontSize, 12);
        expect(style.fontWeight, FontWeight.w600);
      }
    });

    testWidgets('the primary action is the brand blue #296CFF', (tester) async {
      await pumpLogin(tester, FakeAuthRepository());

      final fill = tester
          .widget<Material>(
            find.descendant(of: signInButton(), matching: find.byType(Material)).first,
          )
          .color;
      expect(fill, const Color(0xFF296CFF));
    });

    testWidgets('white controls sit on a light grey page', (tester) async {
      await pumpLogin(tester, FakeAuthRepository());

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.background);
      expect(
        AppColors.background,
        isNot(AppColors.surface),
        reason: 'a flat white page loses the card and field surfaces',
      );
      expect(decorationAt(tester, 0).fillColor, AppColors.surface);
    });

    testWidgets('the card fits both lines without truncating', (tester) async {
      await pumpLogin(tester, FakeAuthRepository());

      for (final text in [LoginStrings.contactSupporting, LoginStrings.contactManager]) {
        final rendered = tester.renderObject<RenderParagraph>(find.text(text));
        expect(
          rendered.didExceedMaxLines,
          isFalse,
          reason: '"$text" is being ellipsised',
        );
      }
    });
  });

  group('geometry', () {
    testWidgets('matches the design frame', (tester) async {
      await pumpLogin(tester, FakeAuthRepository());

      final field = tester.getRect(fieldAt(0));
      expect(field.height, 56, reason: 'field height');
      expect(field.left, 16, reason: 'left gutter');
      expect(field.width, 361, reason: '393 less two 16pt gutters');

      // 12pt between the two fields.
      expect(tester.getRect(fieldAt(1)).top - field.bottom, 12);

      final button = tester.getRect(
        find
            .ancestor(of: find.text(LoginStrings.signIn), matching: find.byType(Ink))
            .first,
      );
      expect(button.height, 44, reason: 'button height');
      expect(button.width, 361);
    });

    testWidgets('keeps a phone-width column on a desktop-sized window', (tester) async {
      // The macOS build opens a wide window; the design is a phone layout, and
      // the fields must not stretch into desktop-width bars.
      await pumpLogin(tester, FakeAuthRepository(), size: const Size(1200, 900));

      final field = tester.getRect(fieldAt(0));
      expect(field.width, 480 - 32);
      expect(
        field.center.dx,
        600,
        reason: 'the column is centred, not pinned to the left',
      );
    });

    testWidgets('stays scrollable when the keyboard takes half the screen', (
      tester,
    ) async {
      // A short viewport stands in for the space left once the keyboard is up.
      await pumpLogin(tester, FakeAuthRepository(), size: const Size(393, 420));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
