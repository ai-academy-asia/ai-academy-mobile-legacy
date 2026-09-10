import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/home_placeholder_screen.dart';

/// The application root.
///
/// Two routes and a named-route table — the app has one screen and one
/// placeholder destination, which does not yet justify a routing package. When
/// the navigation grows deep links or nested shells, this is the single place
/// that changes.
class AiAcademyApp extends StatelessWidget {
  const AiAcademyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI academy Asia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/',
      routes: {
        '/': (_) => const LoginScreen(),
        '/home': (_) => const HomePlaceholderScreen(),
      },
    );
  }
}
