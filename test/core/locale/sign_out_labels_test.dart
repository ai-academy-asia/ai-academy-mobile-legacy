import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/l10n.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/auth/presentation/login_screen.dart';
import 'package:aia_mobile/features/auth/presentation/sign_out.dart';
import 'package:aia_mobile/features/auth/presentation/sign_out_strings.dart';
import 'package:aia_mobile/features/auth/presentation/widgets/sign_out_confirmation_dialog.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_profile_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_profile_strings.dart';
import 'package:aia_mobile/features/profile/presentation/profile_screen.dart';
import 'package:aia_mobile/features/profile/presentation/profile_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/auth/fake_auth_repository.dart';
import '../../features/profile/fake_current_user_repository.dart';
import '../../support/screenshot.dart';

/// Issue #521: the sign-out confirmation every Profile opens, in the
/// selected language. Mongolian reads exactly as before.
void main() {
  setUpAll(loadAppFonts);
  final locale = AppLocaleController.instance;
  tearDown(() => locale.setPreference(LocalePreference.mongolian));

  /// The dialog's four lines, by key.
  const copy = <String, ({String mongolian, String english})>{
    'signOutTitle': (mongolian: 'Гарах уу?', english: 'Log out?'),
    'signOutMessage': (
      mongolian: 'Та бүртгэлээс гарахдаа итгэлтэй байна уу?',
      english: 'Are you sure you want to log out of your account?',
    ),
    'signOutConfirm': (mongolian: 'Гарах', english: 'Log out'),
    'signOutCancel': (mongolian: 'Цуцлах', english: 'Cancel'),
  };

  String text(String key, LocalePreference language) =>
      language == LocalePreference.mongolian
      ? copy[key]!.mongolian
      : copy[key]!.english;

  group('the keys', () {
    for (final language in LocalePreference.values) {
      test(language.name, () {
        final s = L10n.of(language);
        expect(
          {
            'signOutTitle': s.signOutTitle,
            'signOutMessage': s.signOutMessage,
            'signOutConfirm': s.signOutConfirm,
            'signOutCancel': s.signOutCancel,
          },
          {for (final key in copy.keys) key: text(key, language)},
        );
      });
    }

    for (final language in LocalePreference.values) {
      test('SignOutStrings in ${language.name}', () async {
        await locale.setPreference(language);
        expect(SignOutStrings.title, text('signOutTitle', language));
        expect(SignOutStrings.message, text('signOutMessage', language));
        expect(SignOutStrings.confirm, text('signOutConfirm', language));
        expect(SignOutStrings.cancel, text('signOutCancel', language));
      });
    }
  });

  const signedIn = AuthSession(
    accessToken: 'access-1',
    refreshToken: 'refresh-1',
  );

  /// Each Profile, with the label of its own log-out row and the screen.
  final profiles =
      <
        ({
          String name,
          String Function() logOut,
          Widget Function(FakeAuthRepository, AuthSessionStore) build,
        })
      >[
        (
          name: 'Adult Profile',
          logOut: () => ProfileStrings.logOut,
          build: (auth, store) => ProfileScreen(
            repository: FakeCurrentUserRepository(hold: true),
            authRepository: auth,
            sessionStore: store,
          ),
        ),
        (
          name: 'Junior Profile',
          logOut: () => JuniorProfileStrings.logOut,
          build: (auth, store) => JuniorProfileScreen(
            repository: FakeCurrentUserRepository(hold: true),
            authRepository: auth,
            sessionStore: store,
          ),
        ),
        (
          name: 'Teacher Profile',
          logOut: () => ProfileStrings.logOut,
          build: (auth, store) => TeacherProfileScreen(
            repository: FakeCurrentUserRepository(hold: true),
            authRepository: auth,
            sessionStore: store,
          ),
        ),
      ];

  /// The Profile over a stand-in Home, with `/login` the real Login — as
  /// `sign_out_test.dart` stacks them — under the language rebuild scope.
  Future<void> pumpProfile(
    WidgetTester tester,
    Widget profile,
    FakeAuthRepository auth,
    AuthSessionStore store, {
    Size size = const Size(393, 852),
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    // A fresh tree: nothing carried over from an earlier pump.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      L10nRebuildScope(
        child: MaterialApp(
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
      ),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(builder: (_) => profile));
    await tester.pumpAndSettle();
  }

  final dialog = find.byType(SignOutConfirmationDialog);
  Finder inDialog(String label) =>
      find.descendant(of: dialog, matching: find.text(label));

  /// Taps the Profile's own log-out row, which opens the confirmation.
  Future<void> openConfirmation(WidgetTester tester, String row) async {
    final label = find.text(row);
    await tester.ensureVisible(label);
    await tester.pumpAndSettle();
    await tester.tap(label);
    await tester.pumpAndSettle();
  }

  for (final profile in profiles) {
    group('${profile.name} in English', () {
      setUp(() => locale.setEnglish(true));

      testWidgets('the confirmation reads in English; Cancel keeps the '
          'session', (tester) async {
        final auth = FakeAuthRepository();
        final store = AuthSessionStore()..save(signedIn);
        await pumpProfile(tester, profile.build(auth, store), auth, store);

        await openConfirmation(tester, profile.logOut());

        expect(dialog, findsOneWidget);
        for (final key in copy.keys) {
          expect(
            inDialog(text(key, LocalePreference.english)),
            findsOneWidget,
            reason: key,
          );
          expect(
            inDialog(text(key, LocalePreference.mongolian)),
            findsNothing,
            reason: key,
          );
        }

        await tester.tap(inDialog('Cancel'));
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(auth.signOutCalls, isEmpty);
        expect(store.isSignedIn, isTrue);
        expect(find.byType(LoginScreen), findsNothing);
      });

      testWidgets('Log out still signs out to Login', (tester) async {
        final auth = FakeAuthRepository();
        final store = AuthSessionStore()..save(signedIn);
        await pumpProfile(tester, profile.build(auth, store), auth, store);

        await openConfirmation(tester, profile.logOut());
        await tester.tap(inDialog('Log out'));
        await tester.pumpAndSettle();

        expect(auth.signOutCalls, ['refresh-1']);
        expect(store.isSignedIn, isFalse);
        expect(find.byType(LoginScreen), findsOneWidget);
      });
    });
  }

  testWidgets('switching language with the confirmation open: its title and '
      'message change; it stays open and still answers', (tester) async {
    final auth = FakeAuthRepository();
    final store = AuthSessionStore()..save(signedIn);
    final profile = profiles.first;
    await pumpProfile(tester, profile.build(auth, store), auth, store);
    await openConfirmation(tester, profile.logOut());
    expect(inDialog('Гарах уу?'), findsOneWidget);

    await locale.setEnglish(true);
    await tester.pump();

    expect(dialog, findsOneWidget);
    expect(inDialog('Log out?'), findsOneWidget);
    expect(
      inDialog('Are you sure you want to log out of your account?'),
      findsOneWidget,
    );
    expect(inDialog('Гарах уу?'), findsNothing);

    await tester.tap(inDialog('Cancel'));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(store.isSignedIn, isTrue);
  });

  testWidgets('English at 2.0× text on a 320 pt phone: no overflow, every '
      'line inside the screen, nothing cut short that Mongolian is not', (
    tester,
  ) async {
    Future<Set<String>> cutShort(LocalePreference language) async {
      await locale.setPreference(language);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final auth = FakeAuthRepository();
      final store = AuthSessionStore()..save(signedIn);
      final profile = profiles.first;
      await pumpProfile(
        tester,
        profile.build(auth, store),
        auth,
        store,
        size: const Size(320, 568),
      );
      await openConfirmation(tester, profile.logOut());
      expect(tester.takeException(), isNull);

      final cut = <String>{};
      for (final key in copy.keys) {
        final label = inDialog(text(key, language));
        expect(label, findsOneWidget, reason: key);
        final rect = tester.getRect(label);
        expect(rect.left, greaterThanOrEqualTo(0), reason: key);
        expect(rect.right, lessThanOrEqualTo(320), reason: key);
        expect(rect.top, greaterThanOrEqualTo(0), reason: key);
        expect(rect.bottom, lessThanOrEqualTo(568), reason: key);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: label, matching: find.byType(RichText)).first,
        );
        if (paragraph.didExceedMaxLines) cut.add(key);
      }
      expect(tester.takeException(), isNull);
      return cut;
    }

    final mongolian = await cutShort(LocalePreference.mongolian);
    final english = await cutShort(LocalePreference.english);
    expect(english.difference(mongolian), isEmpty);
  });
}
