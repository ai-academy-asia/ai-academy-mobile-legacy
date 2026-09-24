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
  /// on, and overshooting even slightly is exactly what it takes for the
  /// controller's `status` to reach [AnimationStatus.completed] — which now
  /// triggers the automatic hand-off, one reason this suite pumps by exact
  /// durations rather than settling.
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

  // Landing a pump exactly on an `Interval`'s own end (e.g. the 1200ms tick
  // that is exactly `1200/7000` of the controller) can leave a curve's
  // output a hair under 1.0, or a hair over 0.0, to floating-point rounding
  // — close enough that nothing on screen could ever show the difference,
  // but not bit-exact. `closeToOne` is for "this phase just finished"
  // assertions; `closeToZero` is for a phase's own lower boundary when it is
  // also the instant the previous phase's Interval ends (1200ms, 1800ms) —
  // an elapsed-time division landing a hair on either side of the exact
  // fraction shows up here, not at 0ms, which has no division to round.
  final closeToOne = closeTo(1, 0.001);
  final closeToZero = closeTo(0, 0.001);

  group('layout', () {
    testWidgets('shows a white screen with only the logo mark at t=0', (
      tester,
    ) async {
      await pumpSplash(tester);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.surface);

      expect(find.byType(Image), findsOneWidget);
      expect(opacityOf(tester, SplashScreen.screenFadeKey), 1);
      expect(opacityOf(tester, SplashScreen.logoOpacityKey), 0);
      expect(widthFactorOf(tester, SplashScreen.textSlotKey), 0);
      expect(opacityOf(tester, SplashScreen.textOpacityKey), 0);
    });
  });

  group('storyboard timing', () {
    testWidgets(
      'the logo fades in, then the slot opens, then the text fades in, '
      'then holds, then the whole lockup fades out',
      (tester) async {
        await pumpSplash(tester);

        // 0ms: blank but for the (still invisible) icon.
        expect(opacityOf(tester, SplashScreen.logoOpacityKey), 0);
        expect(widthFactorOf(tester, SplashScreen.textSlotKey), 0);
        expect(opacityOf(tester, SplashScreen.textOpacityKey), 0);

        // ~600ms: mid icon fade-in; the text slot has not started opening.
        await tester.pump(const Duration(milliseconds: 600));
        expect(opacityOf(tester, SplashScreen.logoOpacityKey), greaterThan(0));
        expect(opacityOf(tester, SplashScreen.logoOpacityKey), lessThan(1));
        expect(widthFactorOf(tester, SplashScreen.textSlotKey), 0);

        // 1200ms: icon fully visible; the slot has not started opening yet
        // (the two intervals are back-to-back, so this is the one instant
        // both are true).
        await tester.pump(const Duration(milliseconds: 600));
        expect(opacityOf(tester, SplashScreen.logoOpacityKey), closeToOne);
        expect(widthFactorOf(tester, SplashScreen.textSlotKey), closeToZero);
        expect(opacityOf(tester, SplashScreen.textOpacityKey), 0);

        // 1500ms: slot mid-open; the text itself is still invisible.
        await tester.pump(const Duration(milliseconds: 300));
        expect(widthFactorOf(tester, SplashScreen.textSlotKey), greaterThan(0));
        expect(widthFactorOf(tester, SplashScreen.textSlotKey), lessThan(1));
        expect(opacityOf(tester, SplashScreen.textOpacityKey), 0);

        // 1800ms: slot fully open; the text fade has not started yet.
        await tester.pump(const Duration(milliseconds: 300));
        expect(widthFactorOf(tester, SplashScreen.textSlotKey), closeToOne);
        expect(opacityOf(tester, SplashScreen.textOpacityKey), closeToZero);

        // 2400ms: text mid fade-in.
        await tester.pump(const Duration(milliseconds: 600));
        expect(opacityOf(tester, SplashScreen.textOpacityKey), greaterThan(0));
        expect(opacityOf(tester, SplashScreen.textOpacityKey), lessThan(1));

        // 3000ms: text fully visible — entrance is over, the lockup is at
        // its resting, fully-opaque state.
        await tester.pump(const Duration(milliseconds: 600));
        expect(opacityOf(tester, SplashScreen.textOpacityKey), closeToOne);
        expect(widthFactorOf(tester, SplashScreen.textSlotKey), closeToOne);
        expect(opacityOf(tester, SplashScreen.logoOpacityKey), closeToOne);
        expect(opacityOf(tester, SplashScreen.screenFadeKey), 1);

        // 4000ms: mid-hold — nothing has moved since 3000ms. The hold is
        // only 2 seconds now (was 5), so this sits at its midpoint rather
        // than its start.
        await tester.pump(const Duration(milliseconds: 1000));
        expect(opacityOf(tester, SplashScreen.textOpacityKey), closeToOne);
        expect(opacityOf(tester, SplashScreen.screenFadeKey), 1);
        expect(find.byType(SplashScreen), findsOneWidget);

        // 5000ms: the hold ends; the fade-out has not started yet.
        await tester.pump(const Duration(milliseconds: 1000));
        expect(opacityOf(tester, SplashScreen.screenFadeKey), closeToOne);

        // 6000ms: mid fade-out — the whole lockup is partway to invisible.
        // The fade-out is now 2 seconds (5000ms – 7000ms, was 4), so this is
        // its midpoint rather than the 7000ms mark an earlier pass used.
        await tester.pump(const Duration(milliseconds: 1000));
        expect(opacityOf(tester, SplashScreen.screenFadeKey), greaterThan(0));
        expect(opacityOf(tester, SplashScreen.screenFadeKey), lessThan(1));
        expect(find.byType(SplashScreen), findsOneWidget);
      },
    );
  });

  group('navigation', () {
    testWidgets('automatically navigates to Login once the fade-out completes, '
        'with no tap', (tester) async {
      await pumpSplash(tester);

      await tester.pump(SplashScreen.duration);
      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('does not navigate before the animation completes', (
      tester,
    ) async {
      await pumpSplash(tester);

      // Well into the fade-out, but short of the full 7s.
      await tester.pump(const Duration(milliseconds: 6500));

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('a tap does nothing — there is no tap requirement', (
      tester,
    ) async {
      await pumpSplash(tester);

      await tester.pump(const Duration(milliseconds: 3000));
      await tester.tap(find.byType(SplashScreen));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('navigates only once, even pumped well past completion', (
      tester,
    ) async {
      final observer = _ReplaceCountingObserver();
      await pumpSplash(tester, observers: [observer]);

      await tester.pump(SplashScreen.duration);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);
      expect(observer.replaceCount, 1);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('the login screen is not reachable by popping back', (
      tester,
    ) async {
      await pumpSplash(tester);

      await tester.pump(SplashScreen.duration);
      await tester.pumpAndSettle();

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigator.canPop(), isFalse);
    });
  });
}
