import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('preferred', () {
    test('prefers Mongolian when both are present', () {
      const text = LocalizedText(en: 'Summer Bootcamp', mn: 'Зуны бүтээлч кэмп');
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
}
