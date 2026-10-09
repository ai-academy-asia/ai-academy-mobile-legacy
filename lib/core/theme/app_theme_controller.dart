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
/// **Gated: light only.** `MaterialApp` carries the candidate `AppTheme.dark`
/// (Issue #276), but its values are not approved
/// (`DARK_MODE_DESIGN_PROPOSAL.md` §17). Until [darkThemeApproved] is true,
/// only [ThemePreference.light] can be chosen, and every preference — a
/// stored one included — resolves to [ThemeMode.light]. Nothing in `lib/`
/// calls [setMode] or names another mode (`app_palette_dark_test.dart`).
class AppThemeController extends ChangeNotifier {
  AppThemeController([this._mode = ThemeMode.light]);

  /// The app's own, read by `AiAcademyApp`.
  static final AppThemeController instance = AppThemeController();

  /// The production gate. False until §17 of the proposal records the dark
  /// values as approved; `theme_preference_test.dart` fails if the two
  /// disagree. Turning it on is its own change: it maps Dark and System in
  /// [_modeFor] and relaxes the Phase 9 rules in the same commit.
  static const bool darkThemeApproved = false;

  /// Whether [preference] can be chosen now: Light always; Dark and System
  /// once [darkThemeApproved].
  static bool isAvailable(ThemePreference preference) =>
      preference == ThemePreference.light || darkThemeApproved;

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

  /// The one place a preference becomes a mode. While [darkThemeApproved] is
  /// false there is only one answer; the approval change adds Dark and
  /// System here.
  static ThemeMode _modeFor(ThemePreference preference) => ThemeMode.light;

  /// Changes the mode for the whole app. Setting the current mode does
  /// nothing.
  void setMode(ThemeMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
  }
}
