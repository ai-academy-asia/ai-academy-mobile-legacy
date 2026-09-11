import 'auth_session.dart';

/// Holds the signed-in session for the running app.
///
/// Login used to drop the token on the floor: the screen took the [AuthSession],
/// navigated, and let it go. This is where it lives instead, so the first screen
/// that needs an authenticated call can read [authorizationHeader] rather than
/// asking the user to sign in again.
///
/// **In memory only — the token does not survive a restart.** Keeping a bearer
/// token across launches means the platform keychain (`flutter_secure_storage`
/// or equivalent), which is a dependency and a set of platform entitlements
/// this change deliberately does not reach for. Swapping the storage later
/// means reimplementing this one class; nothing above it changes.
///
/// There is no refresh endpoint, so nothing here renews a token. [isExpired]
/// exists so a caller can tell a dead session from a live one and send the user
/// back to login, which is the only recovery the API offers.
class AuthSessionStore {
  AuthSessionStore();

  /// The instance the app runs on. Injected in tests.
  static final AuthSessionStore instance = AuthSessionStore();

  AuthSession? _session;
  DateTime? _expiresAt;

  AuthSession? get session => _session;

  String? get accessToken => _session?.accessToken;

  /// When the token stops being usable, if the backend reported a lifetime.
  /// Null means it reported none — `expires_in` is optional in the contract.
  DateTime? get expiresAt => _expiresAt;

  bool get isSignedIn => _session != null;

  /// True once a reported lifetime has run out.
  ///
  /// A session whose lifetime was never reported is never called expired here:
  /// guessing one would sign people out for no reason. The backend rejecting
  /// the token with a 401 is the authority in that case.
  bool isExpired({DateTime? now}) {
    final expiry = _expiresAt;
    if (expiry == null) return false;
    return !(now ?? DateTime.now()).isBefore(expiry);
  }

  /// Stores the session issued by a successful sign-in.
  void save(AuthSession session, {DateTime? now}) {
    _session = session;
    final lifetime = session.expiresIn;
    _expiresAt = lifetime == null ? null : (now ?? DateTime.now()).add(lifetime);
  }

  /// Forgets the session — sign-out, or a token the backend has rejected.
  void clear() {
    _session = null;
    _expiresAt = null;
  }

  /// The header an authenticated request carries, or empty when signed out.
  ///
  /// `Bearer <access_token>`, matching how every other client in the AI Academy
  /// stack attaches this API's token.
  Map<String, String> get authorizationHeader {
    final token = accessToken;
    return token == null ? const {} : {'Authorization': 'Bearer $token'};
  }
}
