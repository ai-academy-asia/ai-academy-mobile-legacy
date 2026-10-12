import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/certificates/domain/certificate_entry.dart';
import 'package:aia_mobile/features/certificates/domain/certificate_list_repository.dart';
import 'package:aia_mobile/features/certificates/presentation/certificate_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_module_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_progress_cta_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../certificates/certificate_screen_test.dart'
    show issuedEntry, pendingEntry;
import 'fake_course_learning_repository.dart';

/// The progress row and its "Continue learning" button (Issue #347) — the
/// Course Module List hero and certification panel and the Certificate
/// screen — at narrow widths and larger text sizes.
///
/// On a 320-wide phone the row used to squeeze its bar to nothing and run
/// the button off the screen even at the default size, and from 1.3× the
/// button's fixed 40 cut its wrapped label. Now the button moves to its own
/// line when the row does not fit, and grows with its label.
void main() {
  setUpAll(loadAppFonts);

  const widths = [320.0, 375.0, 393.0];
  const scales = [1.0, 1.1, 1.3, 1.5, 2.0, 3.0];

  /// The screens that draw the row, each tall enough to lay out whole.
  final screens = <String, Widget Function()>{
    'Course Module List': () => CourseModuleListScreen(
      courseSlug: 'how-ai-works',
      repository: FakeCourseLearningRepository(),
    ),
    'Certificate': () => CertificateScreen(
      repository: _Entries(),
      courseLearning: FakeCourseLearningRepository(),
    ),
  };

  /// Pumps [screen] and returns every error it raised — all of them, so a
  /// test can show what went wrong rather than only the first. Every caller
  /// expects none: the module cards' clipped date line, once let through
  /// here, is fixed (Issue #349).
  Future<List<String>> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    required double width,
    required double scale,
  }) async {
    useLogicalViewport(tester, Size(width, 4000), padding: iPhonePadding);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.toString());
    try {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: screen));
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = previous;
    }
    return errors;
  }

  Finder within(Element row, Finder matching) => find.descendant(
    of: find.byElementPredicate((e) => e == row),
    matching: matching,
  );

  /// The progress label's natural one-line width, as drawn.
  double labelWidth(WidgetTester tester, Element row) {
    final paragraph = tester.renderObject<RenderParagraph>(
      within(row, find.textContaining('%')),
    );
    return paragraph.getMaxIntrinsicWidth(double.infinity);
  }

  for (final MapEntry(key: name, value: screen) in screens.entries) {
    for (final width in widths) {
      for (final scale in scales) {
        testWidgets('$name, ${width.toInt()} wide, text ×$scale: no '
            'overflow, a visible bar, and the whole button on screen', (
          tester,
        ) async {
          final errors = await pumpScreen(
            tester,
            screen(),
            width: width,
            scale: scale,
          );
          expect(errors, isEmpty);

          final rows = find.byType(CourseProgressCtaRow).evaluate().toList();
          expect(rows, isNotEmpty);
          for (final row in rows) {
            final widget = row.widget as CourseProgressCtaRow;
            final rowRect = tester.getRect(
              find.byElementPredicate((e) => e == row),
            );
            final bar = tester.getRect(
              within(row, find.byType(LinearProgressIndicator)),
            );
            final button = tester.getRect(
              within(row, find.byType(ContinueLearningButton)),
            );

            expect(bar.width, greaterThan(0), reason: 'the bar is visible');
            expect(button.left, greaterThanOrEqualTo(rowRect.left - 0.01));
            expect(button.right, lessThanOrEqualTo(rowRect.right + 0.01));
            expect(button.right, lessThanOrEqualTo(width));
            expect(button.top, greaterThanOrEqualTo(rowRect.top - 0.01));
            expect(button.bottom, lessThanOrEqualTo(rowRect.bottom + 0.01));
            expect(button.width, widget.buttonWidth);
            expect(button.height, greaterThanOrEqualTo(40));

            // Every line drawn whole: the label and the percentage.
            for (final element in within(
              row,
              find.byType(RichText),
            ).evaluate()) {
              final paragraph = element.renderObject! as RenderParagraph;
              expect(
                paragraph.size.height,
                greaterThanOrEqualTo(
                  paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
                ),
                reason: paragraph.text.toPlainText(),
              );
            }

            // One row exactly when bar, label, gaps and button fit with the
            // bar keeping at least 16; otherwise the button sits beneath,
            // at the row's end.
            final fits =
                16 + 13 + labelWidth(tester, row) + 31 + widget.buttonWidth <=
                rowRect.width + 0.01;
            if (fits) {
              expect(button.top, lessThan(bar.bottom), reason: 'one row');
              expect(bar.width, greaterThanOrEqualTo(16 - 0.01));
            } else {
              expect(button.top, greaterThan(bar.bottom), reason: 'wrapped');
              expect(button.right, moreOrLessEquals(rowRect.right));
            }
          }
        });
      }
    }
  }

  testWidgets('320 wide, default size — where it first broke: the bar was '
      '0 wide and the buttons ran off the screen; now the buttons wrap '
      'beneath it', (tester) async {
    final errors = await pumpScreen(
      tester,
      screens['Course Module List']!(),
      width: 320,
      scale: 1,
    );
    expect(errors, isEmpty);

    final rows = find.byType(CourseProgressCtaRow).evaluate().toList();
    expect(rows, hasLength(2));
    for (final row in rows) {
      final bar = tester.getRect(
        within(row, find.byType(LinearProgressIndicator)),
      );
      final button = tester.getRect(
        within(row, find.byType(ContinueLearningButton)),
      );
      expect(bar.width, greaterThan(16));
      expect(button.top, greaterThan(bar.bottom));
      expect(button.right, lessThanOrEqualTo(320 - 16));
    }
  });

  testWidgets('393 wide, default size: both rows on the reference phone '
      'keep the one-row layout, the bars as wide as before', (tester) async {
    final errors = await pumpScreen(
      tester,
      screens['Course Module List']!(),
      width: 393,
      scale: 1,
    );
    expect(errors, isEmpty);

    final bars = [
      for (final row in find.byType(CourseProgressCtaRow).evaluate())
        tester.getRect(within(row, find.byType(LinearProgressIndicator))),
    ];
    final buttons = [
      for (final row in find.byType(CourseProgressCtaRow).evaluate())
        tester.getRect(within(row, find.byType(ContinueLearningButton))),
    ];
    // The hero's bar, then the certification panel's.
    expect(bars[0].width, moreOrLessEquals(54.5, epsilon: 0.5));
    expect(bars[1].width, moreOrLessEquals(36.5, epsilon: 0.5));
    for (var i = 0; i < 2; i++) {
      expect(buttons[i].height, 40);
      expect(buttons[i].top, lessThan(bars[i].bottom));
    }
  });

  testWidgets('pumpScreen keeps every layout error — it does not swallow '
      'one — so the grid above fails on any', (tester) async {
    final errors = await pumpScreen(
      tester,
      const Center(
        child: SizedBox(
          width: 10,
          height: 10,
          // A real area: Flutter reports no overflow of a 0-tall row.
          child: Row(children: [SizedBox(width: 50, height: 10)]),
        ),
      ),
      width: 393,
      scale: 1,
    );
    expect(errors, hasLength(1));
    expect(errors.single, contains('A RenderFlex overflowed'));
  });

  group('the button itself', () {
    /// One row on its own, [width] wide.
    Future<List<int>> pumpRow(
      WidgetTester tester, {
      required double width,
      required double scale,
      bool active = true,
    }) async {
      useLogicalViewport(tester, const Size(400, 800));
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final taps = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: CourseProgressCtaRow(
                  percent: 30,
                  buttonWidth: 148,
                  onContinue: active ? () => taps.add(1) : null,
                ),
              ),
            ),
          ),
        ),
      );
      return taps;
    }

    // One row (361 at 1.0), and wrapped (254, as the panel at 320; and
    // 361 at 3.0).
    for (final (width, scale) in const [
      (361.0, 1.0),
      (254.0, 1.0),
      (361.0, 3.0),
    ]) {
      final name = '${width.toInt()} wide, text ×$scale';

      testWidgets('$name: a tap calls onContinue, and it is one button '
          'read as "Continue learning"', (tester) async {
        WidgetController.hitTestWarningShouldBeFatal = true;
        addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
        final semantics = tester.ensureSemantics();
        final taps = await pumpRow(tester, width: width, scale: scale);

        final nodes = find.semantics
            .byPredicate((node) => node.label.contains('Continue'))
            .evaluate()
            .toList();
        expect(nodes, hasLength(1));
        expect(
          tester.getSemantics(find.byType(ContinueLearningButton)),
          isSemantics(
            label: CourseLearningStrings.continueLearning,
            isButton: true,
            hasTapAction: true,
          ),
        );

        await tester.tap(find.byType(ContinueLearningButton));
        expect(taps, [1]);
        semantics.dispose();
      });

      testWidgets('$name: with no destination it stays inert', (tester) async {
        final semantics = tester.ensureSemantics();
        final taps = await pumpRow(
          tester,
          width: width,
          scale: scale,
          active: false,
        );

        expect(
          tester.getSemantics(find.byType(ContinueLearningButton)),
          isSemantics(
            label: CourseLearningStrings.continueLearning,
            isButton: true,
            hasTapAction: false,
          ),
        );
        await tester.tap(find.byType(ContinueLearningButton));
        await tester.pump();
        expect(taps, isEmpty);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  });
}

class _Entries implements CertificateListRepository {
  @override
  Future<List<CertificateEntry>> getCertificates() async => [
    issuedEntry,
    pendingEntry,
  ];
}
