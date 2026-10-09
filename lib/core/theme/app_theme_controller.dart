import 'package:flutter/material.dart';

import 'theme_preference.dart';

/// The app's one theme state — light, dark or follow the system — for every
/// experience: Adult, Junior and Teacher read it, and none keeps its own
/// (Issue #252, `docs/design-system/DARK_MODE_ARCHITECTURE_AUDIT.md` §14.1).
///
/// It sits above `MaterialApp` — `AiAcademyApp` listens to it — so it is
/// settled before Splash runs and before any role's shell is chosen, and
/// every route of every role draws in the same theme.
///
/// **The user's choice** (Phase 10, Issue #278) is a [ThemePreference],
/// **one per signed-in account** (Issue #286): [activateAccount] applies the
/// account's own saved choice, Light when it has none, and
/// [setPreference] saves under that account. `main()` restores it before
/// `runApp`, so the first frame is already in it. Every role's Profile
/// writes it. Screens never keep a copy.
///
/// **Light and Dark** (Issue #282): `MaterialApp` carries `AppTheme.dark`
/// (Issue #276), enabled for users since §17 of
/// `DARK_MODE_DESIGN_PROPOSAL.md` records it ([darkThemeApproved]). Profile's
/// "Dark mode" switch chooses between the two. [ThemePreference.system] is
/// not offered (the control type is open, §16.1) and resolves to light.
/// Nothing in `lib/` calls [setMode]; [_modeFor] is the one place a mode
/// other than light is named (`app_palette_dark_test.dart`).
class AppThemeController extends ChangeNotifier {
  AppThemeController([this._mode = ThemeMode.light]);

  /// The app's own, read by `AiAcademyApp`.
  static final AppThemeController instance = AppThemeController();

  /// Whether users may choose Dark. It mirrors the first box of the
  /// proposal's §17; `theme_preference_test.dart` fails if the two disagree.
  static const bool darkThemeApproved = true;

  /// Whether [preference] can be chosen now: Light always, Dark once
  /// [darkThemeApproved], System not yet (§16.1).
  static bool isAvailable(ThemePreference preference) => switch (preference) {
    ThemePreference.light => true,
    ThemePreference.dark => darkThemeApproved,
    ThemePreference.system => false,
  };

  ThemeMode _mode;
  ThemePreference _preference = ThemePreference.light;
  ThemePreferencePersistence? _persistence;
  String? _account;

  /// Bumped by every account change and every choice, so a read begun before
  /// either can never apply (Issue #286).
  int _generation = 0;

  /// The account's read while it is in flight; null once applied, so a
  /// settled controller never hands out a future made in another zone.
  Future<void>? _activation;
  Object? _activationToken;

  /// Writes, in the order the choices were made.
  Future<void> _writes = Future.value();

  /// The mode `MaterialApp` is given.
  ThemeMode get mode => _mode;

  /// The user's choice, as the Profile row shows it.
  ThemePreference get preference => _preference;

  /// Whose preference this is: the signed-in account's `GET /auth/me` `id`,
  /// or null when signed out or not yet identified (Issue #286).
  String? get account => _account;

  /// Completes once the current [account]'s saved preference is applied.
  Future<void> get ready => _activation ?? Future.value();

  /// What every role's Profile "Dark mode" switch shows (Issues #284,
  /// #288): on for [ThemePreference.dark], off for Light.
  bool get darkModeOn => _preference == ThemePreference.dark;

  /// The switch's write: on chooses Dark, off chooses Light.
  Future<bool> setDarkMode(bool on) =>
      setPreference(on ? ThemePreference.dark : ThemePreference.light);

  /// Keeps choices in [persistence] from now on. Called by `main()` before
  /// `runApp`.
  ///
  /// Deletes the device-wide value stored before Issue #286, unread: it
  /// belongs to whichever account chose last, so carrying it to any account
  /// could hand one account's choice to another. Never throws.
  Future<void> attach(ThemePreferencePersistence persistence) async {
    _persistence = persistence;
    try {
      await persistence.deleteLegacy();
    } on Object {
      // Left behind, and never read: harmless.
    }
  }

  /// Switches to [account]'s own preference (Issue #286) — the signed-in
  /// account, or null when there is none. Kept in step with the session by
  /// `followAccountTheme`.
  ///
  /// Light at once, so another account's choice is never shown as this
  /// one's, then [account]'s saved choice once read. No saved value, one
  /// this build does not know or does not offer, or a storage error all
  /// leave Light; nothing is written or deleted. A read that finishes after
  /// another account change, or after a choice, is dropped.
  Future<void> activateAccount(String? account) {
    if (account == _account) return ready;
    _account = account;
    final generation = ++_generation;
    _apply(ThemePreference.light);
    final persistence = _persistence;
    if (account == null || persistence == null) {
      _activation = null;
      return ready;
    }
    final token = _activationToken = Object();
    return _activation = () async {
      ThemePreference? stored;
      try {
        stored = ThemePreference.parse(await persistence.read(account));
      } on Object {
        stored = null;
      }
      if (identical(_activationToken, token)) {
        _activation = null;
        _activationToken = null;
      }
      if (generation != _generation) return;
      if (stored != null && isAvailable(stored)) _apply(stored);
    }();
  }

  /// Chooses [preference] for the whole app and saves it as the current
  /// [account]'s. Returns false, and changes nothing, when it is not
  /// [isAvailable]. With no identified account the choice holds for this
  /// session only — it has no account to be kept under. A failed write keeps
  /// the choice in memory.
  Future<bool> setPreference(ThemePreference preference) async {
    if (!isAvailable(preference)) return false;
    _generation++;
    _apply(preference);
    final account = _account;
    final persistence = _persistence;
    if (account != null && persistence != null) {
      // Bound to the account that chose: a write still queued when another
      // account signs in lands under the chooser's key, never the new one's.
      final write = _writes.then(
        (_) => persistence.write(account, preference.storedName),
      );
      _writes = write.then((_) {}, onError: (Object _) {});
      await _writes;
    }
    return true;
  }

  void _apply(ThemePreference preference) {
    final mode = _modeFor(preference);
    if (preference == _preference && mode == _mode) return;
    _preference = preference;
    _mode = mode;
    notifyListeners();
  }

  /// The one place a preference becomes a mode. Only an available
  /// preference reaches it ([activateAccount], [setPreference]); anything
  /// else is light.
  static ThemeMode _modeFor(ThemePreference preference) =>
      preference == ThemePreference.dark && darkThemeApproved
      ? ThemeMode.dark
      : ThemeMode.light;

  /// Changes the mode for the whole app. Setting the current mode does
  /// nothing.
  void setMode(ThemeMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
  }
}
