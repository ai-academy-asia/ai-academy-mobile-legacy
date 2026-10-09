import 'dart:ui' show Tristate;

import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/core/theme/app_theme_controller.dart';
import 'package:aia_mobile/core/theme/theme_preference.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_profile_screen.dart';
import 'package:aia_mobile/features/profile/presentation/profile_screen.dart';
import 'package:aia_mobile/features/profile/presentation/profile_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../../support/theme_storage.dart';
import 'fake_current_user_repository.dart';

/// Every role's Profile has a working "Dark mode" switch (Issues #284, #288):
/// on is Dark, off is Light — and
/// all three show and write the one `AppThemeController` — the signed-in
/// account's own preference (Issue #286) — so no role can be left in a theme
/// it cannot leave.
void main() {
  final roles = <String, Widget Function(AppThemeController)>{
    'Adult': (theme) => ProfileScreen(
      repository: FakeCurrentUserRepository(hold: true),
      themeController: theme,
    ),
    'Junior': (theme) => JuniorProfileScreen(
      repository: FakeCurrentUserRepository(hold: true),
      themeController: theme,
    ),
    'Teacher': (theme) => TeacherProfileScreen(
      repository: FakeCurrentUserRepository(hold: true),
      themeController: theme,
    ),
  };

  /// As `AiAcademyApp` does: the app's theme follows the controller.
  Future<void> pumpRole(
    WidgetTester tester,
    String role,
    AppThemeController theme,
  ) async {
    useLogicalViewport(tester, const Size(393, 1400), padding: iPhonePadding);
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: theme,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: theme.mode,
          home: roles[role]!(theme),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder darkSwitch() => find.bySemanticsLabel(ProfileStrings.darkMode).last;

  bool on(WidgetTester tester) =>
      tester.getSemantics(darkSwitch()).flagsCollection.isToggled ==
      Tristate.isTrue;

  Brightness brightness(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

  for (final role in roles.keys) {
    group(role, () {
      testWidgets('the row leads with the Phosphor moon (Issue #288), in '
          'iconInk at the SVG icons\' 90% — visible in Light and in Dark', (
        tester,
      ) async {
        for (final (stored, palette) in [
          ('light', AppPalette.light),
          ('dark', AppPalette.dark),
        ]) {
          final theme = await themeFor(MemoryThemeStorage({'9': stored}));
          await pumpRole(tester, role, theme);
          final moon = tester.widget<Icon>(
            find.descendant(
              of: find
                  .ancestor(
                    of: find.text(ProfileStrings.darkMode),
                    matching: find.byType(Row),
                  )
                  .first,
              matching: find.byType(Icon),
            ),
          );
          expect(moon.icon, AppIcons.moon, reason: stored);
          expect(moon.size, 20, reason: stored);
          expect(
            moon.color,
            palette.iconInk.withValues(alpha: 0.9),
            reason: stored,
          );
        }
      });

      testWidgets('shows the saved preference: Dark reads on, Light off', (
        tester,
      ) async {
        for (final (stored, expected) in [('dark', true), ('light', false)]) {
          final theme = await themeFor(MemoryThemeStorage({'9': stored}));
          await pumpRole(tester, role, theme);
          expect(on(tester), expected, reason: stored);
        }
      });

      testWidgets('Dark → Light → Dark: the whole app follows at once, and '
          'each choice is saved to the one preference', (tester) async {
        final storage = MemoryThemeStorage({'9': 'dark'});
        final theme = await themeFor(storage);
        await pumpRole(tester, role, theme);
        expect(brightness(tester), Brightness.dark);
        expect(
          tester.element(find.byType(Scaffold).first).palette,
          same(AppPalette.dark),
        );

        expect(on(tester), isTrue, reason: 'Dark mode on means Dark');

        // Off: Light.
        await tester.tap(darkSwitch());
        await tester.pumpAndSettle();
        expect(on(tester), isFalse);
        expect(theme.preference, ThemePreference.light);
        expect(brightness(tester), Brightness.light);

        // On: Dark.
        await tester.tap(darkSwitch());
        await tester.pumpAndSettle();
        expect(on(tester), isTrue);
        expect(theme.preference, ThemePreference.dark);
        expect(brightness(tester), Brightness.dark);
        expect(storage.writes, ['9=light', '9=dark']);
      });
    });
  }

  testWidgets('one preference per account, not per device (Issue #286): '
      'Dark chosen by Teacher C is not Junior B\'s or Adult A\'s, and C gets '
      'it back', (tester) async {
    final storage = MemoryThemeStorage();
    // Teacher C (account 31) chooses Dark.
    final theme = await themeFor(storage, account: '31');
    await pumpRole(tester, 'Teacher', theme);
    await tester.tap(darkSwitch());
    await tester.pumpAndSettle();
    expect(on(tester), isTrue);
    expect(storage.values, {'31': 'dark'});

    // Junior B (12), then Adult A (9), sign in on the same device: Light.
    for (final (role, account) in [('Junior', '12'), ('Adult', '9')]) {
      await theme.activateAccount(account);
      await pumpRole(tester, role, theme);
      expect(on(tester), isFalse, reason: role);
      expect(brightness(tester), Brightness.light, reason: role);
    }

    // Teacher C again: their own Dark.
    await theme.activateAccount('31');
    await pumpRole(tester, 'Teacher', theme);
    expect(on(tester), isTrue);
    expect(brightness(tester), Brightness.dark);
  });
}
