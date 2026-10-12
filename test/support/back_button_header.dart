import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/shared/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screenshot.dart';

/// The checks a "back button + centred title" header — `BackTitleHeader` (Issue
/// #327) — must pass at every width and text size (Issues #318, #325): the back
/// circle goes back when tapped at its centre and both edges, the title stays
/// clear of it and on screen, nothing overflows, and both stay readable to
/// assistive tech.
///
/// Defines the tests where it is called. [screen] builds the real screen
/// that draws the header; it is pushed over a blank home so the back button
/// has somewhere to go. Call [loadAppFonts] in the caller's `setUpAll`: under
/// the test font a title is far wider than it really is.
void backButtonHeaderChecks({
  required String title,
  required Widget Function() screen,
  List<double> widths = const [320, 393],
  List<double> scales = const [1.0, 1.5, 2.0, 2.5, 3.0],
}) {
  /// A miss is a failure here, not a warning — the point of these tests.
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  Future<List<Route<dynamic>>> pump(
    WidgetTester tester, {
    required double width,
    required double scale,
  }) async {
    useLogicalViewport(tester, Size(width, 700), padding: iPhonePadding);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final popped = <Route<dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        navigatorObservers: [_PopRecorder(popped)],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => screen())),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return popped;
  }

  /// The back button's circle — the tappable ink, not its full-width row.
  Finder circle() => find.descendant(
    of: find.byType(AppBackButton),
    matching: find.byType(InkWell),
  );

  for (final width in widths) {
    for (final scale in scales) {
      group('${width.toInt()} wide, text ×$scale', () {
        for (final (point, at) in <(String, Offset Function(Rect))>[
          ('centre', (r) => r.center),
          ('left edge', (r) => Offset(r.left + 3, r.center.dy)),
          ('right edge', (r) => Offset(r.right - 3, r.center.dy)),
        ]) {
          testWidgets('a tap on the circle\'s $point goes back', (
            tester,
          ) async {
            final popped = await pump(tester, width: width, scale: scale);

            await tester.tapAt(at(tester.getRect(circle())));
            await tester.pumpAndSettle();

            expect(popped, hasLength(1));
            expect(find.text('open'), findsOneWidget);
          });
        }

        testWidgets('the title stays clear of the circle, on screen and '
            'without overflow', (tester) async {
          await pump(tester, width: width, scale: scale);

          final button = tester.getRect(circle());
          final text = tester.getRect(find.text(title));
          expect(text.overlaps(button), isFalse, reason: '$text vs $button');
          expect(text.left, greaterThanOrEqualTo(button.right));
          expect(text.right, lessThanOrEqualTo(width));
          expect(
            tester
                .hitTestOnBinding(button.center)
                .path
                .any((entry) => entry.target == tester.renderObject(circle())),
            isTrue,
            reason: 'the circle is hit-tested as itself',
          );
          expect(tester.takeException(), isNull);
        });

        testWidgets('the back button is still a button to assistive tech, '
            'and the title is still read', (tester) async {
          final semantics = tester.ensureSemantics();
          await pump(tester, width: width, scale: scale);

          expect(
            tester.getSemantics(
              find.bySemanticsLabel(CourseLearningStrings.back),
            ),
            isSemantics(
              label: CourseLearningStrings.back,
              isButton: true,
              hasTapAction: true,
            ),
          );
          expect(find.bySemanticsLabel(title), findsOneWidget);
          semantics.dispose();
        });
      });
    }
  }

  for (final width in widths) {
    testWidgets('${width.toInt()} wide, default size: the title is centred '
        'on the row and on the circle, as before', (tester) async {
      await pump(tester, width: width, scale: 1);
      final text = tester.getRect(find.text(title));
      expect(text.center.dx, moreOrLessEquals(width / 2, epsilon: 0.5));
      expect(
        text.center.dy,
        moreOrLessEquals(tester.getRect(circle()).center.dy, epsilon: 0.5),
      );
    });
  }
}

class _PopRecorder extends NavigatorObserver {
  _PopRecorder(this.popped);

  final List<Route<dynamic>> popped;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      popped.add(route);
}
