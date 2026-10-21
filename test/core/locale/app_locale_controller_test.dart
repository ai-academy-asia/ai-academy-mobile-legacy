import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_locale_persistence.dart';

/// Issue #501: the app's one language state.
void main() {
  tearDown(() => ContentLanguage.prefersEnglish = false);

  test('starts in Mongolian, with Mongolian content', () {
    final controller = AppLocaleController();

    expect(controller.preference, LocalePreference.mongolian);
    expect(controller.locale, const Locale('mn'));
    expect(controller.english, isFalse);
    expect(ContentLanguage.prefersEnglish, isFalse);
  });

  test('supports Mongolian, then English', () {
    expect(AppLocaleController.supportedLocales, const [
      Locale('mn'),
      Locale('en'),
    ]);
  });

  group('attach — restoring the device\'s choice', () {
    test(
      'a saved English is applied, with English content, and notifies',
      () async {
        final controller = AppLocaleController();
        var notified = 0;
        controller.addListener(() => notified++);

        await controller.attach(FakeLocalePersistence(stored: 'en'));

        expect(controller.preference, LocalePreference.english);
        expect(controller.locale, const Locale('en'));
        expect(ContentLanguage.prefersEnglish, isTrue);
        expect(notified, 1);
      },
    );

    test('a saved Mongolian stays Mongolian', () async {
      final controller = AppLocaleController();
      await controller.attach(FakeLocalePersistence(stored: 'mn'));

      expect(controller.preference, LocalePreference.mongolian);
      expect(ContentLanguage.prefersEnglish, isFalse);
    });

    test(
      'nothing saved, an unknown value or a failed read: Mongolian',
      () async {
        for (final persistence in [
          FakeLocalePersistence(),
          FakeLocalePersistence(stored: 'fr'),
          FakeLocalePersistence(stored: ''),
          FakeLocalePersistence(stored: 'en', failRead: true),
        ]) {
          final controller = AppLocaleController();
          await controller.attach(persistence);
          expect(controller.preference, LocalePreference.mongolian);
          expect(ContentLanguage.prefersEnglish, isFalse);
        }
      },
    );
  });

  group('choosing', () {
    test('applies at once, notifies, and saves the choice', () async {
      final persistence = FakeLocalePersistence();
      final controller = AppLocaleController();
      await controller.attach(persistence);
      var notified = 0;
      controller.addListener(() => notified++);

      final saving = controller.setEnglish(true);
      // Already applied, before the save finishes.
      expect(controller.locale, const Locale('en'));
      expect(ContentLanguage.prefersEnglish, isTrue);
      expect(notified, 1);
      expect(await saving, isTrue);
      expect(persistence.stored, 'en');

      expect(await controller.setEnglish(false), isTrue);
      expect(controller.preference, LocalePreference.mongolian);
      expect(ContentLanguage.prefersEnglish, isFalse);
      expect(persistence.stored, 'mn');
      expect(notified, 2);
    });

    test('choosing the current language does not notify again', () async {
      final controller = AppLocaleController();
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.setPreference(LocalePreference.mongolian);

      expect(notified, 0);
    });

    test('a failed save keeps the choice for this session', () async {
      final persistence = FakeLocalePersistence()..failWrite = true;
      final controller = AppLocaleController();
      await controller.attach(persistence);

      expect(await controller.setEnglish(true), isFalse);

      expect(controller.preference, LocalePreference.english);
      expect(controller.locale, const Locale('en'));
      expect(ContentLanguage.prefersEnglish, isTrue);
    });

    test('quick choices are saved in the order they were made', () async {
      final persistence = FakeLocalePersistence();
      final controller = AppLocaleController();
      await controller.attach(persistence);

      final first = controller.setEnglish(true);
      final second = controller.setEnglish(false);
      await Future.wait([first, second]);

      expect(persistence.writes, ['en', 'mn']);
      expect(persistence.stored, 'mn');
      expect(controller.preference, LocalePreference.mongolian);
    });

    test('before attach — no storage yet — a choice still applies', () async {
      final controller = AppLocaleController();

      expect(await controller.setEnglish(true), isTrue);
      expect(controller.preference, LocalePreference.english);
    });
  });
}
