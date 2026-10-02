import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/home/domain/lesson_schedule.dart';
import 'package:aia_mobile/features/home/presentation/attendance_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';

/// A deterministic capture of the Adult attendance screen, for comparing
/// against its reference export, `HomePage - Adult/attendance.png` (1179
/// wide — 3x the 393 frame — so a reference pixel divided by 3 is a point on
/// this capture).
///
/// The frame's own grid is not a real month (it starts August 2026 on a
/// Monday, repeats a 7 and stops at 30), so this draws the real August 2026
/// from data shaped like the frame's: Tuesday/Saturday lessons, the 1st
/// attended, the 4th absent, today the 7th, the next lesson the 8th
/// 09:00–11:00, and the frame's `1/20 · 10%` summary.
///
/// Run `flutter test --update-goldens <this file>` to refresh, then compare
/// `test/goldens/attendance_detail.png` against the reference.
void main() {
  setUpAll(loadAppFonts);

  testWidgets('Adult attendance at the reference frame', (tester) async {
    useLogicalViewport(tester, const Size(393, 910), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: AttendanceDetailScreen(
          attendance: AttendanceSummary(
            attended: 1,
            total: 20,
            percent: 10,
            attendedDates: {DateTime(2026, 8, 1)},
            missedDates: {DateTime(2026, 8, 4)},
          ),
          schedule: const LessonSchedule(
            weekdays: {DateTime.tuesday, DateTime.saturday},
            start: (9, 0),
            end: (11, 0),
          ),
          nextLesson: NextLesson(
            startsAt: DateTime(2026, 8, 8, 9),
            endsAt: DateTime(2026, 8, 8, 11),
          ),
          clock: () => DateTime(2026, 8, 7, 10),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/attendance_detail.png'),
    );
  });
}
