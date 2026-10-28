import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_request_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_pill_button.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_request_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'teacher_home_screen_test.dart' show sampleClass;

/// The "Багш нар" rows at larger system text sizes (Issue #548). The request
/// pill beside the name is capped at 180 wide and one line, so from 1.5× a
/// label was cut short. Now, where any of the three labels would not fit
/// the cap, every row stacks — the identity, then the pill at the row's full
/// width, its label wrapping. At the default size the rows are as before.
/// In both languages since L17 (Issue #547) gave the labels English. The
/// rows also stack where a name or "Teacher" would not fit beside the pill,
/// so neither is cut nor broken mid-word (Issue #557).
void main() {
  setUpAll(loadAppFonts);
  final locale = AppLocaleController.instance;
  tearDown(() => locale.setPreference(LocalePreference.mongolian));

  const widths = [320.0, 375.0, 393.0];
  const scales = [1.0, 1.5, 2.0, 3.0];

  /// One row in each state, as the screen lists them, with its label in
  /// the selected language.
  final rows = [
    (
      name: 'Болд Бат',
      status: TeacherRequestStatus.notSent,
      label: () => TeacherScheduleStrings.requestSend,
    ),
    (
      name: 'Сараа Ганбат',
      status: TeacherRequestStatus.pending,
      label: () => TeacherScheduleStrings.requestPending,
    ),
    (
      name: 'Анар Бат',
      status: TeacherRequestStatus.rejected,
      label: () => TeacherScheduleStrings.requestRejected,
    ),
  ];

  /// Each language's three labels, as the rows must show them.
  const labels = {
    LocalePreference.mongolian: [
      'Хүсэлт илгээх',
      'Хүлээгдэж байна',
      'Татгалзсан',
    ],
    LocalePreference.english: ['Send request', 'Pending', 'Declined'],
  };

  /// "Багш нар" with [rows] at [width] and [scale], and every error raised.
  Future<List<String>> pump(
    WidgetTester tester, {
    required double width,
    required double scale,
    ValueChanged<TeacherRequestCandidate>? onSend,
  }) async {
    useLogicalViewport(tester, Size(width, 2400), padding: iPhonePadding);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.toString());
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: TeacherRequestScreen(
            candidates: [
              for (final (index, row) in rows.indexed)
                TeacherRequestCandidate(
                  id: index + 1,
                  name: row.name,
                  status: row.status,
                ),
            ],
            onSend: onSend,
          ),
        ),
      );
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = previous;
    }
    return errors;
  }

  /// [finder]'s text is drawn whole: no ellipsis, its full height.
  void expectWhole(WidgetTester tester, Finder finder, String reason) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: finder, matching: find.byType(RichText)).first,
    );
    expect(paragraph.didExceedMaxLines, isFalse, reason: reason);
    expect(
      paragraph.size.height,
      greaterThanOrEqualTo(
        paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
      ),
      reason: reason,
    );
  }

  /// The lines [text] takes as drawn under [finder].
  int lineCount(WidgetTester tester, Finder finder, String text) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: finder, matching: find.byType(RichText)).first,
    );
    return {
      for (final box in paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: text.length),
      ))
        box.top.round(),
    }.length;
  }

  Finder pillOf(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byType(TeacherPillButton),
  );

  for (final language in LocalePreference.values) {
    for (final width in widths) {
      for (final scale in scales) {
        testWidgets('${language.name}, ${width.toInt()} wide, text ×$scale: '
            'every label whole and inside its pill, the pill inside the '
            'screen and clear of the name, and every row laid out alike', (
          tester,
        ) async {
          await locale.setPreference(language);
          final errors = await pump(tester, width: width, scale: scale);
          expect(errors, isEmpty);
          expect([for (final row in rows) row.label()], labels[language]);

          final stacked = <bool>{};
          for (final row in rows) {
            final value = row.label();
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

            final text = tester.getRect(label);
            final pill = tester.getRect(pillOf(value));
            expect(text.left, greaterThanOrEqualTo(pill.left), reason: value);
            expect(text.right, lessThanOrEqualTo(pill.right), reason: value);
            expect(text.top, greaterThanOrEqualTo(pill.top), reason: value);
            expect(text.bottom, lessThanOrEqualTo(pill.bottom), reason: value);
            // On the 16 gutter either side.
            expect(pill.left, greaterThanOrEqualTo(16), reason: value);
            expect(pill.right, lessThanOrEqualTo(width - 16), reason: value);

            final name = tester.getRect(find.text(row.name));
            expect(name.overlaps(pill), isFalse, reason: row.name);
            expect(name.right, lessThanOrEqualTo(width - 16), reason: row.name);
            // The name whole, and "Teacher" on one line (Issue #557).
            expectWhole(tester, find.text(row.name), row.name);
            final identityFinder = find.ancestor(
              of: find.text(row.name),
              matching: find.byType(TeacherIdentity),
            );
            expect(
              lineCount(
                tester,
                find.descendant(
                  of: identityFinder,
                  matching: find.text('Teacher'),
                ),
                'Teacher',
              ),
              1,
              reason: '"Teacher" beside ${row.name}',
            );

            // Stacked: the pill below the whole identity (avatar, name and
            // "Teacher"); beside it, the pill starts above the identity's foot.
            final identity = tester.getRect(identityFinder);

            final isStacked = pill.top >= identity.bottom;
            stacked.add(isStacked);
            if (isStacked) {
              // The row's full width, below the identity.
              expect(pill.left, 16, reason: value);
              expect(pill.right, width - 16, reason: value);
            } else {
              // Beside the name, at its cap and height, on the trailing edge.
              expect(pill.width, lessThanOrEqualTo(180), reason: value);
              expect(pill.height, 40, reason: value);
              expect(pill.right, width - 16, reason: value);
            }
          }
          expect(stacked, hasLength(1), reason: 'one layout for every row');
          // The reference's width at the default size: side by side, as the
          // frame draws it. Narrower phones stack where a name would not
          // fit beside the pill (Issue #557).
          if (scale == 1.0 && width == 393) {
            expect(stacked.single, isFalse, reason: 'beside the name at 1.0×');
          }
        });
      }
    }
  }

  testWidgets('stacked, "Хүсэлт илгээх" still sends; the other two stay '
      'inert — in English too', (tester) async {
    await locale.setPreference(LocalePreference.english);
    final sent = <int?>[];
    await pump(tester, width: 320, scale: 3, onSend: (c) => sent.add(c.id));
    expect(find.text('Send request'), findsOneWidget);

    final send = tester.getRect(pillOf(TeacherScheduleStrings.requestSend));
    expect(send.width, 320 - 32, reason: 'stacked at 3.0×');
    await tester.tap(pillOf(TeacherScheduleStrings.requestSend));
    await tester.tap(pillOf(TeacherScheduleStrings.requestPending));
    await tester.tap(pillOf(TeacherScheduleStrings.requestRejected));
    expect(sent, [1]);
  });

  group('a name too long to sit beside the pill (Issue #557)', () {
    const long = 'Доржпаламын Сүхбаатар';

    testWidgets('one long name stacks the whole list, even at the default '
        'size, and shows in full', (tester) async {
      useLogicalViewport(tester, const Size(393, 2400), padding: iPhonePadding);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const TeacherRequestScreen(
            candidates: [
              TeacherRequestCandidate(
                name: 'Болд Бат',
                status: TeacherRequestStatus.notSent,
              ),
              TeacherRequestCandidate(
                name: long,
                status: TeacherRequestStatus.pending,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expectWhole(tester, find.text(long), long);
      for (final name in ['Болд Бат', long]) {
        final identity = tester.getRect(
          find.ancestor(
            of: find.text(name),
            matching: find.byType(TeacherIdentity),
          ),
        );
        final pill = tester.getRect(
          find.descendant(
            of: find.ancestor(
              of: find.text(name),
              matching: find.byType(TeacherRequestRow),
            ),
            matching: find.byType(TeacherPillButton),
          ),
        );
        expect(pill.top, greaterThanOrEqualTo(identity.bottom), reason: name);
      }
    });

    for (final width in [320.0, 393.0]) {
      for (final scale in [1.0, 2.0, 3.0]) {
        testWidgets('the incoming sheet, ${width.toInt()} wide, text '
            '×$scale: the sender in full, "Teacher" on one line', (
          tester,
        ) async {
          useLogicalViewport(tester, Size(width, 2400), padding: iPhonePadding);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: TeacherIncomingRequestSheet(
                    senderName: long,
                    teacherClass: sampleClass(),
                    sessionLabel: '10-р сарын 20 • 09:00-11:00',
                    onDecline: () {},
                    onAccept: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectWhole(tester, find.text(long), long);
          expect(
            lineCount(
              tester,
              find.descendant(
                of: find.byType(TeacherIdentity),
                matching: find.text('Teacher'),
              ),
              'Teacher',
            ),
            1,
          );
        });
      }
    }
  });
}
