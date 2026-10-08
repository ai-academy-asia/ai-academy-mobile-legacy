import 'dart:convert';

import 'auth_session.dart';
import 'session_persistence.dart';
import 'user_type.dart';

/// Holds the signed-in session for the running app.
///
/// Login used to drop the token on the floor: the screen took the [AuthSession],
/// navigated, and let it go. This is where it lives instead, so the first screen
/// that needs an authenticated call can read [authorizationHeader] rather than
/// asking the user to sign in again.
///
/// **It survives a restart once [attach]ed (Issue #235).** The OS routinely
/// kills a backgrounded app — a student switching to another app and back
/// came back to Login. `main` therefore attaches the app's instance to secure
/// device storage before the first frame: [attach] restores what was stored,
/// and from then on every [save] and [clear] is written through, so a rotated
/// refresh token is what the next launch finds and a sign-out leaves nothing
/// behind. A store never attached — every test's `AuthSessionStore()` — is in
/// memory only, exactly as before.
///
/// A session holding a refresh token is renewed by `SessionRefresher`
/// (`POST /auth/refresh`, Issue #176) when its access token runs out, so
/// [isExpired] calls a session dead only when it can no longer be renewed;
/// [isAccessTokenExpired] is the access token's own lifetime.
class AuthSessionStore {
  AuthSessionStore();

  /// The instance the app runs on. Injected in tests.
  static final AuthSessionStore instance = AuthSessionStore();

  AuthSession? _session;
  DateTime? _expiresAt;

  SessionPersistence? _persistence;

  /// Writes to [_persistence], in the order [save] and [clear] were called.
  Future<void> _writes = Future.value();

  /// Bumped by every [save] and [clear], so [attach] can tell that the
  /// session changed while it was reading.
  int _changes = 0;

  AuthSession? get session => _session;

  String? get accessToken => _session?.accessToken;

  /// When the token stops being usable, if the backend reported a lifetime.
  /// Null means it reported none — `expires_in` is optional in the contract.
  DateTime? get expiresAt => _expiresAt;

  bool get isSignedIn => _session != null;

  /// Whether the session holds a refresh token to renew itself with.
  bool get canRefresh => _session?.refreshToken != null;

  /// True once the session can no longer authenticate: its access token's
  /// reported lifetime has run out ([isAccessTokenExpired]) and it holds no
  /// refresh token to renew it with. A refreshable session is not expired —
  /// the next authenticated request renews it.
  bool isExpired({DateTime? now}) =>
      isAccessTokenExpired(now: now) && !canRefresh;

  /// True once the access token's reported lifetime has run out.
  ///
  /// A session whose lifetime was never reported is never called expired here:
  /// guessing one would sign people out for no reason. The backend rejecting
  /// the token with a 401 is the authority in that case.
  bool isAccessTokenExpired({DateTime? now}) {
    final expiry = _expiresAt;
    if (expiry == null) return false;
    return !(now ?? DateTime.now()).isBefore(expiry);
  }

  /// Keeps the session in [persistence] from now on, starting from what it
  /// already holds: a stored session becomes this store's, with the absolute
  /// expiry it was saved with — so an access token that ran out while the app
  /// was closed is renewed by the next request, like any other.
  ///
  /// Never throws. Storage that cannot be read, or a value that cannot be
  /// decoded, simply restores nothing (the unreadable value is deleted): the
  /// cost is one sign-in, never a launch that fails.
  Future<void> attach(SessionPersistence persistence) async {
    _persistence = persistence;
    final changesBefore = _changes;
    final String? stored;
    try {
      stored = await persistence.read();
    } catch (_) {
      return;
    }
    // Signed in (or out) while the read was in flight: that is newer.
    if (stored == null || _changes != changesBefore) return;

    final restored = _decode(stored);
    if (restored == null) {
      _write((p) => p.delete());
      return;
    }
    _session = restored.session;
    _expiresAt = restored.expiresAt;
  }

  /// Completes once every [save] and [clear] so far has reached persistence.
  Future<void> flush() => _writes;

  /// Stores the session issued by a successful sign-in or renewal.
  void save(AuthSession session, {DateTime? now}) {
    _changes++;
    _session = session;
    final lifetime = session.expiresIn;
    _expiresAt = lifetime == null
        ? null
        : (now ?? DateTime.now()).add(lifetime);
    final encoded = _encode(session, _expiresAt);
    _write((p) => p.write(encoded));
  }

  /// Forgets the session — sign-out, or a token the backend has rejected —
  /// on this device too.
  void clear() {
    _changes++;
    _session = null;
    _expiresAt = null;
    _write((p) => p.delete());
  }

  /// Queues [operation] behind the writes already queued, so a quick save
  /// then clear can never land the other way round. A failed write is
  /// dropped: the in-memory session is still right, and the worst outcome is
  /// one more sign-in after a restart.
  void _write(Future<void> Function(SessionPersistence p) operation) {
    final persistence = _persistence;
    if (persistence == null) return;
    _writes = _writes
        .then((_) => operation(persistence))
        .then((_) {}, onError: (Object _) {});
  }

  static String _encode(AuthSession session, DateTime? expiresAt) =>
      jsonEncode({
        'access_token': session.accessToken,
        'refresh_token': session.refreshToken,
        'expires_at': expiresAt?.toUtc().toIso8601String(),
        'user_type': session.userType.name,
      });

  static ({AuthSession session, DateTime? expiresAt})? _decode(String stored) {
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! Map<String, dynamic>) return null;
      final accessToken = decoded['access_token'];
      if (accessToken is! String || accessToken.isEmpty) return null;
      final refreshToken = decoded['refresh_token'];
      final expiresAt = decoded['expires_at'];
      return (
        session: AuthSession(
          accessToken: accessToken,
          refreshToken: refreshToken is String && refreshToken.isNotEmpty
              ? refreshToken
              : null,
          userType: UserType.fromApi(decoded['user_type']),
        ),
        expiresAt: expiresAt is String
            ? DateTime.tryParse(expiresAt)?.toLocal()
            : null,
      );
    } on FormatException {
      return null;
    }
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
