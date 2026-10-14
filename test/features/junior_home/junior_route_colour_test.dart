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
/// One rule: the path walked is the unbroken run of completed lessons from
/// the start — a stretch is blue only when both of its nodes lie in it;
/// from the first unfinished lesson (the one to continue with) on, every
/// stretch is the white way ahead, even past a lesson completed out of
/// turn; the last stretch, to the certificate, is blue only once every
/// lesson is completed. Every expectation here is read off the route's
/// actual draw calls, not the geometry helper.
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
    // (states, blue? per stretch — the last one is to the certificate)
    'completed into the lesson to continue with, then locked': (
      [done, done, current, locked, locked],
      [true, false, false, false, false],
    ),
    'nothing completed yet — the continue lesson first': (
      [current, locked, locked],
      [false, false, false],
    ),
    'lessons waiting their turn after the continue lesson': (
      [done, current, open, open, locked],
      [false, false, false, false, false],
    ),
    'alternating: completed after a gap stays on the way ahead': (
      [done, done, done, current, done, done, open, done, open, open],
      [true, true, false, false, false, false, false, false, false, false],
    ),
    'the seeded device path ·✓✓✓·✓✓·✓··': (
      [current, done, done, done, open, done, done, open, done, open, open],
      List.filled(11, false),
    ),
    'a completed lesson whose module locked again, mid-run': (
      [done, done, done, locked, current],
      [true, true, false, false, false],
    ),
    'every lesson completed — the whole route, the certificate stretch too': (
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
    const blue = [true, true, false, false, false, false, false];

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
      // The band was really crossed — a blue stretch (1) and white ones
      // (3, 5) alike; stretch 0 starts above it and only scrolls away.
      expect(crossed, containsAll(<int>{1, 3, 5}));
    });
  });
}
