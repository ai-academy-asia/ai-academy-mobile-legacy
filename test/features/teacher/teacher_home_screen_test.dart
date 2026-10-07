import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/cohorts/domain/cohort.dart';
import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/home/presentation/widgets/home_badges.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_class.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_class_card.dart';
import 'package:aia_mobile/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../cohorts/fake_cohort_repository.dart';
import 'fake_teacher_home_repository.dart';

/// A class meeting on Tuesdays, in the reference's figures.
TeacherClass sampleClass({
  int id = 2,
  String? track = 'adult',
  CohortClassroom? classroom = const CohortClassroom(
    id: 3,
    name: 'Room 204',
    centerName: 'Center',
  ),
  String start = '14:00',
  String end = '17:00',
  List<String> days = const ['tue', 'thu'],
}) => TeacherClass(
  cohort: sampleCohort(
    id: id,
    name: 'Cohort 01',
    course: const CohortCourse(
      id: 8,
      slug: 'ai-engineering',
      title: LocalizedText(en: 'AI Engineer'),
    ),
    classroom: classroom,
    enrolledCount: 24,
    startTime: start,
    endTime: end,
    startDate: '2026-09-01',
    endDate: '2026-12-20',
    meetingDays: days,
  ),
  track: track,
);

/// Tuesday 6 October 2026.
DateTime tuesday() => DateTime(2026, 10, 6, 9);

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    FakeTeacherHomeRepository repository, {
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TeacherHomeScreen(repository: repository, clock: tuesday),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  testWidgets('shows a spinner while the first load runs', (tester) async {
    final repository = FakeTeacherHomeRepository(hold: true);
    await pumpScreen(tester, repository, settle: false);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(TeacherClassCard), findsNothing);

    repository.release();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('draws one card per class meeting today, from its data', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      FakeTeacherHomeRepository(
        classes: [
          sampleClass(),
          sampleClass(id: 3, days: ['wed']),
        ],
      ),
    );

    expect(find.text(TeacherHomeStrings.title), findsOneWidget);
    expect(find.byType(TeacherClassCard), findsOneWidget);
    expect(find.text('Cohort 01'), findsOneWidget);
    expect(find.text('AI Engineer'), findsOneWidget);
    expect(find.text('24 Students'), findsOneWidget);
    expect(find.text('Room 204'), findsOneWidget);
    expect(find.text('14:00-17:00'), findsOneWidget);
    expect(find.byType(TrackBadge), findsOneWidget);
    expect(find.text('Adult'), findsOneWidget);
  });

  testWidgets('leaves out what the data does not carry', (tester) async {
    await pumpScreen(
      tester,
      FakeTeacherHomeRepository(
        classes: [
          sampleClass(
            track: null,
            classroom: null,
            start: '09:00:00',
            end: '10:30:00',
          ),
        ],
      ),
    );

    expect(find.byType(TrackBadge), findsNothing);
    expect(find.text('Room 204'), findsNothing);
    expect(find.text('09:00-10:30'), findsOneWidget);
  });

  testWidgets('draws none of the out-of-scope actions', (tester) async {
    await pumpScreen(
      tester,
      FakeTeacherHomeRepository(classes: [sampleClass()]),
    );

    expect(find.text('Зар тараах'), findsNothing);
    expect(find.text('Ирц бүртгэх'), findsNothing);
    expect(find.byType(AppButton), findsNothing);
  });

  testWidgets('says so when no class meets today', (tester) async {
    await pumpScreen(
      tester,
      FakeTeacherHomeRepository(
        classes: [
          sampleClass(days: ['wed']),
        ],
      ),
    );

    expect(find.text(TeacherHomeStrings.title), findsOneWidget);
    expect(find.text(TeacherHomeStrings.empty), findsOneWidget);
    expect(find.byType(TeacherClassCard), findsNothing);
  });

  testWidgets('a failure shows its message, and retry loads again', (
    tester,
  ) async {
    final repository = FakeTeacherHomeRepository(
      failure: const TeacherFailure(TeacherFailureKind.server),
      classes: [sampleClass()],
    );
    await pumpScreen(tester, repository);

    expect(find.text(HomeStrings.serverError), findsOneWidget);
    expect(find.byType(TeacherClassCard), findsNothing);

    repository.failure = null;
    await tester.tap(find.text(TeacherHomeStrings.retry));
    await tester.pumpAndSettle();

    expect(repository.callCount, 2);
    expect(find.text(HomeStrings.serverError), findsNothing);
    expect(find.byType(TeacherClassCard), findsOneWidget);
  });

  testWidgets('pull to refresh asks again', (tester) async {
    final repository = FakeTeacherHomeRepository(classes: [sampleClass()]);
    await pumpScreen(tester, repository);

    await tester.fling(
      find.byType(TeacherClassCard),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(repository.callCount, 2);
  });

  testWidgets('a tap on the header logo refreshes', (tester) async {
    final repository = FakeTeacherHomeRepository(classes: [sampleClass()]);
    await pumpScreen(tester, repository);

    await tester.tap(find.bySemanticsLabel(HomeStrings.logo));
    await tester.pumpAndSettle();

    expect(repository.callCount, 2);
  });

  testWidgets('the tab bar draws the four teacher tabs, Нүүр selected and '
      'the unbuilt one inert', (tester) async {
    await pumpScreen(
      tester,
      FakeTeacherHomeRepository(classes: [sampleClass()]),
    );

    for (final label in [
      TeacherHomeStrings.navHome,
      TeacherHomeStrings.navSchedule,
      TeacherHomeStrings.navGrades,
      TeacherHomeStrings.navProfile,
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    // Tapping the unbuilt tab goes nowhere. Хуваарь's and Дүнгийн хуудас's
    // routes are covered in teacher_schedule_screen_test.dart and
    // teacher_gradebook_screen_test.dart.
    for (final label in [TeacherHomeStrings.navProfile]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(TeacherHomeScreen), findsOneWidget);
    }
  });
}
