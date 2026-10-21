import 'package:flutter/widgets.dart';

import '../models/localized_text.dart';
import 'locale_preference.dart';

/// The app's one language state (Issue #501): `AiAcademyApp` gives its
/// [locale] to `MaterialApp`, and every role's Profile MN/EN control writes
/// it. Screens never keep a copy.
///
/// **Device-level**, not per account: `main()` restores the saved choice
/// with [attach] before `runApp`, so the first frame — Splash and Login
/// included — is already in it, and no account change touches it.
///
/// Mongolian when nothing is saved, the saved value is unknown, or storage
/// cannot be read. A choice applies at once; a save that fails still keeps
/// it for this session. It also sets [ContentLanguage], which side of the
/// API's bilingual text is shown.
class AppLocaleController extends ChangeNotifier {
  AppLocaleController();

  /// The app's own, read by `AiAcademyApp`.
  static final AppLocaleController instance = AppLocaleController();

  /// What `MaterialApp` supports: Mongolian, then English.
  static final List<Locale> supportedLocales = [
    for (final preference in LocalePreference.values) preference.locale,
  ];

  LocalePreference _preference = LocalePreference.mongolian;
  LocalePreferencePersistence? _persistence;

  /// Writes, in the order the choices were made.
  Future<void> _writes = Future.value();

  /// The user's choice, as the Profile control shows it.
  LocalePreference get preference => _preference;

  /// The locale `MaterialApp` is given.
  Locale get locale => _preference.locale;

  /// What every Profile MN/EN control shows: on for English.
  bool get english => _preference == LocalePreference.english;

  /// Restores the device's saved choice and keeps later ones in
  /// [persistence]. Called by `main()` before `runApp`. Never throws:
  /// anything unreadable leaves Mongolian.
  Future<void> attach(LocalePreferencePersistence persistence) async {
    _persistence = persistence;
    LocalePreference? stored;
    try {
      stored = LocalePreference.parse(await persistence.read());
    } on Object {
      stored = null;
    }
    _apply(stored ?? LocalePreference.mongolian);
  }

  /// The MN/EN control's write: true chooses English, false Mongolian.
  Future<bool> setEnglish(bool english) => setPreference(
    english ? LocalePreference.english : LocalePreference.mongolian,
  );

  /// Applies [preference] at once, then saves it. Answers whether the save
  /// succeeded; a failed one keeps the choice for this session.
  Future<bool> setPreference(LocalePreference preference) {
    _apply(preference);
    final persistence = _persistence;
    if (persistence == null) return Future.value(true);
    final saved = _writes.then((_) async {
      try {
        await persistence.write(preference.storedName);
        return true;
      } on Object {
        return false;
      }
    });
    _writes = saved;
    return saved;
  }

  void _apply(LocalePreference preference) {
    ContentLanguage.prefersEnglish = preference == LocalePreference.english;
    if (preference == _preference) return;
    _preference = preference;
    notifyListeners();
  }
}
