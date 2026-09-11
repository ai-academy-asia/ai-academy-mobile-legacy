import 'package:flutter/widgets.dart';

import '../domain/auth_failure.dart';
import '../domain/password_policy.dart';
import '../domain/password_repository.dart';
import 'reset_password_strings.dart';

/// Form state and submission for the reset-password screen.
///
/// Mirrors `LoginController`: a plain [ChangeNotifier], validation quiet until
/// the first submit and eager afterwards, and the transport behind a repository
/// interface. Three fields instead of two, plus the live requirement checks the
/// design shows under them.
class ResetPasswordController extends ChangeNotifier {
  ResetPasswordController({required this._repository}) {
    currentPassword.addListener(_onFieldChanged);
    newPassword.addListener(_onFieldChanged);
    confirmPassword.addListener(_onFieldChanged);
  }

  final PasswordRepository _repository;

  final TextEditingController currentPassword = TextEditingController();
  final TextEditingController newPassword = TextEditingController();
  final TextEditingController confirmPassword = TextEditingController();

  bool _disposed = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  bool _succeeded = false;
  bool _validateEagerly = false;
  String? _currentError;
  String? _newError;
  String? _confirmError;
  String? _formError;

  bool get obscureCurrent => _obscureCurrent;
  bool get obscureNew => _obscureNew;
  bool get obscureConfirm => _obscureConfirm;
  bool get submitting => _submitting;

  /// True once the password has actually been changed.
  bool get succeeded => _succeeded;

  String? get currentPasswordError => _currentError;
  String? get newPasswordError => _newError;
  String? get confirmPasswordError => _confirmError;

  /// Failure of the request as a whole, as opposed to one bad field.
  String? get formError => _formError;

  /// The one line of text under the form, in priority order. A field's own red
  /// border says *which* field; this says why.
  String? get message => _currentError ?? _newError ?? _confirmError ?? _formError;

  // --- Live requirement state ---------------------------------------------

  /// Which of the five rules the new password currently passes.
  Set<PasswordRequirement> get satisfiedRequirements =>
      PasswordPolicy.satisfiedBy(newPassword.text);

  /// 0.0–1.0, driving the strength meter.
  double get strength => PasswordPolicy.strength(newPassword.text);

  /// Until something is typed the rules are shown neutral rather than failed —
  /// an untouched form should not open covered in red.
  bool get requirementsEvaluated => newPassword.text.isNotEmpty;

  // --- Interaction ---------------------------------------------------------

  void toggleObscureCurrent() {
    _obscureCurrent = !_obscureCurrent;
    _notify();
  }

  void toggleObscureNew() {
    _obscureNew = !_obscureNew;
    _notify();
  }

  void toggleObscureConfirm() {
    _obscureConfirm = !_obscureConfirm;
    _notify();
  }

  void _onFieldChanged() {
    // A new keystroke makes a stale server error meaningless.
    if (_formError != null) _formError = null;
    if (_validateEagerly) _revalidate();
    // Even when not validating eagerly the requirement panel tracks every
    // keystroke, so the screen still has to rebuild.
    _notify();
  }

  void _revalidate() {
    _currentError = validateCurrentPassword(currentPassword.text);
    _newError = validateNewPassword(
      newPassword.text,
      currentPassword: currentPassword.text,
    );
    _confirmError = validateConfirmPassword(
      confirmPassword.text,
      newPassword: newPassword.text,
    );
  }

  /// Validates, and on success asks the repository to change the password.
  ///
  /// Returns true only when the password was actually changed.
  Future<bool> submit() async {
    if (_submitting) return false;

    _validateEagerly = true;
    _revalidate();
    _formError = null;

    if (_currentError != null || _newError != null || _confirmError != null) {
      _notify();
      return false;
    }

    _submitting = true;
    _notify();

    try {
      await _repository.changePassword(
        currentPassword: currentPassword.text,
        newPassword: newPassword.text,
      );
      _succeeded = true;
      return true;
    } on AuthFailure catch (failure) {
      // A refused *credential* means the current password was wrong, so it
      // belongs on that field. A refused *session* does not — reddening the
      // password field would send the user to correct something that is right.
      if (failure.kind == AuthFailureKind.invalidCredentials) {
        _currentError = ResetPasswordStrings.invalidCurrentPassword;
      } else {
        _formError = _messageFor(failure.kind);
      }
      return false;
    } catch (error) {
      _formError = ResetPasswordStrings.unexpectedError;
      return false;
    } finally {
      _submitting = false;
      _notify();
    }
  }

  static String _messageFor(AuthFailureKind kind) => switch (kind) {
    AuthFailureKind.invalidCredentials => ResetPasswordStrings.invalidCurrentPassword,
    AuthFailureKind.sessionExpired => ResetPasswordStrings.sessionExpired,
    AuthFailureKind.network => ResetPasswordStrings.networkError,
    AuthFailureKind.server => ResetPasswordStrings.serverError,
    AuthFailureKind.unexpected => ResetPasswordStrings.unexpectedError,
  };

  // --- Rules ---------------------------------------------------------------

  static String? validateCurrentPassword(String value) =>
      value.isEmpty ? ResetPasswordStrings.currentPasswordRequired : null;

  static String? validateNewPassword(String value, {required String currentPassword}) {
    if (value.isEmpty) return ResetPasswordStrings.newPasswordRequired;
    if (!PasswordPolicy.isAcceptable(value)) {
      return ResetPasswordStrings.newPasswordWeak;
    }
    if (value == currentPassword) {
      return ResetPasswordStrings.newPasswordSameAsCurrent;
    }
    return null;
  }

  static String? validateConfirmPassword(String value, {required String newPassword}) {
    if (value.isEmpty) return ResetPasswordStrings.confirmPasswordRequired;
    if (value != newPassword) {
      return ResetPasswordStrings.confirmPasswordMismatch;
    }
    return null;
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    currentPassword.removeListener(_onFieldChanged);
    newPassword.removeListener(_onFieldChanged);
    confirmPassword.removeListener(_onFieldChanged);
    currentPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
    super.dispose();
  }
}
