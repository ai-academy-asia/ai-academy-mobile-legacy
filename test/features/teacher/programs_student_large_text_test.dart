import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:aia_mobile/core/theme/app_dimens.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_submission.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_gradebook_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_gradebook_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/gradebook_widgets.dart';
import 'package:aia_mobile/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'teacher_gradebook_screen_test.dart' show classRepository;

/// The Programs student screen at larger system text sizes (Issue #552).
/// The two stat titles were one line with an ellipsis, and the score's range
/// error one line too, so both were cut short — the Mongolian titles even at
/// the default size on a 320pt phone. Both now wrap; where they fit, they
/// are drawn as before. The screen runs in both languages since L18/L19
/// (Issue #551) gave it English.
void main() {
  setUpAll(loadAppFonts);
  final locale = AppLocaleController.instance;
  tearDown(() => locale.setPreference(LocalePreference.mongolian));

  const widths = [320.0, 375.0, 393.0];
  const scales = [1.0, 1.5, 2.0, 3.0];

  /// [value] is drawn whole wherever it shows: no ellipsis, its full height,
  /// inside [width].
  void expectWhole(WidgetTester tester, String value, double width) {
    final label = find.text(value);
    expect(label, findsOneWidget, reason: value);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: label, matching: find.byType(RichText)).first,
    );
    expect(paragraph.didExceedMaxLines, isFalse, reason: value);
    expect(
      paragraph.size.height,
      greaterThanOrEqualTo(
        paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
      ),
      reason: value,
    );
    final rect = tester.getRect(label);
    expect(rect.left, greaterThanOrEqualTo(0), reason: value);
    expect(rect.right, lessThanOrEqualTo(width), reason: value);
  }

  /// [value]'s line count as drawn.
  int lines(WidgetTester tester, String value) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find
          .descendant(of: find.text(value), matching: find.byType(RichText))
          .first,
    );
    return {
      for (final box in paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: value.length),
      ))
        box.top.round(),
    }.length;
  }

  group('the student screen', () {
    /// Student A, whose assignment has a 100-point maximum, with "150"
    /// entered: the stat cards and the range error on screen.
    Future<List<String>> pumpStudent(
      WidgetTester tester, {
      required double width,
      required double scale,
    }) async {
      useLogicalViewport(tester, Size(width, 2400), padding: iPhonePadding);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details.toString());
      try {
        final repo = classRepository()
          ..assignments = {
            2: const [
              TeacherAssignment(
                id: 2,
                title: LocalizedText(mn: 'Даалгавар 2'),
                maxScore: 100,
              ),
              TeacherAssignment(
                id: 3,
                title: LocalizedText(en: 'Assignment 3'),
                maxScore: 100,
              ),
            ],
          };
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: TeacherGradebookScreen(
              repository: repo,
              showBottomNav: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(PillButton, TeacherGradebookStrings.details),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(TeacherGradebookStrings.studentsInfo));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Student A'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byWidgetPredicate(
            (w) =>
                w is TextField &&
                w.decoration?.labelText ==
                    TeacherGradebookStrings.scoreLabel(100),
          ),
          '150',
        );
        await tester.pump();
      } finally {
        FlutterError.onError = previous;
      }
      return errors;
    }

    for (final language in LocalePreference.values) {
      for (final width in widths) {
        for (final scale in scales) {
          testWidgets('${language.name}, ${width.toInt()} wide, text ×$scale: '
              'both stat titles and the range error whole, the cards side by '
              'side', (tester) async {
            await locale.setPreference(language);
            final errors = await pumpStudent(
              tester,
              width: width,
              scale: scale,
            );
            expect(errors, isEmpty);
            expect(tester.takeException(), isNull);

            for (final value in [
              TeacherGradebookStrings.attendance,
              TeacherGradebookStrings.examScore,
              TeacherGradebookStrings.scoreLabel(100),
              TeacherGradebookStrings.scoreInvalid(100),
            ]) {
              expectWhole(tester, value, width);
            }
            final cards = tester
                .widgetList<GradebookStatCard>(find.byType(GradebookStatCard))
                .map((card) => tester.getRect(find.byWidget(card)))
                .toList();
            expect(cards, hasLength(2));
            expect(cards[0].top, cards[1].top, reason: 'one row');
            expect(cards[0].right, lessThan(cards[1].left));
            expect(cards[1].right, lessThanOrEqualTo(width - 16));
          });
        }
      }

      testWidgets('${language.name}, at the default size on a 393pt phone: '
          'each title and the error stay on one line, as before', (
        tester,
      ) async {
        await locale.setPreference(language);
        await pumpStudent(tester, width: 393, scale: 1);
        expect(lines(tester, TeacherGradebookStrings.attendance), 1);
        expect(lines(tester, TeacherGradebookStrings.examScore), 1);
        expect(lines(tester, TeacherGradebookStrings.scoreInvalid(100)), 1);
      });
    }
  });

  group('the stat cards, any title', () {
    // The screen's row, at its widths: the 16 gutter either side, the tile
    // gap between two halves. English with L18/L19 (Issue #551).
    for (final titles in [
      ('Хичээлийн ирц', 'Шалгалтын дүн'),
      ('Class attendance', 'Exam score'),
    ]) {
      for (final width in widths) {
        for (final scale in scales) {
          testWidgets('"${titles.$1}" / "${titles.$2}", ${width.toInt()} '
              'wide, text ×$scale: both whole', (tester) async {
            useLogicalViewport(tester, Size(width, 1200));
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.light,
                home: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.screenPadding,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GradebookStatCard(
                            title: titles.$1,
                            value: '—',
                          ),
                        ),
                        const SizedBox(width: AppDimens.tileGap),
                        Expanded(
                          child: GradebookStatCard(
                            title: titles.$2,
                            value: '—',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            expect(tester.takeException(), isNull);
            expectWhole(tester, titles.$1, width);
            expectWhole(tester, titles.$2, width);
          });
        }
      }
    }
  });
}
