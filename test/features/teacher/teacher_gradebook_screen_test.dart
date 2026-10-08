import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/presentation/home_route.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/home/presentation/widgets/home_badges.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_submission.dart';
import 'package:aia_mobile/features/teacher/presentation/gradebook_class_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/gradebook_student_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/gradebook_submission_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_gradebook_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_gradebook_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_profile_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_shell.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/gradebook_widgets.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_class_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../profile/fake_current_user_repository.dart';
import 'fake_teacher_gradebook_repository.dart';
import 'fake_teacher_home_repository.dart';
import 'fake_teacher_schedule_repository.dart';
import 'teacher_home_screen_test.dart' show sampleClass, tuesday;

/// Rows as a future verified source would supply them. Test values only:
/// nothing in the app builds a [GradebookRow] yet (BACKEND GAP).
/// Class 2's assignments and their latest-per-student submissions, in the
/// confirmed shapes. Test values only.
const assignments = [
  TeacherAssignment(id: 2, title: LocalizedText(mn: 'Даалгавар 2')),
  TeacherAssignment(id: 3, title: LocalizedText(en: 'Assignment 3')),
];

final submissionsOf = {
  2: [
    sampleSubmission(id: 18, studentId: 13, studentName: 'Student A'),
    sampleSubmission(
      id: 19,
      studentId: 9,
      studentName: 'Student B',
      initials: 'SB',
      status: 'submitted',
      score: null,
      feedback: null,
      submittedAt: DateTime(2026, 5, 1),
    ),
  ],
  3: [
    sampleSubmission(
      id: 30,
      assignmentId: 3,
      studentId: 13,
      studentName: 'Student A',
      status: 'submitted',
      score: null,
      feedback: null,
      submittedAt: DateTime(2026, 5, 5),
    ),
  ],
};

FakeTeacherGradebookRepository classRepository() =>
    FakeTeacherGradebookRepository(
      classes: [sampleClass()],
      assignments: {2: assignments},
      submissionsOf: submissionsOf,
      submissions: {
        18: submissionsOf[2]![0],
        19: submissionsOf[2]![1],
        30: submissionsOf[3]![0],
      },
    );

/// Student A's rows, as the student list hands them on.
final studentRows = [
  GradebookRow(
    submission: submissionsOf[3]![0],
    assignmentTitle: 'Assignment 3',
  ),
  GradebookRow(
    submission: submissionsOf[2]![0],
    assignmentTitle: 'Даалгавар 2',
  ),
];

