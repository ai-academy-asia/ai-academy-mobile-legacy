import 'dart:async';
import 'dart:io';

import 'package:aia_mobile/app.dart';
import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme_controller.dart';
import 'package:aia_mobile/core/theme/theme_preference.dart';
import 'package:aia_mobile/features/auth/data/secure_session_persistence.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/theme_storage.dart';

/// The theme preference (Phase 10, Issue #278): Light or Dark, chosen by the
/// user (Issue #282), **one per signed-in account** (Issue #286), restored
/// before the first frame. System is not offered yet (§16.1).
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
  });

  group('SecureThemePreferencePersistence', () {
    test('one key per account — aia.theme.preference.<id> — apart from the '
        'session and from the legacy device-wide key', () async {
      expect(
        SecureThemePreferencePersistence.keyFor('9'),
        'aia.theme.preference.9',
      );
      expect(
        SecureThemePreferencePersistence.keyFor('9'),
        isNot(SecureSessionPersistence.key),
      );
      FlutterSecureStorage.setMockInitialValues({});
      final persistence = SecureThemePreferencePersistence();
      await persistence.write('9', 'dark');
      expect(await persistence.read('9'), 'dark');
      expect(await persistence.read('12'), isNull);
    });

    test('deleteLegacy removes only the device-wide key', () async {
      FlutterSecureStorage.setMockInitialValues({
        SecureThemePreferencePersistence.legacyKey: 'dark',
        SecureThemePreferencePersistence.keyFor('9'): 'dark',
      });
      await SecureThemePreferencePersistence().deleteLegacy();
      final all = await const FlutterSecureStorage().readAll();
      expect(all.keys, [SecureThemePreferencePersistence.keyFor('9')]);
    });
  });

  group('AppThemeController.activateAccount', () {
    test('no account: light, and nothing read', () async {
      final storage = MemoryThemeStorage({'9': 'dark'});
      final controller = await themeFor(storage, account: null);
      expect(controller.mode, ThemeMode.light);
      expect(storage.reads, isEmpty);
    });

    test('an account that never chose: light', () async {
      final controller = await themeFor(
        MemoryThemeStorage({'9': 'dark'}),
        account: '12',
      );
      expect(controller.preference, ThemePreference.light);
      expect(controller.mode, ThemeMode.light);
    });

    test('an account\'s own saved light or dark', () async {
      final storage = MemoryThemeStorage({'9': 'dark', '12': 'light'});
      expect((await themeFor(storage, account: '9')).mode, ThemeMode.dark);
      expect((await themeFor(storage, account: '12')).mode, ThemeMode.light);
    });

    test(
      'a saved system or unknown value: light, and left as it was',
      () async {
        for (final stored in ['system', 'sepia']) {
          final storage = MemoryThemeStorage({'9': stored});
          final controller = await themeFor(storage);
          expect(controller.mode, ThemeMode.light, reason: stored);
          expect(storage.values['9'], stored);
          expect(storage.writes, isEmpty);
        }
      },
    );

    test('unreadable storage: light, and it never throws', () async {
      final controller = await themeFor(FailingThemeStorage());
      expect(controller.mode, ThemeMode.light);
    });

    test('another account: Light at once — never the previous account\'s '
        'choice — then its own', () async {
      final storage = MemoryThemeStorage({'9': 'dark', '12': 'dark'});
      final controller = await themeFor(storage, account: '9');
      storage.gate = Completer<void>();

      final switching = controller.activateAccount('12');
      expect(controller.mode, ThemeMode.light);
      expect(controller.preference, ThemePreference.light);
      storage.gate!.complete();
      await switching;
      expect(controller.mode, ThemeMode.dark);
    });

    test(
      'a read that finishes after the account changed again is dropped',
      () async {
        final storage = MemoryThemeStorage({'9': 'dark'});
        final controller = await themeFor(storage, account: null);
        storage.gate = Completer<void>();

        final stale = controller.activateAccount('9');
        await controller.activateAccount(null); // signed out meanwhile
        storage.gate!.complete();
        await stale;
        expect(controller.mode, ThemeMode.light);
      },
    );

    test('a read that finishes after a choice is dropped', () async {
      final storage = MemoryThemeStorage({'9': 'dark'});
      final controller = await themeFor(storage, account: null);
      storage.gate = Completer<void>();

      final reading = controller.activateAccount('9');
      final choosing = controller.setPreference(ThemePreference.light);
      storage.gate!.complete();
      await reading;
      await choosing;
      expect(controller.mode, ThemeMode.light);
      expect(storage.values['9'], 'light');
    });
  });

  group('AppThemeController.attach: the legacy device-wide value', () {
    test(
      'is deleted unread — it never becomes any account\'s choice',
      () async {
        final storage = MemoryThemeStorage({}, 'dark');
        final controller = await themeFor(storage, account: '9');
        expect(storage.legacy, isNull);
        expect(controller.mode, ThemeMode.light);
        for (final account in ['12', '31']) {
          await controller.activateAccount(account);
          expect(controller.mode, ThemeMode.light, reason: account);
        }
        expect(storage.writes, isEmpty);
      },
    );

    test('a failed delete never throws', () async {
      await AppThemeController().attach(FailingThemeStorage());
    });
  });

  group('AppThemeController.setPreference', () {
    test('Light → Dark → Light: applied at once, notified, saved under the '
        'account', () async {
      final storage = MemoryThemeStorage();
      final controller = await themeFor(storage);
      var notified = 0;
      controller.addListener(() => notified++);

      expect(await controller.setPreference(ThemePreference.dark), isTrue);
      expect(controller.mode, ThemeMode.dark);
      expect(await controller.setPreference(ThemePreference.light), isTrue);
      expect(controller.mode, ThemeMode.light);
      expect(storage.writes, ['9=dark', '9=light']);
      expect(notified, 2);
    });

    test(
      'with no identified account: applied for now, saved nowhere',
      () async {
        final storage = MemoryThemeStorage();
        final controller = await themeFor(storage, account: null);
        await controller.setPreference(ThemePreference.dark);
        expect(controller.mode, ThemeMode.dark);
        expect(storage.writes, isEmpty);
      },
    );

    test('a write queued when another account signs in lands under the '
        'chooser\'s key', () async {
      final storage = MemoryThemeStorage();
      final controller = await themeFor(storage, account: '9');
      final writing = controller.setPreference(ThemePreference.dark);
      await controller.activateAccount('12');
      await writing;
      expect(storage.values, {'9': 'dark'});
      expect(controller.mode, ThemeMode.light);
    });

    test('choosing the current preference notifies nothing', () async {
      final controller = await themeFor(MemoryThemeStorage({'9': 'dark'}));
      var notified = 0;
      controller.addListener(() => notified++);
      await controller.setPreference(ThemePreference.dark);
      expect(notified, 0);
    });

    test('system cannot be chosen yet: refused, nothing saved, nothing '
        'notified', () async {
      final storage = MemoryThemeStorage({'9': 'dark'});
      final controller = await themeFor(storage);
      var notified = 0;
      controller.addListener(() => notified++);
      expect(await controller.setPreference(ThemePreference.system), isFalse);
      expect(controller.mode, ThemeMode.dark);
      expect(storage.writes, isEmpty);
      expect(notified, 0);
    });

    test('a failed write keeps the choice and never throws', () async {
      final controller = await themeFor(FailingThemeStorage());
      expect(await controller.setPreference(ThemePreference.dark), isTrue);
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
        final controller = await themeFor(MemoryThemeStorage({'9': ?stored}));
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
      // As `main()` does: the account's preference, then the app.
      final controller = await tester.runAsync(
        () => themeFor(MemoryThemeStorage({'9': ?stored})),
      );
      await tester.pumpWidget(AiAcademyApp(themeController: controller));
      return controller!;
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
      testWidgets('the first frame, with "$stored" saved for the account, is '
          'already ${brightness.name} — no flash of the other', (tester) async {
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expectTheme(tester, Brightness.light);
    });
  });
}
