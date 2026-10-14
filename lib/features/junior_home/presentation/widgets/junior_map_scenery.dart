import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_palette.dart';
import 'junior_map_geometry.dart';
import 'junior_map_theme.dart';

/// The Junior map's scenery, behind the learning content ([content]).
///
/// **Fixed layers.** All are fixed to the map's viewport and none scrolls:
/// first **the sky** — the field and the travelling clouds — then **the
/// bank** — the theme's large clouds on the background's bottom edge, still
/// (Issue #410) — then **the ground** — the islands and their coins.
/// [content], the scrolling route, nodes and cards, sits over all three.
/// Nothing here moves, scales or rebuilds [content].
///
/// **Ambient motion.** A sky of clouds at many sizes and heights travels
/// slowly from left to right, each at its own speed, coming round again from
/// the left; the islands float a pixel or two, and each coin rides its
/// island with a small bob of its own ([JuniorSceneryMotion]), in place,
/// whatever the content does. One ticker drives both layers. Every motion
/// fades in softly from still.
///
/// **No zoom** (Issue #410). The scenery does not scale: a pinch does
/// nothing, so one and two fingers alike are the content's own — its
/// scrolling and its taps.
///
/// **Reduced motion.** When the platform asks for reduced motion
/// ([MediaQuery.disableAnimationsOf]) there is no ticker and no travel:
/// the scenery is the export itself, fixed to the viewport like the
/// rest of the scenery, and there is no separate ground.
///
/// **Cost.** Each frame the ticker rebuilds only the small [Transform]s that
/// carry the moving pieces, each behind its own [RepaintBoundary]. Hidden
/// behind another tab, its ticker is muted ([TickerMode]).
class JuniorMapScenery extends StatefulWidget {
  const JuniorMapScenery({
    required this.scale,
    required this.content,
    super.key,
    this.theme = JuniorMapTheme.junior,
  });

  /// The map's design-space-to-pixels factor.
  final double scale;

  /// The scrolling learning content, drawn over the scenery and never
  /// touched by it.
  final Widget content;

  /// The program's sky — its field colour and cloud artwork (Issue #410).
  final JuniorMapTheme theme;

  /// The sky, bank and ground layers, for tests to find them.
  @visibleForTesting
  static const Key skyKey = Key('junior-map-sky');
  @visibleForTesting
  static const Key bankKey = Key('junior-map-bank');
  @visibleForTesting
  static const Key groundKey = Key('junior-map-ground');

  @override
  State<JuniorMapScenery> createState() => _JuniorMapSceneryState();
}

