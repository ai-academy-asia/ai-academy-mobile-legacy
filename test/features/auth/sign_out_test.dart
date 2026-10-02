import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/domain/auth_failure.dart';
import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/auth/presentation/login_screen.dart';
import 'package:aia_mobile/features/auth/presentation/login_strings.dart';
import 'package:aia_mobile/features/auth/presentation/sign_out.dart';
import 'package:aia_mobile/features/auth/presentation/sign_out_strings.dart';
import 'package:aia_mobile/features/auth/presentation/widgets/sign_out_confirmation_dialog.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_profile_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_profile_strings.dart';
import 'package:aia_mobile/features/profile/presentation/profile_screen.dart';
import 'package:aia_mobile/features/profile/presentation/profile_strings.dart';
import 'package:aia_mobile/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../profile/fake_current_user_repository.dart';
import 'fake_auth_repository.dart';

/// "Гарах" on both Profiles, end to end: the confirmation dialog, the revoke
/// request, the local sign-out, the landing on Login, and a second account
/// signing in after.
///
/// Every test runs against its own [AuthSessionStore], never the app-wide
/// one, so no token leaks into whatever runs next.
void main() {
  // The real Manrope faces: the Profiles are laid out for them, and the test
  // font's wider glyphs overflow the adult rows.
  setUpAll(loadAppFonts);

  const signedIn = AuthSession(
    accessToken: 'access-1',
    refreshToken: 'refresh-1',
  );

  /// The two Profiles, each with its own "Гарах" label, built with the
  /// injected repository and store.
  final profiles =
      <
        ({
          String name,
          String logOut,
          Widget Function(FakeAuthRepository, AuthSessionStore) build,
        })
      >[
        (
          name: 'Adult Profile',
          logOut: ProfileStrings.logOut,
          build: (auth, store) => ProfileScreen(
            repository: FakeCurrentUserRepository(hold: true),
            authRepository: auth,
            sessionStore: store,
          ),
        ),
        (
          name: 'Junior Profile',
          logOut: JuniorProfileStrings.logOut,
          build: (auth, store) => JuniorProfileScreen(
            repository: FakeCurrentUserRepository(hold: true),
            authRepository: auth,
            sessionStore: store,
          ),
        ),
      ];

  /// Pumps [profile] on top of a stand-in Home, with `/login` the real
  /// [LoginScreen] on the same repository and store — the way
  /// `AiAcademyApp` stacks them.
  Future<void> pumpProfile(
    WidgetTester tester,
    Widget profile,
    FakeAuthRepository auth,
    AuthSessionStore store,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(393, 852) * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        routes: {
          '/': (_) => const Scaffold(body: Text('home')),
          loginRoute: (_) => LoginScreen(
            repository: auth,
            sessionStore: store,
            onSignedIn: () {},
          ),
        },
      ),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(builder: (_) => profile));
    await tester.pumpAndSettle();
  }

  final dialog = find.byType(SignOutConfirmationDialog);
  Finder inDialog(String text) =>
      find.descendant(of: dialog, matching: find.text(text));

  /// Taps the Profile's own "Гарах", which opens the confirmation.
  Future<void> openConfirmation(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  /// The whole confirmed sign-out: the Profile's "Гарах", then the dialog's.
  Future<void> tapLogOut(WidgetTester tester, String label) async {
    await openConfirmation(tester, label);
    await tester.tap(inDialog(SignOutStrings.confirm));
    await tester.pumpAndSettle();
  }

  for (final profile in profiles) {
    group(profile.name, () {
      testWidgets('revokes the refresh token, signs out and lands on Login', (
        tester,
      ) async {
        final auth = FakeAuthRepository();
        final store = AuthSessionStore()..save(signedIn);
        await pumpProfile(tester, profile.build(auth, store), auth, store);

        await tapLogOut(tester, profile.logOut);

        expect(auth.signOutCalls, ['refresh-1']);
        expect(store.isSignedIn, isFalse);
        expect(store.authorizationHeader, isEmpty);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text(profile.logOut), findsNothing);
      });

      testWidgets('"Гарах" opens the confirmation, without signing out', (
        tester,
      ) async {
        final auth = FakeAuthRepository();
        final store = AuthSessionStore()..save(signedIn);
        await pumpProfile(tester, profile.build(auth, store), auth, store);

        await openConfirmation(tester, profile.logOut);

        expect(dialog, findsOneWidget);
        expect(inDialog(SignOutStrings.title), findsOneWidget);
        expect(inDialog(SignOutStrings.message), findsOneWidget);
        expect(inDialog(SignOutStrings.cancel), findsOneWidget);
        expect(inDialog(SignOutStrings.confirm), findsOneWidget);
        expect(auth.signOutCalls, isEmpty);
        expect(store.isSignedIn, isTrue);
        expect(find.byType(LoginScreen), findsNothing);
      });

      testWidgets('the dialog is built from the app\'s own button pair', (
        tester,
      ) async {
        final auth = FakeAuthRepository();
        final store = AuthSessionStore()..save(signedIn);
        await pumpProfile(tester, profile.build(auth, store), auth, store);
        await openConfirmation(tester, profile.logOut);

        AppButton button(String label) => tester.widget<AppButton>(
          find.descendant(
            of: dialog,
            matching: find.widgetWithText(AppButton, label),
          ),
        );
        expect(button(SignOutStrings.confirm).variant, AppButtonVariant.filled);
        expect(
          button(SignOutStrings.cancel).variant,
          AppButtonVariant.outlined,
        );
        // The confirmation sits above the way back, as on Login.
        expect(
          tester.getTopLeft(inDialog(SignOutStrings.confirm)).dy,
          lessThan(tester.getTopLeft(inDialog(SignOutStrings.cancel)).dy),
        );
      });

      testWidgets('"Цуцлах" closes the dialog and keeps the session', (
        tester,
      ) async {
        final auth = FakeAuthRepository();
        final store = AuthSessionStore()..save(signedIn);
        await pumpProfile(tester, profile.build(auth, store), auth, store);
        await openConfirmation(tester, profile.logOut);

        await tester.tap(inDialog(SignOutStrings.cancel));
        await tester.pumpAndSettle();

        expect(dialog, findsNothing);
        expect(auth.signOutCalls, isEmpty);
        expect(store.isSignedIn, isTrue);
        expect(find.text(profile.logOut), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
      });

      testWidgets('tapping outside the dialog keeps the session', (
        tester,
      ) async {
        final auth = FakeAuthRepository();
        final store = AuthSessionStore()..save(signedIn);
        await pumpProfile(tester, profile.build(auth, store), auth, store);
        await openConfirmation(tester, profile.logOut);

        await tester.tapAt(const Offset(8, 8));
        await tester.pumpAndSettle();

        expect(dialog, findsNothing);
        expect(auth.signOutCalls, isEmpty);
        expect(store.isSignedIn, isTrue);
        expect(find.text(profile.logOut), findsOneWidget);
      });

      testWidgets('the system back gesture keeps the session', (tester) async {
        final auth = FakeAuthRepository();
        final store = AuthSessionStore()..save(signedIn);
        await pumpProfile(tester, profile.build(auth, store), auth, store);
        await openConfirmation(tester, profile.logOut);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(dialog, findsNothing);
        expect(auth.signOutCalls, isEmpty);
        expect(store.isSignedIn, isTrue);
        expect(find.text(profile.logOut), findsOneWidget);
      });

      testWidgets('a double tap on the confirmation signs out once', (
        tester,
      ) async {
        final auth = FakeAuthRepository();
        final store = AuthSessionStore()..save(signedIn);
        await pumpProfile(tester, profile.build(auth, store), auth, store);
        await openConfirmation(tester, profile.logOut);

        await tester.tap(inDialog(SignOutStrings.confirm));
        await tester.tap(inDialog(SignOutStrings.confirm), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(auth.signOutCalls, ['refresh-1']);
        expect(store.isSignedIn, isFalse);
        expect(find.byType(LoginScreen), findsOneWidget);
        // The second tap did not pop the stand-in Home out from under Login.
        expect(find.text('home'), findsNothing);
      });

      testWidgets('"Гарах" again while a sign-out is running does nothing', (
        tester,
      ) async {
        final auth = FakeAuthRepository()..holdSignOut = true;
        final store = AuthSessionStore()..save(signedIn);
        await pumpProfile(tester, profile.build(auth, store), auth, store);
        await openConfirmation(tester, profile.logOut);
        await tester.tap(inDialog(SignOutStrings.confirm));
        await tester.pumpAndSettle();

        // The revoke is still in flight: the Profile is up, its button live.
        await tester.tap(find.text(profile.logOut));
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(auth.signOutCalls, ['refresh-1']);

        auth.releaseSignOut();
        await tester.pumpAndSettle();
        expect(auth.signOutCalls, ['refresh-1']);
        expect(store.isSignedIn, isFalse);
        expect(find.byType(LoginScreen), findsOneWidget);
      });

      testWidgets('leaves no authenticated screen to go back to', (
        tester,
      ) async {
        final auth = FakeAuthRepository();
        final store = AuthSessionStore()..save(signedIn);
        await pumpProfile(tester, profile.build(auth, store), auth, store);

        await tapLogOut(tester, profile.logOut);

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        expect(navigator.canPop(), isFalse);
        expect(find.text('home'), findsNothing);
      });

      for (final failure in const [
        AuthFailure(AuthFailureKind.server),
        AuthFailure(AuthFailureKind.network),
        AuthFailure(AuthFailureKind.sessionExpired),
      ]) {
        testWidgets(
          'still signs out when the revoke fails (${failure.kind.name})',
          (tester) async {
            final auth = FakeAuthRepository()..signOutFailure = failure;
            final store = AuthSessionStore()..save(signedIn);
            await pumpProfile(tester, profile.build(auth, store), auth, store);

            await tapLogOut(tester, profile.logOut);

            expect(auth.signOutCalls, ['refresh-1']);
            expect(store.isSignedIn, isFalse);
            expect(find.byType(LoginScreen), findsOneWidget);
            // Nothing about the failed revoke reaches the student.
            expect(find.byType(SnackBar), findsNothing);
            expect(find.text(LoginStrings.serverError), findsNothing);
            expect(find.text(LoginStrings.networkError), findsNothing);
          },
        );
      }

      testWidgets('skips the revoke when the session has no refresh token', (
        tester,
      ) async {
        final auth = FakeAuthRepository();
        final store = AuthSessionStore()
          ..save(const AuthSession(accessToken: 'access-only'));
        await pumpProfile(tester, profile.build(auth, store), auth, store);

        await tapLogOut(tester, profile.logOut);

        expect(auth.signOutCalls, isEmpty);
        expect(store.isSignedIn, isFalse);
        expect(find.byType(LoginScreen), findsOneWidget);
      });

      testWidgets('a second account can sign in afterwards', (tester) async {
        final auth = FakeAuthRepository();
        final store = AuthSessionStore()..save(signedIn);
        await pumpProfile(tester, profile.build(auth, store), auth, store);
        await tapLogOut(tester, profile.logOut);

        auth.session = const AuthSession(
          accessToken: 'access-2',
          refreshToken: 'refresh-2',
        );
        await tester.enterText(
          find.byType(TextField).at(0),
          'second@ai-academy.asia',
        );
        await tester.enterText(find.byType(TextField).at(1), 'password-2');
        await tester.tap(find.widgetWithText(AppButton, LoginStrings.signIn));
        await tester.pumpAndSettle();

        expect(auth.calls.single.email, 'second@ai-academy.asia');
        expect(store.isSignedIn, isTrue);
        expect(store.accessToken, 'access-2');
        expect(store.session?.refreshToken, 'refresh-2');
        expect(store.authorizationHeader, {'Authorization': 'Bearer access-2'});
      });
    });
  }
}
