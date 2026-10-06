import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'junior_home_palette.dart';
import 'junior_map_geometry.dart';

/// The Junior map's scenery, behind the learning content ([content]).
///
/// **Two fixed layers.** Both are fixed to the map's viewport, at the
/// design's own positions, and neither scrolls: first **the sky** — the
/// field and the clouds — then **the ground** — the islands and their
/// coins. [content], the scrolling route, nodes and cards, sits over both.
/// Nothing here moves, scales or rebuilds [content].
///
/// **Ambient motion.** A sky of clouds at many sizes and heights travels
/// slowly from left to right, each at its own speed, coming round again from
/// the left; the islands float a pixel or two, and each coin rides its
/// island with a small bob of its own ([JuniorSceneryMotion]), in place,
/// whatever the content does. One ticker drives both layers. Every motion
/// fades in softly from still.
///
/// **Pinch.** Two fingers zoom the sky — and only the sky: not the islands
/// and coins, not the content — between [minZoom] and [maxZoom],
/// continuously and about the fingers. The gesture
/// is recognised on an ancestor of both layers, so a pinch that starts over
/// a node or a card still reaches it; it is claimed the moment the second
/// finger lands, so the content does not scroll and no node is tapped. One
/// finger is never claimed: scrolling and taps are the content's own.
///
/// **Reduced motion.** When the platform asks for reduced motion
/// ([MediaQuery.disableAnimationsOf]) there is no ticker, no travel and no
/// pinch: the scenery is the export itself, fixed to the viewport like the
/// rest of the scenery, and there is no separate ground.
///
/// **Cost.** Each frame the ticker rebuilds only the small [Transform]s that
/// carry the moving pieces, each behind its own [RepaintBoundary], and a
/// pinch only changes one [Transform] over the sky.
class JuniorMapScenery extends StatefulWidget {
  const JuniorMapScenery({
    required this.scale,
    required this.content,
    super.key,
  });

  /// The map's design-space-to-pixels factor.
  final double scale;

  /// The scrolling learning content, drawn over the scenery and never
  /// touched by it.
  final Widget content;

  /// The scenery's zoom range. Chosen, not a design value.
  static const double minZoom = 0.6;
  static const double maxZoom = 1.4;

  /// The sky and the ground layers, for tests to find them.
  @visibleForTesting
  static const Key skyKey = Key('junior-map-sky');
  @visibleForTesting
  static const Key groundKey = Key('junior-map-ground');

  /// Keeps the zoomed sky covering its box: at or above 1.0x the
  /// visible part stays inside the frame, and below it may show at most the
  /// extra width and height the zoom-out reveals — so at 1.0x the scenery is
  /// always exactly where the design puts it.
  ///
  /// [offset] is the screen position of the scenery's origin at [zoom].
  static Offset clampOffset(double zoom, Offset offset, Size box) => Offset(
    _clampAxis(zoom, offset.dx, box.width),
    _clampAxis(zoom, offset.dy, box.height),
  );

  static double _clampAxis(double zoom, double offset, double extent) {
    final extra = math.max(0.0, extent / zoom - extent);
    return offset.clamp(extent - zoom * (extent + extra), zoom * extra);
  }

  @override
  State<JuniorMapScenery> createState() => _JuniorMapSceneryState();
}

typedef _Zoom = ({double scale, Offset offset});