class _JuniorMapSceneryState extends State<JuniorMapScenery>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);

  /// Seconds since the scenery started moving. Never wraps.
  final _seconds = ValueNotifier<double>(0);

  bool _animate = false;

  /// The sky's box, in logical pixels: the viewport, down to the map's own
  /// height.
  Size _box = Size.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = !MediaQuery.disableAnimationsOf(context);
    if (animate == _animate) return;
    _animate = animate;
    if (animate) {
      _ticker.start();
    } else {
      _ticker.stop();
      _seconds.value = 0;
    }
  }

  void _onTick(Duration elapsed) {
    _seconds.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  // --- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _box = Size(
          constraints.maxWidth,
          math.min(
            constraints.maxHeight,
            JuniorMapGeometry.mapHeight * widget.scale,
          ),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            // Below the map's own height there has only ever been the
            // field, so the scenery stops there.
            _layer(
              JuniorMapScenery.skyKey,
              _animate
                  ? _sky()
                  : Stack(clipBehavior: Clip.hardEdge, children: [_backdrop()]),
            ),
            // The theme's cloud bank on the background's bottom edge —
            // still, and drawn with or without motion (Issue #410).
            _bank(constraints.maxHeight),
            if (_animate) _layer(JuniorMapScenery.groundKey, _ground()),
            widget.content,
          ],
        );
      },
    );
  }

  /// One fixed scenery layer: the sky's box, its own repaint layer, and no
  /// part in hit testing, so the content's scrolls and taps are untouched.
  Widget _layer(Key key, Widget child) => Positioned(
    left: 0,
    top: 0,
    width: _box.width,
    height: _box.height,
    child: IgnorePointer(
      child: RepaintBoundary(key: key, child: child),
    ),
  );

  /// The theme's bank of large clouds, anchored to the bottom edge of the
  /// whole background ([height] tall) and scaled with the map's width: the
  /// program's boundary, which the path and its certificate scroll over and
  /// never drag along. It does not move, so no ticker reaches it.
  Widget _bank(double height) {
    final scale = widget.scale;
    final theme = widget.theme;
    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: RepaintBoundary(
            key: JuniorMapScenery.bankKey,
            child: ClipRect(
              child: Stack(
                children: [
                  for (final cloud in theme.bankClouds)
                    Positioned(
                      left: cloud.rect.left * scale,
                      top: height + cloud.rect.top * scale,
                      width: cloud.rect.width * scale,
                      height: cloud.rect.height * scale,
                      child: Transform.flip(
                        flipX: cloud.mirrored,
                        child: SvgPicture.asset(
                          theme.cloudAsset,
                          fit: BoxFit.fill,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The theme's field, then its clouds, travelling. The clouds, islands
  /// and coins are authored artwork, drawn as exported; the clip keeps them
  /// inside the box.
  Widget _sky() {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final theme = widget.theme;
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: theme.sky(context.palette)),
          for (var i = 0; i < JuniorSceneryMotion.clouds.length; i++)
            _moving(
              JuniorScenery(
                theme.cloudAsset,
                JuniorSceneryMotion.cloudBox(i, _box.height / widget.scale),
                mirrored: JuniorSceneryMotion.clouds[i].mirrored,
              ),
              pixelRatio,
              (t) => Offset(JuniorSceneryMotion.cloudLeft(i, t), 0),
            ),
        ],
      ),
    );
  }

  /// The islands and their coins at their design places, each floating
  /// about its place. Transparent between them, so the sky shows through.
  Widget _ground() {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final islands = JuniorMapGeometry.islands;
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        // The one pair no SVG reproduces, as the export's own pixels; it
        // does not float.
        _at(
          JuniorMapGeometry.unmatchedScenery,
          Image.asset(
            JuniorMapGeometry.farIsland,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: true,
          ),
        ),
        for (var i = 0; i < islands.length; i++)
          _moving(
            JuniorScenery(
              JuniorMapGeometry.island,
              islands[i] & JuniorMapGeometry.islandSize,
            ),
            pixelRatio,
            (t) => Offset(0, JuniorSceneryMotion.islandRise(i, t)),
          ),
        for (var i = 0; i < islands.length; i++)
          _moving(
            JuniorScenery(
              JuniorMapGeometry.coin,
              islands[i] + JuniorMapGeometry.coinOnIsland &
                  JuniorMapGeometry.coinSize,
            ),
            pixelRatio,
            (t) => Offset(0, JuniorSceneryMotion.coinRise(i, t)),
          ),
      ],
    );
  }

  /// The whole export, placed so that its map rows land on the map's origin.
  ///
  /// The export is the whole 393 x 1428 frame, so it is drawn at its full
  /// height and shifted up by the header's band; the enclosing clip drops
  /// what falls outside. The box carries the export's own aspect, so nothing
  /// is stretched — the composition is the design's, unaltered.
  Widget _backdrop() {
    final scale = widget.scale;
    return Positioned(
      left: 0,
      top: -JuniorMapGeometry.mapTopInFrame * scale,
      width: JuniorMapGeometry.mapWidth * scale,
      height: JuniorMapGeometry.frameHeight * scale,
      child: Image.asset(
        JuniorMapGeometry.backdrop,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      ),
    );
  }

  Widget _at(Rect rect, Widget child) => Positioned(
    left: rect.left * widget.scale,
    top: rect.top * widget.scale,
    width: rect.width * widget.scale,
    height: rect.height * widget.scale,
    child: child,
  );

  /// A piece at its design place, offset by [motion] (in design units) at
  /// the current time.
  ///
  /// The offset is rounded to whole device pixels: the clouds are pixel art,
  /// and a sub-pixel shift would soften their stepped edges as they move.
  Widget _moving(
    JuniorScenery piece,
    double pixelRatio,
    Offset Function(double seconds) motion,
  ) {
    return _at(
      piece.rect,
      ValueListenableBuilder<double>(
        valueListenable: _seconds,
        builder: (context, seconds, child) {
          final offset = motion(seconds) * widget.scale * pixelRatio;
          return Transform.translate(
            offset: Offset(
              offset.dx.roundToDouble() / pixelRatio,
              offset.dy.roundToDouble() / pixelRatio,
            ),
            child: child,
          );
        },
        child: RepaintBoundary(
          child: Transform.flip(
            flipX: piece.mirrored,
            child: SvgPicture.asset(
              piece.asset,
              fit: BoxFit.fill,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }
}

/// Where each piece of scenery is at a given moment, in design units. Pure
/// functions of time: the same moment always gives the same scene, on every
/// launch and every device.
///
/// None of these numbers comes from the design, which is still — they are
/// chosen to stay beneath the learning content.
abstract final class JuniorSceneryMotion {
  /// How long every motion takes to fade in from the still design.
  static const double rampSeconds = 6;

  /// The sky: the design's cloud at ten sizes and heights, smallest (and
  /// furthest-looking) first, so the larger ones pass in front.
  ///
  /// Fixed data rather than a random draw, so the sky is the same on every
  /// build, reload and test. It was laid out once, on a phone's sky, by a
  /// seeded search built on a loose three-by-three grid of zones: the
  /// clouds split four to the top, two to the middle and four to the
  /// bottom (the three largest one to a row), the top and bottom rows
  /// reaching right to the sky's edges so clouds tuck under the header and
  /// the tab bar; each at its own height within its row, and the moments
  /// they cross the screen spread round the [cloudPeriod] so their row is
  /// rarely empty. Every candidate was then simulated through a whole
  /// period and kept only if it met the rules the tests hold it to:
  ///
  /// - **Balanced cover, weighted to the edges.** The top and bottom of the
  ///   sky carry more cloud than the middle and almost never go without;
  ///   the middle — where the route runs — still holds a cloud about half
  ///   the time; left, centre and right each hold one most of the time;
  ///   every corner is visited at least every 50 seconds, and no wide
  ///   stretch of sky stays empty for long. The first frame fills all four
  ///   corners.
  /// - **No two clouds ever overlap**, anywhere the sky can show them: they
  ///   always keep a clear gap of 8 design units plus a tenth of their two
  ///   widths, so large clouds keep further apart than small ones. Every
  ///   cloud comes round in the same [cloudPeriod], so the whole sky repeats
  ///   exactly; one period without an overlap is every period without one.
  /// - **No clustering:** on screen, no cloud ever has more than one other
  ///   within 170 design units; two to five are in view at a time.
  /// - Heights spread over the sky, top to bottom, no two on one line.
  /// - Sizes from 0.45x to 1.3x the design's cloud — never larger than the
  ///   largest cloud the frame draws ([JuniorMapGeometry.largestDesignCloud]).
  /// - Larger clouds a little faster (5–10 design units per second), as
  ///   nearer things pass quicker.
  ///
  /// Checked on skies from the shortest phone's (480 design units) to a
  /// tall one's (700); the layout scales with the sky's height.
  static const List<JuniorCloud> clouds = [
    JuniorCloud(scale: 0.45, height: 0.439, speed: 5, start: 0.599),
    JuniorCloud(
      scale: 0.5,
      height: 0.885,
      speed: 5.5,
      start: 0.258,
      mirrored: true,
    ),
    JuniorCloud(scale: 0.55, height: 0.213, speed: 5.2, start: 0.438),
    JuniorCloud(scale: 0.62, height: 0.105, speed: 6.1, start: 0.767),
    JuniorCloud(
      scale: 0.7,
      height: 0.936,
      speed: 6.6,
      start: 0.012,
      mirrored: true,
    ),
    JuniorCloud(scale: 0.78, height: 0.156, speed: 7, start: 0.247),
    JuniorCloud(
      scale: 0.85,
      height: 0.828,
      speed: 7.6,
      start: 0.607,
      mirrored: true,
    ),
    JuniorCloud(scale: 1, height: 0.054, speed: 8.4, start: 0.052),
    JuniorCloud(scale: 1.1, height: 0.776, speed: 9, start: 0.853),
    JuniorCloud(
      scale: 1.3,
      height: 0.498,
      speed: 9.8,
      start: 0.216,
      mirrored: true,
    ),
  ];

  /// How long every cloud takes to come round its lap, in seconds.
  ///
  /// The same for all, which is what makes the sky repeat exactly; each
  /// cloud's own speed then sets how far out of sight it waits on the left
  /// ([cloudEntry]). The shortest that leaves every cloud some wait is 202 s.
  static const double cloudPeriod = 250;

  static const List<double> islandPeriods = [7.3, 8.9, 10.7];
  static const double islandFloat = 1.5;

  static const List<double> coinPeriods = [2.07, 2.29, 2.43];
  static const double coinBob = 2;

  /// How far past either side of the frame a cloud travels before it comes
  /// round — out of sight, so it never jumps. The value the former 0.6x
  /// zoom-out needed, kept as it was (Issue #410): every cloud's lap, and so
  /// the sky's arrangement at every moment, is exactly what it was.
  static const double reach = JuniorMapGeometry.mapWidth * (1 / 0.6 - 1);

  /// Cloud [index]'s box at the start of its lap, in a sky [skyHeight] tall:
  /// its size, and its height centred on its share of the sky. Travel moves
  /// it right from here by [cloudLeft].
  static Rect cloudBox(int index, double skyHeight) {
    final cloud = clouds[index];
    final size = JuniorMapGeometry.cloudSize * cloud.scale;
    return Rect.fromLTWH(
      0,
      cloud.height * skyHeight - size.height / 2,
      size.width,
      size.height,
    );
  }

  /// The length of cloud [index]'s lap: what its speed covers in a
  /// [cloudPeriod].
  static double cloudLap(int index) => clouds[index].speed * cloudPeriod;

  /// Where cloud [index]'s left edge enters: one lap before [cloudExit],
  /// which puts the whole cloud left of everything that can be seen, plus
  /// its own wait (see [cloudPeriod]).
  static double cloudEntry(int index) => cloudExit(index) - cloudLap(index);

  /// Where cloud [index]'s left edge leaves: past everything that can be
  /// seen on the right.
  static double cloudExit(int index) => JuniorMapGeometry.mapWidth + reach;

  /// The left edge of cloud [index] after [seconds].
  ///
  /// It starts its own share of the way round its lap and travels right;
  /// once wholly past [cloudExit] it comes round to [cloudEntry] — both out
  /// of sight — and travels on.
  static double cloudLeft(int index, double seconds) {
    final cloud = clouds[index];
    final lap = cloudLap(index);
    final travelled = cloud.speed * _easedTime(seconds);
    return cloudEntry(index) + (cloud.start * lap + travelled) % lap;
  }

  /// The vertical float of island [index] after [seconds].
  static double islandRise(int index, double seconds) =>
      _wave(islandFloat, islandPeriods[index], 10 + index, seconds);

  /// The vertical position of island [index]'s coin after [seconds]: the
  /// island's float plus a bob of its own.
  static double coinRise(int index, double seconds) =>
      islandRise(index, seconds) +
      _wave(coinBob, coinPeriods[index], 20 + index, seconds);

  /// Time with the same soft start as [_wave]: speed eases from nothing to
  /// full over [rampSeconds] (the integral of a smoothstep), then runs on.
  static double _easedTime(double t) {
    const r = rampSeconds;
    if (t >= r) return t - r / 2;
    final x = t / r;
    return r * (x * x * x - x * x * x * x / 2);
  }

  /// [amplitude] · sin(2πt / [period] + phase), faded in over [rampSeconds].
  ///
  /// Phases step by the golden ratio, which spreads them evenly without any
  /// two lining up.
  static double _wave(double amplitude, double period, int seed, double t) {
    final phase = 2 * math.pi * ((seed * 0.6180339887498949) % 1);
    final x = (t / rampSeconds).clamp(0.0, 1.0);
    final ramp = x * x * (3 - 2 * x);
    return amplitude * ramp * math.sin(2 * math.pi * t / period + phase);
  }
}

/// One cloud of the Junior sky. See [JuniorSceneryMotion.clouds].
class JuniorCloud {
  const JuniorCloud({
    required this.scale,
    required this.height,
    required this.speed,
    required this.start,
    this.mirrored = false,
  });

  /// Size, as a multiple of the design's cloud.
  final double scale;

  /// Where its centre sits, as a share of the sky's height: 0 the top, 1 the
  /// bottom.
  final double height;

  /// Travel speed, in design units per second.
  final double speed;

  /// How far round its lap it is at the start, as a share of the lap.
  final double start;

  /// Drawn flipped left-to-right, for variety from the one drawing.
  final bool mirrored;
}
