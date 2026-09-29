import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/domain/course_exercise.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_exercise_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_course_learning_repository.dart';

/// Deterministic captures of the Exercise Detail screen, one per state in the
/// Figma reference pack, at the reference frames' own 393pt width.
///
/// The frames are taller than a phone because each one shows its whole scroll
/// body at once; the viewport height per state matches the frame so the
/// capture and the reference can be compared without scrolling either.
void main() {
  setUpAll(loadAppFonts);

  Future<void> pump(
    WidgetTester tester,
    double height, {
    CourseExercise? exercise,
  }) async {
    useLogicalViewport(tester, Size(393, height), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: CourseExerciseDetailScreen(
          moduleId: 2,
          repository: FakeCourseLearningRepository(exercise: exercise),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);
  }

  Future<void> shot(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../goldens/exercise_$name.png'),
  );

  testWidgets('01 initial assignment state', (tester) async {
    await pump(tester, 1088);
    await shot(tester, '01_initial');
  });

  testWidgets('02 expanded description + upload area', (tester) async {
    await pump(
      tester,
      1463,
      exercise: sampleExercise(assignmentAttachment: sampleAttachment()),
    );
    await tester.tap(find.text('Read more'));
    await tester.pumpAndSettle();
    await shot(tester, '02_expanded');
  });

  testWidgets('03 file transfer in progress', (tester) async {
    await pump(
      tester,
      1224,
      exercise: sampleExercise(
        assignmentAttachment: sampleAttachment(),
        quiz: sampleQuiz(),
      ),
    );
    await tester.tap(find.text('Upload File'));
    await tester.pump(const Duration(milliseconds: 400));
    await shot(tester, '03_progress');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('04 no video + empty assignment', (tester) async {
    await pump(
      tester,
      1088,
      exercise: sampleExercise(
        hasVideo: false,
        assignmentAttachment: sampleAttachment(),
        quiz: sampleQuiz(),
      ),
    );
    await shot(tester, '04_no_video');
  });

  /// Drives the attachment from the drop area through to "complete".
  Future<void> attachAndDescribe(WidgetTester tester) async {
    await tester.tap(find.text('Upload File'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Lorem ipsum dolor sit amet consectetur. Lacus molestie mi tempor '
      'morbi scelerisque euismod et. Feugiat auctor est enim proin et '
      'ornare aliquet quam.',
    );
    await tester.pumpAndSettle();
  }

  testWidgets('05 file attached, ready to submit', (tester) async {
    await pump(
      tester,
      1224,
      exercise: sampleExercise(
        assignmentAttachment: sampleAttachment(),
        quiz: sampleQuiz(),
      ),
    );
    await attachAndDescribe(tester);
    await shot(tester, '05_ready');
  });

  testWidgets('06 assignment submitted', (tester) async {
    await pump(
      tester,
      1088,
      exercise: sampleExercise(
        assignmentAttachment: sampleAttachment(),
        assignmentFeedback: const [],
        quiz: sampleQuiz(),
      ),
    );
    await attachAndDescribe(tester);
    await tester.tap(find.text('Submit'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await shot(tester, '06_submitted');
  });

  testWidgets('07 mentor feedback received', (tester) async {
    await pump(
      tester,
      1273,
      exercise: sampleExercise(
        assignmentAttachment: sampleAttachment(),
        quiz: sampleQuiz(),
        // The reference frame's own feedback copy, quotes included, so the
        // capture wraps to the same four lines it does.
        assignmentFeedback: const [
          AssignmentMentorFeedback(
            mentorInitials: 'БП',
            mentorName: 'Б.Пүрэв',
            mentorRole: 'Lead Mentor',
            message:
                '"Good foundation — improve validation accuracy before final '
                'submission. Look into hyperparameter tuning for the XGBoost '
                'model."',
            timestampLabel: 'Today, 14:20',
          ),
        ],
      ),
    );
    await attachAndDescribe(tester);
    await tester.tap(find.text('Submit'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await shot(tester, '07_feedback');
  });

  testWidgets('08 course materials tab', (tester) async {
    await pump(tester, 917);
    await tester.tap(find.text('Course materials'));
    await tester.pumpAndSettle();
    await shot(tester, '08_materials');
  });

  testWidgets('10 note tab, existing note', (tester) async {
    await pump(tester, 1039);
    await tester.tap(find.text('Note'));
    await tester.pumpAndSettle();
    await shot(tester, '10_note');
  });

  testWidgets('11 note tab, editing', (tester) async {
    await pump(tester, 981, exercise: sampleExercise(note: null));
    await tester.tap(find.text('Note'));
    await tester.pumpAndSettle();
    await shot(tester, '11_note_editing');
  });

  testWidgets('12 note tab, edited text', (tester) async {
    await pump(tester, 981, exercise: sampleExercise(note: null));
    await tester.tap(find.text('Note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Lorem ipsum dolor sit amet consectetur. Lacus molestie mi tempor '
      'morbi scelerisque euismod et. Feugiat auctor est enim proin et '
      'ornare aliquet quam.',
    );
    await tester.pumpAndSettle();
    await shot(tester, '12_note_edited');
  });
}
