import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/cohorts/domain/cohort.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_class.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_gradebook_repository.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_submission.dart';
import 'package:aia_mobile/features/teacher/presentation/gradebook_class_controller.dart';
import 'package:aia_mobile/features/teacher/presentation/gradebook_class_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/gradebook_student_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_gradebook_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_gradebook_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/program_widgets.dart';
import 'package:aia_mobile/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../cohorts/fake_cohort_repository.dart' show sampleCohort;
import 'fake_teacher_gradebook_repository.dart';
import 'teacher_home_screen_test.dart' show sampleClass;

/// Deterministic captures of Teacher Programs (Issue #390) at the frames'
/// 393pt width, for comparing against `Sign in - 33/34/35/40/41`,
/// `Contract(2)` and `Close(1)`. The data mirrors the frames' own figures;
/// the values are test values.
///
/// Run `flutter test --update-goldens <this file>` to refresh the captures,
/// after comparing them against the frames.
void main() {
  setUpAll(loadAppFonts);

  final today = DateTime(2026, 10, 13, 20);
  final junior = TeacherClass(
    cohort: sampleCohort(
      id: 3,
      name: 'Cohort 02',
      course: const CohortCourse(
        id: 9,
        slug: 'ai-bootcamp',
        title: LocalizedText(en: 'AI BootCamp'),
      ),
      enrolledCount: 13,
    ),
    track: 'junior',
  );

  const names = [
    'Болд Батаа',
    'Саруул Батбаатар',
    'Ганчимэг Батбаяр',
    'Доржпалам Сүхбаатар',
    'Анхбаяр Болд',
    'Мөнхцэцэг Батсүх',
    'Сүхбаатар Тэмүүжин',
    'Дэлгэрмаа Содбилэг',
    'Мөнхбат Даваасүрэн',
  ];
  // How many submissions wait for review, per student — the frame's badges.
  const pending = [12, 0, 1, 0, 3, 0, 0, 2, 4];
  final roster = [
    for (final (i, name) in names.indexed) CohortStudent(id: i + 1, name: name),
  ];
  final assignments = [
    for (var n = 1; n <= 12; n++)
      TeacherAssignment(
        id: 100 + n,
        title: const LocalizedText(en: 'Prediction and Probabilities'),
      ),
  ];

  FakeTeacherGradebookRepository repository({bool reviewed = false}) {
    final submissionsOf = <int, List<TeacherSubmission>>{};
    for (final (i, student) in roster.indexed) {
      for (var k = 0; k < pending[i]; k++) {
        final assignment = assignments[k];
        (submissionsOf[assignment.id] ??= []).add(
          TeacherSubmission(
            id: 1000 + i * 100 + k,
            status: SubmissionStatus.submitted,
            assignmentId: assignment.id,
            student: SubmissionStudent(id: student.id, name: student.name),
            description:
                '"Good foundation — improve validation accuracy before final '
                'submission. Look into hyperparameter tuning for the XGBoost '
                'model."',
            submittedAt: DateTime(2026, 10, 13, 14, 20),
          ),
        );
      }
    }
    if (reviewed) {
      final first = submissionsOf[assignments.first.id]!;
      first[0] = TeacherSubmission(
        id: first[0].id,
        status: SubmissionStatus.reviewed,
        assignmentId: first[0].assignmentId,
        student: first[0].student,
        description: first[0].description,
        submittedAt: first[0].submittedAt,
        feedback:
            'Lorem ipsum dolor sit amet consectetur. Massa in quisque quis '
            'feugiat sit. Massa sed consequat lectus volutpat mauris leo diam '
            'elit laoreet. Ut vel aliquam nec morbi. Ac tempor amet nunc '
            'nulla.',
        feedbackAt: DateTime(2026, 10, 13, 14, 20),
        mentor: const SubmissionStudent(id: 4, name: 'Анужин Болд'),
      );
    }
    return FakeTeacherGradebookRepository(
      classes: [sampleClass(), junior],
      assignments: {2: assignments},
      submissionsOf: submissionsOf,
      students: {2: roster},
    );
  }

  Future<void> show(WidgetTester tester, Widget home) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: home,
      ),
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);
  }

  Future<void> expectGolden(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../goldens/$name.png'),
  );

  Future<GradebookStudentScreen> student(
    WidgetTester tester,
    FakeTeacherGradebookRepository repo,
  ) async {
    final controller = GradebookClassController(repository: repo, cohortId: 2);
    addTearDown(controller.dispose);
    await tester.runAsync(controller.load);
    return GradebookStudentScreen(
      student: roster.first,
      classController: controller,
      repository: repo,
      clock: () => today,
    );
  }

  testWidgets('Хөтөлбөрүүд (Sign in - 33)', (tester) async {
    await show(tester, TeacherGradebookScreen(repository: repository()));
    await expectGolden(tester, 'teacher_gradebook');
  });

  testWidgets('the class\'s actions (Contract(2))', (tester) async {
    await show(tester, TeacherGradebookScreen(repository: repository()));
    await tester.tap(
      find.widgetWithText(PillButton, TeacherGradebookStrings.details).first,
    );
    await tester.pumpAndSettle();
    await expectGolden(tester, 'teacher_programs_actions');
  });

  testWidgets('the announcement composer (Close(1))', (tester) async {
    await show(tester, TeacherGradebookScreen(repository: repository()));
    await tester.tap(
      find.widgetWithText(PillButton, TeacherGradebookStrings.details).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(TeacherGradebookStrings.announce));
    await tester.pumpAndSettle();
    await expectGolden(tester, 'teacher_programs_announcement');
  });

  testWidgets('the students (Sign in - 34)', (tester) async {
    await show(
      tester,
      GradebookClassScreen(
        teacherClass: sampleClass(),
        repository: repository(),
      ),
    );
    await expectGolden(tester, 'teacher_gradebook_students');
  });

  testWidgets('a student and their note (Sign in - 35)', (tester) async {
    final repo = repository();
    await show(tester, await student(tester, repo));
    await expectGolden(tester, 'teacher_gradebook_student');
  });

  testWidgets('the assignment picker (Sign in - 40)', (tester) async {
    final repo = repository();
    await show(tester, await student(tester, repo));
    await tester.tap(find.byType(AssignmentSelector));
    await tester.pumpAndSettle();
    await expectGolden(tester, 'teacher_programs_assignments');
  });

  testWidgets('a note with the teacher\'s reply (Sign in - 41)', (
    tester,
  ) async {
    final repo = repository(reviewed: true);
    await show(tester, await student(tester, repo));
    // The reviewed assignment is the first; the screen opens on a pending
    // one, so pick it as the teacher would.
    await tester.tap(find.byType(AssignmentSelector));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AssignmentOption).first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
    await expectGolden(tester, 'teacher_programs_reply');
  });
}
