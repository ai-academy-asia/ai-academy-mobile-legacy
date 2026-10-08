import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/session_persistence.dart';

/// The session kept in the platform's secure storage — the iOS Keychain, and
/// Android's encrypted storage (Issue #235). `main` attaches it to
/// `AuthSessionStore.instance`.
class SecureSessionPersistence implements SessionPersistence {
  SecureSessionPersistence({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// The one key the session is stored under.
  static const String key = 'aia.auth.session';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: key);

  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete() => _storage.delete(key: key);
}
