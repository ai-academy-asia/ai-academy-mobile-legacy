import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/teacher/presentation/gradebook_class_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/gradebook_student_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/gradebook_submission_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_gradebook_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_teacher_gradebook_repository.dart';
import 'teacher_gradebook_screen_test.dart'
    show assignments, studentRows, submissionsOf;
import 'teacher_home_screen_test.dart' show sampleClass;

/// Deterministic captures of Teacher Gradebook (Issue #233) at the
/// references' 393pt width, for comparing against `dungiin-huudas`,
/// `angiin-students-list`, `student-detail` and `feedback`. Data in the
/// confirmed shapes; the values are test values.
///
/// Run `flutter test --update-goldens <this file>` to refresh the captures.
void main() {
  setUpAll(loadAppFonts);

  final repository = FakeTeacherGradebookRepository(
    classes: [
      sampleClass(),
      sampleClass(id: 3, track: 'junior'),
    ],
    assignments: {2: assignments},
    submissionsOf: submissionsOf,
    submissions: {18: submissionsOf[2]![0]},
  );

  Future<void> capture(WidgetTester tester, Widget home, String name) async {
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
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/$name.png'),
    );
  }

  testWidgets('Gradebook', (tester) async {
    await capture(
      tester,
      TeacherGradebookScreen(repository: repository),
      'teacher_gradebook',
    );
  });

  testWidgets('student list', (tester) async {
    await capture(
      tester,
      GradebookClassScreen(teacherClass: sampleClass(), repository: repository),
      'teacher_gradebook_students',
    );
  });

  testWidgets('student detail', (tester) async {
    await capture(
      tester,
      GradebookStudentScreen(
        courseTitle: 'AI Engineer',
        student: studentRows[1],
        submissions: studentRows,
        repository: repository,
      ),
      'teacher_gradebook_student',
    );
  });

  testWidgets('submission detail', (tester) async {
    await capture(
      tester,
      GradebookSubmissionScreen(
        courseTitle: 'AI Engineer',
        submissionId: 18,
        repository: repository,
      ),
      'teacher_gradebook_submission',
    );
  });
}
