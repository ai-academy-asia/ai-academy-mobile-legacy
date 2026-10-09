import 'package:flutter/material.dart';

/// The app's one theme state — light, dark or follow the system — for every
/// experience: Adult, Junior and Teacher read it, and none keeps its own
/// (Issue #252, `docs/design-system/DARK_MODE_ARCHITECTURE_AUDIT.md` §14.1).
///
/// It sits above `MaterialApp` — `AiAcademyApp` listens to it — so it is
/// settled before Splash runs and before any role's shell is chosen, and
/// every route of every role draws in the same theme.
///
/// **Light only, for now.** It starts at [ThemeMode.light], and nothing in
/// the app sets another mode: `MaterialApp` carries the candidate
/// `AppTheme.dark` (Issue #276), but its values are not approved, so no user
/// can reach it. There is no UI and no persistence yet. Later, each role's Profile row will write
/// [setMode], and `main()` will restore the saved choice before `runApp`
/// (audit §10, Phase 10). Screens never keep a copy of the mode.
class AppThemeController extends ChangeNotifier {
  AppThemeController([this._mode = ThemeMode.light]);

  /// The app's own, read by `AiAcademyApp`.
  static final AppThemeController instance = AppThemeController();

  ThemeMode _mode;

  /// The mode `MaterialApp` is given.
  ThemeMode get mode => _mode;

  /// Changes the mode for the whole app. Setting the current mode does
  /// nothing.
  void setMode(ThemeMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
  }
}
