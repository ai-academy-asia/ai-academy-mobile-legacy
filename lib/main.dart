import 'package:flutter/material.dart';

import 'app.dart';
import 'core/theme/app_theme_controller.dart';
import 'core/theme/theme_preference.dart';
import 'features/auth/data/secure_session_persistence.dart';
import 'features/auth/data/session_refresher.dart';
import 'features/auth/domain/auth_session_store.dart';
import 'features/auth/presentation/account_theme.dart';
import 'features/auth/presentation/sign_out.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The session outlives the process — the OS killing a backgrounded app is
  // not a sign-out (Issue #235). Restored before the first frame, so Splash
  // finds it.
  await AuthSessionStore.instance.attach(SecureSessionPersistence());
  // The theme too, so the first frame is drawn in the saved choice (Issue
  // #278) — the restored account's own (Issue #286). Never throws: anything
  // unreadable falls back to light.
  await AppThemeController.instance.attach(SecureThemePreferencePersistence());
  await followAccountTheme(
    AuthSessionStore.instance,
    AppThemeController.instance,
  );
  // A session that cannot be renewed ends on Login (Issue #176).
  returnToLoginWhenSessionEnds(SessionRefresher.instance, appNavigatorKey);
  runApp(const AiAcademyApp());
}
