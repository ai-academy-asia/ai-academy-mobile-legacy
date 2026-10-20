import 'dart:async';

import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_gradebook_repository.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_submission.dart';
import 'package:aia_mobile/features/teacher/presentation/gradebook_class_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/gradebook_student_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_gradebook_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_gradebook_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/program_widgets.dart';
import 'package:aia_mobile/shared/widgets/app_back_button.dart';
import 'package:aia_mobile/shared/widgets/pill_button.dart';
import 'package:aia_mobile/shared/widgets/track_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_teacher_gradebook_repository.dart';
import 'teacher_home_screen_test.dart' show sampleClass;

/// Teacher Programs — formerly the Gradebook (Issues #233, #390). Fakes
/// only: no production call, no review or announcement written anywhere.

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

/// Class 2's roster, in the API's order. Student C has submitted nothing.
const roster = [
  CohortStudent(id: 13, name: 'Student A'),
  CohortStudent(id: 9, name: 'Student B'),
  CohortStudent(id: 21, name: 'Student C'),
];

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
      students: {2: roster},
    );

void main() {
  setUpAll(loadAppFonts);

  Future<List<String>> pump(
    WidgetTester tester,
    Widget home, {
    double width = 393,
    double height = 1000,
    double scale = 1,
  }) async {
    useLogicalViewport(tester, Size(width, height), padding: iPhonePadding);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.toString());
    try {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: home,
        ),
      );
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = previous;
    }
    return errors;
  }

  Finder pill(String label) => find.widgetWithText(PillButton, label);

  Future<FakeTeacherGradebookRepository> openOverview(
    WidgetTester tester, {
    FakeTeacherGradebookRepository? repository,
    double width = 393,
    double height = 1000,
  }) async {
    final repo = repository ?? classRepository();
    await pump(
      tester,
      TeacherGradebookScreen(repository: repo, showBottomNav: false),
      width: width,
      height: height,
    );
    return repo;
  }

  Future<void> openStudents(WidgetTester tester) async {
    await tester.tap(pill(TeacherGradebookStrings.details));
    await tester.pumpAndSettle();
    await tester.tap(find.text(TeacherGradebookStrings.studentsInfo));
    await tester.pumpAndSettle();
  }

  Future<FakeTeacherGradebookRepository> openStudent(
    WidgetTester tester,
    String name, {
    FakeTeacherGradebookRepository? repository,
    double width = 393,
    double height = 1000,
  }) async {
    final repo = await openOverview(
      tester,
      repository: repository,
      width: width,
      height: height,
    );
    await openStudents(tester);
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
    expect(find.byType(GradebookStudentScreen), findsOneWidget);
    return repo;
  }

  Finder replyField() => find.byWidgetPredicate(
    (w) =>
        w is TextField &&
        w.decoration?.labelText == TeacherGradebookStrings.replyLabel,
  );

  /// The student screen's own back control.
  Future<void> leaveStudent(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(GradebookStudentScreen),
        matching: find.descendant(
          of: find.byType(AppBackButton),
          matching: find.byType(InkWell),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<int> rosterBadges(WidgetTester tester) => [
    for (final row in tester.widgetList<ProgramStudentRow>(
      find.byType(ProgramStudentRow),
    ))
      row.pending,
  ];

  group('Хөтөлбөрүүд', () {
    test('is the tab label and the title — formerly "Дүнгийн хуудас"', () {
      expect(TeacherGradebookStrings.title, 'Хөтөлбөрүүд');
      expect(TeacherHomeStrings.navGrades, 'Хөтөлбөрүүд');
    });

    testWidgets('a program card: the badge, the cohort over the course, '
        '"Нийт сурагч" and its count, and "Дэлгэрэнгүй"', (tester) async {
      await openOverview(tester);
      expect(find.text('Хөтөлбөрүүд'), findsOneWidget);
      expect(find.byType(TeacherProgramCard), findsOneWidget);
      expect(find.byType(TrackBadge), findsOneWidget);
      expect(find.text('Cohort 01'), findsOneWidget);
      expect(find.text('AI Engineer'), findsOneWidget);
      expect(find.text(TeacherGradebookStrings.totalStudents), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      expect(pill(TeacherGradebookStrings.details), findsOneWidget);
    });

    testWidgets('"Дэлгэрэнгүй" opens the two actions; dismissing opens '
        'nothing', (tester) async {
      final repo = await openOverview(tester);
      await tester.tap(pill(TeacherGradebookStrings.details));
      await tester.pumpAndSettle();
      expect(find.byType(CohortActionSheet), findsOneWidget);
      expect(find.text(TeacherGradebookStrings.announce), findsOneWidget);
      expect(find.text(TeacherGradebookStrings.studentsInfo), findsOneWidget);

      await tester.tapAt(const Offset(196, 100));
      await tester.pumpAndSettle();
      expect(find.byType(CohortActionSheet), findsNothing);
      expect(find.byType(GradebookClassScreen), findsNothing);
      expect(repo.studentCalls, isEmpty);
    });

    testWidgets('"Сурагчдын мэдээлэл" opens the class\'s students; back '
        'returns to the cards', (tester) async {
      await openOverview(tester);
      await openStudents(tester);
      expect(find.byType(GradebookClassScreen), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AppBackButton),
          matching: find.byType(InkWell),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TeacherProgramCard), findsOneWidget);
    });

    testWidgets('"Зар тараах" opens the composer: the counter follows the '
        'text, and Submit never sends — no endpoint lets a teacher '
        'announce', (tester) async {
      await openOverview(tester);
      await tester.tap(pill(TeacherGradebookStrings.details));
      await tester.pumpAndSettle();
      await tester.tap(find.text(TeacherGradebookStrings.announce));
      await tester.pumpAndSettle();
      expect(find.byType(AnnouncementSheet), findsOneWidget);
      expect(find.text('0/100'), findsOneWidget);
      expect(find.text(TeacherGradebookStrings.announceHint), findsOneWidget);
      expect(
        find.text(TeacherGradebookStrings.announceUnavailable),
        findsOneWidget,
      );
      Finder submit() => find.descendant(
        of: find.byType(AnnouncementSheet),
        matching: pill(TeacherGradebookStrings.submit),
      );
      expect(tester.widget<PillButton>(submit()).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Маргааш хичээл 19:00');
      await tester.pump();
      expect(find.text('20/100'), findsOneWidget);
      expect(tester.widget<PillButton>(submit()).onPressed, isNull);
    });

    testWidgets('a failed read says so, and retry asks again', (tester) async {
      final repo = classRepository()
        ..failure = const TeacherFailure(TeacherFailureKind.network);
      await openOverview(tester, repository: repo);
      expect(find.text(TeacherHomeStrings.retry), findsOneWidget);
      repo.failure = null;
      await tester.tap(find.text(TeacherHomeStrings.retry));
      await tester.pumpAndSettle();
      expect(find.byType(TeacherProgramCard), findsOneWidget);
    });

    testWidgets('no class: the empty line', (tester) async {
      await openOverview(tester, repository: FakeTeacherGradebookRepository());
      expect(find.text(TeacherGradebookStrings.empty), findsOneWidget);
    });
  });

  group('the students', () {
    testWidgets('the real roster, in order, each with its awaiting-review '
        'badge — none for a student with nothing pending', (tester) async {
      final repo = await openOverview(tester);
      await openStudents(tester);
      expect(repo.studentCalls, [2]);
      expect(repo.assignmentCalls, [2]);
      expect(repo.submissionListCalls, [2, 3]);
      expect(find.text('Cohort 01'), findsOneWidget);
      expect(find.text('AI Engineer'), findsOneWidget);
      expect(
        find.text(TeacherGradebookStrings.studentsHeading),
        findsOneWidget,
      );

      final rows = tester.widgetList<ProgramStudentRow>(
        find.byType(ProgramStudentRow),
      );
      expect(
        [for (final r in rows) r.student.name],
        ['Student A', 'Student B', 'Student C'],
      );
      expect([for (final r in rows) r.pending], [1, 1, 0]);
    });

    testWidgets('a failed read offers retry; an empty roster says so', (
      tester,
    ) async {
      final repo = classRepository();
      await openOverview(tester, repository: repo);
      repo.failure = const TeacherFailure(TeacherFailureKind.server);
      await openStudents(tester);
      expect(find.text(TeacherHomeStrings.retry), findsOneWidget);

      repo
        ..failure = null
        ..students = {2: const []};
      await tester.tap(find.text(TeacherHomeStrings.retry));
      await tester.pumpAndSettle();
      expect(find.text(TeacherGradebookStrings.noStudents), findsOneWidget);
    });

    test('a badge reads "9+" past nine', () {
      expect(TeacherGradebookStrings.badge(1), '1');
      expect(TeacherGradebookStrings.badge(9), '9');
      expect(TeacherGradebookStrings.badge(10), '9+');
    });
  });

  group('a student', () {
    testWidgets('opens on the assignment waiting for review: the selector, '
        'the "—" figures, and the student\'s note with its time', (
      tester,
    ) async {
      await openStudent(tester, 'Student A');
      expect(find.text(TeacherGradebookStrings.attendance), findsOneWidget);
      expect(find.text(TeacherGradebookStrings.examScore), findsOneWidget);
      expect(find.text(TeacherGradebookStrings.noFigure), findsNWidgets(2));
      // Assignment 3, second in the class's list, waits for review.
      expect(find.text('Даалгавар 2'), findsOneWidget);
      expect(find.text('Assignment 3'), findsOneWidget);
      expect(find.text(TeacherGradebookStrings.roleStudent), findsOneWidget);
      expect(find.text('Засварласан хувилбар.'), findsOneWidget);
      expect(find.text('05/05, 00:00'), findsOneWidget);
      expect(replyField(), findsOneWidget);
    });

    testWidgets('the picker lists every assignment with the selected one '
        'marked; picking shows that thread — here a saved reply', (
      tester,
    ) async {
      await openStudent(tester, 'Student A');
      await tester.tap(find.byType(AssignmentSelector));
      await tester.pumpAndSettle();
      expect(find.byType(AssignmentPickerSheet), findsOneWidget);
      final options = tester.widgetList<AssignmentOption>(
        find.byType(AssignmentOption),
      );
      expect([for (final o in options) o.selected], [false, true]);
      expect([for (final o in options) o.pending], [0, 1]);

      await tester.tap(find.byType(AssignmentOption).first);
      await tester.pumpAndSettle();
      expect(find.byType(AssignmentPickerSheet), findsNothing);
      expect(find.text('Validation хэсэг дутуу байна.'), findsOneWidget);
      expect(find.text(TeacherGradebookStrings.roleTeacher), findsWidgets);
    });

    testWidgets('Submit waits for text; a reply is shown only once the '
        'server answers, and the class list\'s badge follows', (tester) async {
      final repo = classRepository()..reviewGate = Completer<void>();
      await openStudent(tester, 'Student A', repository: repo);
      Finder submit() => pill(TeacherGradebookStrings.submit);
      expect(tester.widget<PillButton>(submit()).onPressed, isNull);
      await tester.enterText(replyField(), '   ');
      await tester.pump();
      expect(tester.widget<PillButton>(submit()).onPressed, isNull);

      await tester.enterText(replyField(), 'Сайн ажил, үргэлжлүүлээрэй.');
      await tester.pump();
      await tester.tap(submit());
      await tester.pump();
      expect(repo.reviewCalls, [(30, 'Сайн ажил, үргэлжлүүлээрэй.', null)]);
      // In flight: no reply yet, and no second send.
      expect(find.text('Анужин Болд'), findsNothing);
      expect(tester.widget<PillButton>(submit()).onPressed, isNull);

      repo.reviewGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Сайн ажил, үргэлжлүүлээрэй.'), findsOneWidget);
      expect(find.text('Анужин Болд'), findsOneWidget);
      expect(tester.widget<TextField>(replyField()).controller!.text, isEmpty);

      await tester.tap(
        find.descendant(
          of: find.byType(GradebookStudentScreen),
          matching: find.descendant(
            of: find.byType(AppBackButton),
            matching: find.byType(InkWell),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rows = tester.widgetList<ProgramStudentRow>(
        find.byType(ProgramStudentRow),
      );
      expect([for (final r in rows) r.pending], [0, 1, 0]);
    });

    testWidgets('a refused reply says why, keeps the text, shows no reply', (
      tester,
    ) async {
      final repo = classRepository()
        ..reviewFailure = const TeacherFailure(
          TeacherFailureKind.rejected,
          code: 'feedback_too_long',
        );
      await openStudent(tester, 'Student A', repository: repo);
      await tester.enterText(replyField(), 'Хариулт');
      await tester.pump();
      await tester.tap(pill(TeacherGradebookStrings.submit));
      await tester.pumpAndSettle();
      expect(
        find.text('Хариулт 5000 тэмдэгтээс хэтэрсэн байна.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(replyField()).controller!.text,
        'Хариулт',
      );
      expect(find.text('Анужин Болд'), findsNothing);

      // Nothing was saved, so the class list still counts it (Issue #392).
      await leaveStudent(tester);
      expect(rosterBadges(tester), [1, 1, 0]);
    });

    testWidgets('a reply the server confirms after the teacher has left the '
        'student still reaches the class list, with no refresh (Issue #392)', (
      tester,
    ) async {
      final repo = classRepository()..reviewGate = Completer<void>();
      await openStudent(tester, 'Student A', repository: repo);
      await tester.enterText(replyField(), 'Сайн ажил.');
      await tester.pump();
      await tester.tap(pill(TeacherGradebookStrings.submit));
      await tester.pump();
      expect(repo.reviewCalls, [(30, 'Сайн ажил.', null)]);

      // Leave while the save is in flight: the screen is disposed.
      await leaveStudent(tester);
      expect(find.byType(GradebookStudentScreen), findsNothing);
      expect(rosterBadges(tester), [1, 1, 0]);
      final reads = (
        repo.studentCalls.length,
        repo.assignmentCalls.length,
        repo.submissionListCalls.length,
      );

      repo.reviewGate!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(rosterBadges(tester), [0, 1, 0]);
      // From the server's answer, not a re-read.
      expect((
        repo.studentCalls.length,
        repo.assignmentCalls.length,
        repo.submissionListCalls.length,
      ), reads);

      // Back on the student, nothing waits for review any more; the saved
      // reply is on its assignment (3).
      await tester.tap(find.text('Student A'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AssignmentSelector));
      await tester.pumpAndSettle();
      expect(
        [
          for (final o in tester.widgetList<AssignmentOption>(
            find.byType(AssignmentOption),
          ))
            o.pending,
        ],
        [0, 0],
      );
      await tester.tap(find.byType(AssignmentOption).last);
      await tester.pumpAndSettle();
      expect(find.text('Сайн ажил.'), findsOneWidget);
      expect(find.text('Анужин Болд'), findsOneWidget);
    });

    testWidgets('a reply refused after the teacher has left changes nothing '
        '(Issue #392)', (tester) async {
      final repo = classRepository()
        ..reviewGate = Completer<void>()
        ..reviewFailure = const TeacherFailure(
          TeacherFailureKind.rejected,
          code: 'invalid_score',
        );
      await openStudent(tester, 'Student A', repository: repo);
      await tester.enterText(replyField(), 'Сайн ажил.');
      await tester.pump();
      await tester.tap(pill(TeacherGradebookStrings.submit));
      await tester.pump();
      await leaveStudent(tester);

      repo.reviewGate!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(rosterBadges(tester), [1, 1, 0]);

      // Still awaiting review on the student's own screen, with no reply.
      await tester.tap(find.text('Student A'));
      await tester.pumpAndSettle();
      expect(find.byType(AssignmentSelector), findsOneWidget);
      expect(
        tester
            .widget<AssignmentSelector>(find.byType(AssignmentSelector))
            .pending,
        1,
      );
      expect(find.text('Сайн ажил.'), findsNothing);
      expect(find.text('Анужин Болд'), findsNothing);
    });

    testWidgets('the edit control puts the saved reply back in the composer', (
      tester,
    ) async {
      await openStudent(tester, 'Student A');
      await tester.tap(find.byType(AssignmentSelector));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AssignmentOption).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(TeacherGradebookStrings.editReply));
      await tester.pump();
      expect(
        tester.widget<TextField>(replyField()).controller!.text,
        'Validation хэсэг дутуу байна.',
      );
    });

    testWidgets('an assignment with a maximum asks for a score, and refuses '
        'one out of range', (tester) async {
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
      await openStudent(tester, 'Student A', repository: repo);
      final score = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == TeacherGradebookStrings.scoreLabel(100),
      );
      expect(score, findsOneWidget);
      await tester.enterText(replyField(), 'Сайн');
      await tester.pump();
      expect(
        tester
            .widget<PillButton>(pill(TeacherGradebookStrings.submit))
            .onPressed,
        isNull,
      );
      await tester.enterText(score, '150');
      await tester.pump();
      expect(
        find.text(TeacherGradebookStrings.scoreInvalid(100)),
        findsOneWidget,
      );
      await tester.enterText(score, '85');
      await tester.pump();
      await tester.tap(pill(TeacherGradebookStrings.submit));
      await tester.pumpAndSettle();
      expect(repo.reviewCalls, [(30, 'Сайн', 85)]);
    });

    testWidgets('a class with no assignments: the student says so, with no '
        'selector, thread or composer', (tester) async {
      final repo = FakeTeacherGradebookRepository(
        classes: [sampleClass()],
        students: {2: roster},
      );
      await openStudent(tester, 'Student A', repository: repo);
      expect(repo.assignmentCalls, [2]);
      expect(find.text(TeacherGradebookStrings.noAssignments), findsOneWidget);
      expect(find.byType(AssignmentSelector), findsNothing);
      expect(replyField(), findsNothing);
      expect(pill(TeacherGradebookStrings.submit), findsNothing);
    });

    testWidgets('a student who submitted nothing: no thread, no composer', (
      tester,
    ) async {
      await openStudent(tester, 'Student C');
      expect(find.text(TeacherGradebookStrings.notSubmitted), findsOneWidget);
      expect(replyField(), findsNothing);
    });
  });

  group('keyboard (Issue #463)', () {
    // An iPhone keyboard over a 393 x 852 screen: the page above it ends
    // at 516.
    const keyboard = 336.0;
    const visibleBottom = 852 - keyboard;
    // `TextField`'s default `scrollPadding`, kept clear around the field.
    const margin = 20.0;

    Finder submit() => pill(TeacherGradebookStrings.submit);
    Finder scoreField() => find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.labelText == TeacherGradebookStrings.scoreLabel(100),
    );

    FakeTeacherGradebookRepository scoredRepository() =>
        classRepository()
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

    Future<void> openKeyboard(
      WidgetTester tester, [
      double height = keyboard,
    ]) async {
      tester.view.viewInsets = FakeViewPadding(bottom: height);
      await tester.pumpAndSettle();
    }

    Future<void> closeKeyboard(WidgetTester tester) async {
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
    }

    Future<void> focus(WidgetTester tester, Finder field) async {
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.tap(field);
      await tester.pump();
    }

    void expectAbove(
      WidgetTester tester,
      Finder finder, {
      double bottom = visibleBottom,
      double clear = margin,
    }) {
      final rect = tester.getRect(finder);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(bottom - clear));
    }

    ScrollPosition thread(WidgetTester tester) => tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(GradebookStudentScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;

    Future<void> openOnPhone(
      WidgetTester tester, {
      FakeTeacherGradebookRepository? repository,
      Size size = const Size(393, 852),
    }) => openStudent(
      tester,
      'Student A',
      repository: repository,
      width: size.width,
      height: size.height,
    );

    testWidgets('the reply field and Submit land together above the '
        'keyboard', (tester) async {
      await openOnPhone(tester);
      await focus(tester, replyField());

      await openKeyboard(tester);

      expectAbove(tester, replyField());
      expectAbove(tester, submit());
    });

    testWidgets('typing within the reply\'s first lines moves nothing; '
        'growing it keeps it and Submit above the keyboard', (tester) async {
      await openOnPhone(tester);
      await focus(tester, replyField());
      await openKeyboard(tester);
      final field = tester.getRect(replyField());
      final button = tester.getRect(submit());

      // Within its four-line minimum: the field does not grow.
      await tester.enterText(replyField(), 'Сайн\nажил\nбайна');
      await tester.pumpAndSettle();
      expect(tester.getRect(replyField()), field);
      expect(tester.getRect(submit()), button);

      // Past it the field grows, to eight lines; both stay revealed.
      await tester.enterText(
        replyField(),
        [for (var i = 1; i <= 8; i++) 'Мөр $i'].join('\n'),
      );
      await tester.pumpAndSettle();
      expectAbove(tester, replyField());
      expectAbove(tester, submit());
    });

    testWidgets('no doubled keyboard padding: open, the thread scrolls no '
        'further than its content; closed, the page is as it was', (
      tester,
    ) async {
      await openOnPhone(tester);
      final viewport = thread(tester).viewportDimension;
      final extent = thread(tester).maxScrollExtent;
      await focus(tester, replyField());

      await openKeyboard(tester);
      final shrunk = viewport - thread(tester).viewportDimension;
      expect(shrunk, keyboard);
      // The content is the same; only the view of it shrank — and the home
      // indicator's inset, under the keyboard now, is no longer padded.
      expect(
        thread(tester).maxScrollExtent,
        lessThanOrEqualTo(extent + shrunk),
      );

      await closeKeyboard(tester);
      expect(thread(tester).viewportDimension, viewport);
      expect(thread(tester).maxScrollExtent, extent);
      expect(
        thread(tester).pixels,
        inInclusiveRange(0, thread(tester).maxScrollExtent),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a score: the score field, its error and Submit stay above '
        'the keyboard, and the review sends', (tester) async {
      final repo = scoredRepository();
      await openOnPhone(tester, repository: repo);
      await tester.enterText(replyField(), 'Сайн');
      await focus(tester, scoreField());
      await openKeyboard(tester);
      expectAbove(tester, scoreField());
      expectAbove(tester, submit());

      await tester.enterText(scoreField(), '150');
      await tester.pumpAndSettle();
      final error = find.text(TeacherGradebookStrings.scoreInvalid(100));
      expectAbove(tester, error, clear: 0);
      expect(tester.widget<PillButton>(submit()).onPressed, isNull);

      await tester.enterText(scoreField(), '85');
      await tester.pumpAndSettle();
      expectAbove(tester, submit());
      await tester.tap(submit());
      await tester.pumpAndSettle();
      expect(repo.reviewCalls, [(30, 'Сайн', 85)]);
    });

    testWidgets('focus moves from the reply to the score: each lands with '
        'Submit', (tester) async {
      await openOnPhone(tester, repository: scoredRepository());
      await focus(tester, replyField());
      await openKeyboard(tester);
      expectAbove(tester, replyField());

      await tester.showKeyboard(scoreField());
      await tester.pumpAndSettle();
      expectAbove(tester, scoreField());
      expectAbove(tester, submit());
    });

    testWidgets('saving: Submit waits, the spinner shows below it, and the '
        'confirmed reply replaces the text', (tester) async {
      final repo = classRepository()..reviewGate = Completer<void>();
      await openOnPhone(tester, repository: repo);
      await focus(tester, replyField());
      await openKeyboard(tester);
      expect(tester.widget<PillButton>(submit()).onPressed, isNull);

      await tester.enterText(replyField(), 'Сайн ажил.');
      await tester.pump();
      await tester.tap(submit());
      await tester.pump();
      final spinner = find.descendant(
        of: find.byType(GradebookStudentScreen),
        matching: find.byType(CircularProgressIndicator),
      );
      expect(spinner, findsOneWidget);
      expect(
        tester.getRect(spinner).top,
        greaterThan(tester.getRect(submit()).bottom),
      );
      expect(tester.widget<PillButton>(submit()).onPressed, isNull);

      repo.reviewGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Сайн ажил.'), findsOneWidget);
      expect(tester.widget<TextField>(replyField()).controller!.text, isEmpty);
    });

    /// The thread list's visible window — under the page header, above the
    /// keyboard.
    Rect threadWindow(WidgetTester tester) => tester.getRect(
      find
          .descendant(
            of: find.byType(GradebookStudentScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    /// [finder] wholly inside [window].
    void expectInside(WidgetTester tester, Finder finder, Rect window) {
      final rect = tester.getRect(finder);
      expect(rect.top, greaterThanOrEqualTo(window.top));
      expect(rect.bottom, lessThanOrEqualTo(window.bottom));
    }

    /// A field's first line, where the caret starts: its text's top, one
    /// line tall.
    Rect caretLine(WidgetTester tester, Finder field) {
      final text = find.descendant(
        of: field,
        matching: find.byType(EditableText),
      );
      final top = tester.getRect(text);
      final line = tester
          .state<EditableTextState>(text)
          .renderEditable
          .preferredLineHeight;
      return Rect.fromLTWH(top.left, top.top, top.width, line);
    }

    testWidgets('an SE-size phone with the predictive bar: the reply and '
        'Submit still land together', (tester) async {
      await openOnPhone(tester, size: const Size(375, 667));
      await focus(tester, replyField());

      await openKeyboard(tester, 260);

      final window = threadWindow(tester);
      expectInside(tester, replyField(), window);
      expectInside(tester, submit(), window);
    });

    testWidgets('too short for the whole reply and Submit: the caret line '
        'and Submit, tight', (tester) async {
      // A 200pt thread window: the reply with its padding and Submit need
      // more; its caret line down to Submit fits.
      await openOnPhone(tester, size: const Size(393, 600));
      await focus(tester, replyField());

      await openKeyboard(tester, 292);

      final window = threadWindow(tester);
      expect(window.height, 200);
      expectInside(tester, submit(), window);
      final line = caretLine(tester, replyField());
      expect(line.top, greaterThanOrEqualTo(window.top));
      expect(line.bottom, lessThanOrEqualTo(window.bottom));
    });

    testWidgets('landscape, too short even for that: the caret line stays '
        'visible', (tester) async {
      // A 105pt thread window under the header: no room for Submit too.
      await openOnPhone(tester, size: const Size(852, 393));
      await focus(tester, replyField());

      await openKeyboard(tester, 180);

      final window = threadWindow(tester);
      final line = caretLine(tester, replyField());
      expect(line.top, greaterThanOrEqualTo(window.top));
      expect(line.bottom, lessThanOrEqualTo(window.bottom));
    });

    testWidgets('the announcement field lifts above the keyboard; its '
        'Submit stays off', (tester) async {
      await openOverview(tester, height: 852);
      await tester.tap(pill(TeacherGradebookStrings.details));
      await tester.pumpAndSettle();
      await tester.tap(find.text(TeacherGradebookStrings.announce));
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(AnnouncementSheet),
        matching: find.byType(TextField),
      );
      final announceSubmit = find.descendant(
        of: find.byType(AnnouncementSheet),
        matching: submit(),
      );
      await tester.tap(field);
      await tester.pump();

      await openKeyboard(tester);
      expectAbove(tester, field, clear: 0);
      expectAbove(tester, announceSubmit, clear: 0);

      await tester.enterText(field, 'Маргааш хичээл 19:00');
      await tester.pumpAndSettle();
      expect(tester.widget<PillButton>(announceSubmit).onPressed, isNull);
    });

    testWidgets('landscape: the announcement\'s caret line stays visible '
        'in the sheet', (tester) async {
      await openOverview(tester, width: 852, height: 393);
      await tester.tap(pill(TeacherGradebookStrings.details));
      await tester.pumpAndSettle();
      await tester.tap(find.text(TeacherGradebookStrings.announce));
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(AnnouncementSheet),
        matching: find.byType(TextField),
      );
      await tester.tap(field);
      await tester.pump();

      await openKeyboard(tester, 180);

      // The sheet's own scroll window, above the keyboard. The field, its
      // note and Submit need more than it has: the caret line wins.
      final window = tester.getRect(
        find
            .descendant(
              of: find.byType(AnnouncementSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(window.bottom, lessThanOrEqualTo(213));
      final line = caretLine(tester, field);
      expect(line.top, greaterThanOrEqualTo(window.top));
      expect(line.bottom, lessThanOrEqualTo(window.bottom));
    });
  });

  group('large text and small screens', () {
    for (final width in [320.0, 393.0]) {
      for (final scale in [1.0, 2.0, 3.0]) {
        testWidgets('${width.toInt()} wide, text ×$scale: cards, sheets, '
            'roster and student without overflow', (tester) async {
          final errors = await pump(
            tester,
            TeacherGradebookScreen(
              repository: classRepository(),
              showBottomNav: false,
            ),
            width: width,
            height: 900,
            scale: scale,
          );
          final previous = FlutterError.onError;
          FlutterError.onError = (details) => errors.add(details.toString());
          try {
            // At ×3 the card's pill sits below the fold — scroll, as a user
            // would.
            await tester.ensureVisible(pill(TeacherGradebookStrings.details));
            await tester.pumpAndSettle();
            await tester.tap(pill(TeacherGradebookStrings.details));
            await tester.pumpAndSettle();
            await tester.ensureVisible(
              find.text(TeacherGradebookStrings.announce),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text(TeacherGradebookStrings.announce));
            await tester.pumpAndSettle();
            await tester.enterText(find.byType(TextField), 'Мэдэгдэл');
            await tester.pumpAndSettle();
            Navigator.of(tester.element(find.byType(AnnouncementSheet))).pop();
            await tester.pumpAndSettle();

            await openStudents(tester);
            await tester.tap(find.text('Student A'));
            await tester.pumpAndSettle();
            await tester.tap(find.byType(AssignmentSelector));
            await tester.pumpAndSettle();
            await tester.tap(find.byType(AssignmentOption).first);
            await tester.pumpAndSettle();
          } finally {
            FlutterError.onError = previous;
          }
          expect(errors, isEmpty);
        });
      }
    }
  });
}