void main() {
  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(393, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Taps a filter chip, scrolling the chip row to it first.
  Future<void> tapChip(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    bool settle = true,
  }) async {
    tallView(tester);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: home));
    if (settle) await tester.pumpAndSettle();
  }

  group('Gradebook', () {
    testWidgets('shows a spinner while the first load runs', (tester) async {
      final repository = FakeTeacherGradebookRepository(
        classes: [sampleClass()],
        hold: true,
      );
      await pump(
        tester,
        TeacherGradebookScreen(repository: repository),
        settle: false,
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repository.release();
      await tester.pumpAndSettle();
      expect(find.byType(TeacherClassCard), findsOneWidget);
    });

    testWidgets(
      'draws one card per class from its data, without room or time',
      (tester) async {
        await pump(
          tester,
          TeacherGradebookScreen(
            repository: FakeTeacherGradebookRepository(
              classes: [
                sampleClass(),
                sampleClass(id: 3, track: 'junior'),
              ],
            ),
          ),
        );

        // The title, and the selected tab's label.
        expect(find.text(TeacherGradebookStrings.title), findsNWidgets(2));
        expect(find.byType(TeacherClassCard), findsNWidgets(2));
        expect(find.byType(TrackBadge), findsNWidgets(2));
        expect(find.text('Junior'), findsOneWidget);
        expect(find.text('Cohort 01'), findsNWidgets(2));
        expect(find.text('AI Engineer'), findsNWidgets(2));
        expect(find.text('24 Students'), findsNWidgets(2));
        expect(find.text('Room 204'), findsNothing);
        expect(find.text('14:00-17:00'), findsNothing);
        // No submission summary is invented.
        expect(find.textContaining('Даалгавар илгээсэн'), findsNothing);
      },
    );

    testWidgets('says so when there is no class', (tester) async {
      await pump(
        tester,
        TeacherGradebookScreen(repository: FakeTeacherGradebookRepository()),
      );
      expect(find.text(TeacherGradebookStrings.empty), findsOneWidget);
    });

    testWidgets('a failure shows its message, and retry loads again', (
      tester,
    ) async {
      final repository = FakeTeacherGradebookRepository(
        classes: [sampleClass()],
        failure: const TeacherFailure(TeacherFailureKind.network),
      );
      await pump(tester, TeacherGradebookScreen(repository: repository));
      expect(find.text(HomeStrings.networkError), findsOneWidget);

      repository.failure = null;
      await tester.tap(find.text(TeacherHomeStrings.retry));
      await tester.pumpAndSettle();
      expect(repository.classCalls, 2);
      expect(find.byType(TeacherClassCard), findsOneWidget);
    });

    testWidgets('pull to refresh asks again', (tester) async {
      final repository = FakeTeacherGradebookRepository(
        classes: [sampleClass()],
      );
      await pump(tester, TeacherGradebookScreen(repository: repository));
      await tester.fling(
        find.byType(TeacherClassCard),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(repository.classCalls, 2);
    });

    testWidgets('a tap on a class opens its student list', (tester) async {
      await pump(
        tester,
        TeacherGradebookScreen(
          repository: FakeTeacherGradebookRepository(classes: [sampleClass()]),
        ),
      );
      await tester.tap(find.byType(TeacherClassCard));
      await tester.pumpAndSettle();

      expect(find.byType(GradebookClassScreen), findsOneWidget);
      expect(find.text('AI Engineer'), findsOneWidget);
    });
  });

  group('student list', () {
    Future<FakeTeacherGradebookRepository> pumpList(
      WidgetTester tester, [
      FakeTeacherGradebookRepository? repository,
    ]) async {
      final repo = repository ?? classRepository();
      await pump(
        tester,
        GradebookClassScreen(teacherClass: sampleClass(), repository: repo),
      );
      return repo;
    }

    testWidgets('lists every submission of every assignment, newest first, '
        'from the class\'s own data', (tester) async {
      final repository = await pumpList(tester);

      expect(repository.assignmentCalls, [2]);
      expect(repository.submissionListCalls, unorderedEquals([2, 3]));
      final labels = [
        for (final card in tester.widgetList<GradebookRowCard>(
          find.byType(GradebookRowCard),
        ))
          '${card.row.studentName}, ${card.row.assignmentTitle}',
      ];
      expect(labels, [
        'Student A, Assignment 3',
        'Student B, Даалгавар 2',
        'Student A, Даалгавар 2',
      ]);
      // The confirmed initials stand in for a photo.
      expect(find.text('ХЦ'), findsNWidgets(2));
      expect(find.text('SB'), findsOneWidget);
    });

    testWidgets('only students who submitted appear', (tester) async {
      final repository = classRepository()..submissionsOf = {2: [], 3: []};
      await pumpList(tester, repository);

      expect(find.byType(GradebookRowCard), findsNothing);
      expect(find.text(TeacherGradebookStrings.noRows), findsOneWidget);
    });

    testWidgets('the filters keep submitted under Хүлээгдэж буй and reviewed '
        'under Дүгнэгдсэн', (tester) async {
      await pumpList(tester);
      expect(find.byType(GradebookRowCard), findsNWidgets(3));

      await tapChip(tester, TeacherGradebookStrings.filterPending);
      expect(find.byType(GradebookRowCard), findsNWidgets(2));
      expect(find.bySemanticsLabel('Student A, Даалгавар 2'), findsNothing);

      await tapChip(tester, TeacherGradebookStrings.filterGraded);
      expect(find.byType(GradebookRowCard), findsOneWidget);
      expect(find.bySemanticsLabel('Student A, Даалгавар 2'), findsOneWidget);

      await tapChip(tester, TeacherGradebookStrings.filterAll);
      expect(find.byType(GradebookRowCard), findsNWidgets(3));
    });

    testWidgets('a filter with nothing under it says so', (tester) async {
      final repository = classRepository()
        ..submissionsOf = {
          2: [submissionsOf[2]![0]],
        };
      await pumpList(tester, repository);
      await tapChip(tester, TeacherGradebookStrings.filterPending);
      expect(find.text(TeacherGradebookStrings.noRows), findsOneWidget);
    });

    testWidgets('a failure shows its message, and retry loads again', (
      tester,
    ) async {
      final repository = classRepository()
        ..failure = const TeacherFailure(TeacherFailureKind.server);
      await pumpList(tester, repository);
      expect(find.text(HomeStrings.serverError), findsOneWidget);

      repository.failure = null;
      await tester.tap(find.text(TeacherHomeStrings.retry));
      await tester.pumpAndSettle();
      expect(find.byType(GradebookRowCard), findsNWidgets(3));
    });

    testWidgets('pull to refresh asks again', (tester) async {
      final repository = await pumpList(tester);
      await tester.fling(
        find.byType(GradebookRowCard).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(repository.assignmentCalls, [2, 2]);
    });

    testWidgets('a tap on a student opens them, with their own submissions', (
      tester,
    ) async {
      await pumpList(tester);
      await tester.tap(find.bySemanticsLabel('Student A, Даалгавар 2'));
      await tester.pumpAndSettle();

      final screen = tester.widget<GradebookStudentScreen>(
        find.byType(GradebookStudentScreen),
      );
      expect(screen.student.studentId, 13);
      expect(screen.student.assignmentTitle, 'Даалгавар 2');
      expect([for (final s in screen.submissions) s.submissionId], [30, 18]);
    });
  });

  group('student detail', () {
    Widget detail(FakeTeacherGradebookRepository repository) =>
        GradebookStudentScreen(
          courseTitle: 'AI Engineer',
          student: studentRows[1],
          submissions: studentRows,
          repository: repository,
        );

    testWidgets('draws the student and no invented figure', (tester) async {
      await pump(tester, detail(classRepository()));

      expect(find.text('AI Engineer'), findsOneWidget);
      expect(find.text('ХЦ'), findsOneWidget);
      expect(find.text(TeacherGradebookStrings.attendance), findsOneWidget);
      expect(find.text(TeacherGradebookStrings.examScore), findsOneWidget);
      expect(find.text(TeacherGradebookStrings.noFigure), findsNWidgets(2));
      expect(find.textContaining('%'), findsNothing);
      expect(find.byType(GradebookRowCard), findsNWidgets(2));
    });

    testWidgets('a tap on a submission opens it', (tester) async {
      final repository = classRepository();
      await pump(tester, detail(repository));
      await tester.tap(find.bySemanticsLabel('Student A, Assignment 3'));
      await tester.pumpAndSettle();

      expect(find.byType(GradebookSubmissionScreen), findsOneWidget);
      expect(repository.submissionCalls, [30]);
    });
  });

  group('submission detail', () {
    Widget submissionScreen(FakeTeacherGradebookRepository repository) =>
        GradebookSubmissionScreen(
          courseTitle: 'AI Engineer',
          submissionId: 7,
          repository: repository,
        );

    testWidgets('a reviewed submission shows its status, score and feedback', (
      tester,
    ) async {
      await pump(
        tester,
        submissionScreen(
          FakeTeacherGradebookRepository(
            submissions: {
              7: const TeacherSubmission(
                id: 7,
                status: 'reviewed',
                score: 85,
                feedback: 'Сайн байна',
              ),
            },
          ),
        ),
      );

      expect(find.text(TeacherGradebookStrings.tabAssignment), findsOneWidget);
      expect(find.text(TeacherGradebookStrings.tabNote), findsOneWidget);
      expect(find.text(TeacherGradebookStrings.filterGraded), findsOneWidget);
      expect(find.text('Оноо: 85'), findsOneWidget);
      expect(find.text('Сайн байна'), findsOneWidget);
      expect(
        find.text(TeacherGradebookStrings.contentUnavailable),
        findsOneWidget,
      );
    });

    testWidgets('draws the submitted link and description from its data, '
        'and opens the link', (tester) async {
      final opened = <Uri>[];
      final repository = classRepository();
      await pump(
        tester,
        GradebookSubmissionScreen(
          courseTitle: 'AI Engineer',
          submissionId: 18,
          repository: repository,
          openUrl: (url) async {
            opened.add(url);
            return true;
          },
        ),
      );

      expect(find.text('https://github.com/example/hw-2'), findsOneWidget);
      expect(find.text(TeacherGradebookStrings.description), findsOneWidget);
      expect(find.text('Засварласан хувилбар.'), findsOneWidget);
      expect(find.text('Оноо: 80'), findsOneWidget);
      expect(find.text('Validation хэсэг дутуу байна.'), findsOneWidget);
      expect(
        find.text(TeacherGradebookStrings.contentUnavailable),
        findsNothing,
      );

      await tester.tap(find.text('https://github.com/example/hw-2'));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse('https://github.com/example/hw-2')]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a link the OS will not open says so', (tester) async {
      await pump(
        tester,
        GradebookSubmissionScreen(
          courseTitle: 'AI Engineer',
          submissionId: 18,
          repository: classRepository(),
          openUrl: (_) async => false,
        ),
      );
      await tester.tap(find.text('https://github.com/example/hw-2'));
      await tester.pumpAndSettle();
      expect(find.text(HomeStrings.unexpectedError), findsOneWidget);
    });

    testWidgets('a pending submission shows no score or feedback', (
      tester,
    ) async {
      await pump(
        tester,
        submissionScreen(
          FakeTeacherGradebookRepository(
            submissions: {
              7: const TeacherSubmission(id: 7, status: 'submitted'),
            },
          ),
        ),
      );

      expect(find.text(TeacherGradebookStrings.filterPending), findsOneWidget);
      expect(find.textContaining('Оноо'), findsNothing);
      expect(find.byType(InputDecorator), findsNothing);
    });

    testWidgets('the Note tab is a BACKEND GAP', (tester) async {
      await pump(
        tester,
        submissionScreen(
          FakeTeacherGradebookRepository(
            submissions: {
              7: const TeacherSubmission(id: 7, status: 'submitted'),
            },
          ),
        ),
      );
      await tester.tap(find.text(TeacherGradebookStrings.tabNote));
      await tester.pumpAndSettle();

      expect(
        find.text(TeacherGradebookStrings.noteUnavailable),
        findsOneWidget,
      );
      expect(
        find.text(TeacherGradebookStrings.contentUnavailable),
        findsNothing,
      );
    });

    testWidgets('Mentor Feedback is drawn but sends nothing', (tester) async {
      final repository = FakeTeacherGradebookRepository(
        submissions: {7: const TeacherSubmission(id: 7, status: 'submitted')},
      );
      await pump(tester, submissionScreen(repository));

      await tester.tap(find.text(TeacherGradebookStrings.mentorFeedback));
      await tester.pumpAndSettle();

      expect(find.byType(GradebookSubmissionScreen), findsOneWidget);
      expect(repository.submissionCalls, [7]);
    });

    testWidgets('a failure shows its message, and retry loads again', (
      tester,
    ) async {
      final repository = FakeTeacherGradebookRepository(
        submissions: {7: const TeacherSubmission(id: 7, status: 'submitted')},
        submissionFailure: const TeacherFailure(TeacherFailureKind.server),
      );
      await pump(tester, submissionScreen(repository));
      expect(find.text(HomeStrings.serverError), findsOneWidget);

      repository.submissionFailure = null;
      await tester.tap(find.text(TeacherHomeStrings.retry));
      await tester.pumpAndSettle();
      expect(repository.submissionCalls, [7, 7]);
      expect(find.text(TeacherGradebookStrings.filterPending), findsOneWidget);
    });
  });

  group('teacher tab bar', () {
    Future<void> pumpApp(WidgetTester tester) async {
      tallView(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          initialRoute: HomeRoutes.teacher,
          // The app's own: the tabs inside one persistent shell (#241).
          routes: {
            HomeRoutes.teacher: (_) => TeacherShell(
              home: TeacherHomeScreen(
                repository: FakeTeacherHomeRepository(classes: [sampleClass()]),
                clock: tuesday,
                showBottomNav: false,
              ),
              schedule: TeacherScheduleScreen(
                repository: FakeTeacherScheduleRepository(),
                clock: tuesday,
                showBottomNav: false,
              ),
              grades: TeacherGradebookScreen(
                repository: FakeTeacherGradebookRepository(
                  classes: [sampleClass()],
                ),
                showBottomNav: false,
              ),
              profile: TeacherProfileScreen(
                repository: FakeCurrentUserRepository(),
              ),
            ),
          },
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('keeps Нүүр, Хуваарь, Дүнгийн хуудас, Профайл in that order', (
      tester,
    ) async {
      await pumpApp(tester);
      final xs = [
        for (final label in [
          TeacherHomeStrings.navHome,
          TeacherHomeStrings.navSchedule,
          TeacherHomeStrings.navGrades,
          TeacherHomeStrings.navProfile,
        ])
          tester.getCenter(find.text(label)).dx,
      ];
      expect(xs, orderedEquals([...xs]..sort()));
    });

    testWidgets('Дүнгийн хуудас opens the Gradebook from Home and Schedule, '
        'and Нүүр returns', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text(TeacherHomeStrings.navGrades));
      await tester.pumpAndSettle();
      expect(find.byType(TeacherGradebookScreen), findsOneWidget);

      await tester.tap(find.text(TeacherHomeStrings.navSchedule));
      await tester.pumpAndSettle();
      expect(find.byType(TeacherScheduleScreen), findsOneWidget);
      expect(find.byType(TeacherGradebookScreen), findsNothing);

      await tester.tap(find.text(TeacherHomeStrings.navGrades));
      await tester.pumpAndSettle();
      expect(find.byType(TeacherGradebookScreen), findsOneWidget);

      await tester.tap(find.text(TeacherHomeStrings.navHome));
      await tester.pumpAndSettle();
      expect(find.byType(TeacherHomeScreen), findsOneWidget);
      expect(find.byType(TeacherGradebookScreen), findsNothing);
    });

    testWidgets('Профайл opens the Teacher Profile, and Дүнгийн хуудас '
        'returns as it was left (Issue #243)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text(TeacherHomeStrings.navGrades));
      await tester.pumpAndSettle();
      final gradebook = tester.state(find.byType(TeacherGradebookScreen));

      await tester.tap(find.text(TeacherHomeStrings.navProfile));
      await tester.pumpAndSettle();
      expect(find.byType(TeacherProfileScreen), findsOneWidget);
      expect(find.byType(TeacherGradebookScreen), findsNothing);

      await tester.tap(find.text(TeacherHomeStrings.navGrades));
      await tester.pumpAndSettle();
      expect(
        identical(tester.state(find.byType(TeacherGradebookScreen)), gradebook),
        isTrue,
      );
    });
  });
}