class _JuniorMapSceneryState extends State<JuniorMapScenery>
    with SingleTickerProviderStateMixin {
  static const _Zoom _rest = (scale: 1, offset: Offset.zero);

  late final Ticker _ticker = createTicker(_onTick);

  /// Seconds since the scenery started moving. Never wraps.
  final _seconds = ValueNotifier<double>(0);

  final _zoom = ValueNotifier<_Zoom>(_rest);

  bool _animate = false;

  /// The sky's box, in logical pixels: the viewport, down to the map's own
  /// height.
  Size _box = Size.zero;

  _Zoom _pinchStart = _rest;
  Offset _pinchFocal = Offset.zero;
  double _pinchSpan = 0;

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
      _zoom.value = _rest;
    }
  }

  void _onTick(Duration elapsed) {
    _seconds.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    _zoom.dispose();
    super.dispose();
  }

  // --- Pinch --------------------------------------------------------------

  /// Re-anchors whenever a finger lands or lifts, so nothing jumps.
  void _onPinchStart(Offset focal, double span) {
    _pinchStart = _zoom.value;
    _pinchFocal = _toLocal(focal);
    _pinchSpan = span;
  }

  /// Scales with the fingers' spread, about the point between them: the
  /// scenery that was under the fingers when the pinch began stays under
  /// them.
  void _onPinchUpdate(Offset focal, double span) {
    final ratio = _pinchSpan == 0 ? 1.0 : span / _pinchSpan;
    final scale = (_pinchStart.scale * ratio).clamp(
      JuniorMapScenery.minZoom,
      JuniorMapScenery.maxZoom,
    );
    final anchor = (_pinchFocal - _pinchStart.offset) / _pinchStart.scale;
    _zoom.value = (
      scale: scale,
      offset: JuniorMapScenery.clampOffset(
        scale,
        _toLocal(focal) - anchor * scale,
        _box,
      ),
    );
  }

  Offset _toLocal(Offset global) =>
      (context.findRenderObject()! as RenderBox).globalToLocal(global);

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
        return RawGestureDetector(
          gestures: {
            if (_animate)
              _PinchGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<_PinchGestureRecognizer>(
                    () => _PinchGestureRecognizer(debugOwner: this),
                    (recognizer) => recognizer
                      ..onStart = _onPinchStart
                      ..onUpdate = _onPinchUpdate,
                  ),
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Below the map's own height there has only ever been the
              // field, so the scenery stops there.
              _layer(
                JuniorMapScenery.skyKey,
                _animate
                    ? _sky()
                    : Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [_backdrop()],
                      ),
              ),
              // Separate from the sky, so the sky's zoom never reaches it.
              if (_animate) _layer(JuniorMapScenery.groundKey, _ground()),
              widget.content,
            ],
          ),
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

  /// The field, then the clouds under the zoom. The field is outside the
  /// zoom, so zooming out never shows an edge; the clip is outside it too,
  /// so zooming never draws past the box.
  Widget _sky() {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: JuniorPalette.mapField),
          ValueListenableBuilder<_Zoom>(
            valueListenable: _zoom,
            builder: (context, zoom, clouds) => Transform(
              transform: Matrix4.diagonal3Values(zoom.scale, zoom.scale, 1)
                ..setTranslationRaw(zoom.offset.dx, zoom.offset.dy, 0),
              child: clouds,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < JuniorSceneryMotion.allClouds.length; i++)
                  _moving(
                    JuniorScenery(
                      JuniorMapGeometry.cloud,
                      JuniorSceneryMotion.cloudBox(
                        i,
                        _box.height / widget.scale,
                      ),
                      mirrored: JuniorSceneryMotion.allClouds[i].mirrored,
                    ),
                    pixelRatio,
                    (t) => Offset(JuniorSceneryMotion.cloudLeft(i, t), 0),
                  ),
              ],
            ),
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
  /// - **No two clouds ever overlap**, anywhere any zoom can show them: they
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

  /// Twelve more clouds out of sight at 1.0x: six above the sky and six
  /// below it, wholly outside it at every sky height from 480 to 700.
  ///
  /// Zooming in, or staying at 1.0x, never shows them — the zoom keeps the
  /// view inside the sky there. Zooming out reveals up to two-thirds of a
  /// sky's height more, above or below or both, and these fill it, so the
  /// widened sky is about as cloudy as the sky at rest rather than bare.
  /// They are not made when the zoom changes: like every cloud they are
  /// always there, and where they are depends only on time.
  ///
  /// The same kind of cloud as [clouds] — the same sizes, the same pace for
  /// their size, the same [cloudPeriod] — chosen by the same seeded search,
  /// held to the same rules: no cloud of either kind ever overlaps another
  /// anywhere any zoom can show them, none cluster, and no two share a line.
  static const List<JuniorCloud> reserveClouds = [
    JuniorCloud(scale: 0.48, height: -0.467, speed: 5.3, start: 0.951),
    JuniorCloud(scale: 0.58, height: -0.222, speed: 5.7, start: 0.773),
    JuniorCloud(scale: 0.66, height: -0.556, speed: 6.2, start: 0.173),
    JuniorCloud(scale: 0.82, height: -0.696, speed: 7.1, start: 0.805),
    JuniorCloud(scale: 0.95, height: -0.169, speed: 7.8, start: 0.349),
    JuniorCloud(scale: 1.2, height: -0.282, speed: 9.2, start: 0.61),
    JuniorCloud(scale: 0.52, height: 1.308, speed: 5.4, start: 0.814),
    JuniorCloud(scale: 0.6, height: 1.411, speed: 5.8, start: 0.129),
    JuniorCloud(scale: 0.74, height: 1.665, speed: 6.7, start: 0.225),
    JuniorCloud(scale: 0.9, height: 1.168, speed: 7.5, start: 0.643),
    JuniorCloud(scale: 1.05, height: 1.257, speed: 8.5, start: 0.481),
    JuniorCloud(scale: 1.25, height: 1.61, speed: 9.5, start: 0.939),
  ];

  /// Every cloud in the sky: [clouds], then [reserveClouds]. The index every
  /// motion function below takes is an index into this list.
  static const List<JuniorCloud> allClouds = [...clouds, ...reserveClouds];

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

  /// How far past either side of the frame the scenery can ever be seen —
  /// the extra width at the smallest zoom. A cloud only wraps beyond this, so
  /// no zoom ever shows it jump.
  static const double reach =
      JuniorMapGeometry.mapWidth * (1 / JuniorMapScenery.minZoom - 1);

  /// Cloud [index]'s box at the start of its lap, in a sky [skyHeight] tall:
  /// its size, and its height centred on its share of the sky. Travel moves
  /// it right from here by [cloudLeft].
  static Rect cloudBox(int index, double skyHeight) {
    final cloud = allClouds[index];
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
  static double cloudLap(int index) => allClouds[index].speed * cloudPeriod;

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
  /// of sight at every zoom — and travels on.
  static double cloudLeft(int index, double seconds) {
    final cloud = allClouds[index];
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

/// Two or more fingers, claimed as soon as the second one lands.
///
/// [ScaleGestureRecognizer] waits for the fingers to travel before it
/// competes, which would let the scroll view's drag win a slightly vertical
/// pinch and a still two-finger touch tap the node under it. This one takes
/// every finger it is tracking the moment there are two. With one finger it
/// never claims anything, leaving scrolls and taps to their owners.
class _PinchGestureRecognizer extends OneSequenceGestureRecognizer {
  _PinchGestureRecognizer({super.debugOwner});

  /// A pinch began, or its fingers changed: [focal] is their centre, in
  /// global coordinates, and [span] their mean distance from it.
  void Function(Offset focal, double span)? onStart;
  void Function(Offset focal, double span)? onUpdate;

  final Map<int, Offset> _points = {};
  bool _pinching = false;

  Offset get _focal =>
      _points.values.reduce((a, b) => a + b) / _points.length.toDouble();

  double get _span {
    final focal = _focal;
    return _points.values
            .map((p) => (p - focal).distance)
            .reduce((a, b) => a + b) /
        _points.length;
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _points[event.pointer] = event.position;
    if (_points.length >= 2) {
      resolve(GestureDisposition.accepted);
      _pinching = true;
      onStart?.call(_focal, _span);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _points[event.pointer] = event.position;
      if (_pinching) onUpdate?.call(_focal, _span);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _drop(event.pointer);
    }
  }

  @override
  void rejectGesture(int pointer) => _drop(pointer);

  void _drop(int pointer) {
    if (_points.remove(pointer) == null) return;
    stopTrackingPointer(pointer);
    if (!_pinching) return;
    if (_points.length >= 2) {
      onStart?.call(_focal, _span);
    } else {
      _pinching = false;
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _points.clear();
    _pinching = false;
  }

  @override
  String get debugDescription => 'pinch';
}

/// One cloud of the Junior sky. See [JuniorSceneryMotion.allClouds].
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
