import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/cohorts/domain/cohort.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_class.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_session.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_request_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../cohorts/fake_cohort_repository.dart';
import 'fake_teacher_schedule_repository.dart';
import 'teacher_home_screen_test.dart' show sampleClass;

/// Deterministic captures of Teacher Schedule (Issue #231) at the
/// references' 393pt width — the week, both session sheets and "Багш нар" —
/// for comparing against the `huvaari`, `huvaari-deerh-oroh-angi`,
/// `huvaari-deerh-orson-angi` and `tsag-solih` references.
///
/// Run `flutter test --update-goldens <this file>` to refresh the captures.
void main() {
  setUpAll(loadAppFonts);

  final junior = TeacherClass(
    cohort: sampleCohort(
      id: 5,
      name: 'Cohort 02',
      course: const CohortCourse(
        id: 9,
        slug: 'junior-ai-engineer',
        title: LocalizedText(en: 'Junior AI Engineer'),
      ),
      enrolledCount: 18,
      startDate: '2026-09-01',
      endDate: '2026-12-20',
    ),
    track: 'junior',
  );

  FakeTeacherScheduleRepository repository() => FakeTeacherScheduleRepository(
    classes: [sampleClass(), junior],
    sessions: {
      2: [
        sampleSession(id: 1, date: '2026-10-07', start: (9, 0), end: (13, 0)),
        sampleSession(id: 2, date: '2026-10-07', start: (14, 0), end: (17, 0)),
        sampleSession(id: 3, date: '2026-10-09', start: (14, 0), end: (17, 0)),
      ],
      5: [
        sampleSession(
          id: 4,
          cohortId: 5,
          date: '2026-10-05',
          start: (9, 0),
          end: (13, 0),
        ),
        sampleSession(
          id: 5,
          cohortId: 5,
          date: '2026-10-05',
          start: (14, 0),
          end: (17, 0),
        ),
      ],
    },
    attendance: {
      1: const AttendanceCounts(present: 12, late: 2, absent: 9, excused: 1),
    },
  );

  // Wednesday 7 October 2026, 13:30.
  DateTime clock() => DateTime(2026, 10, 7, 13, 30);

  Future<void> pumpSchedule(WidgetTester tester) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: TeacherScheduleScreen(repository: repository(), clock: clock),
      ),
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);
  }

  testWidgets('Teacher Schedule at the reference width', (tester) async {
    await pumpSchedule(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/teacher_schedule.png'),
    );
  });

  testWidgets('the upcoming session sheet', (tester) async {
    await pumpSchedule(tester);
    await tester.tap(find.bySemanticsLabel('AI Engineer, 14:00-17:00').first);
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/teacher_schedule_upcoming_sheet.png'),
    );
  });

  testWidgets('the held session sheet', (tester) async {
    await pumpSchedule(tester);
    await tester.tap(find.bySemanticsLabel('AI Engineer, 09:00-13:00'));
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/teacher_schedule_held_sheet.png'),
    );
  });

  testWidgets('"Багш нар" with the three row states', (tester) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: const TeacherRequestScreen(
          candidates: [
            TeacherRequestCandidate(
              name: 'Баатар',
              status: TeacherRequestStatus.pending,
            ),
            TeacherRequestCandidate(
              name: 'Анужин Болд',
              status: TeacherRequestStatus.notSent,
            ),
            TeacherRequestCandidate(
              name: 'Отгонбаяр',
              status: TeacherRequestStatus.rejected,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/teacher_request_rows.png'),
    );
  });
}
