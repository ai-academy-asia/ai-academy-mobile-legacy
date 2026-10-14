import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_palette.dart';
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
/// background theme and its cloud bank — and the path on a small phone
/// with large text.
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
    // (state, check-in, sprite, face, edge) — every node one exported
    // glyph, never the book icon (Issue #410).
    final looks =
        <
          (
            JuniorNodeState,
            bool,
            String?,
            Color Function(AppPalette),
            Color Function(AppPalette),
          )
        >[
          (
            JuniorNodeState.completed,
            false,
            'node_check',
            (p) => p.juniorCard,
            (p) => p.accent,
          ),
          (
            JuniorNodeState.current,
            false,
            // The continue lesson: Figma's QR mark in the grey outline — no
            // tick, as a tick always means completed (Issue #412).
            'node_current',
            (p) => p.surface,
            (p) => p.outline,
          ),
          (
            JuniorNodeState.locked,
            false,
            'node_lock',
            (p) => p.juniorMutedFill,
            (p) => p.outline,
          ),
          (
            JuniorNodeState.current,
            true,
            'node_current',
            (p) => p.surface,
            (p) => p.accent,
          ),
        ];
    for (final (state, checkIn, name, face, edge) in looks) {
      testWidgets('${state.name}${checkIn ? ' (live check-in)' : ''}: $name '
          'on its own face — and never the book icon', (tester) async {
        await pumpTile(
          tester,
          JuniorMapNode(id: 1, state: state),
          checkIn: checkIn,
        );
        final palette = tester.element(find.byType(JuniorMapNodeTile)).palette;

        if (name != null) expect(sprite(name), findsOneWidget);
        for (final other in ['node_check', 'node_lock', 'node_current']) {
          if (other != name) expect(sprite(other), findsNothing);
        }
        expect(
          find.descendant(
            of: find.byType(JuniorMapNodeTile),
            matching: find.byType(Icon),
          ),
          findsNothing,
        );
        final decoration =
            tester
                    .widget<Container>(
                      find.descendant(
                        of: find.byType(JuniorMapNodeTile),
                        matching: find.byType(Container),
                      ),
                    )
                    .decoration!
                as BoxDecoration;
        expect(decoration.color, face(palette));
        expect((decoration.border! as Border).top.color, edge(palette));
        expect(
          tester.getSize(find.byType(JuniorMapNodeTile)),
          const Size.square(JuniorMapGeometry.nodeSize),
        );
      });
    }

    testWidgets('open (its class date has come, not yet its turn): it '
        'cannot be opened, so it wears the grey padlock — read as "not yet '
        'available", unlike a locked lesson', (tester) async {
      await pumpTile(
        tester,
        const JuniorMapNode(id: 1, state: JuniorNodeState.open),
      );
      final palette = tester.element(find.byType(JuniorMapNodeTile)).palette;

      expect(sprite('node_lock'), findsOneWidget);
      for (final name in ['node_check', 'node_current']) {
        expect(sprite(name), findsNothing);
      }
      expect(
        find.descendant(
          of: find.byType(JuniorMapNodeTile),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
      final decoration =
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byType(JuniorMapNodeTile),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      expect(decoration.color, palette.juniorMutedFill);
      expect((decoration.border! as Border).top.color, palette.outline);
      expect(
        find.bySemanticsLabel('Lesson 1, not yet available'),
        findsOneWidget,
      );
    });

    testWidgets('completed and available are told apart by the face: pale '
        'blue done, white in the accent available', (tester) async {
      await pumpTile(
        tester,
        const JuniorMapNode(id: 1, state: JuniorNodeState.completed),
      );
      final done = tester.widget<Container>(
        find.descendant(
          of: find.byType(JuniorMapNodeTile),
          matching: find.byType(Container),
        ),
      );
      await pumpTile(tester, lesson);
      final available = tester.widget<Container>(
        find.descendant(
          of: find.byType(JuniorMapNodeTile),
          matching: find.byType(Container),
        ),
      );
      expect(
        (done.decoration! as BoxDecoration).color,
        isNot((available.decoration! as BoxDecoration).color),
      );
    });

    testWidgets('the whole path draws no book icon', (tester) async {
      useLogicalViewport(tester, const Size(393, 2400));
      useReducedMotion(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: JuniorLearningMapView(
              map: sampleJuniorLearningMap(),
              now: DateTime(2026, 10, 7),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(AppIcons.bookOpenText), findsNothing);
      // The two completed lessons; the continue lesson carries no tick.
      expect(sprite('node_check'), findsNWidgets(2));
      expect(sprite('node_lock'), findsNWidgets(9));
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

  group('the cloud bank — background, not content', () {
    final bank = find.descendant(
      of: find.byKey(JuniorMapScenery.bankKey),
      matching: find.byType(SvgPicture),
    );
    final certificate = find.byType(JuniorCertificateCard);
    Finder scrollable() => find.descendant(
      of: find.byType(JuniorLearningMapView),
      matching: find.byType(Scrollable),
    );

    Future<void> pumpHome(
      WidgetTester tester, {
      Size size = const Size(393, 852),
      bool reducedMotion = true,
    }) async {
      useLogicalViewport(tester, size, padding: iPhonePadding);
      if (reducedMotion) useReducedMotion(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: JuniorHomeScreen(
            repository: FakeJuniorHomeRepository(),
            clock: () => DateTime(2026, 10, 7),
          ),
        ),
      );
      if (reducedMotion) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
      }
    }

    List<Rect> bankRects(WidgetTester tester) => [
      for (var i = 0; i < bank.evaluate().length; i++)
        tester.getRect(bank.at(i)),
    ];

    testWidgets('lives in the scenery\'s bank layer, not in the scrolling '
        'content', (tester) async {
      await pumpHome(tester);

      expect(bank, findsNWidgets(JuniorMapTheme.junior.bankClouds.length));
      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byKey(JuniorMapScenery.bankKey),
        ),
        findsNothing,
      );
      // Painted before the content: depth-first order is paint order.
      final order = [
        for (final e in tester.allElements)
          if (e.widget.key == JuniorMapScenery.bankKey)
            'bank'
          else if (e.widget is SingleChildScrollView)
            'content',
      ];
      expect(order, ['bank', 'content']);
    });

    testWidgets('scrolling the path and the certificate never drags it: the '
        'card moves, the bank stays', (tester) async {
      await pumpHome(tester);
      final before = bankRects(tester);
      final card = tester.getRect(certificate);

      await tester.drag(scrollable(), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.getRect(certificate).top, lessThan(card.top - 500));
      expect(bankRects(tester), before);

      await tester.drag(scrollable(), const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(bankRects(tester), before);
    });

    for (final size in const [Size(320, 568), Size(393, 852), Size(430, 932)]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}: on the '
          'background\'s bottom edge, scaled with the width — and at the end '
          'of the path the card stands in front of it', (tester) async {
        await pumpHome(tester, size: size);
        final view = tester.getRect(find.byType(JuniorLearningMapView));
        final scale = view.width / JuniorMapGeometry.mapWidth;

        final rects = bankRects(tester);
        final clouds = JuniorMapTheme.junior.bankClouds;
        for (var i = 0; i < clouds.length; i++) {
          final r = clouds[i].rect;
          expect(
            rects[i],
            rectMoreOrLessEquals(
              Rect.fromLTWH(
                view.left + r.left * scale,
                view.bottom + r.top * scale,
                r.width * scale,
                r.height * scale,
              ),
              epsilon: 0.01,
            ),
          );
        }

        await tester.drag(scrollable(), const Offset(0, -10000));
        await tester.pumpAndSettle();
        final card = tester.getRect(certificate);
        expect(
          view.bottom - card.bottom,
          moreOrLessEquals(
            JuniorMapGeometry.certificateBottomMargin * scale,
            epsilon: 0.5,
          ),
        );
        // The bank rises behind the card's lower part and either side.
        final top = rects.map((r) => r.top).reduce((a, b) => a < b ? a : b);
        expect(top, greaterThan(card.top));
        expect(top, lessThan(card.bottom));
        expect(rects.any((r) => r.left < card.left), isTrue);
        expect(rects.any((r) => r.right > card.right), isTrue);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('takes no taps and says nothing', (tester) async {
      await pumpHome(tester);

      for (var i = 0; i < bank.evaluate().length; i++) {
        final cloud = tester.renderObject(bank.at(i));
        final rect = tester.getRect(bank.at(i));
        final point = Offset(
          rect.center.dx.clamp(1, 392).toDouble(),
          (rect.top + 20).clamp(0, 760).toDouble(),
        );
        final path = tester.hitTestOnBinding(point).path;
        expect(path.any((entry) => entry.target == cloud), isFalse);
      }
      expect(
        find.ancestor(of: bank.first, matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );
    });

    testWidgets('reduced motion: drawn, still, and no ticker', (tester) async {
      await pumpHome(tester);

      expect(bank, findsNWidgets(6));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('in motion: the small clouds travel, the bank never moves', (
      tester,
    ) async {
      await pumpHome(tester, reducedMotion: false);
      final before = bankRects(tester);

      await tester.pump(const Duration(seconds: 20));

      expect(bankRects(tester), before);
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('the background theme', () {
    test('every program draws the Junior sky today', () {
      for (final track in [null, 'junior', 'adult', 'anything']) {
        expect(JuniorMapTheme.forTrack(track), same(JuniorMapTheme.junior));
      }
    });

    testWidgets('another theme brings its own sky and bank without moving '
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
          bankClouds: const [JuniorBankCloud(Rect.fromLTWH(0, -100, 100, 50))],
        ),
      );

      expect(other, junior);
      // Its one bank cloud in place of Junior's six. (With reduced
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
                bankClouds: const [],
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
