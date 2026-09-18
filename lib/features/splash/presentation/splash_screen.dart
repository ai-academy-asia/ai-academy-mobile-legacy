import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/presentation/login_screen.dart';
import 'splash_strings.dart';

/// The screen shown on launch, before sign-in.
///
/// One [AnimationController] over [duration] (~1 second, per the storyboard),
/// split into three back-to-back beats and a closing hold — nothing repeats
/// or reverses, so the controller simply runs once and then sits at rest:
///
///   * 0 – 40%: the icon fades and scales in, alone and centred — a blank
///     white screen is the true first frame.
///   * 40 – 60%: an invisible slot beside the icon widens from nothing to the
///     wordmark's full width. Centred as a whole, the [Row] grows around its
///     own centre, so this is what reads as "the icon moves left" — nothing
///     about the icon itself moves; the space opening up beside it does.
///   * 60 – 80%: the wordmark, already sized into that slot, fades in and
///     slides the last few pixels in from the right.
///   * 80 – 100%: hold. No animation targets this range, so every value
///     above is already at its resting state — [Interval] holds a curve's
///     output at 1.0 for any input past its own end.
///
/// It does **not** hand off to `/login` on its own: the whole screen is one
/// tap target, but a tap before the animation has reached that resting state
/// does nothing — see [_handleTap]. Only the first tap once it has settled
/// navigates; every tap after that (including a second tap on the same
/// still-mounted frame, before the route push takes effect) is ignored, via
/// [_navigating].
///
/// The icon is cropped from the one bundled logo image rather than redrawn —
/// see [SplashAssets.logo] for the measured crop and why the wordmark is
/// drawn separately instead of read off the same picture.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Total run time, start to hand-off. Short and non-negotiable: the
  /// storyboard calls for "~1 second", not something a user waits through.
  static const Duration duration = Duration(milliseconds: 1000);

  /// The route a tap hands off to, once the animation has settled.
  static const String nextRoute = '/login';

  /// Exposed so a test can read an animation's progress straight off the
  /// widget tree — the only way to reach one driven by this screen's private
  /// state.
  static const Key logoOpacityKey = ValueKey('splash-logo-opacity');
  static const Key textSlotKey = ValueKey('splash-text-slot');
  static const Key textOpacityKey = ValueKey('splash-text-opacity');

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

  /// Set once a tap has started the hand-off, so a second tap — before the
  /// route push actually removes this screen — can't start it again.
  bool _navigating = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: SplashScreen.duration,
    )..forward();

    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.4, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.9, end: 1.0).animate(_logoOpacity);

    _textSlotFactor = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.6, curve: Curves.easeOut),
    );

    final textCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 0.8, curve: Curves.easeOut),
    );
    _textOpacity = textCurve;
    // Slides in from 10 logical pixels right of rest — inside the
    // storyboard's 8–12px range. Riding the same curve as the fade means the
    // offset is already small by the time the text is visible enough to
    // notice it moving.
    _textSlide = Tween<double>(begin: 10, end: 0).animate(textCurve);
  }

  /// Sends the screen on to sign-in — only once the animation has settled,
  /// and only for the first tap that catches it settled.
  ///
  /// Gates on [AnimationController.value] reaching [AnimationController.upperBound]
  /// rather than on [AnimationController.isCompleted]/[AnimationStatus.completed]:
  /// the two are not the same instant. A controller's value reaches its upper
  /// bound the moment elapsed time reaches its duration, but its status only
  /// flips to `completed` once elapsed time *exceeds* that duration — so a
  /// tap landing in that gap would read `isCompleted` as still false even
  /// though the storyboard has visibly finished (every value on screen is
  /// already at its resting state, per the class doc). The value check has
  /// no such gap.
  void _handleTap() {
    if (_controller.value < _controller.upperBound || _navigating) return;
    _navigating = true;
    // A plain `PageRouteBuilder` rather than `pushReplacementNamed`: a named
    // push takes the platform's default (slide-in) transition, and the
    // hand-off from this screen's own fade-heavy storyboard reads better as
    // one more fade than as a sudden switch to a different transition style.
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: GestureDetector(
        // Opaque: the animation leaves most of the screen visually blank, and
        // a tap anywhere on it — not just on the logo or the wordmark — is
        // still a tap on the splash screen.
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Row(
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

/// The bundled logo image, cropped to just its icon — see
/// [SplashAssets.logo] for the measured crop.
class _LogoMark extends StatelessWidget {
  const _LogoMark();

  static const double _sourceWidth = 320;
  static const double _sourceHeight = 97;

  /// Sits inside the transparent gap between the icon and the wordmark
  /// (columns 106–125), so the crop carries a hair of breathing room on
  /// either side without reaching into either shape's pixels.
  static const double _iconCropWidth = 112;

  /// The icon's rendered height on screen.
  ///
  /// The source PNG is only 320 x 97 — its icon glyph occupies roughly
  /// 105 x 96 of that. 48 keeps this close to the asset's own resolution
  /// rather than stretching it further than necessary: on a 2x display that's
  /// 96 physical pixels, essentially native; on the densest common displays
  /// (3x) it's 144, under a 1.5x upscale. `AppDimens.avatarSize` (44) is the
  /// closest existing icon-scale reference in this app, so 48 also reads as
  /// "one more icon at this app's usual glyph size" rather than a one-off.
  /// The wordmark is sized to read well beside it instead — see
  /// [AppTypography.splashWordmark].
  static const double _renderedHeight = 48;

  static const double _scale = _renderedHeight / _sourceHeight;
  static const double _renderedFullWidth = _sourceWidth * _scale;
  static const double _iconCropFraction = _iconCropWidth / _sourceWidth;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Align(
        alignment: Alignment.centerLeft,
        widthFactor: _iconCropFraction,
        child: Image.asset(
          SplashAssets.logo,
          width: _renderedFullWidth,
          height: _renderedHeight,
          fit: BoxFit.fill,
        ),
      ),
    );
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
