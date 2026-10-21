import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The app's language: Mongolian or English (Issue #501). One for the whole
/// device — before sign-in, and whichever account signs in — never one per
/// account.
///
/// Today it decides Flutter's own widgets (Material, Widgets, Cupertino) and
/// which side of the API's bilingual `{"mn", "en"}` text is shown. The app's
/// own UI copy is not translated yet: it stays as written, in either
/// language (`docs/ai/PROJECT_CONTEXT.md`).
enum LocalePreference {
  mongolian('mn'),
  english('en');

  const LocalePreference(this.storedName);

  /// How it is written to storage, and the locale's language code. Stable: a
  /// stored value outlives builds.
  final String storedName;

  /// The [Locale] `MaterialApp` is given.
  Locale get locale => Locale(storedName);

  /// The preference stored as [value], or null when there is none or it is
  /// not one this build knows.
  static LocalePreference? parse(String? value) {
    for (final preference in values) {
      if (preference.storedName == value) return preference;
    }
    return null;
  }
}

/// Where the device's preference is kept. An interface, so tests can fail it.
abstract interface class LocalePreferencePersistence {
  /// The stored preference, or null when none was ever chosen.
  Future<String?> read();

  Future<void> write(String value);
}

/// The preference in the platform's secure storage — the dependency the
/// session and the theme already use, so nothing is added.
///
/// One device-level [key], not one per account (unlike the theme's): the
/// language applies before sign-in, and sign-out deletes only the session's
/// own key, so the choice survives any account change.
class SecureLocalePreferencePersistence implements LocalePreferencePersistence {
  SecureLocalePreferencePersistence({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String key = 'aia.locale.preference';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: key);

  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);
}
