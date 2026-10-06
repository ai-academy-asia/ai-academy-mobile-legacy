import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/junior_home/data/sample_junior_learning_map.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_learning_map.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_certificate_card.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_learning_map_view.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_geometry.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_node.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_scenery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';

/// The Junior map's scenery: the frame's own clouds, islands and coins,
/// fixed to the viewport behind the scrolling learning content — clouds
/// travelling, islands and coins floating, and a pinch that zooms only them.
///
/// A 393 x 600 viewport at a pixel ratio of 1 is a phone's map area at the
/// frame's own width, so the map's scale is exactly 1, every expected value
/// is in design units, and a moving piece snaps to whole points.
void main() {
  setUpAll(loadAppFonts);

  const viewport = Size(393, 600);

  Finder svg(String asset) => find.byWidgetPredicate(
    (w) =>
        w is SvgPicture &&
        w.bytesLoader is SvgAssetLoader &&
        (w.bytesLoader as SvgAssetLoader).assetName == asset,
  );
  final clouds = svg(JuniorMapGeometry.cloud);
  final islands = svg(JuniorMapGeometry.island);
  final coins = svg(JuniorMapGeometry.coin);
  final backdrop = find.byWidgetPredicate(
    (w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == JuniorMapGeometry.backdrop,
  );
  final farIsland = find.byWidgetPredicate(
    (w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == JuniorMapGeometry.farIsland,
  );
  final nodes = find.byType(JuniorMapNodeTile);
  final map = find.byType(JuniorLearningMapView);

  /// The whole export, placed with its map rows on the map's origin.
  const exportRect = Rect.fromLTWH(
    0,
    -JuniorMapGeometry.mapTopInFrame,
    JuniorMapGeometry.mapWidth,
    JuniorMapGeometry.frameHeight,
  );

  /// Pumps the map alone and returns the nodes it reports as tapped. In
  /// motion, the first frame after this one is the scenery's time zero.
  Future<List<JuniorMapNode>> pumpMap(
    WidgetTester tester, {
    bool reducedMotion = false,
  }) async {
    useLogicalViewport(tester, viewport);
    if (reducedMotion) useReducedMotion(tester);
    final tapped = <JuniorMapNode>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: JuniorLearningMapView(
            map: sampleJuniorLearningMap(),
            onNodeTap: tapped.add,
          ),
        ),
      ),
    );
    return tapped;
  }

  /// Runs the scenery's clock to [seconds] after its time zero.
  Future<void> runTo(WidgetTester tester, double seconds) async {
    await tester.pump();
    await tester.pump(Duration(microseconds: (seconds * 1e6).round()));
  }

  List<Rect> rectsOf(WidgetTester tester, Finder finder) => [
    for (var i = 0; i < finder.evaluate().length; i++)
      tester.getRect(finder.at(i)),
  ];

  /// The fixed sky's pieces, and the scrolling ground's.
  List<Rect> skyScene(WidgetTester tester) => rectsOf(tester, clouds);
  List<Rect> groundScene(WidgetTester tester) => [
    ...rectsOf(tester, islands),
    ...rectsOf(tester, coins),
    tester.getRect(farIsland),
  ];

  /// Every cloud's box at [seconds], in this viewport's sky (the map's scale
  /// is 1 and the sky is the whole viewport). Travel snaps to whole points.
  List<Rect> skyClouds([double seconds = 0]) => [
    for (var i = 0; i < JuniorSceneryMotion.allClouds.length; i++)
      JuniorSceneryMotion.cloudBox(
        i,
        viewport.height,
      ).translate(JuniorSceneryMotion.cloudLeft(i, seconds).roundToDouble(), 0),
  ];

  /// The width of cloud [i].
  double cloudWidth(int i) =>
      JuniorMapGeometry.cloudSize.width *
      JuniorSceneryMotion.allClouds[i].scale;
  List<Rect> designIslands() => [
    for (final island in JuniorMapGeometry.islands)
      island & JuniorMapGeometry.islandSize,
  ];
  List<Rect> designCoins() => [
    for (final island in JuniorMapGeometry.islands)
      island + JuniorMapGeometry.coinOnIsland & JuniorMapGeometry.coinSize,
  ];

  void expectRects(List<Rect> actual, List<Rect> expected) {
    expect(actual, hasLength(expected.length));
    for (var i = 0; i < expected.length; i++) {
      expect(actual[i], rectMoreOrLessEquals(expected[i], epsilon: 1e-6));
    }
  }

  /// The sky's current zoom, read off the largest cloud's drawn width
  /// (clouds only ever move sideways, so their width is the zoom alone).
  double zoomOf(WidgetTester tester) =>
      tester.getRect(clouds.at(9)).width / cloudWidth(9);

  /// Two fingers about [centre], [gap] apart horizontally, that land and
  /// stay down. [spread] moves both apart (or together) by [by] each.
  Future<(TestGesture, TestGesture)> land(
    WidgetTester tester,
    Offset centre,
    double gap,
  ) async {
    final a = await tester.startGesture(
      centre - Offset(gap / 2, 0),
      pointer: 1,
    );
    final b = await tester.startGesture(
      centre + Offset(gap / 2, 0),
      pointer: 2,
    );
    await tester.pump();
    return (a, b);
  }

  Future<void> spread(
    WidgetTester tester,
    (TestGesture, TestGesture) fingers,
    double by,
  ) async {
    await fingers.$1.moveBy(Offset(-by, 0));
    await fingers.$2.moveBy(Offset(by, 0));
    await tester.pump();
  }

  Future<void> lift(
    WidgetTester tester,
    (TestGesture, TestGesture) fingers,
  ) async {
    await fingers.$1.up();
    await fingers.$2.up();
    await tester.pump();
  }

  group('reduced motion', () {
    testWidgets('draws the export itself, exactly as before, and holds still', (
      tester,
    ) async {
      await pumpMap(tester, reducedMotion: true);
      await tester.pumpAndSettle();

      expect(backdrop, findsOneWidget);
      expect(tester.getRect(backdrop), exportRect);
      expect(clouds, findsNothing);
      expect(islands, findsNothing);
      expect(coins, findsNothing);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pump(const Duration(seconds: 30));
      expect(tester.getRect(backdrop), exportRect);
    });

    testWidgets('the still export stays fixed to the viewport while the '
        'content scrolls', (tester) async {
      await pumpMap(tester, reducedMotion: true);
      await tester.pumpAndSettle();
      final node = tester.getRect(nodes.first);

      await tester.drag(map, const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.getRect(nodes.first).top, lessThan(node.top - 200));
      expect(tester.getRect(backdrop), exportRect);
    });

    testWidgets('a pinch does not zoom the still scenery', (tester) async {
      await pumpMap(tester, reducedMotion: true);
      await tester.pumpAndSettle();
      final nodesBefore = rectsOf(tester, nodes);

      final fingers = await land(tester, const Offset(196, 300), 100);
      for (var i = 0; i < 20; i++) {
        await spread(tester, fingers, 2);
      }
      await lift(tester, fingers);
      await tester.pumpAndSettle();

      expect(tester.getRect(backdrop), exportRect);
      expect(rectsOf(tester, nodes), nodesBefore);
    });

    testWidgets('switching it on mid-motion stills and unzooms the scenery', (
      tester,
    ) async {
      await pumpMap(tester);
      await runTo(tester, 12);
      final fingers = await land(tester, const Offset(196, 300), 100);
      await spread(tester, fingers, 5);
      await lift(tester, fingers);
      expect(zoomOf(tester), isNot(1));

      useReducedMotion(tester);
      await tester.pump();

      expect(clouds, findsNothing);
      expect(tester.getRect(backdrop), exportRect);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('in motion', () {
    testWidgets('animates 22 clouds — the sky\'s 10 and 12 in reserve — and '
        'the design\'s 3 islands and 3 coins', (tester) async {
      await pumpMap(tester);
      await tester.pump();

      // The 10 of the sky at rest and the 12 held in reserve for zooming
      // out — all there all the time.
      expect(clouds, findsNWidgets(22));
      expect(islands, findsNWidgets(3));
      expect(coins, findsNWidgets(3));
      expect(farIsland, findsOneWidget);
      // The whole export is only ever the still scenery.
      expect(backdrop, findsNothing);
    });

    testWidgets('opens with the islands and coins exactly on the design and '
        'every cloud at its own start', (tester) async {
      await pumpMap(tester);
      await runTo(tester, 0);

      expectRects(rectsOf(tester, clouds), skyClouds());
      expectRects(rectsOf(tester, islands), designIslands());
      expectRects(rectsOf(tester, coins), designCoins());
    });

    testWidgets('places every piece by the motion functions, nothing else', (
      tester,
    ) async {
      const t = 12.5;
      await pumpMap(tester);
      await runTo(tester, t);

      expectRects(rectsOf(tester, clouds), skyClouds(t));
      expectRects(rectsOf(tester, islands), [
        for (final (i, rect) in designIslands().indexed)
          rect.translate(
            0,
            JuniorSceneryMotion.islandRise(i, t).roundToDouble(),
          ),
      ]);
      expectRects(rectsOf(tester, coins), [
        for (final (i, rect) in designCoins().indexed)
          rect.translate(0, JuniorSceneryMotion.coinRise(i, t).roundToDouble()),
      ]);
    });

    testWidgets('the same moment always gives the same scene', (tester) async {
      await pumpMap(tester);
      await runTo(tester, 33.3);
      final first = [...skyScene(tester), ...groundScene(tester)];

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpMap(tester);
      await runTo(tester, 33.3);

      expect([...skyScene(tester), ...groundScene(tester)], first);
    });

    testWidgets('clouds travel right, islands and coins only float — and the '
        'learning content never moves', (tester) async {
      await pumpMap(tester);
      await tester.pump();
      final nodesAtRest = rectsOf(tester, nodes);
      final card = tester.getRect(find.byType(JuniorCertificateCard));
      final islandRects = designIslands();
      var previous = rectsOf(tester, clouds);

      for (var step = 1; step <= 120; step++) {
        await tester.pump(const Duration(milliseconds: 500));

        final now = rectsOf(tester, clouds);
        for (final (i, rect) in now.indexed) {
          expect(rect.top, skyClouds()[i].top);
          // Right, or round to the left again — and only from the far side
          // of everything any zoom shows. (Sampled every half second, so the
          // last sight of it can be up to half a second's travel short.)
          final step = JuniorSceneryMotion.allClouds[i].speed * 0.5 + 1;
          if (rect.left < previous[i].left) {
            expect(
              previous[i].left,
              greaterThanOrEqualTo(
                JuniorMapGeometry.mapWidth + JuniorSceneryMotion.reach - step,
              ),
            );
            expect(
              rect.right,
              lessThanOrEqualTo(-JuniorSceneryMotion.reach + step),
            );
          }
        }
        previous = now;

        final rises = <double>[];
        for (final (i, rect) in rectsOf(tester, islands).indexed) {
          expect(rect.left, islandRects[i].left);
          final rise = rect.top - islandRects[i].top;
          expect(
            rise.abs(),
            lessThanOrEqualTo(JuniorSceneryMotion.islandFloat + 0.5),
          );
          rises.add(rise);
        }
        for (final (i, rect) in rectsOf(tester, coins).indexed) {
          final design = designCoins()[i];
          expect(rect.left, design.left);
          final bob = rect.top - design.top - rises[i];
          expect(bob.abs(), lessThanOrEqualTo(JuniorSceneryMotion.coinBob + 1));
        }

        expect(rectsOf(tester, nodes), nodesAtRest);
        expect(tester.getRect(find.byType(JuniorCertificateCard)), card);
      }

      // And they really travel: after a minute every cloud is well on its way.
      for (final (i, rect) in rectsOf(tester, clouds).indexed) {
        expect(rect.left, isNot(skyClouds()[i].left));
      }
    });

    testWidgets('the unmatched island and coin sit at their design place and '
        'do not float', (tester) async {
      await pumpMap(tester);
      await runTo(tester, 0);
      expect(tester.getRect(farIsland), JuniorMapGeometry.unmatchedScenery);

      await tester.pump(const Duration(seconds: 40));
      expect(tester.getRect(farIsland), JuniorMapGeometry.unmatchedScenery);
    });

    testWidgets('a node still opens on a tap', (tester) async {
      final tapped = await pumpMap(tester);
      await runTo(tester, 10);

      await tester.tap(nodes.at(2));
      await tester.pump();

      expect(tapped, hasLength(1));
      expect(tapped.single.state, JuniorNodeState.current);
    });

    testWidgets('vertical scrolling reaches the certificate: the content '
        'moves, the clouds, islands and coins stay', (tester) async {
      await pumpMap(tester);
      await runTo(tester, 10);
      final certificate = find.byType(JuniorCertificateCard);
      expect(tester.getRect(certificate).top, greaterThan(viewport.height));
      final node = tester.getRect(nodes.first);
      final sky = skyScene(tester);
      final ground = groundScene(tester);

      await tester.drag(map, const Offset(0, -500));
      // No time passes, so only the scroll could have moved anything.
      await tester.pump();

      expect(tester.getRect(certificate).top, lessThan(viewport.height));
      expect(tester.getRect(nodes.first).top - node.top, lessThan(-400));
      expect(skyScene(tester), sky);
      expect(groundScene(tester), ground);
    });

    testWidgets('the islands and coins keep floating in place while the '
        'content is scrolled', (tester) async {
      await pumpMap(tester);
      await runTo(tester, 4);
      await tester.drag(map, const Offset(0, -250));
      await tester.pump();
      expect(
        tester.getRect(nodes.first).top,
        lessThan(JuniorMapGeometry.nodes[0].dy - 150),
      );

      // Time passes with the map scrolled: each piece is where its float
      // puts it, about its own fixed design place.
      await tester.pump(const Duration(milliseconds: 8300));
      const t = 4 + 8.3;
      expectRects(rectsOf(tester, islands), [
        for (final (i, rect) in designIslands().indexed)
          rect.translate(
            0,
            JuniorSceneryMotion.islandRise(i, t).roundToDouble(),
          ),
      ]);
      expectRects(rectsOf(tester, coins), [
        for (final (i, rect) in designCoins().indexed)
          rect.translate(0, JuniorSceneryMotion.coinRise(i, t).roundToDouble()),
      ]);
    });

    testWidgets('the sky and the ground both fill the viewport', (
      tester,
    ) async {
      await pumpMap(tester);
      await runTo(tester, 0);

      expect(
        tester.getRect(find.byKey(JuniorMapScenery.skyKey)),
        Offset.zero & viewport,
      );
      expect(
        tester.getRect(find.byKey(JuniorMapScenery.groundKey)),
        Offset.zero & viewport,
      );
    });

    testWidgets('its ticker stops when the map goes away', (tester) async {
      await pumpMap(tester);
      await runTo(tester, 5);
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pumpWidget(const SizedBox.shrink());

      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('pinch', () {
    // Each test pinches at the scenery's time zero and pumps no time, so
    // nothing moves but the zoom.

    testWidgets('the zoom follows the fingers continuously: 1.01, 1.02, …', (
      tester,
    ) async {
      await pumpMap(tester);
      await runTo(tester, 0);
      expect(zoomOf(tester), moreOrLessEquals(1));

      // Fingers 100 apart, each moving 0.5 out: the spread grows 1% a step.
      final fingers = await land(tester, const Offset(196, 300), 100);
      for (var step = 1; step <= 40; step++) {
        await spread(tester, fingers, 0.5);
        expect(zoomOf(tester), moreOrLessEquals(1 + step / 100));
      }
      // Past 1.4 it holds.
      for (var step = 0; step < 10; step++) {
        await spread(tester, fingers, 0.5);
      }
      expect(zoomOf(tester), moreOrLessEquals(JuniorMapScenery.maxZoom));
      await lift(tester, fingers);
      expect(zoomOf(tester), moreOrLessEquals(JuniorMapScenery.maxZoom));
    });

    testWidgets('pinching in goes 0.99, 0.98, … and stops at 0.6', (
      tester,
    ) async {
      await pumpMap(tester);
      await runTo(tester, 0);

      final fingers = await land(tester, const Offset(196, 300), 100);
      for (var step = 1; step <= 40; step++) {
        await spread(tester, fingers, -0.5);
        expect(zoomOf(tester), moreOrLessEquals(1 - step / 100));
      }
      for (var step = 0; step < 10; step++) {
        await spread(tester, fingers, -0.5);
      }
      expect(zoomOf(tester), moreOrLessEquals(JuniorMapScenery.minZoom));
      await lift(tester, fingers);
    });

    testWidgets('zooms about the fingers: what was under them stays there', (
      tester,
    ) async {
      await pumpMap(tester);
      await runTo(tester, 0);
      // Upper right.
      const focal = Offset(300, 100);
      final big = tester.getRect(clouds.at(9));
      final cloud = tester.getRect(clouds.at(2));
      final ground = groundScene(tester);

      final fingers = await land(tester, focal, 60);
      for (var step = 0; step < 6; step++) {
        await spread(tester, fingers, 1);
      }
      final zoom = zoomOf(tester);
      expect(zoom, moreOrLessEquals(1.2));

      Rect about(Rect r) => Rect.fromPoints(
        focal + (r.topLeft - focal) * zoom,
        focal + (r.bottomRight - focal) * zoom,
      );
      expect(tester.getRect(clouds.at(9)), rectMoreOrLessEquals(about(big)));
      expect(tester.getRect(clouds.at(2)), rectMoreOrLessEquals(about(cloud)));
      // The islands and coins are the map's, not the sky's: untouched.
      expect(groundScene(tester), ground);
      await lift(tester, fingers);
    });

    testWidgets('zooming out about the fingers works the same way', (
      tester,
    ) async {
      await pumpMap(tester);
      await runTo(tester, 0);
      const focal = Offset(196, 300);
      final cloud = tester.getRect(clouds.at(4));
      final ground = groundScene(tester);

      final fingers = await land(tester, focal, 100);
      for (var step = 0; step < 40; step++) {
        await spread(tester, fingers, -0.5);
      }
      expect(zoomOf(tester), moreOrLessEquals(0.6));

      expect(
        tester.getRect(clouds.at(4)).topLeft,
        offsetMoreOrLessEquals(focal + (cloud.topLeft - focal) * 0.6),
      );
      expect(groundScene(tester), ground);
      await lift(tester, fingers);
    });

    testWidgets('back at 1.0 the scenery is exactly the design again', (
      tester,
    ) async {
      await pumpMap(tester);
      await runTo(tester, 0);

      // In at the upper right…
      var fingers = await land(tester, const Offset(300, 100), 60);
      for (var step = 0; step < 6; step++) {
        await spread(tester, fingers, 1);
      }
      await lift(tester, fingers);
      // …and out again somewhere else entirely.
      fingers = await land(tester, const Offset(80, 500), 120);
      for (var step = 0; step < 5; step++) {
        await spread(tester, fingers, -2);
      }
      await lift(tester, fingers);

      expect(zoomOf(tester), moreOrLessEquals(1));
      expectRects(rectsOf(tester, islands), designIslands());
      expectRects(rectsOf(tester, clouds), skyClouds());
    });

    testWidgets('zooming out reveals the reserve clouds above and below', (
      tester,
    ) async {
      for (final (focal, revealed) in [
        // Pinching at the bottom grows the view upwards, and the reverse.
        (const Offset(196.5, 590), [11, 13, 15]),
        (const Offset(196.5, 10), [16, 19, 21]),
      ]) {
        await pumpMap(tester);
        await runTo(tester, 0);
        final screen = Offset.zero & viewport;
        for (var i = 10; i < 22; i++) {
          expect(tester.getRect(clouds.at(i)).overlaps(screen), isFalse);
        }

        final fingers = await land(tester, focal, 100);
        for (var step = 0; step < 40; step++) {
          await spread(tester, fingers, -0.5);
        }
        await lift(tester, fingers);
        expect(zoomOf(tester), moreOrLessEquals(JuniorMapScenery.minZoom));

        for (final i in revealed) {
          expect(
            tester.getRect(clouds.at(i)).overlaps(screen),
            isTrue,
            reason: 'cloud $i',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('zooming never makes, removes or moves a cloud: back at 1.0 '
        'all 22 are exactly where they were', (tester) async {
      await pumpMap(tester);
      await runTo(tester, 0);
      final before = rectsOf(tester, clouds);
      expect(before, hasLength(22));

      var fingers = await land(tester, const Offset(120, 450), 100);
      for (var step = 0; step < 40; step++) {
        await spread(tester, fingers, -0.5);
        expect(clouds, findsNWidgets(22));
      }
      await lift(tester, fingers);
      fingers = await land(tester, const Offset(260, 150), 60);
      for (var step = 0; step < 40; step++) {
        await spread(tester, fingers, 1);
        expect(clouds, findsNWidgets(22));
      }
      await lift(tester, fingers);
      expect(zoomOf(tester), moreOrLessEquals(JuniorMapScenery.maxZoom));
      // Back to rest: from 1.4 to 1.0, the spread shrinks to 1/1.4 of itself.
      fingers = await land(tester, const Offset(196, 300), 60);
      await spread(tester, fingers, 30 / JuniorMapScenery.maxZoom - 30);
      await lift(tester, fingers);

      expect(zoomOf(tester), moreOrLessEquals(1));
      expectRects(rectsOf(tester, clouds), before);
    });

    testWidgets('never moves or scales the learning content, nor scrolls it', (
      tester,
    ) async {
      await pumpMap(tester);
      await runTo(tester, 0);
      final nodesBefore = rectsOf(tester, nodes);
      final card = tester.getRect(find.byType(JuniorCertificateCard));
      final ground = groundScene(tester);

      var fingers = await land(tester, const Offset(196, 250), 80);
      for (var step = 0; step < 10; step++) {
        await spread(tester, fingers, 2);
      }
      await lift(tester, fingers);
      // And a pinch whose fingers travel vertically — a scroll's direction.
      final a = await tester.startGesture(const Offset(196, 400), pointer: 1);
      final b = await tester.startGesture(const Offset(196, 300), pointer: 2);
      await tester.pump();
      for (var step = 0; step < 10; step++) {
        await b.moveBy(const Offset(0, -15));
        await tester.pump();
      }
      fingers = (a, b);
      await lift(tester, fingers);

      expect(rectsOf(tester, nodes), nodesBefore);
      expect(tester.getRect(find.byType(JuniorCertificateCard)), card);
      expect(groundScene(tester), ground);
    });

    testWidgets('a pinch starting over a node does not open it', (
      tester,
    ) async {
      final tapped = await pumpMap(tester);
      await runTo(tester, 0);
      final current = tester.getCenter(nodes.at(2));

      // Perfectly still: only the second finger landing tells it from a tap.
      final a = await tester.startGesture(current, pointer: 1);
      final b = await tester.startGesture(const Offset(60, 120), pointer: 2);
      await tester.pump();
      await a.up();
      await b.up();
      await tester.pump();

      final fingers = await land(tester, current, 60);
      await spread(tester, fingers, 10);
      await lift(tester, fingers);

      expect(tapped, isEmpty);
    });

    testWidgets('vertical scrolling still works once zoomed', (tester) async {
      await pumpMap(tester);
      await runTo(tester, 0);
      final fingers = await land(tester, const Offset(196, 300), 100);
      await spread(tester, fingers, 5);
      await lift(tester, fingers);
      final zoomedSky = skyScene(tester);
      final ground = groundScene(tester);
      final node = tester.getRect(nodes.first);

      await tester.drag(map, const Offset(0, -400));
      await tester.pump();

      expect(tester.getRect(nodes.first).top - node.top, lessThan(-300));
      expect(skyScene(tester), zoomedSky);
      expect(groundScene(tester), ground);
    });

    test('keeps the scenery covering its box at every zoom', () {
      const box = Size(393, 600);
      // At 1.0 there is only one place for it: exactly where it was drawn.
      expect(
        JuniorMapScenery.clampOffset(1, const Offset(50, -80), box),
        Offset.zero,
      );
      // Zoomed in, no edge of the scenery may come inside the box.
      final inZoom = JuniorMapScenery.clampOffset(
        1.4,
        const Offset(20, -500),
        box,
      );
      expect(inZoom.dx, lessThanOrEqualTo(0));
      expect(inZoom.dy, greaterThanOrEqualTo(box.height - 1.4 * box.height));
      // Zoomed out, it may slide only by the room the zoom-out made.
      final outZoom = JuniorMapScenery.clampOffset(
        0.6,
        const Offset(500, 500),
        box,
      );
      expect(outZoom.dx, moreOrLessEquals(0.6 * (box.width / 0.6 - box.width)));
    });
  });

  group('motion', () {
    test('every cloud starts at its own point round its lap, and starts '
        'softly', () {
      for (var i = 0; i < JuniorSceneryMotion.allClouds.length; i++) {
        final entry = JuniorSceneryMotion.cloudEntry(i);
        final lap = JuniorSceneryMotion.cloudExit(i) - entry;
        final left = entry + JuniorSceneryMotion.allClouds[i].start * lap;
        expect(JuniorSceneryMotion.cloudLeft(i, 0), moreOrLessEquals(left));
        // A tenth of a second in, barely a hundredth of a point.
        expect(
          JuniorSceneryMotion.cloudLeft(i, 0.1),
          moreOrLessEquals(left, epsilon: 0.01),
        );
      }
      for (var i = 0; i < 3; i++) {
        expect(JuniorSceneryMotion.islandRise(i, 0), 0);
        expect(JuniorSceneryMotion.coinRise(i, 0), 0);
      }
    });

    test('every cloud travels left to right and comes round only out of '
        'sight, at its own speed', () {
      final speeds = [for (final c in JuniorSceneryMotion.clouds) c.speed];
      expect(speeds.toSet(), hasLength(speeds.length));
      for (var i = 0; i < JuniorSceneryMotion.allClouds.length; i++) {
        final width = cloudWidth(i);
        var previous = JuniorSceneryMotion.cloudLeft(i, 0);
        var laps = 0;
        for (var t = 0.05; t <= 600; t += 0.05) {
          final left = JuniorSceneryMotion.cloudLeft(i, t);
          if (left < previous) {
            laps++;
            // Gone past everything any zoom shows on the right…
            expect(
              previous,
              greaterThan(
                JuniorMapGeometry.mapWidth + JuniorSceneryMotion.reach - 1,
              ),
            );
            // …and back beyond everything it shows on the left.
            expect(left + width, lessThan(-JuniorSceneryMotion.reach + 1));
          } else {
            // Otherwise only ever a small step right.
            expect(left - previous, lessThan(1));
          }
          previous = left;
        }
        expect(laps, greaterThanOrEqualTo(1), reason: 'cloud $i');
      }
    });

    test('clouds switch sides beyond the widest view any zoom allows', () {
      // At the frame's own width the map's scale is 1, so the box is in
      // design units. At the smallest zoom, pushed as far as the clamp lets
      // it go either way, this is everything the viewport can show.
      const box = Size(JuniorMapGeometry.mapWidth, 600);
      const zoom = JuniorMapScenery.minZoom;
      final farLeft =
          -JuniorMapScenery.clampOffset(zoom, const Offset(1e9, 0), box).dx /
          zoom;
      final farRight =
          (box.width -
              JuniorMapScenery.clampOffset(
                zoom,
                const Offset(-1e9, 0),
                box,
              ).dx) /
          zoom;
      expect(farLeft, lessThan(0));
      expect(farRight, greaterThan(box.width));

      for (var i = 0; i < JuniorSceneryMotion.allClouds.length; i++) {
        final width = cloudWidth(i);
        // Entering: wholly left of the farthest-left view.
        expect(
          JuniorSceneryMotion.cloudEntry(i) + width,
          lessThanOrEqualTo(farLeft),
        );
        // Leaving: wholly right of the farthest-right view.
        expect(
          JuniorSceneryMotion.cloudExit(i),
          greaterThanOrEqualTo(farRight),
        );
      }
    });

    group('the sky', () {
      final sky = JuniorSceneryMotion.clouds;

      test('is fixed data: the same boxes and travel every time', () {
        for (var i = 0; i < sky.length; i++) {
          expect(
            JuniorSceneryMotion.cloudBox(i, 600),
            JuniorSceneryMotion.cloudBox(i, 600),
          );
          expect(
            JuniorSceneryMotion.cloudLeft(i, 77.7),
            JuniorSceneryMotion.cloudLeft(i, 77.7),
          );
        }
        // Pinned, so the sky cannot drift between releases.
        expect(sky, hasLength(10));
        expect(
          JuniorSceneryMotion.cloudBox(9, 600),
          rectMoreOrLessEquals(const Rect.fromLTWH(0, 229.9, 269.1, 137.8)),
        );
        expect(JuniorSceneryMotion.cloudLeft(9, 0), moreOrLessEquals(-1265.8));
      });

      test('has small, medium, large and extra-large clouds, none huge', () {
        final scales = [for (final c in sky) c.scale];
        expect(scales.reduce((a, b) => a < b ? a : b), 0.45);
        expect(scales.reduce((a, b) => a > b ? a : b), 1.3);
        expect(scales.where((s) => s < 0.6), isNotEmpty, reason: 'small');
        expect(
          scales.where((s) => s >= 0.6 && s < 0.9),
          isNotEmpty,
          reason: 'medium',
        );
        expect(
          scales.where((s) => s >= 0.9 && s < 1.2),
          isNotEmpty,
          reason: 'large',
        );
        expect(scales.where((s) => s >= 1.2), isNotEmpty, reason: 'XL');
        // Never larger than the largest cloud the frame itself draws.
        for (var i = 0; i < sky.length; i++) {
          final box = JuniorSceneryMotion.cloudBox(i, 600);
          expect(
            box.width,
            lessThanOrEqualTo(JuniorMapGeometry.largestDesignCloud.width),
          );
          expect(
            box.height,
            lessThanOrEqualTo(JuniorMapGeometry.largestDesignCloud.height),
          );
        }
        // Drawn smallest first, so the larger pass in front.
        expect(scales, orderedEquals([...scales]..sort()));
      });

      test('spreads over the whole sky, never two on one line', () {
        final heights = [for (final c in sky) c.height]..sort();
        expect(heights.first, lessThan(0.15), reason: 'near the top');
        expect(heights.last, greaterThan(0.8), reason: 'low in the sky');
        expect(
          heights.where((h) => h > 0.35 && h < 0.65),
          isNotEmpty,
          reason: 'around the middle',
        );
        for (var i = 1; i < heights.length; i++) {
          expect(heights[i] - heights[i - 1], greaterThanOrEqualTo(0.04));
        }
        // Not a regular grid: the gaps between rows are not all alike.
        final gaps = [
          for (var i = 1; i < heights.length; i++) heights[i] - heights[i - 1],
        ];
        expect(gaps.toSet().length, greaterThan(gaps.length ~/ 2));
      });

      test(
        'starts out of step, and every cloud waits its turn out of sight',
        () {
          final starts = [for (final c in sky) c.start];
          expect(starts.toSet(), hasLength(sky.length));
          expect(starts.reduce((a, b) => a < b ? a : b), lessThan(0.2));
          expect(starts.reduce((a, b) => a > b ? a : b), greaterThan(0.8));
          for (var i = 0; i < sky.length; i++) {
            // The lap is at least the whole visible run plus the cloud itself.
            expect(
              JuniorSceneryMotion.cloudLap(i),
              greaterThanOrEqualTo(
                JuniorMapGeometry.mapWidth +
                    2 * JuniorSceneryMotion.reach +
                    cloudWidth(i),
              ),
            );
          }
        },
      );

      test('larger clouds pass a little faster, all of them gently', () {
        for (var i = 1; i < sky.length; i++) {
          expect(sky[i].speed, greaterThanOrEqualTo(sky[i - 1].speed - 0.5));
        }
        for (final cloud in sky) {
          expect(cloud.speed, inInclusiveRange(4, 10));
        }
      });

      test('repeats exactly every period, so one period proves them all', () {
        const period = JuniorSceneryMotion.cloudPeriod;
        for (var i = 0; i < JuniorSceneryMotion.allClouds.length; i++) {
          for (final t in <double>[6, 31.4, 100, 249.9]) {
            expect(
              JuniorSceneryMotion.cloudLeft(i, t + period),
              moreOrLessEquals(
                JuniorSceneryMotion.cloudLeft(i, t),
                epsilon: 1e-6,
              ),
            );
          }
        }
      });

      /// Every 0.1 s across one whole period (after the soft start, plus the
      /// start itself), calls [check] with every cloud's box — the sky's and
      /// the reserve's — at that moment.
      void simulate(double skyHeight, void Function(List<Rect> boxes) check) {
        const period = JuniorSceneryMotion.cloudPeriod;
        for (var step = 0; step <= (period + 6) * 10; step++) {
          final t = step / 10;
          check([
            for (var i = 0; i < JuniorSceneryMotion.allClouds.length; i++)
              JuniorSceneryMotion.cloudBox(
                i,
                skyHeight,
              ).translate(JuniorSceneryMotion.cloudLeft(i, t), 0),
          ]);
        }
      }

      /// Anywhere any zoom can show.
      bool inSight(Rect box) =>
          box.right > -JuniorSceneryMotion.reach &&
          box.left < JuniorMapGeometry.mapWidth + JuniorSceneryMotion.reach;

      test('never overlap — none of the 22, not at the start, not at any '
          'moment after', () {
        // The shortest phone sky is the tightest; taller ones only spread
        // the clouds further apart, but check a typical and a tall one too.
        for (final skyHeight in [480.0, 600.0, 1214.0]) {
          var closest = double.infinity;
          simulate(skyHeight, (boxes) {
            for (var i = 0; i < boxes.length; i++) {
              for (var j = i + 1; j < boxes.length; j++) {
                final a = boxes[i];
                final b = boxes[j];
                if (!inSight(a) || !inSight(b)) continue;
                // The gap between them, along whichever axis separates them.
                final across =
                    (a.left > b.left ? a.left : b.left) -
                    (a.right < b.right ? a.right : b.right);
                final down =
                    (a.top > b.top ? a.top : b.top) -
                    (a.bottom < b.bottom ? a.bottom : b.bottom);
                final gap = across > down ? across : down;
                // Large clouds keep further apart than small ones.
                final required = 8 + 0.1 * (a.width + b.width);
                final spare = gap - required;
                if (spare < closest) closest = spare;
              }
            }
          });
          expect(
            closest,
            greaterThanOrEqualTo(0),
            reason: 'sky height $skyHeight',
          );
        }
      });

      test('never cluster: on screen, no cloud ever has more than one other '
          'close by, and two to five are in view', () {
        var mostNeighbours = 0;
        var fewest = JuniorSceneryMotion.allClouds.length;
        var most = 0;
        simulate(600, (boxes) {
          // At 1.0x: the reserve is never among these.
          final onScreen = [
            for (final box in boxes)
              if (box.right > 0 &&
                  box.left < JuniorMapGeometry.mapWidth &&
                  box.bottom > 0 &&
                  box.top < 600)
                box,
          ];
          if (onScreen.length < fewest) fewest = onScreen.length;
          if (onScreen.length > most) most = onScreen.length;
          for (final a in onScreen) {
            final near = onScreen
                .where((b) => b != a && (b.center - a.center).distance < 170)
                .length;
            if (near > mostNeighbours) mostNeighbours = near;
          }
        });
        expect(mostNeighbours, lessThanOrEqualTo(1));
        expect(fewest, greaterThanOrEqualTo(2), reason: 'never an empty sky');
        expect(most, lessThanOrEqualTo(5), reason: 'never crowded');
      });
    });

    group('cover', () {
      // The phone's sky as a loose three-by-three grid: a cloud counts in a
      // zone when at least 30% of it is inside. Zones are for measuring
      // balance only — nothing is placed on them.
      const width = JuniorMapGeometry.mapWidth;
      final sky = JuniorSceneryMotion.clouds;

      List<Rect> boxesAt(double t, double skyHeight) => [
        for (var i = 0; i < sky.length; i++)
          JuniorSceneryMotion.cloudBox(
            i,
            skyHeight,
          ).translate(JuniorSceneryMotion.cloudLeft(i, t), 0),
      ];

      Rect zone(int column, int row, double skyHeight) => Rect.fromLTWH(
        column * width / 3,
        row * skyHeight / 3,
        width / 3,
        skyHeight / 3,
      );

      bool holds(Rect zone, List<Rect> boxes, {double share = 0.3}) {
        for (final box in boxes) {
          final part = box.intersect(zone);
          if (part.width > 0 &&
              part.height > 0 &&
              part.width * part.height >= share * box.width * box.height) {
            return true;
          }
        }
        return false;
      }

      /// How far the emptiest point of the visible sky is from any cloud.
      double emptiest(List<Rect> boxes, double skyHeight) {
        final onScreen = [
          for (final box in boxes)
            if (box.right > 0 && box.left < width) box,
        ];
        var worst = 0.0;
        for (var gx = 0; gx <= 8; gx++) {
          for (var gy = 0; gy <= 12; gy++) {
            final p = Offset(gx * width / 8, gy * skyHeight / 12);
            var nearest = double.infinity;
            for (final box in onScreen) {
              final dx = p.dx < box.left
                  ? box.left - p.dx
                  : (p.dx > box.right ? p.dx - box.right : 0.0);
              final dy = p.dy < box.top
                  ? box.top - p.dy
                  : (p.dy > box.bottom ? p.dy - box.bottom : 0.0);
              final d = Offset(dx, dy).distance;
              if (d < nearest) nearest = d;
            }
            if (nearest > worst) worst = nearest;
          }
        }
        return worst;
      }

      /// For each zone: the share of a whole period it holds a cloud, and
      /// the longest it is ever empty, in seconds. Sampled every half second
      /// over two periods, so an empty stretch across the period's end is
      /// measured whole.
      ({double share, double longestEmpty}) presence(
        Rect Function(double skyHeight) zoneOf,
        double skyHeight,
      ) {
        const period = JuniorSceneryMotion.cloudPeriod;
        var held = 0;
        var samples = 0;
        var run = 0.0;
        var longest = 0.0;
        for (var t = 6.0; t < 6 + 2 * period; t += 0.5) {
          final has = holds(zoneOf(skyHeight), boxesAt(t, skyHeight));
          if (t < 6 + period) {
            samples++;
            if (has) held++;
          }
          run = has ? 0 : run + 0.5;
          if (run > longest) longest = run;
        }
        return (share: held / samples, longestEmpty: longest);
      }

      for (final skyHeight in [480.0, 600.0, 700.0]) {
        test('left, centre and right, top, middle and bottom all hold a '
            'cloud most of the time (sky $skyHeight)', () {
          for (var column = 0; column < 3; column++) {
            final p = presence(
              (h) => Rect.fromLTWH(column * width / 3, 0, width / 3, h),
              skyHeight,
            );
            expect(
              p.share,
              greaterThanOrEqualTo(0.75),
              reason: 'column $column',
            );
            expect(
              p.longestEmpty,
              lessThanOrEqualTo(30),
              reason: 'column $column',
            );
          }
          for (var row = 0; row < 3; row++) {
            final p = presence(
              (h) => Rect.fromLTWH(0, row * h / 3, width, h / 3),
              skyHeight,
            );
            // The edges almost always; the middle, where the route runs,
            // about half the time.
            final middle = row == 1;
            expect(
              p.share,
              greaterThanOrEqualTo(middle ? 0.5 : 0.95),
              reason: 'row $row',
            );
            expect(
              p.longestEmpty,
              lessThanOrEqualTo(middle ? 70 : 30),
              reason: 'row $row',
            );
          }
        });

        test(
          'every corner is visited at least every 50 s (sky $skyHeight)',
          () {
            for (final (name, column, row) in [
              ('top left', 0, 0),
              ('top right', 2, 0),
              ('bottom left', 0, 2),
              ('bottom right', 2, 2),
            ]) {
              final p = presence((h) => zone(column, row, h), skyHeight);
              expect(p.share, greaterThanOrEqualTo(0.4), reason: name);
              expect(p.longestEmpty, lessThanOrEqualTo(50), reason: name);
            }
          },
        );

        test('no wide stretch of sky stays empty (sky $skyHeight)', () {
          const period = JuniorSceneryMotion.cloudPeriod;
          final radii = <double>[
            for (var t = 6.0; t < 6 + period; t += 0.5)
              emptiest(boxesAt(t, skyHeight), skyHeight),
          ]..sort();
          final p90 = radii[(radii.length * 0.9).floor()];
          expect(p90, lessThanOrEqualTo(300));
          expect(radii.last, lessThanOrEqualTo(330));
        });

        test('the top and bottom of the sky are almost never bare '
            '(sky $skyHeight)', () {
          final top = presence(
            (h) => Rect.fromLTWH(0, 0, width, h / 4),
            skyHeight,
          );
          final bottom = presence(
            (h) => Rect.fromLTWH(0, h * 3 / 4, width, h / 4),
            skyHeight,
          );
          expect(top.share, greaterThanOrEqualTo(0.95));
          expect(bottom.share, greaterThanOrEqualTo(0.95));
        });

        test('the top and bottom carry more cloud than the middle '
            '(sky $skyHeight)', () {
          const period = JuniorSceneryMotion.cloudPeriod;
          final perThird = [0.0, 0.0, 0.0];
          var samples = 0;
          for (var t = 6.0; t < 6 + period; t += 0.5) {
            samples++;
            for (final box in boxesAt(t, skyHeight)) {
              if (box.right <= 0 || box.left >= width) continue;
              final third = (box.center.dy / (skyHeight / 3)).floor();
              if (third >= 0 && third < 3) perThird[third]++;
            }
          }
          final top = perThird[0] / samples;
          final middle = perThird[1] / samples;
          final bottom = perThird[2] / samples;
          expect(top, greaterThan(middle));
          expect(bottom, greaterThan(middle));
          // …while the middle still has its share.
          expect(middle, greaterThan(0.4));
        });
      }

      test('the first frame fills all four corners', () {
        const skyHeight = 600.0;
        final first = boxesAt(0, skyHeight);
        var strong = 0;
        for (final (column, row) in [(0, 0), (2, 0), (0, 2), (2, 2)]) {
          final corner = zone(column, row, skyHeight);
          expect(holds(corner, first, share: 0.05), isTrue);
          if (holds(corner, first)) strong++;
        }
        expect(strong, 4);
        expect(emptiest(first, skyHeight), lessThanOrEqualTo(160));
      });
    });

    group('reserve clouds', () {
      const reserve = JuniorSceneryMotion.reserveClouds;
      const width = JuniorMapGeometry.mapWidth;
      final first = JuniorSceneryMotion.clouds.length;

      Rect boxAt(int k, double t, double skyHeight) =>
          JuniorSceneryMotion.cloudBox(
            first + k,
            skyHeight,
          ).translate(JuniorSceneryMotion.cloudLeft(first + k, t), 0);

      /// What the viewport shows, in the sky's own coordinates, at [zoom]
      /// with the sky pushed as far towards [push] as the clamp allows.
      Rect view(double zoom, Offset push, double skyHeight) {
        final offset = JuniorMapScenery.clampOffset(
          zoom,
          push,
          Size(width, skyHeight),
        );
        return Rect.fromLTWH(
          -offset.dx / zoom,
          -offset.dy / zoom,
          width / zoom,
          skyHeight / zoom,
        );
      }

      test('twelve — six above the sky, six below — of the same kind', () {
        expect(reserve, hasLength(12));
        expect(reserve.where((c) => c.height < 0), hasLength(6));
        expect(reserve.where((c) => c.height > 1), hasLength(6));
        final speeds = [for (final c in JuniorSceneryMotion.allClouds) c.speed];
        expect(speeds.toSet(), hasLength(speeds.length));
        for (var k = 0; k < reserve.length; k++) {
          final cloud = reserve[k];
          expect(cloud.scale, inInclusiveRange(0.45, 1.3));
          final box = JuniorSceneryMotion.cloudBox(first + k, 600);
          expect(
            box.width,
            lessThanOrEqualTo(JuniorMapGeometry.largestDesignCloud.width),
          );
          // The sky's own pace for its size.
          expect(
            cloud.speed,
            moreOrLessEquals(5 + 5.65 * (cloud.scale - 0.45), epsilon: 0.6),
          );
          expect(
            JuniorSceneryMotion.cloudLap(first + k),
            greaterThanOrEqualTo(
              width + 2 * JuniorSceneryMotion.reach + box.width,
            ),
          );
        }
        for (final band in [
          [
            for (final c in reserve)
              if (c.height < 0) c.height,
          ],
          [
            for (final c in reserve)
              if (c.height > 1) c.height,
          ],
        ]) {
          band.sort();
          for (var i = 1; i < band.length; i++) {
            expect(band[i] - band[i - 1], greaterThanOrEqualTo(0.05));
          }
        }
      });

      test('are never seen at 1.0x or closer, at any sky height from 480 '
          'to 700, wherever the view is pushed', () {
        for (var skyHeight = 480.0; skyHeight <= 700; skyHeight += 10) {
          for (final zoom in [1.0, 1.1, 1.25, JuniorMapScenery.maxZoom]) {
            for (final push in const [
              Offset.zero,
              Offset(1e9, 1e9),
              Offset(-1e9, -1e9),
              Offset(1e9, -1e9),
              Offset(-1e9, 1e9),
            ]) {
              final seen = view(zoom, push, skyHeight);
              for (var k = 0; k < reserve.length; k++) {
                // Its height alone keeps it out, wherever it is in its lap.
                final box = JuniorSceneryMotion.cloudBox(first + k, skyHeight);
                expect(
                  box.top >= seen.bottom || box.bottom <= seen.top,
                  isTrue,
                  reason: 'cloud ${first + k}, sky $skyHeight, ${zoom}x',
                );
              }
            }
          }
        }
      });

      test('zoomed out, they fill the sky it reveals above and below', () {
        const skyHeight = 600.0;
        const zoom = JuniorMapScenery.minZoom;
        // Centred across, pushed as far up — or down — as the clamp allows.
        final centre =
            JuniorMapScenery.clampOffset(
              zoom,
              const Offset(1e9, 0),
              const Size(width, skyHeight),
            ).dx /
            2;
        for (final (name, push) in [
          ('above', Offset(centre, 1e9)),
          ('below', Offset(centre, -1e9)),
        ]) {
          final seen = view(zoom, push, skyHeight);
          final revealed = name == 'above'
              ? Rect.fromLTRB(seen.left, seen.top, seen.right, 0)
              : Rect.fromLTRB(seen.left, skyHeight, seen.right, seen.bottom);
          expect(revealed.height, greaterThan(skyHeight / 2));
          var held = 0;
          var count = 0;
          var samples = 0;
          const period = JuniorSceneryMotion.cloudPeriod;
          for (var t = 6.0; t < 6 + period; t += 0.5) {
            samples++;
            var here = 0;
            for (var k = 0; k < reserve.length; k++) {
              final box = boxAt(k, t, skyHeight);
              final part = box.intersect(revealed);
              if (part.width > 0 &&
                  part.height > 0 &&
                  part.width * part.height >= 0.3 * box.width * box.height) {
                here++;
              }
            }
            if (here > 0) held++;
            count += here;
          }
          expect(held / samples, greaterThanOrEqualTo(0.95), reason: name);
          expect(count / samples, greaterThanOrEqualTo(1.8), reason: name);
        }
      });

      test('zoomed out, nothing clusters anywhere the view can reach', () {
        const skyHeight = 600.0;
        const zoom = JuniorMapScenery.minZoom;
        final reach = Rect.fromLTRB(
          -JuniorSceneryMotion.reach,
          -(skyHeight / zoom - skyHeight),
          width + JuniorSceneryMotion.reach,
          skyHeight / zoom,
        );
        const period = JuniorSceneryMotion.cloudPeriod;
        var most = 0;
        for (var t = 6.0; t < 6 + period; t += 0.5) {
          final centres = [
            for (var i = 0; i < JuniorSceneryMotion.allClouds.length; i++)
              JuniorSceneryMotion.cloudBox(
                i,
                skyHeight,
              ).translate(JuniorSceneryMotion.cloudLeft(i, t), 0).center,
          ].where(reach.contains).toList();
          for (final a in centres) {
            final near = centres
                .where((b) => b != a && (b - a).distance < 170)
                .length;
            if (near > most) most = near;
          }
        }
        expect(most, lessThanOrEqualTo(1));
      });
    });

    test('islands and coins: no period divides another', () {
      for (final periods in [
        JuniorSceneryMotion.islandPeriods,
        JuniorSceneryMotion.coinPeriods,
      ]) {
        expect(periods.toSet(), hasLength(periods.length));
        for (final a in periods) {
          for (final b in periods) {
            if (a >= b) continue;
            final ratio = b / a;
            expect((ratio - ratio.round()).abs(), greaterThan(0.01));
          }
        }
      }
    });

    test('stays within the approved ranges', () {
      expect(
        JuniorSceneryMotion.islandPeriods,
        everyElement(inInclusiveRange(7, 11)),
      );
      expect(
        JuniorSceneryMotion.coinPeriods,
        everyElement(inInclusiveRange(2, 2.5)),
      );
      expect(JuniorSceneryMotion.islandFloat, 1.5);
      expect(JuniorSceneryMotion.coinBob, 2);
      expect(JuniorMapScenery.minZoom, 0.6);
      expect(JuniorMapScenery.maxZoom, 1.4);
    });
  });
}
