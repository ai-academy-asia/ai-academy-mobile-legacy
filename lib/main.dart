import 'package:flutter/material.dart';

import 'app.dart';
import 'core/api/api_config.dart';
import 'core/theme/app_theme_controller.dart';
import 'core/theme/theme_preference.dart';
import 'features/auth/data/secure_session_persistence.dart';
import 'features/auth/data/session_refresher.dart';
import 'features/auth/domain/auth_session_store.dart';
import 'features/auth/presentation/account_theme.dart';
import 'features/auth/presentation/sign_out.dart';
import 'features/notifications/push/firebase_push_messaging.dart';
import 'features/notifications/push/push_notifications.dart';

Future<void> main() async {
  // Which API this build talks to, decided first (Issue #388): an invalid
  // debug override stops here, before any request — it never falls back
  // to production. Release builds always use production.
  final api = ApiConfig.current;
  if (api.isOverride) debugPrint('AIA API override: ${api.label}');
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
  // Push notifications (Issue #398) — on only when Firebase starts, which
  // needs the project's configuration; without it the app runs as before.
  // Never throws.
  await PushNotifications.instance.attach(
    await startFirebasePush(),
    navigatorKey: appNavigatorKey,
    messengerKey: appMessengerKey,
  );
  runApp(const AiAcademyApp());
}
