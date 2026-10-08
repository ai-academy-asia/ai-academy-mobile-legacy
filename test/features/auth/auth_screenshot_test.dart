import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/auth/presentation/login_screen.dart';
import 'package:aia_mobile/features/auth/presentation/reset_password_screen.dart';
import 'package:aia_mobile/features/auth/presentation/widgets/manager_contact_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../profile/fake_current_user_repository.dart';
import 'fake_auth_repository.dart';
import 'fake_password_repository.dart';

/// Light-mode captures of Login, Reset password and the manager contact
/// sheet — the home of `AppButton` and `AppTextField` — taken before any
/// theme migration touches them (Dark Mode Phase 0, Issue #252). They must
/// stay byte-identical while colours move onto `AppPalette`.
void main() {
  setUpAll(loadAppFonts);

  Future<void> capture(WidgetTester tester, String name) async {
    await precacheImages(tester);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/$name.png'),
    );
  }

  testWidgets('Login, empty', (tester) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: LoginScreen(
          repository: FakeAuthRepository(),
          sessionStore: AuthSessionStore(),
          currentUserRepository: FakeCurrentUserRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'login');
  });

  testWidgets('Reset password, empty', (tester) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: ResetPasswordScreen(repository: FakePasswordRepository()),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'reset_password');
  });

  testWidgets('Manager contact sheet, open', (tester) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => chooseManagerContact(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await capture(tester, 'manager_contact_sheet');
  });
}
