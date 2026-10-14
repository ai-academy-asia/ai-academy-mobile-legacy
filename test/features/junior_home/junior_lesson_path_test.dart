import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/junior_home/data/sample_junior_learning_map.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_learning_map.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_certificate_card.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_learning_map_view.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_geometry.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_node.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_scenery.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_junior_home_repository.dart';

/// The lesson path's own parts (Issue #410): a lesson node's four looks,
/// the check-in node's pulse, the certificate's divider clouds and the
/// background theme — and the path on a small phone with large text.
void main() {
  setUpAll(loadAppFonts);

  const lesson = JuniorMapNode(id: 7, state: JuniorNodeState.current);

  Future<void> pumpTile(
    WidgetTester tester,
    JuniorMapNode node, {
    bool checkIn = false,
    bool reducedMotion = true,
  }) async {
    useLogicalViewport(tester, const Size(200, 200));
    if (reducedMotion) useReducedMotion(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Center(
          child: SizedBox.square(
            dimension: JuniorMapGeometry.nodeSize,
            child: JuniorMapNodeTile(
              node: node,
              number: 1,
              scale: 1,
              checkIn: checkIn,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
  }

  Finder sprite(String name) => find.byWidgetPredicate(
    (w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == JuniorMapGeometry.sprite(name),
  );
  final pulse = find.descendant(
    of: find.byType(JuniorMapNodeTile),
    matching: find.byType(ScaleTransition),
  );

  group('a lesson node', () {
    for (final (state, checkIn, look) in [
      (JuniorNodeState.completed, false, 'the tick'),
      (JuniorNodeState.locked, false, 'the padlock'),
      (JuniorNodeState.current, true, 'the scan mark'),
    ]) {
      testWidgets('${state.name}${checkIn ? ' check-in' : ''}: $look', (
        tester,
      ) async {
        await pumpTile(
          tester,
          JuniorMapNode(id: 1, state: state),
          checkIn: checkIn,
        );

        final name = switch (look) {
          'the tick' => 'node_check',
          'the padlock' => 'node_lock',
          _ => 'node_current',
        };
        expect(sprite(name), findsOneWidget);
        expect(find.byIcon(AppIcons.bookOpenText), findsNothing);
      });
    }

    testWidgets('open: the lesson glyph, no sprite', (tester) async {
      await pumpTile(tester, lesson);

      expect(find.byIcon(AppIcons.bookOpenText), findsOneWidget);
      for (final name in ['node_check', 'node_lock', 'node_current']) {
        expect(sprite(name), findsNothing);
      }
    });
  });

  group('the check-in pulse', () {
    testWidgets('a gentle, repeating swell — while the node\'s place and tap '
        'target never move', (tester) async {
      await pumpTile(tester, lesson, checkIn: true, reducedMotion: false);
      final place = tester.getRect(find.byType(JuniorMapNodeTile));
      final target = tester.getRect(find.byType(GestureDetector));

      final scales = <double>[];
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 350));
        scales.add(tester.widget<ScaleTransition>(pulse).scale.value);
        expect(tester.getRect(find.byType(JuniorMapNodeTile)), place);
        expect(tester.getRect(find.byType(GestureDetector)), target);
      }
      // It moves, within its bounds, and comes back.
      expect(scales.toSet().length, greaterThan(2));
      expect(
        scales,
        everyElement(inInclusiveRange(1.0, JuniorMapNodeTile.pulseScale)),
      );
      expect(JuniorMapNodeTile.pulseScale, lessThanOrEqualTo(1.1));
      expect(
        JuniorMapNodeTile.pulsePeriod,
        greaterThanOrEqualTo(const Duration(seconds: 1)),
      );
    });

    testWidgets('none with reduced motion: no animation at all', (
      tester,
    ) async {
      await pumpTile(tester, lesson, checkIn: true);
      await tester.pump();

      expect(pulse, findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
      // Still the check-in look.
      expect(sprite('node_current'), findsOneWidget);
    });

    testWidgets('none on any other node', (tester) async {
      await pumpTile(tester, lesson, reducedMotion: false);
      await tester.pump();

      expect(pulse, findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('stops — at full size — the moment check-in closes', (
      tester,
    ) async {
      await pumpTile(tester, lesson, checkIn: true, reducedMotion: false);
      await tester.pump(const Duration(milliseconds: 500));
      expect(pulse, findsOneWidget);

      await pumpTile(tester, lesson, reducedMotion: false);
      await tester.pump();

      expect(pulse, findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
      expect(
        tester.getSize(find.byType(JuniorMapNodeTile)),
        const Size.square(JuniorMapGeometry.nodeSize),
      );
    });
  });

  group('the divider clouds', () {
    final certificate = find.byType(JuniorCertificateCard);
    final divider = find.byWidgetPredicate(
      (w) =>
          w is SvgPicture &&
          w.bytesLoader is SvgAssetLoader &&
          (w.bytesLoader as SvgAssetLoader).assetName ==
              JuniorMapGeometry.cloud,
    );
    // The divider's, not the sky's: those are inside the scenery's sky.
    Finder dividerClouds() => find.byWidgetPredicate(
      (w) =>
          w is SvgPicture &&
          divider.evaluate().any((e) => e.widget == w) &&
          find
              .ancestor(
                of: find.byWidget(w),
                matching: find.byKey(JuniorMapScenery.skyKey),
              )
              .evaluate()
              .isEmpty,
    );

    Future<List<JuniorMapNode>> pumpMap(
      WidgetTester tester, {
      JuniorMapTheme theme = JuniorMapTheme.junior,
    }) async {
      useLogicalViewport(tester, const Size(393, 2400));
      useReducedMotion(tester);
      final tapped = <JuniorMapNode>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: JuniorLearningMapView(
              map: sampleJuniorLearningMap(),
              now: DateTime(2026, 10, 7),
              onLessonTap: tapped.add,
              theme: theme,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tapped;
    }

    testWidgets('the theme\'s four, round the certificate\'s lower half and '
        'under it', (tester) async {
      await pumpMap(tester);

      final card = tester.getRect(certificate);
      final clouds = [
        for (final e in dividerClouds().evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ];
      expect(clouds, hasLength(JuniorMapTheme.junior.dividerClouds.length));
      expect(clouds, hasLength(4));
      for (final cloud in clouds) {
        // Each overlaps the card's lower half…
        expect(cloud.overlaps(card), isTrue);
        expect(cloud.bottom, greaterThan(card.center.dy));
      }
      // …two reach beyond its sides, and the bank runs on under it.
      expect(clouds.where((c) => c.left < card.left), isNotEmpty);
      expect(clouds.where((c) => c.right > card.right), isNotEmpty);
      expect(
        clouds.map((c) => c.bottom).reduce((a, b) => a > b ? a : b),
        greaterThan(card.bottom),
      );
    });

    testWidgets('behind the certificate: painted before it, in the same '
        'layer', (tester) async {
      await pumpMap(tester);

      // Depth-first order is paint order among a Stack's children.
      final order = [
        for (final e in tester.allElements)
          if (e.widget is JuniorCertificateCard)
            'card'
          else if (dividerClouds().evaluate().contains(e))
            'cloud',
      ];
      expect(order, ['cloud', 'cloud', 'cloud', 'cloud', 'card']);
    });

    testWidgets('take no taps and say nothing: a tap on one reaches what is '
        'underneath', (tester) async {
      await pumpMap(tester);

      for (final e in dividerClouds().evaluate()) {
        final cloud = e.renderObject!;
        final rect = tester.getRect(find.byWidget(e.widget));
        // A point of the cloud outside the card.
        final point = Offset(rect.center.dx, rect.bottom - 4);
        final path = tester.hitTestOnBinding(point).path;
        expect(
          path.any((entry) => entry.target == cloud),
          isFalse,
          reason: '$rect',
        );
      }
      expect(
        find.ancestor(
          of: dividerClouds().first,
          matching: find.byType(IgnorePointer),
        ),
        findsWidgets,
      );
      expect(
        tester
            .widgetList<IgnorePointer>(
              find.ancestor(
                of: dividerClouds().first,
                matching: find.byType(IgnorePointer),
              ),
            )
            .any((w) => w.ignoring),
        isTrue,
      );
    });

    testWidgets('never cover a node', (tester) async {
      await pumpMap(tester);

      final clouds = [
        for (final e in dividerClouds().evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ];
      for (var i = 0; i < 12; i++) {
        final node = tester.getRect(find.byType(JuniorMapNodeTile).at(i));
        for (final cloud in clouds) {
          expect(cloud.overlaps(node), isFalse, reason: 'node ${i + 1}');
        }
      }
    });
  });

  group('the background theme', () {
    test('every program draws the Junior sky today', () {
      for (final track in [null, 'junior', 'adult', 'anything']) {
        expect(JuniorMapTheme.forTrack(track), same(JuniorMapTheme.junior));
      }
    });

    testWidgets('another theme brings its own sky and divider without moving '
        'a node', (tester) async {
      Future<List<Rect>> nodesWith(JuniorMapTheme theme) async {
        useLogicalViewport(tester, const Size(393, 2400));
        useReducedMotion(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: JuniorLearningMapView(
                key: UniqueKey(),
                map: sampleJuniorLearningMap(),
                now: DateTime(2026, 10, 7),
                theme: theme,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return [
          for (var i = 0; i < 12; i++)
            tester.getRect(find.byType(JuniorMapNodeTile).at(i)),
        ];
      }

      final junior = await nodesWith(JuniorMapTheme.junior);
      const magenta = Color(0xFFFF00FF);
      final other = await nodesWith(
        JuniorMapTheme(
          sky: (_) => magenta,
          cloudAsset: JuniorMapGeometry.cloud,
          dividerClouds: const [
            JuniorDividerCloud(Rect.fromLTWH(0, 200, 100, 50)),
          ],
        ),
      );

      expect(other, junior);
      // Its one divider cloud in place of Junior's four. (With reduced
      // motion the sky is the still export, so no sky cloud is drawn; the
      // field's colour is checked in motion, below.)
      expect(
        find.descendant(
          of: find.byType(JuniorLearningMapView),
          matching: find.byWidgetPredicate(
            (w) =>
                w is SvgPicture &&
                w.bytesLoader is SvgAssetLoader &&
                (w.bytesLoader as SvgAssetLoader).assetName ==
                    JuniorMapGeometry.cloud,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('in motion, the sky\'s field is the theme\'s colour', (
      tester,
    ) async {
      const magenta = Color(0xFFFF00FF);
      useLogicalViewport(tester, const Size(393, 600));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: JuniorMapScenery(
              scale: 1,
              theme: JuniorMapTheme(
                sky: (_) => magenta,
                cloudAsset: JuniorMapGeometry.cloud,
                dividerClouds: const [],
              ),
              content: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester
            .widgetList<ColoredBox>(
              find.descendant(
                of: find.byKey(JuniorMapScenery.skyKey),
                matching: find.byType(ColoredBox),
              ),
            )
            .map((b) => b.color),
        contains(magenta),
      );
    });
  });

  group('a small phone with large text', () {
    for (final (size, text) in [
      (const Size(320, 568), 1.0),
      (const Size(320, 568), 2.0),
      (const Size(393, 852), 2.0),
    ]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()} at '
          '${text}x: no overflow, and the whole path scrolls into view', (
        tester,
      ) async {
        useLogicalViewport(tester, size, padding: iPhonePadding);
        useReducedMotion(tester);
        tester.platformDispatcher.textScaleFactorTestValue = text;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final errors = <FlutterErrorDetails>[];
        final previous = FlutterError.onError;
        FlutterError.onError = errors.add;
        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: JuniorHomeScreen(
                repository: FakeJuniorHomeRepository(),
                clock: () => DateTime(2026, 10, 7),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final map = tester.getRect(find.byType(JuniorLearningMapView));
          // Inside the safe area: between the header and the tab bar.
          expect(map.top, greaterThanOrEqualTo(iPhonePadding.top));
          expect(
            map.bottom,
            lessThanOrEqualTo(size.height - iPhonePadding.bottom),
          );

          final last = find.byType(JuniorMapNodeTile).last;
          await tester.scrollUntilVisible(
            find.byType(JuniorCertificateCard),
            200,
            scrollable: find.descendant(
              of: find.byType(JuniorLearningMapView),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
          final card = tester.getRect(find.byType(JuniorCertificateCard));
          expect(card.top, lessThan(map.bottom));
          expect(tester.getRect(last).bottom, lessThan(card.top));
        } finally {
          FlutterError.onError = previous;
        }
        expect(errors, isEmpty);
      });
    }
  });
}
