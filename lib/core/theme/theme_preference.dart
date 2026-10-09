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

/// Where the preference is kept. An interface, so tests can fail it.
abstract interface class ThemePreferencePersistence {
  Future<String?> read();

  Future<void> write(String value);
}

/// The preference in the platform's secure storage — the dependency the
/// session already uses (`SecureSessionPersistence`), so nothing is added.
///
/// Under its own [key]: sign-out deletes only the session's key, so the
/// theme survives it.
class SecureThemePreferencePersistence implements ThemePreferencePersistence {
  SecureThemePreferencePersistence({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// The one key the preference is stored under.
  static const String key = 'aia.theme.preference';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: key);

  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);
}
