import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/presentation/login_screen.dart';
import 'splash_strings.dart';

/// The screen shown on launch, before sign-in.
///
/// One [AnimationController] over [duration] (7 seconds), split into an
/// entrance, a hold and a fade-out — nothing repeats or reverses, so the
/// controller simply runs once and then hands off on its own:
///
///   * 0 – 17.1%: the icon fades and scales in, alone and centred — a blank
///     [AppColors.surface] screen is the true first frame.
///   * 17.1 – 25.7%: an invisible slot beside the icon widens from nothing to
///     the wordmark's full width. Centred as a whole, the [Row] grows around
///     its own centre, so this is what reads as "the icon moves left" —
///     nothing about the icon itself moves; the space opening up beside it
///     does.
///   * 25.7 – 42.9%: the wordmark, already sized into that slot, fades in and
///     slides the last few pixels in from the right. Entrance ends here, at
///     3 seconds — this beat, and the two before it, are unchanged from the
///     original storyboard; only [duration] itself shrank, which is what
///     moved every fraction in this list without moving any of the
///     millisecond marks they still land on.
///   * 42.9 – 71.4%: hold. No animation targets this range, so the lockup
///     simply sits at rest, fully visible, for 2 seconds.
///   * 71.4 – 100%: the whole lockup fades back out together over the final
///     2 seconds — same curve and style as before, just shortened from the
///     4 seconds an earlier pass used.
///
/// It hands off to sign-in **on its own**, once the fade-out completes — see
/// [_onStatusChanged] — rather than waiting for a tap: a splash screen that
/// requires input to end is not really a splash screen. [_navigating] still
/// guards the actual route push, the same reasoning a tap-driven version
/// would need it for — [AnimationStatus.completed] is not itself guaranteed
/// to fire only once for the life of this controller (a hot reload or a
/// forced rebuild could in principle re-observe it), and a second
/// `pushReplacement` on an already-popped-from route is exactly the kind of
/// bug worth foreclosing for free.
///
/// The icon is the same bundled mark [HomeHeader] shows — see
/// [SplashAssets.icon] — drawn directly rather than cropped from a combined
/// image, since that combined export no longer exists.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Total run time, start to hand-off: a 3-second entrance, a 2-second
  /// hold, and a 2-second fade-out. Deliberately unhurried — this is a
  /// branded moment, not a loading spinner standing in for one. The fade-out
  /// is the one beat shortened from an earlier pass (was 4 seconds, felt too
  /// slow); the entrance is exactly as long, and exactly as smooth, as
  /// before, and the fade-out keeps its own curve/style, just over less time.
  static const Duration duration = Duration(milliseconds: 7000);

  /// The route a tap hands off to, once the animation has settled.
  static const String nextRoute = '/login';

  /// Exposed so a test can read an animation's progress straight off the
  /// widget tree — the only way to reach one driven by this screen's private
  /// state.
  static const Key logoOpacityKey = ValueKey('splash-logo-opacity');
  static const Key textSlotKey = ValueKey('splash-text-slot');
  static const Key textOpacityKey = ValueKey('splash-text-opacity');

  /// The whole lockup's own fade-out opacity, distinct from [logoOpacityKey]/
  /// [textOpacityKey] — those two only ever animate up to 1.0 during the
  /// entrance and then hold there; this is what carries the lockup back down
  /// to 0.0 for the closing beat.
  static const Key screenFadeKey = ValueKey('splash-screen-fade');

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _textSlotFactor;
  late final Animation<double> _textOpacity;
  late final Animation<double> _textSlide;
  late final Animation<double> _screenFade;

  /// Set once the hand-off has started, so a stray extra notification can't
  /// start it again — see the class doc.
  bool _navigating = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: SplashScreen.duration,
    )..forward();
    _controller.addStatusListener(_onStatusChanged);

    // Every fraction below is a millisecond mark from the original
    // storyboard divided by the current, shorter [duration] — the entrance
    // marks (0, 1200, 1800, 3000ms) and the hold's own length (2s) are
    // unchanged; only the fade-out (now 5000ms – 7000ms, was 5000ms –
    // 9000ms) actually got shorter, and that alone is why every fraction
    // here moved without any of the millisecond marks themselves moving.
    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 6 / 35, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.9, end: 1.0).animate(_logoOpacity);

    _textSlotFactor = CurvedAnimation(
      parent: _controller,
      curve: const Interval(6 / 35, 9 / 35, curve: Curves.easeOut),
    );

    final textCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(9 / 35, 3 / 7, curve: Curves.easeOut),
    );
    _textOpacity = textCurve;
    // Slides in from 10 logical pixels right of rest — inside the
    // storyboard's 8–12px range. Riding the same curve as the fade means the
    // offset is already small by the time the text is visible enough to
    // notice it moving.
    _textSlide = Tween<double>(begin: 10, end: 0).animate(textCurve);

    _screenFade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(5 / 7, 1.0, curve: Curves.easeInOut),
      ),
    );
  }

  /// The automatic hand-off — see the class doc on why this replaces a tap.
  void _onStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed || _navigating) return;
    _navigating = true;
    // A plain `PageRouteBuilder` rather than `pushReplacementNamed`: a named
    // push takes the platform's default (slide-in) transition, and the
    // hand-off from this screen's own fade-heavy storyboard reads better as
    // one more fade than as a sudden switch to a different transition style.
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Opacity(
            key: SplashScreen.screenFadeKey,
            opacity: _screenFade.value,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  key: SplashScreen.logoOpacityKey,
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: const _LogoMark(),
                  ),
                ),
                ClipRect(
                  child: Align(
                    key: SplashScreen.textSlotKey,
                    alignment: Alignment.centerLeft,
                    widthFactor: _textSlotFactor.value,
                    child: Opacity(
                      key: SplashScreen.textOpacityKey,
                      opacity: _textOpacity.value,
                      child: Transform.translate(
                        offset: Offset(_textSlide.value, 0),
                        child: const _Wordmark(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The bundled icon mark, at the same rendered height the splash's earlier,
/// combined-image version measured out for it.
class _LogoMark extends StatelessWidget {
  const _LogoMark();

  /// The icon's rendered height on screen.
  ///
  /// `AppDimens.avatarSize` (44) is the closest existing icon-scale reference
  /// in this app, so 48 reads as "one more icon at this app's usual glyph
  /// size" rather than a one-off. The wordmark is sized to read well beside
  /// it instead — see [AppTypography.splashWordmark].
  static const double _renderedHeight = 48;

  @override
  Widget build(BuildContext context) {
    return Image.asset(SplashAssets.icon, height: _renderedHeight);
  }
}

/// "AI academy Asia", two lines, in the wordmark's own navy — see
/// [SplashStrings].
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Text(
        '${SplashStrings.wordmarkLine1}\n${SplashStrings.wordmarkLine2}',
        style: AppTypography.splashWordmark,
      ),
    );
  }
}
