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

/// Dark Mode Phase 10 (Issue #278): one theme preference for the whole app,
/// saved, restored before the first frame — and, while the candidate dark
/// palette is unapproved, unable to reach it from any production path.
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
      await persistence.write('light');
      expect(await persistence.read(), 'light');
    });

    test('survives sign-out: clearing the session leaves it', () async {
      FlutterSecureStorage.setMockInitialValues({
        SecureThemePreferencePersistence.key: 'light',
      });
      final store = AuthSessionStore();
      await store.attach(SecureSessionPersistence());
      store.save(const AuthSession(accessToken: 'a', userType: UserType.adult));
      await store.flush();

      // What `signOutToLogin` does locally.
      store.clear();
      await store.flush();

      expect(await SecureSessionPersistence().read(), isNull);
      expect(await SecureThemePreferencePersistence().read(), 'light');
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

    test('a saved dark or system: light while the dark values are '
        'unapproved — and the stored value is left as it was', () async {
      for (final stored in ['dark', 'system']) {
        final storage = _Memory(stored);
        final controller = await restored(storage);
        expect(controller.preference, ThemePreference.light, reason: stored);
        expect(controller.mode, ThemeMode.light, reason: stored);
        expect(storage.value, stored);
        expect(storage.writes, isEmpty);
      }
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
    test('light is chosen and saved', () async {
      final storage = _Memory(null);
      final controller = AppThemeController();
      await controller.restore(storage);
      expect(await controller.setPreference(ThemePreference.light), isTrue);
      expect(storage.value, 'light');
      expect(controller.mode, ThemeMode.light);
    });

    test('dark and system cannot be chosen while gated: refused, nothing '
        'saved, nothing notified, the mode stays light', () async {
      final storage = _Memory(null);
      final controller = AppThemeController();
      await controller.restore(storage);
      var notified = 0;
      controller.addListener(() => notified++);
      for (final preference in [ThemePreference.dark, ThemePreference.system]) {
        expect(await controller.setPreference(preference), isFalse);
      }
      expect(controller.preference, ThemePreference.light);
      expect(controller.mode, ThemeMode.light);
      expect(storage.writes, isEmpty);
      expect(notified, 0);
    });

    test('a failed write keeps the choice and never throws', () async {
      final controller = AppThemeController();
      await controller.restore(_Failing());
      expect(await controller.setPreference(ThemePreference.light), isTrue);
      expect(controller.preference, ThemePreference.light);
    });
  });

  group('the production gate', () {
    test('only light is available while the dark values are unapproved', () {
      expect(AppThemeController.isAvailable(ThemePreference.light), isTrue);
      expect(AppThemeController.isAvailable(ThemePreference.dark), isFalse);
      expect(AppThemeController.isAvailable(ThemePreference.system), isFalse);
    });

    test('the gate agrees with the proposal: off while §17 is unchecked', () {
      final proposal = File(
        'docs/design-system/DARK_MODE_DESIGN_PROPOSAL.md',
      ).readAsStringSync();
      final unchecked = proposal.contains(
        '- [ ] **Every dark value in §4, §11 and §12:**',
      );
      expect(
        AppThemeController.darkThemeApproved,
        !unchecked,
        reason:
            'darkThemeApproved must change only with the §17 approval '
            'recorded in DARK_MODE_DESIGN_PROPOSAL.md',
      );
    });

    test(
      'no preference, saved or chosen, reaches a mode other than light',
      () async {
        for (final stored in [null, 'light', 'dark', 'system', 'x']) {
          final controller = AppThemeController();
          await controller.restore(_Memory(stored));
          for (final choice in ThemePreference.values) {
            await controller.setPreference(choice);
            expect(controller.mode, ThemeMode.light, reason: '$stored/$choice');
          }
        }
      },
    );
  });

  group('debug-only dark preview (Issue #280)', () {
    test('allowed only in a debug build that asks for it', () {
      for (final debugBuild in [true, false]) {
        for (final requested in [true, false]) {
          expect(
            AppThemeController.darkPreviewAllowed(
              debugBuild: debugBuild,
              requested: requested,
            ),
            debugBuild && requested,
            reason: 'debug=$debugBuild requested=$requested',
          );
        }
      }
    });

    test('previewing draws dark whatever is saved or chosen, and never '
        'writes the preference', () async {
      for (final stored in [null, 'light', 'dark', 'system', 'x']) {
        final storage = _Memory(stored);
        final controller = AppThemeController();
        await controller.restore(storage, darkPreview: true);
        expect(controller.mode, ThemeMode.dark, reason: '$stored');
        expect(controller.preference, ThemePreference.light);
        await controller.setPreference(ThemePreference.light);
        expect(controller.mode, ThemeMode.dark, reason: '$stored');
        expect(storage.value, isNot('dark'));
      }
    });

    test('not previewing: as before, light', () async {
      final controller = AppThemeController();
      await controller.restore(_Memory('dark'), darkPreview: false);
      expect(controller.mode, ThemeMode.light);
    });

    testWidgets('the whole app follows: the first frame is the candidate', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(393, 852) * 3;
      addTearDown(tester.view.reset);
      final controller = AppThemeController();
      await tester.runAsync(
        () => controller.restore(_Memory(null), darkPreview: true),
      );
      await tester.pumpWidget(AiAcademyApp(themeController: controller));
      final context = tester.element(find.byType(Navigator).first);
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(context.palette, same(AppPalette.dark));
    });
  });

  group('startup', () {
    Future<void> pumpRestored(WidgetTester tester, String? stored) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(393, 852) * 3;
      addTearDown(tester.view.reset);
      // As `main()` does: restore, then run the app.
      final controller = AppThemeController();
      await tester.runAsync(() => controller.restore(_Memory(stored)));
      await tester.pumpWidget(AiAcademyApp(themeController: controller));
    }

    for (final stored in [null, 'light', 'dark', 'system']) {
      testWidgets('the first frame is light, with "$stored" saved — no flash '
          'of the candidate', (tester) async {
        await pumpRestored(tester, stored);
        final context = tester.element(find.byType(Navigator).first);
        expect(Theme.of(context).brightness, Brightness.light);
        expect(context.palette, same(AppPalette.light));
      });
    }
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
