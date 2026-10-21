import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue #501: the app's language, stored once per device.
void main() {
  group('LocalePreference', () {
    test('parses the two stored names', () {
      expect(LocalePreference.parse('mn'), LocalePreference.mongolian);
      expect(LocalePreference.parse('en'), LocalePreference.english);
    });

    test('a missing or unknown value is no preference', () {
      for (final value in [null, '', 'fr', 'MN', 'english']) {
        expect(LocalePreference.parse(value), isNull, reason: '$value');
      }
    });

    test('each preference is its locale', () {
      expect(LocalePreference.mongolian.locale, const Locale('mn'));
      expect(LocalePreference.english.locale, const Locale('en'));
    });
  });

  group('SecureLocalePreferencePersistence', () {
    test('one device-level key — no account in it', () {
      expect(SecureLocalePreferencePersistence.key, 'aia.locale.preference');
    });

    test('nothing stored reads as null; a write reads back', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final persistence = SecureLocalePreferencePersistence();

      expect(await persistence.read(), isNull);
      await persistence.write('en');
      expect(await persistence.read(), 'en');
      // A fresh instance — a restart — finds the same value.
      expect(await SecureLocalePreferencePersistence().read(), 'en');
    });

    test(
      'another key — the theme\'s or the session\'s — is never read',
      () async {
        FlutterSecureStorage.setMockInitialValues({
          'aia.theme.preference.9': 'en',
          'aia.session': 'en',
        });

        expect(await SecureLocalePreferencePersistence().read(), isNull);
      },
    );
  });
}
