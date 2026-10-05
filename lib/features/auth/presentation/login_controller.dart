import 'package:flutter/widgets.dart';

import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
import '../domain/current_user_repository.dart';
import 'login_strings.dart';

/// Form state and submission for the login screen.
///
/// A plain [ChangeNotifier] — the screen has one form and one request, which
/// does not justify pulling in a state-management package.
///
/// Validation is quiet until the first submit, then eager: complaining about a
/// half-typed email on the third keystroke trains people to ignore the message.
class LoginController extends ChangeNotifier {
  LoginController({required this._repository, this._currentUserRepository}) {
    identifier.addListener(_onFieldChanged);
    password.addListener(_onFieldChanged);
  }

  final AuthRepository _repository;

  /// Reads the signed-in account for [passwordChangeRequired]. Null asks
  /// nothing — the check answers false.
  final CurrentUserRepository? _currentUserRepository;

  /// The first field. Takes a phone number *or* an email address — the design
  /// labels it "Утасны дугаар / Email хаяг" — and whatever is typed is sent as
  /// the API's `email` value, which is the contract's only identifier field.
  final TextEditingController identifier = TextEditingController();
  final TextEditingController password = TextEditingController();

  bool _disposed = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _submitting = false;
  bool _validateEagerly = false;
  String? _identifierError;
  String? _passwordError;
  String? _formError;

  bool get obscurePassword => _obscurePassword;
  bool get rememberMe => _rememberMe;
  bool get submitting => _submitting;
  String? get identifierError => _identifierError;
  String? get passwordError => _passwordError;

  /// Failure of the request as a whole, as opposed to one bad field.
  String? get formError => _formError;

  /// The one line of red text the screen has room for, in priority order.
  /// A field's own red border says *which* field; this says why.
  String? get message => _identifierError ?? _passwordError ?? _formError;

  void toggleObscurePassword() {
    _obscurePassword = !_obscurePassword;
    _notify();
  }

  void setRememberMe({required bool value}) {
    _rememberMe = value;
    _notify();
  }

  void _onFieldChanged() {
    // A new keystroke makes a stale server error meaningless.
    if (_formError != null) _formError = null;
    if (_validateEagerly) {
      _identifierError = validateIdentifier(identifier.text);
      _passwordError = validatePassword(password.text);
    }
    _notify();
  }

  /// Validates, and on success exchanges the credentials for a session.
  ///
  /// Returns the session, or null if the form was invalid or the request
  /// failed — in which case [identifierError], [passwordError] or [formError]
  /// says why.
  Future<AuthSession?> submit() async {
    if (_submitting) return null;

    _validateEagerly = true;
    _identifierError = validateIdentifier(identifier.text);
    _passwordError = validatePassword(password.text);
    _formError = null;

    if (_identifierError != null || _passwordError != null) {
      _notify();
      return null;
    }

    _submitting = true;
    _notify();

    try {
      return await _repository.signIn(
        email: identifier.text.trim(),
        password: password.text,
      );
    } on AuthFailure catch (failure) {
      _formError = _messageFor(failure.kind);
      return null;
    } catch (error) {
      _formError = LoginStrings.unexpectedError;
      return null;
    } finally {
      _submitting = false;
      _notify();
    }
  }

  /// Whether the account just signed in must change its password before
  /// anything else — `GET /auth/me`'s `must_change_password` (Issue #182).
  /// Call it once [submit]'s session is saved, since the request carries it.
  ///
  /// [submitting] stays true while it asks, so the form stays locked and the
  /// button keeps its spinner until the screen navigates.
  ///
  /// The flag is read from `/auth/me`, where it is confirmed; whether the login
  /// response carries it too is UNKNOWN. **When the check itself fails** it
  /// answers false and sign-in continues to Home as it did before the check
  /// existed — the same fallback `SplashScreen` gives a failed `/auth/me` —
  /// and the next sign-in asks again. That fallback is a PRODUCT DECISION
  /// recorded on Issue #182, not a backend rule.
  Future<bool> passwordChangeRequired() async {
    final repository = _currentUserRepository;
    if (repository == null) return false;

    _submitting = true;
    _notify();
    try {
      final user = await repository.getCurrentUser();
      return user.mustChangePassword;
    } catch (_) {
      return false;
    } finally {
      _submitting = false;
      _notify();
    }
  }

  static String _messageFor(AuthFailureKind kind) => switch (kind) {
    AuthFailureKind.invalidCredentials => LoginStrings.invalidCredentials,
    // Sign-in carries no session to expire, so this cannot arrive here; the
    // switch still has to be total.
    AuthFailureKind.sessionExpired => LoginStrings.unexpectedError,
    AuthFailureKind.network => LoginStrings.networkError,
    AuthFailureKind.server => LoginStrings.serverError,
    AuthFailureKind.unexpected => LoginStrings.unexpectedError,
  };

  /// Deliberately loose: the backend is the authority on whether an address
  /// exists, so this only catches input that cannot be an address at all.
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$');

  /// 8 digits covers a Mongolian mobile number; the wider range leaves room
  /// for an international prefix.
  static final RegExp _phonePattern = RegExp(r'^\+?\d{8,15}$');

  /// The field takes either form, so the shape of what was typed decides which
  /// rule applies: an "@" means it was meant as an address, anything else is
  /// read as a phone number.
  static String? validateIdentifier(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return LoginStrings.identifierRequired;

    if (trimmed.contains('@')) {
      return _emailPattern.hasMatch(trimmed) ? null : LoginStrings.identifierInvalid;
    }

    final digits = _phoneDigits(trimmed);
    return _phonePattern.hasMatch(digits) ? null : LoginStrings.identifierInvalid;
  }

  /// What [value] is recognisably meant as, by [validateIdentifier]'s own
  /// rules — never a guess from a partial entry:
  ///
  ///  * an "@" after at least one character is an address, as it is to the
  ///    validator — a phone number never contains one;
  ///  * a whole phone number (the validator's 8–15 digits) is a phone;
  ///  * anything else — empty, a few digits, letters with no "@" yet — is
  ///    [LoginIdentifierKind.unknown]. A number's first digits could still be
  ///    an address's start ("99112233@…"), so they decide nothing.
  static LoginIdentifierKind identifierKindOf(String value) {
    final trimmed = value.trim();
    if (trimmed.indexOf('@') > 0) return LoginIdentifierKind.email;
    if (!trimmed.contains('@') && _phonePattern.hasMatch(_phoneDigits(trimmed))) {
      return LoginIdentifierKind.phone;
    }
    return LoginIdentifierKind.unknown;
  }

  /// The identifier field's floating label: the kind [identifierKindOf] reads
  /// from what is typed, or both while it cannot tell.
  String get identifierLabel => switch (identifierKindOf(identifier.text)) {
    LoginIdentifierKind.phone => LoginStrings.identifierPhoneLabel,
    LoginIdentifierKind.email => LoginStrings.identifierEmailLabel,
    LoginIdentifierKind.unknown => LoginStrings.identifierPlaceholder,
  };

  static String _phoneDigits(String value) => value.replaceAll(RegExp(r'[\s()\-]'), '');

  static String? validatePassword(String value) {
    if (value.isEmpty) return LoginStrings.passwordRequired;
    if (value.length < 6) return LoginStrings.passwordTooShort;
    return null;
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    identifier.removeListener(_onFieldChanged);
    password.removeListener(_onFieldChanged);
    identifier.dispose();
    password.dispose();
    super.dispose();
  }
}

/// What a login identifier is recognisably meant as — see
/// [LoginController.identifierKindOf].
enum LoginIdentifierKind { phone, email, unknown }
