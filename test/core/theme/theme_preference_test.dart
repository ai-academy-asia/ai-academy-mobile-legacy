import 'dart:io';

import 'package:aia_mobile/app.dart';
import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme_controller.dart';
import 'package:aia_mobile/core/theme/theme_preference.dart';
import 'package:aia_mobile/features/auth/data/secure_session_persistence.dart';
import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/auth/domain/user_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// One theme preference for the whole app (Phase 10, Issue #278), saved and
/// restored before the first frame — Light or Dark, chosen by the user
/// (Issue #282). System is not offered yet (§16.1).
void main() {
  group('ThemePreference', () {
    test('parses what it stores, and nothing else', () {
      for (final preference in ThemePreference.values) {
        expect(ThemePreference.parse(preference.storedName), preference);
      }
      for (final unknown in [null, '', 'Dark', 'blue', 'ThemeMode.dark']) {
        expect(ThemePreference.parse(unknown), isNull, reason: '$unknown');
      }
    });

    test('is stored under its own key, apart from the session', () async {
      expect(
        SecureThemePreferencePersistence.key,
        isNot(SecureSessionPersistence.key),
      );
      FlutterSecureStorage.setMockInitialValues({});
      final persistence = SecureThemePreferencePersistence();
      expect(await persistence.read(), isNull);
      await persistence.write('dark');
      expect(await persistence.read(), 'dark');
    });

    test('survives sign-out: clearing the session leaves it, and the next '
        'launch restores it', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final before = AppThemeController();
      await before.restore(SecureThemePreferencePersistence());
      await before.setPreference(ThemePreference.dark);

      final store = AuthSessionStore();
      await store.attach(SecureSessionPersistence());
      store.save(const AuthSession(accessToken: 'a', userType: UserType.adult));
      await store.flush();

      // What `signOutToLogin` does locally.
      store.clear();
      await store.flush();

      expect(await SecureSessionPersistence().read(), isNull);
      expect(await SecureThemePreferencePersistence().read(), 'dark');
      final after = AppThemeController();
      await after.restore(SecureThemePreferencePersistence());
      expect(after.preference, ThemePreference.dark);
      expect(after.mode, ThemeMode.dark);
    });
  });

  group('AppThemeController.restore', () {
    Future<AppThemeController> restored(ThemePreferencePersistence p) async {
      final controller = AppThemeController();
      await controller.restore(p);
      return controller;
    }

    test('no saved preference: light', () async {
      final controller = await restored(_Memory(null));
      expect(controller.preference, ThemePreference.light);
      expect(controller.mode, ThemeMode.light);
    });

    test('a saved light: light', () async {
      final controller = await restored(_Memory('light'));
      expect(controller.preference, ThemePreference.light);
      expect(controller.mode, ThemeMode.light);
    });

    test('a saved dark: dark', () async {
      final controller = await restored(_Memory('dark'));
      expect(controller.preference, ThemePreference.dark);
      expect(controller.mode, ThemeMode.dark);
    });

    test('a saved system: light, as it is not offered yet — and the stored '
        'value is left as it was', () async {
      final storage = _Memory('system');
      final controller = await restored(storage);
      expect(controller.preference, ThemePreference.light);
      expect(controller.mode, ThemeMode.light);
      expect(storage.value, 'system');
      expect(storage.writes, isEmpty);
    });

    test('an unknown value: light', () async {
      final controller = await restored(_Memory('sepia'));
      expect(controller.preference, ThemePreference.light);
      expect(controller.mode, ThemeMode.light);
    });

    test('unreadable storage: light, and it never throws', () async {
      final controller = await restored(_Failing());
      expect(controller.preference, ThemePreference.light);
      expect(controller.mode, ThemeMode.light);
    });
  });

  group('AppThemeController.setPreference', () {
    test('Light → Dark → Light: applied at once, notified, saved', () async {
      final storage = _Memory(null);
      final controller = AppThemeController();
      await controller.restore(storage);
      var notified = 0;
      controller.addListener(() => notified++);

      expect(await controller.setPreference(ThemePreference.dark), isTrue);
      expect(controller.mode, ThemeMode.dark);
      expect(storage.value, 'dark');
      expect(notified, 1);

      expect(await controller.setPreference(ThemePreference.light), isTrue);
      expect(controller.mode, ThemeMode.light);
      expect(storage.value, 'light');
      expect(notified, 2);
    });

    test('choosing the current preference notifies nothing', () async {
      final controller = AppThemeController();
      await controller.restore(_Memory('dark'));
      var notified = 0;
      controller.addListener(() => notified++);
      await controller.setPreference(ThemePreference.dark);
      expect(notified, 0);
    });

    test('system cannot be chosen yet: refused, nothing saved, nothing '
        'notified', () async {
      final storage = _Memory('dark');
      final controller = AppThemeController();
      await controller.restore(storage);
      var notified = 0;
      controller.addListener(() => notified++);
      expect(await controller.setPreference(ThemePreference.system), isFalse);
      expect(controller.preference, ThemePreference.dark);
      expect(controller.mode, ThemeMode.dark);
      expect(storage.writes, isEmpty);
      expect(notified, 0);
    });

    test('a failed write keeps the choice and never throws', () async {
      final controller = AppThemeController();
      await controller.restore(_Failing());
      expect(await controller.setPreference(ThemePreference.dark), isTrue);
      expect(controller.preference, ThemePreference.dark);
      expect(controller.mode, ThemeMode.dark);
    });
  });

  group('availability', () {
    test('Light and Dark can be chosen; System not yet (§16.1)', () {
      expect(AppThemeController.isAvailable(ThemePreference.light), isTrue);
      expect(AppThemeController.isAvailable(ThemePreference.dark), isTrue);
      expect(AppThemeController.isAvailable(ThemePreference.system), isFalse);
    });

    test('the approval agrees with the proposal\'s §17', () {
      final proposal = File(
        'docs/design-system/DARK_MODE_DESIGN_PROPOSAL.md',
      ).readAsStringSync();
      final checked = proposal.contains(
        '- [x] **Every dark value in §4, §11 and §12:**',
      );
      expect(
        AppThemeController.darkThemeApproved,
        checked,
        reason:
            'darkThemeApproved must change only with the §17 approval '
            'recorded in DARK_MODE_DESIGN_PROPOSAL.md',
      );
    });

    test('every stored × chosen combination ends in light or dark, never '
        'system', () async {
      for (final stored in [null, 'light', 'dark', 'system', 'x']) {
        final controller = AppThemeController();
        await controller.restore(_Memory(stored));
        expect(controller.mode, isNot(ThemeMode.system), reason: '$stored');
        for (final choice in ThemePreference.values) {
          await controller.setPreference(choice);
          expect(
            controller.mode,
            isNot(ThemeMode.system),
            reason: '$stored/$choice',
          );
        }
      }
    });
  });

  group('startup and propagation', () {
    Future<AppThemeController> pumpRestored(
      WidgetTester tester,
      String? stored,
    ) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(393, 852) * 3;
      addTearDown(tester.view.reset);
      // As `main()` does: restore, then run the app.
      final controller = AppThemeController();
      await tester.runAsync(() => controller.restore(_Memory(stored)));
      await tester.pumpWidget(AiAcademyApp(themeController: controller));
      return controller;
    }

    void expectTheme(WidgetTester tester, Brightness brightness) {
      final context = tester.element(find.byType(Navigator).first);
      expect(Theme.of(context).brightness, brightness);
      expect(
        context.palette,
        same(
          brightness == Brightness.dark ? AppPalette.dark : AppPalette.light,
        ),
      );
    }

    for (final (stored, brightness) in [
      (null, Brightness.light),
      ('light', Brightness.light),
      ('dark', Brightness.dark),
      ('system', Brightness.light),
    ]) {
      testWidgets('the first frame, with "$stored" saved, is already '
          '${brightness.name} — no flash of the other', (tester) async {
        await pumpRestored(tester, stored);
        expectTheme(tester, brightness);
      });
    }

    testWidgets('a change reaches the running app at once, both ways', (
      tester,
    ) async {
      final controller = await pumpRestored(tester, null);
      expectTheme(tester, Brightness.light);
      await tester.runAsync(
        () => controller.setPreference(ThemePreference.dark),
      );
      // A frame to rebuild, then past MaterialApp's theme animation.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expectTheme(tester, Brightness.dark);
      await tester.runAsync(
        () => controller.setPreference(ThemePreference.light),
      );
      // A frame to rebuild, then past MaterialApp's theme animation.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expectTheme(tester, Brightness.light);
    });
  });
}

/// A [ThemePreferencePersistence] in memory, recording what is written.
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

/// Storage that fails every read and write.
class _Failing implements ThemePreferencePersistence {
  @override
  Future<String?> read() => Future.error(StateError('storage unavailable'));

  @override
  Future<void> write(String value) =>
      Future.error(StateError('storage unavailable'));
}
