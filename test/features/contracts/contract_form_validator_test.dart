import 'package:aia_mobile/features/contracts/domain/contract_detail.dart';
import 'package:aia_mobile/features/contracts/domain/contract_failure.dart';
import 'package:aia_mobile/features/contracts/domain/contract_form_validator.dart';
import 'package:flutter_test/flutter_test.dart';

/// The client mirror of the backend's contract-form check (Issue #306,
/// `ai-academy-backend` `app/services/contracts/fields.py` at `8dc89df`).
/// Test values only.
void main() {
  /// An adult contract with nothing owed: the five student fields required.
  final adult = ContractRules(
    guardianRequired: false,
    finalPaymentDateRequired: false,
    finalPaymentDateMin: DateTime(2026, 10, 10),
    finalPaymentDateMax: DateTime(2026, 10, 30),
  );

  /// A form that passes [adult].
  const valid = ContractForm(
    lastName: 'Тест',
    firstName: 'Сурагч',
    register: 'АА00000000',
    phone: '00000000',
    email: 'student@example.test',
    address: 'Улаанбаатар, 1-р хороо',
  );

  Map<ContractFormField, ContractFieldReason> check(
    ContractForm form, [
    ContractRules? rules,
  ]) => ContractFormValidator.validate(form, rules ?? adult);

  ContractFieldReason? reasonFor(
    ContractFormField field,
    String value, [
    ContractRules? rules,
  ]) => check(valid.withValue(field, value), rules)[field];

  test('a complete adult form passes', () {
    expect(check(valid), isEmpty);
  });

  group('required (STUDENT_REQUIRED)', () {
    test('the five student fields, and nothing else on an adult form', () {
      expect(check(const ContractForm()), {
        ContractFormField.lastName: ContractFieldReason.required,
        ContractFormField.firstName: ContractFieldReason.required,
        ContractFormField.register: ContractFieldReason.required,
        ContractFormField.phone: ContractFieldReason.required,
        ContractFormField.address: ContractFieldReason.required,
      });
    });

    test('whitespace only is empty once trimmed', () {
      expect(
        reasonFor(ContractFormField.address, '   '),
        ContractFieldReason.required,
      );
    });

    test('e-mail is optional', () {
      expect(reasonFor(ContractFormField.email, ''), isNull);
    });
  });

  group('junior course (GUARDIAN_REQUIRED)', () {
    final junior = ContractRules(
      guardianRequired: true,
      finalPaymentDateRequired: false,
      finalPaymentDateMin: DateTime(2026, 10, 10),
    );

    test('requires all four guardian fields', () {
      expect(check(valid, junior), {
        ContractFormField.guardianRelation: ContractFieldReason.required,
        ContractFormField.guardianLastName: ContractFieldReason.required,
        ContractFormField.guardianFirstName: ContractFieldReason.required,
        ContractFormField.guardianRegister: ContractFieldReason.required,
      });
    });

    test('passes once they are filled', () {
      const withGuardian = ContractForm(
        lastName: 'Тест',
        firstName: 'Сурагч',
        register: 'АА00000000',
        phone: '00000000',
        address: 'Улаанбаатар',
        guardianRelation: 'Ээж',
        guardianLastName: 'Тест',
        guardianFirstName: 'Асран',
        guardianRegister: 'ББ11111111',
      );
      expect(check(withGuardian, junior), isEmpty);
    });

    test(
      'an adult form still checks a guardian register that is filled in',
      () {
        expect(
          reasonFor(ContractFormField.guardianRegister, 'AB12'),
          ContractFieldReason.invalidFormat,
        );
      },
    );
  });

  group('balance owed (final_payment_date)', () {
    final owing = ContractRules(
      guardianRequired: false,
      finalPaymentDateRequired: true,
      finalPaymentDateMin: DateTime(2026, 10, 10),
      finalPaymentDateMax: DateTime(2026, 10, 30),
    );

    test('is required while a balance is owed', () {
      expect(check(valid, owing), {
        ContractFormField.finalPaymentDate: ContractFieldReason.required,
      });
    });

    test('is optional when nothing is owed', () {
      expect(reasonFor(ContractFormField.finalPaymentDate, ''), isNull);
    });

    test('the minimum and maximum are inclusive', () {
      expect(
        reasonFor(ContractFormField.finalPaymentDate, '2026-10-10', owing),
        isNull,
      );
      expect(
        reasonFor(ContractFormField.finalPaymentDate, '2026-10-30', owing),
        isNull,
      );
    });

    test('before the minimum or after the maximum is out of range', () {
      expect(
        reasonFor(ContractFormField.finalPaymentDate, '2026-10-09', owing),
        ContractFieldReason.outOfRange,
      );
      expect(
        reasonFor(ContractFormField.finalPaymentDate, '2026-10-31', owing),
        ContractFieldReason.outOfRange,
      );
    });

    test('a null maximum is no upper bound', () {
      final openEnded = ContractRules(
        guardianRequired: false,
        finalPaymentDateRequired: true,
        finalPaymentDateMin: DateTime(2026, 10, 10),
      );
      expect(
        reasonFor(ContractFormField.finalPaymentDate, '2030-01-01', openEnded),
        isNull,
      );
      expect(
        reasonFor(ContractFormField.finalPaymentDate, '2026-10-09', openEnded),
        ContractFieldReason.outOfRange,
      );
    });

    test('anything but a real YYYY-MM-DD date is an invalid format', () {
      for (final text in [
        '2026/10/20',
        // Python 3.12's fromisoformat accepts this one; the client is
        // deliberately stricter (see ContractFormValidator).
        '20261020',
        '2026-10-20T00:00',
        '2026-02-30',
        '2026-13-01',
        'soon',
      ]) {
        expect(
          reasonFor(ContractFormField.finalPaymentDate, text, owing),
          ContractFieldReason.invalidFormat,
          reason: text,
        );
      }
    });
  });

  group('Cyrillic only (CYRILLIC_ONLY: no Latin letter)', () {
    for (final field in ContractFormValidator.cyrillicOnly) {
      test(field.apiName, () {
        expect(reasonFor(field, 'Тест A'), ContractFieldReason.cyrillicOnly);
        expect(reasonFor(field, 'Тест'), isNull);
      });
    }

    test('digits and punctuation pass — only Latin letters are refused', () {
      expect(
        reasonFor(ContractFormField.address, '3-р хороо, 12 тоот'),
        isNull,
      );
    });
  });

  group('register (RE_REGISTER)', () {
    test('two Cyrillic letters and eight digits', () {
      expect(reasonFor(ContractFormField.register, 'АА00000000'), isNull);
    });

    test('anything else is an invalid format', () {
      for (final text in [
        'AA00000000', // Latin letters
        'А00000000', // one letter
        'АА0000000', // seven digits
        'АА000000000', // nine digits
        'АА0000000X',
        '0000000000',
      ]) {
        expect(
          reasonFor(ContractFormField.register, text),
          ContractFieldReason.invalidFormat,
          reason: text,
        );
      }
    });

    test('lower-case letters pass, and normalise to upper case', () {
      expect(reasonFor(ContractFormField.register, 'аа00000000'), isNull);
      expect(
        ContractFormValidator.normalize(
          valid.withValue(ContractFormField.register, ' уб12345678 '),
        ).register,
        'УБ12345678',
      );
      expect(
        ContractFormValidator.normalize(
          valid.withValue(ContractFormField.guardianRegister, 'бб11111111'),
        ).guardianRegister,
        'ББ11111111',
      );
    });
  });

  group('phone (RE_PHONE)', () {
    test('eight digits', () {
      expect(reasonFor(ContractFormField.phone, '99112233'), isNull);
    });

    test('anything else is an invalid format', () {
      for (final text in ['9911223', '991122334', '9911-223', '+97699112233']) {
        expect(
          reasonFor(ContractFormField.phone, text),
          ContractFieldReason.invalidFormat,
          reason: text,
        );
      }
    });
  });

  group('e-mail (RE_EMAIL)', () {
    test('local@domain.tld passes', () {
      expect(reasonFor(ContractFormField.email, 'a@b.mn'), isNull);
    });

    test('anything else is an invalid format', () {
      for (final text in ['ab.mn', 'a@b', 'a b@c.mn', 'a@@b.mn']) {
        expect(
          reasonFor(ContractFormField.email, text),
          ContractFieldReason.invalidFormat,
          reason: text,
        );
      }
    });
  });

  group('too long (MAX_LENGTH)', () {
    test('over 300 is too long; exactly 300 is not', () {
      expect(reasonFor(ContractFormField.address, 'а' * 300), isNull);
      expect(
        reasonFor(ContractFormField.address, 'а' * 301),
        ContractFieldReason.tooLong,
      );
    });

    test('counted in code points, as Python counts', () {
      // 150 emoji are 300 UTF-16 units but 150 code points.
      expect(
        reasonFor(ContractFormField.email, '😀' * 150),
        isNot(ContractFieldReason.tooLong),
      );
    });

    test('applies to an optional field too', () {
      expect(
        reasonFor(ContractFormField.email, '${'a' * 300}@b.mn'),
        ContractFieldReason.tooLong,
      );
    });
  });

  test('a field reports its first problem only: too long before its '
      'format', () {
    expect(
      reasonFor(ContractFormField.lastName, 'A' * 301),
      ContractFieldReason.tooLong,
    );
  });

  test('normalize trims every field', () {
    final clean = ContractFormValidator.normalize(
      const ContractForm(lastName: '  Тест ', email: ' a@b.mn\n'),
    );
    expect(clean.lastName, 'Тест');
    expect(clean.email, 'a@b.mn');
  });
}
