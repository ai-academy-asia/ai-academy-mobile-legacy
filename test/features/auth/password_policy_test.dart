import 'package:aia_mobile/features/auth/domain/password_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('individual rules', () {
    test('minLength wants eight characters', () {
      expect(
        PasswordPolicy.isSatisfied(PasswordRequirement.minLength, '1234567'),
        isFalse,
      );
      expect(
        PasswordPolicy.isSatisfied(PasswordRequirement.minLength, '12345678'),
        isTrue,
      );
    });

    test('uppercase and lowercase are judged separately', () {
      const upperOnly = 'ABCDEFGH';
      const lowerOnly = 'abcdefgh';

      expect(
        PasswordPolicy.isSatisfied(PasswordRequirement.uppercase, upperOnly),
        isTrue,
      );
      expect(
        PasswordPolicy.isSatisfied(PasswordRequirement.lowercase, upperOnly),
        isFalse,
      );
      expect(
        PasswordPolicy.isSatisfied(PasswordRequirement.uppercase, lowerOnly),
        isFalse,
      );
      expect(
        PasswordPolicy.isSatisfied(PasswordRequirement.lowercase, lowerOnly),
        isTrue,
      );
    });

    test('digit', () {
      expect(PasswordPolicy.isSatisfied(PasswordRequirement.digit, 'abcdefgh'), isFalse);
      expect(PasswordPolicy.isSatisfied(PasswordRequirement.digit, 'abcdefg1'), isTrue);
    });

    test('special accepts any symbol, not a fixed list', () {
      for (final symbol in ['!', '@', '#', r'$', '%', '^', '&', '*', '±', '€']) {
        expect(
          PasswordPolicy.isSatisfied(PasswordRequirement.special, 'abcdefg$symbol'),
          isTrue,
          reason: '"$symbol" should count as special',
        );
      }
      expect(
        PasswordPolicy.isSatisfied(PasswordRequirement.special, 'abcdefg1'),
        isFalse,
      );
    });

    test('a space alone is not a special character', () {
      expect(
        PasswordPolicy.isSatisfied(PasswordRequirement.special, 'abcd efgh'),
        isFalse,
      );
    });
  });

  group('aggregates', () {
    test('an empty password satisfies nothing', () {
      expect(PasswordPolicy.satisfiedBy(''), isEmpty);
      expect(PasswordPolicy.satisfiedCount(''), 0);
      expect(PasswordPolicy.strength(''), 0);
      expect(PasswordPolicy.isAcceptable(''), isFalse);
    });

    test('counts exactly the rules that pass', () {
      // Eight characters, upper and lower — but no digit and no symbol.
      expect(PasswordPolicy.satisfiedBy('Abcdefgh'), {
        PasswordRequirement.minLength,
        PasswordRequirement.uppercase,
        PasswordRequirement.lowercase,
      });
      expect(PasswordPolicy.satisfiedCount('Abcdefgh'), 3);
      expect(PasswordPolicy.strength('Abcdefgh'), 0.6);
      expect(PasswordPolicy.isAcceptable('Abcdefgh'), isFalse);
    });

    test('a short password can still pass the character rules', () {
      // Everything but the length.
      expect(PasswordPolicy.satisfiedCount('Ab1!'), 4);
      expect(PasswordPolicy.isAcceptable('Ab1!'), isFalse);
    });

    test('all five', () {
      expect(PasswordPolicy.satisfiedCount('Nuutsug1!'), 5);
      expect(PasswordPolicy.strength('Nuutsug1!'), 1.0);
      expect(PasswordPolicy.isAcceptable('Nuutsug1!'), isTrue);
    });

    test('strength rises one fifth at a time', () {
      expect(PasswordPolicy.strength('a'), 0.2);
      expect(PasswordPolicy.strength('aB'), 0.4);
      expect(PasswordPolicy.strength('aB1'), 0.6);
      expect(PasswordPolicy.strength('aB1!'), 0.8);
      expect(PasswordPolicy.strength('aB1!aB1!'), 1.0);
    });
  });
}
