import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/splash/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';

/// A light-mode capture of Splash at a fixed instant of its animation — the
/// lockup fully shown — taken before any theme migration touches it
/// (Dark Mode Phase 0, Issue #252). It must stay byte-identical while
/// colours move onto `AppPalette`.
void main() {
  setUpAll(loadAppFonts);

  testWidgets('Splash, lockup shown', (tester) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        // Never the app-wide store: no session, so nothing is restored.
        home: SplashScreen(sessionStore: AuthSessionStore()),
      ),
    );
    await tester.pump(Duration.zero);
    // Decode the mark without `precacheImages`: its closing `pumpAndSettle`
    // would play all 7 seconds and hand off to Login.
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    // 3.5s: inside the 3–5s hold, the lockup at rest and fully shown.
    await tester.pump(const Duration(milliseconds: 3500));
    expect(find.byType(SplashScreen), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/splash.png'),
    );
    // Let the animation finish so no timer outlives the test.
    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();
  });
}
