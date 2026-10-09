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
/// persisted by [restore]'s [ThemePreferencePersistence] and restored by
/// `main()` before `runApp`, so the first frame is already in it. Profile
/// writes it with [setPreference]. Screens never keep a copy.
///
/// **Light and Dark** (Issue #282): `MaterialApp` carries `AppTheme.dark`
/// (Issue #276), enabled for users since §17 of
/// `DARK_MODE_DESIGN_PROPOSAL.md` records it ([darkThemeApproved]). Profile's
/// "Light mode" switch chooses between the two. [ThemePreference.system] is
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

  /// The mode `MaterialApp` is given.
  ThemeMode get mode => _mode;

  /// The user's choice, as the Profile row shows it.
  ThemePreference get preference => _preference;

  /// Reads the saved preference from [persistence], which later choices are
  /// written to. Called by `main()` before `runApp`.
  ///
  /// Never throws and never blocks startup: no saved value, a value this
  /// build does not know, one not [isAvailable], or a storage error all
  /// leave [ThemePreference.light]. A stored value is not overwritten by
  /// reading it.
  Future<void> restore(ThemePreferencePersistence persistence) async {
    _persistence = persistence;
    ThemePreference? stored;
    try {
      stored = ThemePreference.parse(await persistence.read());
    } on Object {
      stored = null;
    }
    _apply(
      stored != null && isAvailable(stored) ? stored : ThemePreference.light,
    );
  }

  /// Chooses [preference] for the whole app and saves it. Returns false, and
  /// changes nothing, when it is not [isAvailable]. A failed write keeps the
  /// choice for this run.
  Future<bool> setPreference(ThemePreference preference) async {
    if (!isAvailable(preference)) return false;
    _apply(preference);
    try {
      await _persistence?.write(preference.storedName);
    } on Object {
      // Kept in memory; the next launch falls back to the last saved value.
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
  /// preference reaches it ([restore], [setPreference]); anything else is
  /// light.
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
