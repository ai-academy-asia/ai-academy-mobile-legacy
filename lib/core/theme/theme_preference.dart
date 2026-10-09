import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The user's theme choice (Dark Mode Phase 10, Issue #278): one for the
/// whole app — Adult, Junior and Teacher, Login and Splash — never one per
/// role.
///
/// A choice, not a mode: `AppThemeController` decides which `ThemeMode` it
/// becomes, and while the candidate dark palette is unapproved every choice
/// becomes light (see `AppThemeController.darkThemeApproved`).
enum ThemePreference {
  light('light'),
  dark('dark'),
  system('system');

  const ThemePreference(this.storedName);

  /// How it is written to storage. Stable: a stored value outlives builds.
  final String storedName;

  /// The preference stored as [value], or null when there is none or it is
  /// not one this build knows.
  static ThemePreference? parse(String? value) {
    for (final preference in values) {
      if (preference.storedName == value) return preference;
    }
    return null;
  }
}

/// Where each account's preference is kept (Issue #286). An interface, so
/// tests can fail it.
abstract interface class ThemePreferencePersistence {
  /// [account]'s stored preference, or null when it never chose.
  Future<String?> read(String account);

  Future<void> write(String account, String value);

  /// Deletes the device-level value Issues #278–#285 stored, which belongs
  /// to no known account.
  Future<void> deleteLegacy();
}

/// The preference in the platform's secure storage — the dependency the
/// session already uses (`SecureSessionPersistence`), so nothing is added.
///
/// One key per account, [keyFor] its `GET /auth/me` `id`: an account never
/// reads another's choice. Sign-out deletes only the session's key, so each
/// account's choice survives it.
class SecureThemePreferencePersistence implements ThemePreferencePersistence {
  SecureThemePreferencePersistence({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// `aia.theme.preference.<account>`.
  static String keyFor(String account) => '$legacyKey.$account';

  /// The one device-wide key used before Issue #286. Deleted, never read.
  static const String legacyKey = 'aia.theme.preference';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String account) => _storage.read(key: keyFor(account));

  @override
  Future<void> write(String account, String value) =>
      _storage.write(key: keyFor(account), value: value);

  @override
  Future<void> deleteLegacy() => _storage.delete(key: legacyKey);
}
