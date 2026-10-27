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

/// The "Багш нар" rows at larger system text sizes (Issue #548). The request
/// pill beside the name is capped at 180 wide and one line, so from 1.5× a
/// label was cut short. Now, where any of the three labels would not fit
/// the cap, every row stacks — the identity, then the pill at the row's full
/// width, its label wrapping. At the default size the rows are as before.
/// In both languages since L17 (Issue #547) gave the labels English.
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

            // Stacked: the pill below the whole identity (avatar, name and

            // "Teacher"); beside it, the pill starts above the identity's foot.

            final identity = tester.getRect(
              find.ancestor(
                of: find.text(row.name),

                matching: find.byType(TeacherIdentity),
              ),
            );

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
          if (scale == 1.0) {
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
}
