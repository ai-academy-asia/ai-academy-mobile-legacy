import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/junior_home/data/sample_junior_learning_map.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_learning_map.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_learning_map_view.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_geometry.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_node.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_path_painter.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_scenery.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_junior_home_repository.dart';

/// The route's colours, as painted (Issue #410).
///
/// One rule: every stretch takes its colour from the lesson it **leaves** —
/// blue when that lesson is completed, white when it is not (the lesson to
/// continue with, one waiting its turn, a locked one). The lesson it enters
/// never changes it; the stretch to the certificate follows the last
/// lesson. Every expectation here is read off the route's actual draw
/// calls, not the geometry helper.
void main() {
  setUpAll(loadAppFonts);

  const done = JuniorNodeState.completed;
  const current = JuniorNodeState.current;
  const open = JuniorNodeState.open;
  const locked = JuniorNodeState.locked;

  JuniorLearningMap mapOf(List<JuniorNodeState> states) {
    final sample = sampleJuniorLearningMap();
    return JuniorLearningMap(
      progress: sample.progress,
      certificate: sample.certificate,
      attendanceRecorded: false,
      continueLessonId: states.indexOf(current) + 1,
      nodes: [
        for (final (i, state) in states.indexed)
          JuniorMapNode(id: i + 1, state: state),
      ],
    );
  }

  Finder route() => find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is JuniorMapPathPainter,
  );

  Future<AppPalette> pumpMap(
    WidgetTester tester,
    List<JuniorNodeState> states, {
    JuniorMapTheme theme = JuniorMapTheme.junior,
    bool reducedMotion = true,
  }) async {
    useLogicalViewport(tester, const Size(393, 2400));
    if (reducedMotion) useReducedMotion(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: JuniorLearningMapView(
            key: UniqueKey(),
            map: mapOf(states),
            now: DateTime(2026, 10, 7),
            theme: theme,
            onLessonTap: (_) {},
          ),
        ),
      ),
    );
    if (reducedMotion) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return tester.element(route()).palette;
  }

  /// The colours the route actually paints, stretch by stretch, in order:
  /// one path per stretch, the last to the certificate.
  PaintPattern paintsColours(List<Color> colours) {
    var matcher = paints;
    for (final colour in colours) {
      matcher = matcher..path(color: colour);
    }
    return matcher;
  }

  RenderObject routeRender(WidgetTester tester) => tester.renderObject(route());

  final cases = <String, (List<JuniorNodeState>, List<bool>)>{
    // (states, blue? per stretch, each the lesson it leaves — the last one
    // is to the certificate)
    'completed → completed': ([done, done], [true, true]),
    'completed → current: blue, from a completed lesson': (
      [done, current],
      [true, false],
    ),
    'current → unfinished: white, from the current lesson': (
      [done, current, open],
      [true, false, false],
    ),
    'locked → next: white, from a locked lesson': (
      [done, locked, done],
      [true, false, true],
    ),
    'the worked example: completed, completed, current, locked, completed, '
        'locked': (
      [done, done, current, locked, done, locked],
      [true, true, false, false, true, false],
    ),
    'alternating states': (
      [done, open, done, open, done, current, locked],
      [true, false, true, false, true, false, false],
    ),
    'the seeded device path ·✓✓✓·✓✓·✓·· — an unfinished first lesson '
        'whitens nothing else': (
      [current, done, done, done, open, done, done, open, done, open, open],
      [false, true, true, true, false, true, true, false, true, false, false],
    ),
    'every lesson completed — the certificate stretch too': (
      [done, done, done, done],
      [true, true, true, true],
    ),
  };

  for (final MapEntry(key: name, value: (states, blue)) in cases.entries) {
    testWidgets(
      '$name: painted ${blue.map((b) => b ? 'blue' : 'white').join(', ')}',
      (tester) async {
        final palette = await pumpMap(tester, states);

        expect(
          routeRender(tester),
          paintsColours([
            for (final b in blue) b ? palette.accent : palette.surface,
          ]),
        );
        expect(
          routeRender(tester),
          paintsExactlyCountTimes(#drawPath, blue.length),
        );
      },
    );
  }

  testWidgets('a completed lesson whose module locked again still leaves '
      'blue — and stays shut', (tester) async {
    useLogicalViewport(tester, const Size(393, 2400));
    useReducedMotion(tester);
    final sample = sampleJuniorLearningMap();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: JuniorLearningMapView(
            map: JuniorLearningMap(
              progress: sample.progress,
              certificate: sample.certificate,
              attendanceRecorded: false,
              continueLessonId: 3,
              nodes: const [
                JuniorMapNode(id: 1, state: done),
                JuniorMapNode(id: 2, state: done, locked: true),
                JuniorMapNode(id: 3, state: current),
              ],
            ),
            now: DateTime(2026, 10, 7),
            onLessonTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final palette = tester.element(route()).palette;

    expect(
      routeRender(tester),
      paintsColours([palette.accent, palette.accent, palette.surface]),
    );
    expect(
      tester
          .widgetList<JuniorMapNodeTile>(find.byType(JuniorMapNodeTile))
          .map((t) => t.onTap != null),
      [true, false, true],
    );
  });

  testWidgets('the simulator report, traced: lesson 1 is the continue lesson '
      '— not completed — so the stretch it leaves is white, and it draws no '
      'tick; every stretch joins node i to node i+1', (tester) async {
    // The seeded device path ·✓✓✓·✓✓·✓··: lesson 1 the continue lesson.
    const states = [
      current,
      done,
      done,
      done,
      open,
      done,
      done,
      open,
      done,
      open,
      open,
    ];
    final palette = await pumpMap(tester, states);
    final tiles = tester
        .widgetList<JuniorMapNodeTile>(find.byType(JuniorMapNodeTile))
        .toList();
    String? glyph(int i) {
      final images = tester.widgetList<Image>(
        find.descendant(
          of: find.byWidget(tiles[i]),
          matching: find.byType(Image),
        ),
      );
      if (images.isEmpty) return null;
      return (images.single.image as AssetImage).assetName.split('/').last;
    }

    // The tick marks only the completed node; the continue lesson wears
    // Figma's QR mark (Issue #412) …
    expect(glyph(0), 'node_current.png');
    expect(glyph(1), 'node_check.png');
    // … as only node 2 is completed: node 1 is the continue lesson.
    expect(tiles[0].node.state, current);
    expect(tiles[1].node.state, done);

    // The stretches as painted, each from the node it leaves.
    expect(
      routeRender(tester),
      paintsColours([
        for (final st in states) st == done ? palette.accent : palette.surface,
      ]),
    );

    // Stretch i starts on node i and ends on node i+1 — no shift by one.
    final painter =
        tester.widget<CustomPaint>(route()).painter! as JuniorMapPathPainter;
    final origin = tester.getTopLeft(route());
    final scale = tester.getSize(route()).width / JuniorMapGeometry.mapWidth;
    Offset onScreen(Offset p) => origin + p * scale;
    for (var i = 0; i + 1 < states.length; i++) {
      final c = painter.connectors[i];
      final from = tester.getRect(find.byWidget(tiles[i])).inflate(1);
      final to = tester.getRect(find.byWidget(tiles[i + 1])).inflate(1);
      expect(
        from.contains(onScreen(c.from)),
        isTrue,
        reason: 'stretch $i from',
      );
      expect(to.contains(onScreen(c.to)), isTrue, reason: 'stretch $i to');
      expect(c.active, states[i] == done, reason: 'stretch $i colour');
    }
    expect(painter.connectors, hasLength(states.length));
  });

  testWidgets('colour opens nothing: whatever the route paints, a lesson '
      'waiting its turn and a locked one stay inert', (tester) async {
    await pumpMap(tester, [done, done, current, open, done, locked]);

    final taps = [
      for (final t in tester.widgetList<JuniorMapNodeTile>(
        find.byType(JuniorMapNodeTile),
      ))
        t.onTap != null,
    ];
    expect(taps, [true, true, true, false, true, false]);
  });

  group('scenery never colours the route', () {
    const states = [done, done, done, current, done, open, locked];
    const blue = [true, true, true, false, true, false, false];

    testWidgets('with the cloud bank or without it: the same paint', (
      tester,
    ) async {
      final palette = await pumpMap(tester, states);
      final expected = paintsColours([
        for (final b in blue) b ? palette.accent : palette.surface,
      ]);
      expect(routeRender(tester), expected);

      await pumpMap(
        tester,
        states,
        theme: JuniorMapTheme(
          sky: (p) => p.juniorMapSky,
          cloudAsset: JuniorMapGeometry.cloud,
          bankClouds: const [],
        ),
      );
      expect(routeRender(tester), expected);
    });

    testWidgets('in motion, as the clouds travel: the same paint', (
      tester,
    ) async {
      final palette = await pumpMap(tester, states, reducedMotion: false);
      final expected = paintsColours([
        for (final b in blue) b ? palette.accent : palette.surface,
      ]);
      expect(routeRender(tester), expected);

      await tester.pump(const Duration(seconds: 30));
      expect(routeRender(tester), expected);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('on a phone, the stretches crossing the cloud bank keep '
        'their colours as the path scrolls over it', (tester) async {
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      useReducedMotion(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: JuniorHomeScreen(
            repository: FakeJuniorHomeRepository(map: mapOf(states)),
            clock: () => DateTime(2026, 10, 7),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final palette = tester.element(route()).palette;
      final expected = paintsColours([
        for (final b in blue) b ? palette.accent : palette.surface,
      ]);
      final bank = tester.getRect(find.byKey(JuniorMapScenery.bankKey));
      final scrollable = find.descendant(
        of: find.byType(JuniorLearningMapView),
        matching: find.byType(Scrollable),
      );

      // Scroll in steps so every stretch passes over the bank's band.
      final crossed = <int>{};
      for (var step = 0; step < 12; step++) {
        expect(routeRender(tester), expected, reason: 'step $step');
        final routeTop = tester.getRect(route()).top;
        final connectors =
            (tester.widget<CustomPaint>(route()).painter!
                    as JuniorMapPathPainter)
                .connectors;
        final scale =
            tester.getRect(route()).width / JuniorMapGeometry.mapWidth;
        for (final (i, c) in connectors.indexed) {
          final y = routeTop + c.corner.dy * scale;
          if (y > bank.bottom - 220 && y < bank.bottom) crossed.add(i);
        }
        await tester.drag(scrollable, const Offset(0, -120));
        await tester.pumpAndSettle();
      }
      // The band was really crossed — blue stretches (1, 4) and white ones
      // (3, 5) alike; stretch 0 starts above it and only scrolls away.
      expect(crossed, containsAll(<int>{1, 3, 4, 5}));
    });
  });
}
