import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/domain/auth_failure.dart';
import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/auth/domain/current_user.dart';
import 'package:aia_mobile/features/auth/domain/current_user_failure.dart';
import 'package:aia_mobile/features/auth/domain/session_persistence.dart';
import 'package:aia_mobile/features/auth/presentation/reset_password_screen.dart';
import 'package:aia_mobile/features/auth/presentation/sign_out.dart';
import 'package:aia_mobile/features/auth/presentation/sign_out_strings.dart';
import 'package:aia_mobile/features/auth/presentation/widgets/sign_out_confirmation_dialog.dart';
import 'package:aia_mobile/features/profile/presentation/profile_strings.dart';
import 'package:aia_mobile/features/profile/presentation/widgets/profile_parts.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_profile_screen.dart';
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../auth/fake_auth_repository.dart';
import '../profile/fake_current_user_repository.dart';

/// A teacher's `/auth/me`, in the confirmed shape. Test values only.
const teacher = CurrentUser(
  id: 31,
  actorId: 7,
  actorType: 'teacher',
  email: 'test.teacher@example.mn',
  role: 'teacher',
  isActive: true,
  mustChangePassword: false,
  profile: UserProfile(
    id: 7,
    firstName: 'Test',
    lastName: 'Teacher',
    phone: '99001122',
    uiMode: null,
  ),
);

