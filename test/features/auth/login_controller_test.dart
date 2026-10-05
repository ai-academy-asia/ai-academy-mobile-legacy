import 'package:aia_mobile/features/auth/domain/auth_failure.dart';
import 'package:aia_mobile/features/auth/domain/current_user.dart';
import 'package:aia_mobile/features/auth/domain/current_user_failure.dart';
import 'package:aia_mobile/features/auth/presentation/login_controller.dart';
import 'package:aia_mobile/features/auth/presentation/login_strings.dart';
import 'package:aia_mobile/features/auth/presentation/manager_contact.dart';
import 'package:flutter_test/flutter_test.dart';

import '../profile/fake_current_user_repository.dart';
import 'fake_auth_repository.dart';

void main() {
  group('identifierKindOf', () {
    LoginIdentifierKind kindOf(String value) => LoginController.identifierKindOf(value);

    test('empty or partial input is not classified', () {
      for (final value in [
        '',
        '   ',
        '9',
        '9911',
        '+976',
        'j',
        'jr10.s01',
        '@',
        '@aia',
      ]) {
        expect(kindOf(value), LoginIdentifierKind.unknown, reason: '"$value"');
      }
    });

    test('a whole phone number, as the validator accepts it, is a phone', () {
      for (final value in ['99112233', ' 99112233 ', '+976 9911 2233', '9911-2233']) {
        expect(kindOf(value), LoginIdentifierKind.phone, reason: '"$value"');
      }
    });

    test('an "@" after a character is an address, even mid-way', () {
      for (final value in ['jr10.s01@', 'jr10.s01@test.ai-academy.asia', '99112233@']) {
        expect(kindOf(value), LoginIdentifierKind.email, reason: '"$value"');
      }
    });

    test('the floating label follows the kind', () {
      final controller = LoginController(repository: FakeAuthRepository());
      addTearDown(controller.dispose);

      expect(controller.identifierLabel, LoginStrings.identifierPlaceholder);
      controller.identifier.text = '99112233';
      expect(controller.identifierLabel, LoginStrings.identifierPhoneLabel);
      controller.identifier.text = 'jr10.s01@test.ai-academy.asia';
      expect(controller.identifierLabel, LoginStrings.identifierEmailLabel);
    });

    test('classifying never validates or changes what is sent', () async {
      final repository = FakeAuthRepository();
      final controller = LoginController(repository: repository);
      addTearDown(controller.dispose);

      controller.identifier.text = ' jr10.s01@test.ai-academy.asia ';
      controller.password.text = 'nuutsug123';
      expect(controller.identifierError, isNull);
      await controller.submit();

      expect(repository.calls.single.email, 'jr10.s01@test.ai-academy.asia');
      expect(repository.calls.single.password, 'nuutsug123');
    });
  });

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

  group('passwordChangeRequired (Issue #182)', () {
    CurrentUser account({required bool mustChangePassword}) => CurrentUser(
      id: 9,
      actorId: 5,
      actorType: 'student',
      email: 'student@example.mn',
      role: 'student',
      isActive: true,
      mustChangePassword: mustChangePassword,
      profile: const UserProfile(
        id: 5,
        firstName: 'A',
        lastName: 'B',
        phone: '99123456',
        uiMode: null,
      ),
    );

    LoginController controllerWith(FakeCurrentUserRepository? currentUser) =>
        LoginController(
          repository: FakeAuthRepository(),
          currentUserRepository: currentUser,
        );

    test('answers GET /auth/me\'s must_change_password', () async {
      for (final flag in [true, false]) {
        final currentUser = FakeCurrentUserRepository(
          user: account(mustChangePassword: flag),
        );
        final controller = controllerWith(currentUser);

        expect(await controller.passwordChangeRequired(), flag);
        expect(currentUser.callCount, 1);
        controller.dispose();
      }
    });

    test(
      'a failed check answers false — sign-in continues as before',
      () async {
        for (final kind in CurrentUserFailureKind.values) {
          final controller = controllerWith(
            FakeCurrentUserRepository(failure: CurrentUserFailure(kind)),
          );

          expect(
            await controller.passwordChangeRequired(),
            isFalse,
            reason: kind.name,
          );
          expect(controller.submitting, isFalse);
          expect(
            controller.formError,
            isNull,
            reason: 'the sign-in itself succeeded',
          );
          controller.dispose();
        }
      },
    );

    test('with no account source it asks nothing and answers false', () async {
      final controller = controllerWith(null);
      expect(await controller.passwordChangeRequired(), isFalse);
      controller.dispose();
    });

    test('keeps submitting true while the check is in flight', () async {
      final currentUser = FakeCurrentUserRepository(
        user: account(mustChangePassword: true),
        hold: true,
      );
      final controller = controllerWith(currentUser);

      final pending = controller.passwordChangeRequired();
      await Future<void>.delayed(Duration.zero);
      expect(controller.submitting, isTrue);

      currentUser.release();
      expect(await pending, isTrue);
      expect(controller.submitting, isFalse);
      controller.dispose();
    });
  });

  group('contactManager (Issue #184)', () {
    /// Records every link handed to the OS, opening only those in [opens].
    ({LoginController controller, List<String> opened}) withLauncher(
      Set<String> opens,
    ) {
      final opened = <String>[];
      final controller = LoginController(
        repository: FakeAuthRepository(),
        openUrl: (url) async {
          opened.add(url.toString());
          return opens.contains(url.toString());
        },
      );
      return (controller: controller, opened: opened);
    }

    test('the confirmed contact, exactly: +976 7505 1055 and '
        'info@ai-academy.asia', () {
      expect(ManagerContact.phone.toString(), 'tel:+97675051055');
      expect(ManagerContact.email.toString(), 'mailto:info@ai-academy.asia');
    });

    test('opens the phone, and stops there when it opens', () async {
      final (:controller, :opened) = withLauncher({'tel:+97675051055'});

      expect(await controller.contactManager(), isTrue);
      expect(opened, ['tel:+97675051055']);
      expect(controller.formError, isNull);
      controller.dispose();
    });

    test('falls back to the email when no app takes the phone', () async {
      final (:controller, :opened) = withLauncher({
        'mailto:info@ai-academy.asia',
      });

      expect(await controller.contactManager(), isTrue);
      expect(opened, ['tel:+97675051055', 'mailto:info@ai-academy.asia']);
      expect(controller.formError, isNull);
      controller.dispose();
    });

    test('when neither opens, the message band says so with the generic '
        'copy', () async {
      final (:controller, :opened) = withLauncher(const {});

      expect(await controller.contactManager(), isFalse);
      expect(opened, ['tel:+97675051055', 'mailto:info@ai-academy.asia']);
      expect(controller.formError, LoginStrings.unexpectedError);
      expect(controller.message, LoginStrings.unexpectedError);
      controller.dispose();
    });

    test(
      'a keystroke clears that message, like any stale form error',
      () async {
        final (:controller, opened: _) = withLauncher(const {});
        await controller.contactManager();

        controller.identifier.text = '9';
        expect(controller.formError, isNull);
        controller.dispose();
      },
    );
  });
}
