import 'dart:ui' show Tristate;

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
import 'fake_current_user_repository.dart';

/// Every role's Profile has a working "Light mode" switch (Issue #284), and
/// all three show and write the one `AppThemeController` preference — so no
/// role can be left in a theme it cannot leave.
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

  Finder lightSwitch() => find.bySemanticsLabel(ProfileStrings.lightMode).last;

  bool on(WidgetTester tester) =>
      tester.getSemantics(lightSwitch()).flagsCollection.isToggled ==
      Tristate.isTrue;

  Brightness brightness(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

  for (final role in roles.keys) {
    group(role, () {
      testWidgets('shows the saved preference: Dark reads off, Light on', (
        tester,
      ) async {
        for (final (stored, expected) in [('dark', false), ('light', true)]) {
          final theme = AppThemeController();
          await theme.restore(_Memory(stored));
          await pumpRole(tester, role, theme);
          expect(on(tester), expected, reason: stored);
        }
      });

      testWidgets('Dark → Light → Dark: the whole app follows at once, and '
          'each choice is saved to the one preference', (tester) async {
        final storage = _Memory('dark');
        final theme = AppThemeController();
        await theme.restore(storage);
        await pumpRole(tester, role, theme);
        expect(brightness(tester), Brightness.dark);
        expect(
          tester.element(find.byType(Scaffold).first).palette,
          same(AppPalette.dark),
        );

        await tester.tap(lightSwitch());
        await tester.pumpAndSettle();
        expect(on(tester), isTrue);
        expect(theme.preference, ThemePreference.light);
        expect(brightness(tester), Brightness.light);

        await tester.tap(lightSwitch());
        await tester.pumpAndSettle();
        expect(on(tester), isFalse);
        expect(theme.preference, ThemePreference.dark);
        expect(brightness(tester), Brightness.dark);
        expect(storage.writes, ['light', 'dark']);
      });
    });
  }

  testWidgets('one preference across roles: chosen on Teacher, read on '
      'Junior and Adult — as after signing in as another role', (tester) async {
    final storage = _Memory(null);
    final theme = AppThemeController();
    await theme.restore(storage);
    await pumpRole(tester, 'Teacher', theme);
    await tester.tap(lightSwitch());
    await tester.pumpAndSettle();
    expect(storage.value, 'dark');

    // A later launch restores the same key for whichever role signs in.
    for (final role in ['Junior', 'Adult']) {
      final next = AppThemeController();
      await next.restore(storage);
      await pumpRole(tester, role, next);
      expect(on(tester), isFalse, reason: role);
      expect(brightness(tester), Brightness.dark, reason: role);
    }
  });
}

/// A `ThemePreferencePersistence` in memory, recording what is written.
class _Memory implements ThemePreferencePersistence {
  _Memory(this.value);

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
