import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('preferred', () {
    test('prefers Mongolian when both are present', () {
      const text = LocalizedText(
        en: 'Summer Bootcamp',
        mn: 'Зуны бүтээлч кэмп',
      );
      expect(text.preferred, 'Зуны бүтээлч кэмп');
    });

    test('falls back to English when Mongolian is null', () {
      const text = LocalizedText(en: 'Summer Bootcamp');
      expect(text.preferred, 'Summer Bootcamp');
    });

    test('falls back to English when Mongolian is an empty string', () {
      const text = LocalizedText(en: 'Summer Bootcamp', mn: '');
      expect(text.preferred, 'Summer Bootcamp');
    });

    test('is null when neither is a non-empty string', () {
      expect(const LocalizedText().preferred, isNull);
      expect(const LocalizedText(en: '', mn: '').preferred, isNull);
    });
  });

  // Issue #501: with English selected, English first when it holds text;
  // Mongolian otherwise. The group above is the Mongolian (default) reading.
  group('with English selected', () {
    setUp(() => ContentLanguage.prefersEnglish = true);
    tearDown(() => ContentLanguage.prefersEnglish = false);

    test('prefers English when both are present', () {
      const text = LocalizedText(
        en: 'Summer Bootcamp',
        mn: 'Зуны бүтээлч кэмп',
      );
      expect(text.preferred, 'Summer Bootcamp');
    });

    test('falls back to Mongolian when English is null, empty or blank', () {
      for (final en in [null, '', '   ', '\n\t']) {
        expect(
          LocalizedText(en: en, mn: 'Зуны бүтээлч кэмп').preferred,
          'Зуны бүтээлч кэмп',
          reason: '$en',
        );
      }
    });

    test('is null when neither carries text', () {
      expect(const LocalizedText().preferred, isNull);
      expect(const LocalizedText(en: '', mn: '').preferred, isNull);
    });
  });

  group('preferredText', () {
    tearDown(() => ContentLanguage.prefersEnglish = false);

    test('Mongolian selected (the default): Mongolian first, as before', () {
      expect(ContentLanguage.prefersEnglish, isFalse);
      expect(preferredText('Монгол', 'English'), 'Монгол');
      expect(preferredText(null, 'English'), 'English');
      expect(preferredText('', 'English'), 'English');
      expect(preferredText(null, null), isNull);
    });

    test(
      'English selected: English first, Mongolian when English is blank',
      () {
        ContentLanguage.prefersEnglish = true;
        expect(preferredText('Монгол', 'English'), 'English');
        expect(preferredText('Монгол', '  '), 'Монгол');
        expect(preferredText('Монгол', null), 'Монгол');
        expect(preferredText(null, 'English'), 'English');
        expect(preferredText(null, null), isNull);
      },
    );
  });
}
