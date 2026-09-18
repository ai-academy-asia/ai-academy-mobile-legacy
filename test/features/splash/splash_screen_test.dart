import 'package:aia_mobile/core/theme/app_colors.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/presentation/login_screen.dart';
import 'package:aia_mobile/features/splash/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the real Manrope face, the same reason the other screen tests do —
/// without it, text is measured in the fallback font.
Future<void> _loadFonts() async {
  final loader = FontLoader('Manrope')
    ..addFont(rootBundle.load('assets/fonts/Manrope-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Manrope-Bold.ttf'));
  await loader.load();
}

/// Counts `pushReplacementNamed` calls, so a test can tell "navigated once"
/// from "navigated twice" without guessing at widget-tree timing during a
/// route transition.
class _ReplaceCountingObserver extends NavigatorObserver {
  int replaceCount = 0;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replaceCount++;
  }
}

void main() {
  setUpAll(_loadFonts);

  /// Never `pumpAndSettle` right after starting the animation: its repeated
  /// small pumps overshoot whatever exact elapsed time a test wants to land
  /// on, and — per `SplashScreen._handleTap`'s own doc comment — overshooting
  /// even slightly is exactly what it takes for the controller's `status` to
  /// reach [AnimationStatus.completed], one reason this suite taps rather
  /// than waits for that status to assert "the animation is done".
  Future<void> pumpSplash(
    WidgetTester tester, {
    List<NavigatorObserver> observers = const [],
  }) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(393, 852) * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        initialRoute: '/',
        navigatorObservers: observers,
        routes: {
          '/': (_) => const SplashScreen(),
          SplashScreen.nextRoute: (_) => const LoginScreen(),
        },
      ),
    );
    // A known, exact zero-elapsed frame — pumpWidget's own first frame does
    // not guarantee one, and every assertion below depends on starting from
    // precisely t=0.
    await tester.pump(Duration.zero);
  }

  double opacityOf(WidgetTester tester, Key key) =>
      tester.widget<Opacity>(find.byKey(key)).opacity;

  double widthFactorOf(WidgetTester tester, Key key) =>
      tester.widget<Align>(find.byKey(key)).widthFactor!;

  group('layout', () {
    testWidgets('shows a white screen with only the logo mark at t=0', (
      tester,
    ) async {
      await pumpSplash(tester);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.surface);

      expect(find.byType(Image), findsOneWidget);
      expect(opacityOf(tester, SplashScreen.logoOpacityKey), 0);
      expect(widthFactorOf(tester, SplashScreen.textSlotKey), 0);
      expect(opacityOf(tester, SplashScreen.textOpacityKey), 0);
    });
  });

  group('storyboard timing', () {
    testWidgets(
      'the logo fades in, then the slot opens, then the text fades in, then holds',
      (tester) async {
        await pumpSplash(tester);

        // 0ms: blank but for the (still invisible) icon.
        expect(opacityOf(tester, SplashScreen.logoOpacityKey), 0);
        expect(widthFactorOf(tester, SplashScreen.textSlotKey), 0);
        expect(opacityOf(tester, SplashScreen.textOpacityKey), 0);

        // 200ms: mid icon fade-in; the text slot has not started opening.
        await tester.pump(const Duration(milliseconds: 200));
        expect(opacityOf(tester, SplashScreen.logoOpacityKey), greaterThan(0));
        expect(opacityOf(tester, SplashScreen.logoOpacityKey), lessThan(1));
        expect(widthFactorOf(tester, SplashScreen.textSlotKey), 0);

        // 400ms: icon fully visible; the slot is only just starting to open.
        await tester.pump(const Duration(milliseconds: 200));
        expect(opacityOf(tester, SplashScreen.logoOpacityKey), 1);
        expect(widthFactorOf(tester, SplashScreen.textSlotKey), 0);
        expect(opacityOf(tester, SplashScreen.textOpacityKey), 0);

        // 500ms: slot mid-open; the text itself is still invisible.
        await tester.pump(const Duration(milliseconds: 100));
        expect(widthFactorOf(tester, SplashScreen.textSlotKey), greaterThan(0));
        expect(widthFactorOf(tester, SplashScreen.textSlotKey), lessThan(1));
        expect(opacityOf(tester, SplashScreen.textOpacityKey), 0);

        // 600ms: slot fully open; the text fade is only just starting.
        await tester.pump(const Duration(milliseconds: 100));
        expect(widthFactorOf(tester, SplashScreen.textSlotKey), 1);
        expect(opacityOf(tester, SplashScreen.textOpacityKey), 0);

        // 700ms: text mid fade-in.
        await tester.pump(const Duration(milliseconds: 100));
        expect(opacityOf(tester, SplashScreen.textOpacityKey), greaterThan(0));
        expect(opacityOf(tester, SplashScreen.textOpacityKey), lessThan(1));

        // 800ms: text fully visible — the final layout the design shows.
        await tester.pump(const Duration(milliseconds: 100));
        expect(opacityOf(tester, SplashScreen.textOpacityKey), 1);
        expect(widthFactorOf(tester, SplashScreen.textSlotKey), 1);
        expect(opacityOf(tester, SplashScreen.logoOpacityKey), 1);

        // 900ms: the hold — nothing has moved since 800ms.
        await tester.pump(const Duration(milliseconds: 100));
        expect(opacityOf(tester, SplashScreen.textOpacityKey), 1);
        expect(widthFactorOf(tester, SplashScreen.textSlotKey), 1);
        expect(opacityOf(tester, SplashScreen.logoOpacityKey), 1);
        expect(find.byType(SplashScreen), findsOneWidget);

        // 1000ms: the hold ends. Nothing hands off on its own — the screen
        // simply keeps holding at this exact state, untapped, forever.
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();
        expect(opacityOf(tester, SplashScreen.textOpacityKey), 1);
        expect(widthFactorOf(tester, SplashScreen.textSlotKey), 1);
        expect(opacityOf(tester, SplashScreen.logoOpacityKey), 1);
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
      },
    );
  });

  group('navigation', () {
    testWidgets('does not navigate on its own once the animation completes', (
      tester,
    ) async {
      await pumpSplash(tester);

      await tester.pump(SplashScreen.duration);
      // Well past the hold, with no tap — proves it never fires on its
      // own, not just that it hasn't fired yet.
      await tester.pump(const Duration(seconds: 5));

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('a tap before the animation completes does nothing', (
      tester,
    ) async {
      await pumpSplash(tester);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byType(SplashScreen));
      // Let the rest of the storyboard — and then some — play out untapped.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets(
      'the first tap once the animation has completed navigates to login',
      (tester) async {
        await pumpSplash(tester);
        await tester.pump(SplashScreen.duration);

        await tester.tap(find.byType(SplashScreen));
        await tester.pumpAndSettle();

        expect(find.byType(SplashScreen), findsNothing);
        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );

    testWidgets('a second, immediate tap does not navigate twice', (
      tester,
    ) async {
      final observer = _ReplaceCountingObserver();
      await pumpSplash(tester, observers: [observer]);
      await tester.pump(SplashScreen.duration);

      // Both taps land before either pump lets the route transition (or a
      // widget-tree change from it) run, so this exercises the in-widget
      // guard rather than "the splash screen was already gone".
      await tester.tap(find.byType(SplashScreen));
      await tester.tap(find.byType(SplashScreen), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(observer.replaceCount, 1);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('the login screen is not reachable by popping back', (
      tester,
    ) async {
      await pumpSplash(tester);
      await tester.pump(SplashScreen.duration);
      await tester.tap(find.byType(SplashScreen));
      await tester.pumpAndSettle();

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigator.canPop(), isFalse);
    });
  });
}
