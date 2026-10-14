import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_learning_map.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_certificate_card.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_course_progress_card.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_learning_map_view.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_geometry.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_node.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_path_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_junior_home_repository.dart';

/// Junior Home's certificate card at larger system text sizes (Issue #345).
/// The card used to be pinned at the frame's height, so from 1.1× its last
/// line spilled out of it onto the scenery, and past the map's foot at
/// larger sizes. It now grows downward and the map with it; nothing else on
/// the map moves, and at the default size nothing changes at all.
void main() {
  setUpAll(loadAppFonts);

  Future<void> pumpHome(
    WidgetTester tester, {
    required Size size,
    required double scale,
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    useReducedMotion(tester);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: JuniorHomeScreen(
          repository: FakeJuniorHomeRepository(),
          clock: () => DateTime(2026, 10, 6, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The map's own box — the [Stack] every map element is placed in, the
  /// scrolling content over the scenery.
  Finder mapStack() => find
      .descendant(
        of: find.descendant(
          of: find.byType(JuniorLearningMapView),
          matching: find.byType(SingleChildScrollView),
        ),
        matching: find.byType(Stack),
      )
      .first;

  Finder card() => find.byType(JuniorCertificateCard);

  ScrollableState mapScroll(WidgetTester tester) =>
      tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(JuniorLearningMapView),
              matching: find.byType(Scrollable),
            )
            .first,
      );

  /// The screen's map and the factor it is drawn at.
  (JuniorLearningMap, double) mapAndScale(WidgetTester tester) {
    final view = tester.widget<JuniorLearningMapView>(
      find.byType(JuniorLearningMapView),
    );
    final width = tester.getSize(mapStack()).width;
    return (view.map, width / JuniorMapGeometry.mapWidth);
  }

  /// [rect] from design space onto the screen, against the map's origin.
  Rect onScreen(WidgetTester tester, Rect rect, double scale) {
    final origin = tester.getTopLeft(mapStack());
    return Rect.fromLTWH(
      origin.dx + rect.left * scale,
      origin.dy + rect.top * scale,
      rect.width * scale,
      rect.height * scale,
    );
  }

  void expectRect(Rect actual, Rect expected, {String? reason}) {
    for (final (a, e) in [
      (actual.left, expected.left),
      (actual.top, expected.top),
      (actual.width, expected.width),
      (actual.height, expected.height),
    ]) {
      expect(a, moreOrLessEquals(e, epsilon: 0.01), reason: reason);
    }
  }

  const phones = [Size(320, 568), Size(393, 852), Size(430, 932)];
  const scales = [1.0, 1.1, 1.3, 1.5, 2.0, 3.0];

  for (final size in phones) {
    for (final scale in scales) {
      final name = '${size.width.toInt()}×${size.height.toInt()}, text ×$scale';

      testWidgets('$name: the card holds all its text, its foot can be '
          'scrolled to, and nothing else on the map moves', (tester) async {
        await pumpHome(tester, size: size, scale: scale);
        expect(tester.takeException(), isNull);

        final (map, mapScale) = mapAndScale(tester);
        final frame = JuniorMapGeometry.certificateFor(map.nodes.length);

        // At the frame's place and width, at least its height.
        final cardRect = tester.getRect(card());
        final framed = onScreen(tester, frame, mapScale);
        expect(cardRect.left, moreOrLessEquals(framed.left, epsilon: 0.01));
        expect(cardRect.top, moreOrLessEquals(framed.top, epsilon: 0.01));
        expect(cardRect.width, moreOrLessEquals(framed.width, epsilon: 0.01));
        expect(cardRect.height, greaterThanOrEqualTo(framed.height - 0.01));

        // Every line inside the card, none of it cut short.
        for (final element
            in find
                .descendant(of: card(), matching: find.byType(RichText))
                .evaluate()) {
          final paragraph = element.renderObject! as RenderParagraph;
          final text = paragraph.text.toPlainText();
          final rect = tester.getRect(
            find.byElementPredicate((e) => e == element),
          );
          expect(rect.top, greaterThanOrEqualTo(cardRect.top), reason: text);
          expect(rect.bottom, lessThanOrEqualTo(cardRect.bottom), reason: text);
          expect(
            paragraph.size.height,
            greaterThanOrEqualTo(
              paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
            ),
            reason: '"$text" is drawn at its full height',
          );
        }

        // The rest of the map stays where the frame puts it.
        for (final (i, _) in map.nodes.indexed) {
          expectRect(
            tester.getRect(find.byType(JuniorMapNodeTile).at(i)),
            onScreen(
              tester,
              JuniorMapGeometry.nodeAt(i) &
                  const Size(
                    JuniorMapGeometry.nodeSize,
                    JuniorMapGeometry.nodeSize,
                  ),
              mapScale,
            ),
            reason: 'node $i',
          );
        }
        expectRect(
          tester.getRect(find.byType(JuniorCourseProgressCard)),
          onScreen(tester, JuniorMapGeometry.courseCard, mapScale),
          reason: 'course card',
        );

        // The route still ends 3.7 above the card's top.
        final painter = tester
            .widgetList<CustomPaint>(
              find.descendant(
                of: mapStack(),
                matching: find.byType(CustomPaint),
              ),
            )
            .map((paint) => paint.painter)
            .whereType<JuniorMapPathPainter>()
            .single;
        final routeEnd =
            tester.getTopLeft(mapStack()).dy +
            painter.connectors.last.to.dy * mapScale;
        expect(
          cardRect.top - routeEnd,
          moreOrLessEquals(3.7 * mapScale, epsilon: 0.01),
        );

        // Scrolled to the end: the card's foot, and the frame's margin
        // under it, are on screen. (On a 320×568 phone the map's window is
        // shorter than the card and its margin, so its top has scrolled
        // past by then — as at the default size.)
        final position = mapScroll(tester).position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        final viewport = tester.getRect(
          find
              .descendant(
                of: find.byType(JuniorLearningMapView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        final scrolledCard = tester.getRect(card());
        expect(scrolledCard.bottom, greaterThan(viewport.top));
        expect(
          viewport.bottom - scrolledCard.bottom,
          moreOrLessEquals(
            JuniorMapGeometry.certificateBottomMargin * mapScale,
            epsilon: 0.01,
          ),
          reason: 'the reference\'s margin under the card',
        );
      });
    }
  }

  for (final size in phones) {
    testWidgets('${size.width.toInt()}×${size.height.toInt()}, default size: '
        'the card and the map are exactly the frame\'s', (tester) async {
      await pumpHome(tester, size: size, scale: 1);

      final (map, mapScale) = mapAndScale(tester);
      expectRect(
        tester.getRect(card()),
        onScreen(
          tester,
          JuniorMapGeometry.certificateFor(map.nodes.length),
          mapScale,
        ),
      );
      expect(
        tester.getSize(mapStack()).height,
        moreOrLessEquals(
          JuniorMapGeometry.mapHeightFor(map.nodes.length) * mapScale,
          epsilon: 0.01,
        ),
      );
    });
  }

  testWidgets('393×852, text ×1.1 — where it first broke: no overflow, and '
      'the card grows to hold its last line', (tester) async {
    await pumpHome(tester, size: const Size(393, 852), scale: 1.1);

    expect(tester.takeException(), isNull);
    final (map, mapScale) = mapAndScale(tester);
    final frame = JuniorMapGeometry.certificateFor(map.nodes.length);
    expect(tester.getSize(card()).height, greaterThan(frame.height * mapScale));
    expect(
      tester.getSize(mapStack()).height,
      greaterThan(JuniorMapGeometry.mapHeightFor(map.nodes.length) * mapScale),
    );
  });
}
