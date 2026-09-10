import 'package:aia_mobile/features/auth/domain/auth_failure.dart';
import 'package:aia_mobile/features/auth/presentation/login_controller.dart';
import 'package:aia_mobile/features/auth/presentation/login_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';

void main() {
  group('validateIdentifier', () {
    test('rejects an empty value', () {
      expect(LoginController.validateIdentifier(''), LoginStrings.identifierRequired);
      expect(LoginController.validateIdentifier('   '), LoginStrings.identifierRequired);
    });

    test('accepts a Mongolian mobile number', () {
      expect(LoginController.validateIdentifier('99112233'), isNull);
      expect(LoginController.validateIdentifier(' 99112233 '), isNull);
    });

    test('accepts a number written with separators or a country code', () {
      expect(LoginController.validateIdentifier('+976 9911 2233'), isNull);
      expect(LoginController.validateIdentifier('9911-2233'), isNull);
    });

    test('rejects a number that is too short to be one', () {
      expect(LoginController.validateIdentifier('9911'), LoginStrings.identifierInvalid);
    });

    test('anything with an @ is judged as an address', () {
      expect(LoginController.validateIdentifier('suragch@ai-academy.asia'), isNull);
      for (final value in ['sain@', '@aia.mn', 'sain@aia', 'a b@aia.mn']) {
        expect(
          LoginController.validateIdentifier(value),
          LoginStrings.identifierInvalid,
          reason: '"$value" should not pass',
        );
      }
    });

    test('rejects letters that are neither a number nor an address', () {
      expect(
        LoginController.validateIdentifier('sain-baina-uu'),
        LoginStrings.identifierInvalid,
      );
    });
  });

  group('validatePassword', () {
    test('rejects an empty password', () {
      expect(LoginController.validatePassword(''), LoginStrings.passwordRequired);
    });

    test('rejects a password under six characters', () {
      expect(LoginController.validatePassword('12345'), LoginStrings.passwordTooShort);
    });

    test('accepts six characters or more, spaces included', () {
      expect(LoginController.validatePassword('123456'), isNull);
      expect(LoginController.validatePassword('      '), isNull);
    });
  });

  group('submit', () {
    late FakeAuthRepository repository;
    late LoginController controller;

    setUp(() {
      repository = FakeAuthRepository();
      controller = LoginController(repository: repository);
    });

    tearDown(() => controller.dispose());

    test('does not call the API when the form is invalid', () async {
      controller.identifier.text = 'sain-baina-uu';
      controller.password.text = '123';

      expect(await controller.submit(), isNull);
      expect(repository.calls, isEmpty);
      expect(controller.identifierError, LoginStrings.identifierInvalid);
      expect(controller.passwordError, LoginStrings.passwordTooShort);
    });

    test('sends the trimmed identifier as the API email field', () async {
      controller.identifier.text = '  99112233 ';
      controller.password.text = 'nuutsug123';

      final session = await controller.submit();

      expect(session?.accessToken, 'test-token');
      // The contract has one identifier field; a phone number rides in it.
      expect(repository.calls.single.email, '99112233');
      // The password goes through untouched — trimming it would silently
      // change what the user typed.
      expect(repository.calls.single.password, 'nuutsug123');
    });

    test('reports rejected credentials as a form error', () async {
      repository.failure = const AuthFailure(AuthFailureKind.invalidCredentials);
      controller.identifier.text = '99112233';
      controller.password.text = 'buruu-nuutsug';

      expect(await controller.submit(), isNull);
      expect(controller.formError, LoginStrings.invalidCredentials);
    });

    test('distinguishes a network failure from a server failure', () async {
      controller.identifier.text = '99112233';
      controller.password.text = 'nuutsug123';

      repository.failure = const AuthFailure(AuthFailureKind.network);
      await controller.submit();
      expect(controller.formError, LoginStrings.networkError);

      repository.failure = const AuthFailure(AuthFailureKind.server);
      await controller.submit();
      expect(controller.formError, LoginStrings.serverError);
    });

    test('clears a stale form error on the next keystroke', () async {
      repository.failure = const AuthFailure(AuthFailureKind.invalidCredentials);
      controller.identifier.text = '99112233';
      controller.password.text = 'buruu-nuutsug';
      await controller.submit();
      expect(controller.formError, isNotNull);

      controller.password.text = 'buruu-nuutsug2';
      expect(controller.formError, isNull);
    });

    test('validates eagerly only after the first submit', () async {
      controller.identifier.text = '9911';
      expect(controller.identifierError, isNull, reason: 'quiet before the first submit');

      await controller.submit();
      expect(controller.identifierError, LoginStrings.identifierInvalid);

      controller.identifier.text = '99112233';
      expect(controller.identifierError, isNull, reason: 'clears as soon as it is valid');
    });

    test('message reports the field error first, then the API error', () async {
      expect(controller.message, isNull);

      controller.identifier.text = '9911';
      controller.password.text = 'nuutsug123';
      await controller.submit();
      expect(controller.message, LoginStrings.identifierInvalid);

      repository.failure = const AuthFailure(AuthFailureKind.invalidCredentials);
      controller.identifier.text = '99112233';
      await controller.submit();
      expect(controller.message, LoginStrings.invalidCredentials);
    });

    test('an empty form submits and comes back with both fields flagged', () async {
      // The button is live even when empty — pressing it is how the reference's
      // error states are reached.
      expect(await controller.submit(), isNull);

      expect(controller.identifierError, LoginStrings.identifierRequired);
      expect(controller.passwordError, LoginStrings.passwordRequired);
      expect(repository.calls, isEmpty);
    });

    test('reports submitting while the request is in flight', () async {
      repository.hold = true;
      controller.identifier.text = '99112233';
      controller.password.text = 'nuutsug123';

      final pending = controller.submit();
      await Future<void>.delayed(Duration.zero);

      expect(controller.submitting, isTrue);

      repository.release();
      await pending;

      expect(controller.submitting, isFalse);
    });

    test('ignores a second submit while one is running', () async {
      repository.hold = true;
      controller.identifier.text = '99112233';
      controller.password.text = 'nuutsug123';

      final first = controller.submit();
      await Future<void>.delayed(Duration.zero);
      expect(await controller.submit(), isNull);

      repository.release();
      await first;

      expect(repository.calls, hasLength(1));
    });
  });
}
