import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_screen.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_strings.dart';
import 'package:aia_mobile/features/contracts/presentation/widgets/contract_page_parts.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_learning_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_contract_repository.dart';

/// The shared E-Contract header's back button stays reachable at every
/// width and text size (Issue #318). Before the fix the centred title lay
/// over the button and took its taps: part of the circle at 320 wide and
/// 1.5×, all of it at 2.0× on both widths.
///
/// The app's own fonts are loaded: under the test font the title is far
/// wider than it really is, which would hide the real behaviour.
void main() {
  setUpAll(loadAppFonts);

  /// A miss is a failure here, not a warning — the point of these tests.
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  const widths = [320.0, 393.0];
  const scales = [1.0, 1.3, 1.5, 2.0];

  /// [ContractHeader] on a route pushed over a blank home, at [width] and the
  /// system text size [scale]. Returns the pop count.
  Future<List<Route<dynamic>>> pumpHeader(
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
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(
                  body: SafeArea(child: Column(children: [ContractHeader()])),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ContractHeader), findsOneWidget);
    return popped;
  }

  /// The back button's circle — the tappable ink, not its full-width row.
  Finder circle() => find.descendant(
    of: find.byType(CourseLearningBackButton),
    matching: find.byType(InkWell),
  );

  Finder title() => find.text(ContractStrings.title);

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
            final popped = await pumpHeader(tester, width: width, scale: scale);
            final target = at(tester.getRect(circle()));

            await tester.tapAt(target);
            await tester.pumpAndSettle();

            expect(popped, hasLength(1));
            expect(find.byType(ContractHeader), findsNothing);
          });
        }

        testWidgets('the title stays clear of the circle, on screen and '
            'without overflow', (tester) async {
          await pumpHeader(tester, width: width, scale: scale);

          final button = tester.getRect(circle());
          final text = tester.getRect(title());
          expect(text.overlaps(button), isFalse, reason: '$text vs $button');
          expect(text.left, greaterThanOrEqualTo(button.right));
          expect(text.right, lessThanOrEqualTo(width));
          // And the circle is hit-tested as itself where it is drawn.
          expect(
            tester
                .hitTestOnBinding(button.center)
                .path
                .any((entry) => entry.target == tester.renderObject(circle())),
            isTrue,
          );
          expect(tester.takeException(), isNull);
        });

        testWidgets('the back button is still a button to assistive tech, '
            'and the title is still read', (tester) async {
          final semantics = tester.ensureSemantics();
          await pumpHeader(tester, width: width, scale: scale);

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
          expect(find.bySemanticsLabel(ContractStrings.title), findsOneWidget);
          semantics.dispose();
        });
      });
    }
  }

  for (final width in widths) {
    testWidgets('${width.toInt()} wide, default size: the title is centred '
        'on the row and on the circle, as before', (tester) async {
      await pumpHeader(tester, width: width, scale: 1);
      final text = tester.getRect(title());
      expect(text.center.dx, moreOrLessEquals(width / 2, epsilon: 0.5));
      // One line, centred on the 40-pt circle as the exports draw it.
      expect(
        text.center.dy,
        moreOrLessEquals(tester.getRect(circle()).center.dy, epsilon: 0.5),
      );
    });
  }

  testWidgets('the contract list goes back from its header at 320 wide, '
      'text ×2', (tester) async {
    useLogicalViewport(tester, const Size(320, 700), padding: iPhonePadding);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final popped = <Route<dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        navigatorObservers: [_PopRecorder(popped)],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => ContractScreen.open(
              context,
              repository: FakeContractRepository(),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(circle());
    await tester.pumpAndSettle();

    expect(popped, hasLength(1));
    expect(find.byType(ContractScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _PopRecorder extends NavigatorObserver {
  _PopRecorder(this.popped);

  final List<Route<dynamic>> popped;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      popped.add(route);
}