/// The Teacher Profile (Issue #243): real account data, the shared
/// change-password and sign-out flows, and the frame's unbacked controls
/// drawn but inert.
void main() {
  setUpAll(loadAppFonts);

  Future<void> pump(
    WidgetTester tester, {
    FakeCurrentUserRepository? repository,
    FakeAuthRepository? auth,
    AuthSessionStore? store,
  }) async {
    useLogicalViewport(tester, const Size(393, 966), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        routes: {
          '/': (_) => TeacherProfileScreen(
            repository: repository ?? FakeCurrentUserRepository(user: teacher),
            authRepository: auth ?? FakeAuthRepository(),
            sessionStore: store ?? AuthSessionStore(),
          ),
          loginRoute: (_) => const Scaffold(body: Text('login')),
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  group('account', () {
    testWidgets('name, email and phone come from /auth/me, as returned', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Test Teacher'), findsOneWidget);
      expect(find.text('test.teacher@example.mn'), findsOneWidget);
      expect(find.text('99001122'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Test Teacher')).style,
        profileNameStyle.copyWith(color: AppPalette.light.textPrimary),
      );
    });

    testWidgets('none of the frame\'s example account is drawn', (
      tester,
    ) async {
      await pump(tester);

      for (final example in ['Хулан', 'bayan', '9911', 'ai.asia', '****']) {
        expect(find.textContaining(example), findsNothing, reason: example);
      }
      // The placeholder disc, never a photo.
      expect(find.byType(ProfileAvatar), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('while /auth/me loads, and after it fails, the lines stay '
        'empty', (tester) async {
      final held = FakeCurrentUserRepository(user: teacher, hold: true);
      await pump(tester, repository: held);
      expect(find.text('Test Teacher'), findsNothing);
      expect(find.text('test.teacher@example.mn'), findsNothing);

      await pump(
        tester,
        repository: FakeCurrentUserRepository(
          failure: const CurrentUserFailure(CurrentUserFailureKind.network),
        ),
      );
      expect(find.text('Test Teacher'), findsNothing);
      expect(find.text('99001122'), findsNothing);
    });
  });

  group('layout, as the frame measures it', () {
    testWidgets('title band, avatar hero, captions and rows', (tester) async {
      await pump(tester);

      // "Profile" in the 63pt band under the 44pt status bar.
      expect(find.text(ProfileStrings.heading), findsOneWidget);
      final firstRule = tester.getTopLeft(find.byType(ProfileRule).first).dy;
      expect(firstRule, 44 + ProfileMetrics.headerHeight);

      // The 72pt avatar, 33 below the rule, 17 in — the Teacher frame's own
      // hero, a point off the Adult one each way; the text 8 after it.
      final avatar = tester.getRect(find.byType(ProfileAvatar));
      expect(avatar.size, const Size.square(72));
      expect(avatar.left, 17);
      expect(avatar.top, firstRule + 1 + 33);
      expect(tester.getTopLeft(find.text('Test Teacher')).dx, 97);
      // The band under the hero closes 32 below the avatar.
      expect(
        tester.getTopLeft(find.byType(ProfileRule).at(1)).dy,
        avatar.bottom + 32,
      );

      // The frame's sections, in its order.
      final ys = [
        for (final label in [
          ProfileStrings.appSettingsSection,
          ProfileStrings.language,
          ProfileStrings.changePassword,
          ProfileStrings.notificationSection,
          ProfileStrings.helpCenter,
          ProfileStrings.termsOfService,
          ProfileStrings.privacyPolicy,
          ProfileStrings.logOut,
        ])
          tester.getTopLeft(find.text(label).first).dy,
      ];
      expect(ys, orderedEquals([...ys]..sort()));
      expect(find.text(ProfileStrings.contactSection), findsOneWidget);
      // No adult-only rows.
      for (final adultOnly in [
        ProfileStrings.accountSection,
        ProfileStrings.eContract,
        ProfileStrings.certificate,
        ProfileStrings.transactionHistory,
        ProfileStrings.lightMode,
        ProfileStrings.editProfile,
      ]) {
        expect(find.text(adultOnly), findsNothing, reason: adultOnly);
      }
    });

    testWidgets('draws no tab bar of its own — the shell owns it', (
      tester,
    ) async {
      await pump(tester);

      expect(find.byType(AppBottomNav), findsNothing);
    });

    testWidgets('no version line: the app does not read its version', (
      tester,
    ) async {
      await pump(tester);

      expect(find.textContaining('Version'), findsNothing);
      expect(find.textContaining('1.2.4'), findsNothing);
    });
  });

  group('change password', () {
    testWidgets('opens the shared change-password screen, with a way back', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text(ProfileStrings.changePassword));
      await tester.pumpAndSettle();

      final screen = tester.widget<ResetPasswordScreen>(
        find.byType(ResetPasswordScreen),
      );
      expect(screen.showBackButton, isTrue);
      Navigator.of(tester.element(find.byType(ResetPasswordScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(TeacherProfileScreen), findsOneWidget);
    });
  });

  group('unbacked controls stay inert', () {
    testWidgets('MN/EN shows MN and a tap changes nothing', (tester) async {
      await pump(tester);

      await tester.tap(find.text(ProfileStrings.languageEn));
      await tester.pumpAndSettle();

      final toggle = tester.widget<ProfileLanguageToggle>(
        find.byType(ProfileLanguageToggle),
      );
      expect(toggle.english, isFalse);
      expect(toggle.onChanged, isNull);
    });

    testWidgets('the Notification switch shows off and a tap changes nothing', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.byType(ProfileSwitch));
      await tester.pumpAndSettle();

      final toggle = tester.widget<ProfileSwitch>(find.byType(ProfileSwitch));
      expect(toggle.value, isFalse);
      expect(toggle.onChanged, isNull);
    });

    testWidgets(
      'Help center, Term of Service and Privacy Policy open nothing',
      (tester) async {
        await pump(tester);

        for (final label in [
          ProfileStrings.helpCenter,
          ProfileStrings.termsOfService,
          ProfileStrings.privacyPolicy,
        ]) {
          final row = tester.widget<ProfileRow>(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(ProfileRow),
            ),
          );
          expect(row.onTap, isNull, reason: label);
          await tester.ensureVisible(find.text(label));
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(find.byType(TeacherProfileScreen), findsOneWidget);
        }
      },
    );
  });

  group('log out', () {
    const signedIn = AuthSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );

    Future<void> logOut(WidgetTester tester) async {
      await tester.ensureVisible(find.text(ProfileStrings.logOut));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ProfileStrings.logOut));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(SignOutConfirmationDialog),
          matching: find.text(SignOutStrings.confirm),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('revokes the refresh token, clears the session — its '
        'persisted copy too — and lands on Login', (tester) async {
      final storage = _MemoryPersistence();
      final store = AuthSessionStore();
      await tester.runAsync(() => store.attach(storage));
      store.save(signedIn);
      final auth = FakeAuthRepository();
      await pump(tester, auth: auth, store: store);

      await logOut(tester);
      await tester.runAsync(store.flush);

      expect(auth.signOutCalls, ['refresh-1']);
      expect(store.isSignedIn, isFalse);
      expect(storage.value, isNull);
      expect(find.text('login'), findsOneWidget);
      expect(find.byType(TeacherProfileScreen), findsNothing);
    });

    testWidgets('cancelling the confirmation keeps the session', (
      tester,
    ) async {
      final store = AuthSessionStore()..save(signedIn);
      final auth = FakeAuthRepository();
      await pump(tester, auth: auth, store: store);

      await tester.ensureVisible(find.text(ProfileStrings.logOut));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ProfileStrings.logOut));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(SignOutConfirmationDialog),
          matching: find.text(SignOutStrings.cancel),
        ),
      );
      await tester.pumpAndSettle();

      expect(auth.signOutCalls, isEmpty);
      expect(store.isSignedIn, isTrue);
      expect(find.byType(TeacherProfileScreen), findsOneWidget);
    });

    testWidgets('a failed revoke still signs out locally', (tester) async {
      final store = AuthSessionStore()..save(signedIn);
      final auth = FakeAuthRepository()
        ..signOutFailure = const AuthFailure(AuthFailureKind.network);
      await pump(tester, auth: auth, store: store);

      await logOut(tester);

      expect(store.isSignedIn, isFalse);
      expect(find.text('login'), findsOneWidget);
    });
  });
}

/// Device storage, in memory.
class _MemoryPersistence implements SessionPersistence {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;

  @override
  Future<void> delete() async => value = null;
}
