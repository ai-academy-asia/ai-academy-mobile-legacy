import 'package:aia_mobile/features/auth/domain/auth_failure.dart';
import 'package:aia_mobile/features/auth/domain/password_policy.dart';
import 'package:aia_mobile/features/auth/presentation/reset_password_controller.dart';
import 'package:aia_mobile/features/auth/presentation/reset_password_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_password_repository.dart';

void main() {
  late FakePasswordRepository repository;
  late ResetPasswordController controller;

  setUp(() {
    repository = FakePasswordRepository();
    controller = ResetPasswordController(repository: repository);
  });

  tearDown(() => controller.dispose());

  /// A password that passes all five rules.
  const good = 'Nuutsug1!';

  group('validation rules', () {
    test('the current password is only required', () {
      expect(
        ResetPasswordController.validateCurrentPassword(''),
        ResetPasswordStrings.currentPasswordRequired,
      );
      expect(ResetPasswordController.validateCurrentPassword('anything'), isNull);
    });

    test('the new password must clear every requirement', () {
      expect(
        ResetPasswordController.validateNewPassword('', currentPassword: 'x'),
        ResetPasswordStrings.newPasswordRequired,
      );
      expect(
        ResetPasswordController.validateNewPassword('Abcdefgh', currentPassword: 'x'),
        ResetPasswordStrings.newPasswordWeak,
        reason: 'no digit and no symbol',
      );
      expect(
        ResetPasswordController.validateNewPassword(good, currentPassword: 'x'),
        isNull,
      );
    });

    test('the new password cannot equal the current one', () {
      expect(
        ResetPasswordController.validateNewPassword(good, currentPassword: good),
        ResetPasswordStrings.newPasswordSameAsCurrent,
      );
    });

    test('the confirmation must match', () {
      expect(
        ResetPasswordController.validateConfirmPassword('', newPassword: good),
        ResetPasswordStrings.confirmPasswordRequired,
      );
      expect(
        ResetPasswordController.validateConfirmPassword('Nuutsug2!', newPassword: good),
        ResetPasswordStrings.confirmPasswordMismatch,
      );
      expect(
        ResetPasswordController.validateConfirmPassword(good, newPassword: good),
        isNull,
      );
    });
  });

  group('live requirement state', () {
    test('nothing is evaluated until the field is typed in', () {
      expect(controller.requirementsEvaluated, isFalse);
      expect(controller.satisfiedRequirements, isEmpty);
      expect(controller.strength, 0);
    });

    test('tracks the new password as it is typed', () {
      controller.newPassword.text = 'abc';
      expect(controller.requirementsEvaluated, isTrue);
      expect(controller.satisfiedRequirements, {PasswordRequirement.lowercase});
      expect(controller.strength, 0.2);

      controller.newPassword.text = good;
      expect(controller.satisfiedRequirements, hasLength(5));
      expect(controller.strength, 1.0);
    });

    test('notifies as the new password changes, so the panel repaints', () {
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.newPassword.text = 'a';
      controller.newPassword.text = 'aB';

      expect(notifications, greaterThanOrEqualTo(2));
    });
  });

  group('submit', () {
    test('an untouched form flags all three fields and calls nothing', () async {
      expect(await controller.submit(), isFalse);

      expect(
        controller.currentPasswordError,
        ResetPasswordStrings.currentPasswordRequired,
      );
      expect(controller.newPasswordError, ResetPasswordStrings.newPasswordRequired);
      expect(
        controller.confirmPasswordError,
        ResetPasswordStrings.confirmPasswordRequired,
      );
      expect(repository.calls, isEmpty);
    });

    test('a mismatched confirmation blocks the request', () async {
      controller.currentPassword.text = 'Huuchin1!';
      controller.newPassword.text = good;
      controller.confirmPassword.text = 'Nuutsug2!';

      expect(await controller.submit(), isFalse);
      expect(
        controller.confirmPasswordError,
        ResetPasswordStrings.confirmPasswordMismatch,
      );
      expect(controller.currentPasswordError, isNull);
      expect(controller.newPasswordError, isNull);
      expect(repository.calls, isEmpty);
    });

    test('sends both passwords untouched and reports success', () async {
      controller.currentPassword.text = 'Huuchin1!';
      controller.newPassword.text = good;
      controller.confirmPassword.text = good;

      expect(await controller.submit(), isTrue);
      expect(controller.succeeded, isTrue);
      expect(repository.calls.single.currentPassword, 'Huuchin1!');
      expect(repository.calls.single.newPassword, good);
    });

    test('a rejected current password lands on that field, not under the form', () async {
      repository.failure = const AuthFailure(AuthFailureKind.invalidCredentials);
      controller.currentPassword.text = 'Buruu1!aa';
      controller.newPassword.text = good;
      controller.confirmPassword.text = good;

      expect(await controller.submit(), isFalse);
      expect(
        controller.currentPasswordError,
        ResetPasswordStrings.invalidCurrentPassword,
      );
      expect(controller.formError, isNull);
      expect(controller.succeeded, isFalse);
    });

    test('other failures surface under the form', () async {
      controller.currentPassword.text = 'Huuchin1!';
      controller.newPassword.text = good;
      controller.confirmPassword.text = good;

      repository.failure = const AuthFailure(AuthFailureKind.network);
      await controller.submit();
      expect(controller.formError, ResetPasswordStrings.networkError);

      repository.failure = const AuthFailure(AuthFailureKind.server);
      await controller.submit();
      expect(controller.formError, ResetPasswordStrings.serverError);
    });

    test('reports submitting while the request is in flight', () async {
      repository.hold = true;
      controller.currentPassword.text = 'Huuchin1!';
      controller.newPassword.text = good;
      controller.confirmPassword.text = good;

      final pending = controller.submit();
      await Future<void>.delayed(Duration.zero);
      expect(controller.submitting, isTrue);

      repository.release();
      await pending;
      expect(controller.submitting, isFalse);
    });

    test('ignores a second submit while one is running', () async {
      repository.hold = true;
      controller.currentPassword.text = 'Huuchin1!';
      controller.newPassword.text = good;
      controller.confirmPassword.text = good;

      final first = controller.submit();
      await Future<void>.delayed(Duration.zero);
      expect(await controller.submit(), isFalse);

      repository.release();
      await first;
      expect(repository.calls, hasLength(1));
    });

    test('validates eagerly only after the first submit', () async {
      controller.confirmPassword.text = 'mismatch';
      expect(controller.confirmPasswordError, isNull);

      await controller.submit();
      expect(
        controller.confirmPasswordError,
        ResetPasswordStrings.confirmPasswordMismatch,
      );

      controller.currentPassword.text = 'Huuchin1!';
      controller.newPassword.text = good;
      controller.confirmPassword.text = good;
      expect(controller.confirmPasswordError, isNull);
    });

    test('a stale server error clears on the next keystroke', () async {
      repository.failure = const AuthFailure(AuthFailureKind.network);
      controller.currentPassword.text = 'Huuchin1!';
      controller.newPassword.text = good;
      controller.confirmPassword.text = good;
      await controller.submit();
      expect(controller.formError, isNotNull);

      controller.confirmPassword.text = '$good ';
      expect(controller.formError, isNull);
    });
  });

  group('visibility toggles', () {
    test('each field hides independently', () {
      expect(controller.obscureCurrent, isTrue);
      expect(controller.obscureNew, isTrue);
      expect(controller.obscureConfirm, isTrue);

      controller.toggleObscureNew();

      expect(controller.obscureCurrent, isTrue, reason: 'only the new field toggled');
      expect(controller.obscureNew, isFalse);
      expect(controller.obscureConfirm, isTrue);
    });
  });
}
