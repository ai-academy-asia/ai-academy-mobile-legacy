import '../../../core/theme/app_theme_controller.dart';
import '../domain/auth_session_store.dart';

/// Keeps [theme] on the signed-in account's own preference (Issue #286).
///
/// The theme follows [store]'s account (`GET /auth/me` `id`) through every
/// path that changes it, so none can be missed: sign-in (unidentified until
/// `/auth/me` answers), a restored session, a renewal (the same account),
/// and every `clear()` — sign-out, a rejected token, a renewal that failed.
/// Signed out or unidentified, the theme is Light; each account's saved
/// choice is left in storage for its next sign-in.
///
/// Returns once the current account's preference is applied, so `main()`
/// can await it before the first frame.
Future<void> followAccountTheme(
  AuthSessionStore store,
  AppThemeController theme,
) {
  String? account() => store.userId?.toString();
  store.addListener(() => theme.activateAccount(account()));
  return theme.activateAccount(account());
}
