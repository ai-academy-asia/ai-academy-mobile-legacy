import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_request_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';

/// The "Багш нар" rows at larger system text sizes (Issue #548). The request
/// pill beside the name is capped at 180 wide and one line, so from 1.5× a
/// label was cut short. Now, where any of the three labels would not fit
/// the cap, every row stacks — the identity, then the pill at the row's full
/// width, its label wrapping. At the default size the rows are as before.
void main() {
  setUpAll(loadAppFonts);

  const widths = [320.0, 375.0, 393.0];
  const scales = [1.0, 1.5, 2.0, 3.0];

  /// One row in each state, as the screen lists them.
  const rows = [
    (
      name: 'Болд Бат',
      status: TeacherRequestStatus.notSent,
      label: TeacherScheduleStrings.requestSend,
    ),
    (
      name: 'Сараа Ганбат',
      status: TeacherRequestStatus.pending,
      label: TeacherScheduleStrings.requestPending,
    ),
    (
      name: 'Анар Бат',
      status: TeacherRequestStatus.rejected,
      label: TeacherScheduleStrings.requestRejected,
    ),
  ];

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

  for (final width in widths) {
    for (final scale in scales) {
      testWidgets('${width.toInt()} wide, text ×$scale: every label whole and '
          'inside its pill, the pill inside the screen and clear of the '
          'name, and every row laid out alike', (tester) async {
        final errors = await pump(tester, width: width, scale: scale);
        expect(errors, isEmpty);

        final stacked = <bool>{};
        for (final row in rows) {
          final label = find.text(row.label);
          expect(label, findsOneWidget, reason: row.label);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: label, matching: find.byType(RichText)).first,
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: row.label);
          expect(
            paragraph.size.height,
            greaterThanOrEqualTo(
              paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
            ),
            reason: row.label,
          );

          final text = tester.getRect(label);
          final pill = tester.getRect(pillOf(row.label));
          expect(text.left, greaterThanOrEqualTo(pill.left), reason: row.label);
          expect(text.right, lessThanOrEqualTo(pill.right), reason: row.label);
          expect(text.top, greaterThanOrEqualTo(pill.top), reason: row.label);
          expect(
            text.bottom,
            lessThanOrEqualTo(pill.bottom),
            reason: row.label,
          );
          // On the 16 gutter either side.
          expect(pill.left, greaterThanOrEqualTo(16), reason: row.label);
          expect(pill.right, lessThanOrEqualTo(width - 16), reason: row.label);

          final name = tester.getRect(find.text(row.name));
          expect(name.overlaps(pill), isFalse, reason: row.name);
          expect(name.right, lessThanOrEqualTo(width - 16), reason: row.name);

          final isStacked = pill.top >= name.bottom;
          stacked.add(isStacked);
          if (isStacked) {
            // The row's full width, below the identity.
            expect(pill.left, 16, reason: row.label);
            expect(pill.right, width - 16, reason: row.label);
          } else {
            // Beside the name, at its cap and height, on the trailing edge.
            expect(pill.width, lessThanOrEqualTo(180), reason: row.label);
            expect(pill.height, 40, reason: row.label);
            expect(pill.right, width - 16, reason: row.label);
          }
        }
        expect(stacked, hasLength(1), reason: 'one layout for every row');
        if (scale == 1.0) {
          expect(stacked.single, isFalse, reason: 'beside the name at 1.0×');
        }
      });
    }
  }

  testWidgets('stacked, "Хүсэлт илгээх" still sends; the other two stay '
      'inert', (tester) async {
    final sent = <int?>[];
    await pump(tester, width: 320, scale: 3, onSend: (c) => sent.add(c.id));

    final send = tester.getRect(pillOf(TeacherScheduleStrings.requestSend));
    expect(send.width, 320 - 32, reason: 'stacked at 3.0×');
    await tester.tap(pillOf(TeacherScheduleStrings.requestSend));
    await tester.tap(pillOf(TeacherScheduleStrings.requestPending));
    await tester.tap(pillOf(TeacherScheduleStrings.requestRejected));
    expect(sent, [1]);
  });
}
