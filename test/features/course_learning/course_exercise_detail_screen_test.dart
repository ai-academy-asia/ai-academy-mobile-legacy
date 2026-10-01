import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/core/utils/pick_local_file.dart';
import 'package:aia_mobile/features/course_learning/domain/course_exercise.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/course_learning/domain/lesson.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_exercise_detail_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/assignment_tab.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/assignment_upload_dropzone.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_material_card.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/exercise_submit_button.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/exercise_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_course_learning_repository.dart';

/// Real font metrics, for the same reason the other screen tests load them.
Future<void> _loadFonts() async {
  const families = <String, List<String>>{
    'Manrope': [
      'assets/fonts/Manrope-Regular.ttf',
      'assets/fonts/Manrope-Medium.ttf',
      'assets/fonts/Manrope-SemiBold.ttf',
      'assets/fonts/Manrope-Bold.ttf',
      'assets/fonts/Manrope-ExtraBold.ttf',
    ],
    'Phosphor': ['assets/fonts/Phosphor.ttf'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(_loadFonts);

  Future<void> pumpScreen(
    WidgetTester tester,
    FakeCourseLearningRepository? repository, {
    int lessonId = 2,
    Size size = const Size(393, 852),
    Future<bool> Function(Uri url)? openUrl,
    Future<PickedFile?> Function()? pickFile,
    AssignmentForm? assignmentForm,
  }) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = size * 3;
    addTearDown(tester.view.reset);

    // Pushed onto a stack, like the real navigation, so the back button has
    // something real to pop back to — same harness shape as
    // course_module_list_screen_test.dart's `pumpScreen`.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CourseExerciseDetailScreen(
                      lessonId: lessonId,
                      repository: repository,
                      openUrl: openUrl,
                      pickFile: pickFile,
                      assignmentForm: assignmentForm,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
  }

  Finder backButton() => find.byIcon(Icons.arrow_back);

  group('renders', () {
    testWidgets('the screen renders', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      expect(find.byType(CourseExerciseDetailScreen), findsOneWidget);
    });

    testWidgets('the video header: duration and recording badge', (
      tester,
    ) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      expect(find.text('24:15'), findsOneWidget);
      expect(find.text('Live Classroom Recording'), findsOneWidget);
    });

    testWidgets('the back button', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      expect(backButton(), findsOneWidget);
    });

    testWidgets('the play button', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Play'), findsOneWidget);
    });

    testWidgets('the module caption and title', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      expect(find.text('Modules 2'), findsOneWidget);
      expect(find.text('Nesting loops'), findsOneWidget);
    });
  });

  group('description', () {
    testWidgets('starts collapsed, at 3 lines, with a Read more row', (
      tester,
    ) async {
      final exercise = sampleExercise();
      await pumpScreen(
        tester,
        FakeCourseLearningRepository(exercise: exercise),
      );
      await tester.pumpAndSettle();

      expect(find.text('Read more'), findsOneWidget);
      expect(find.text('Read less'), findsNothing);
      expect(find.text('Pre-training'), findsNothing);

      final text = tester.widget<Text>(find.text(exercise.summary));
      expect(text.maxLines, 3);
    });

    testWidgets('Read more expands: shows the extra section and Read less', (
      tester,
    ) async {
      final exercise = sampleExercise();
      await pumpScreen(
        tester,
        FakeCourseLearningRepository(exercise: exercise),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Read more'));
      await tester.pumpAndSettle();

      expect(find.text('Read less'), findsOneWidget);
      expect(find.text('Read more'), findsNothing);
      expect(find.text('Pre-training'), findsOneWidget);

      final text = tester.widget<Text>(find.text(exercise.summary));
      expect(text.maxLines, isNull);
    });

    testWidgets('Read less collapses back', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Read more'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read less'));
      await tester.pumpAndSettle();

      expect(find.text('Read more'), findsOneWidget);
      expect(find.text('Pre-training'), findsNothing);
    });
  });

  group('assignment tab', () {
    testWidgets('is the tab shown by default', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      expect(find.text('Link оруулна уу'), findsOneWidget);
      expect(find.text('Тайлбар'), findsOneWidget);
      expect(find.text('Энд бичнэ үү...'), findsOneWidget);
    });

    testWidgets('shows the empty Mentor Feedback state', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      expect(find.text('Mentor Feedback'), findsOneWidget);
      expect(find.text('No feedback yet'), findsOneWidget);
    });

    testWidgets('submitting shows the pending state, fields locked', (
      tester,
    ) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'https://a.b/c');
      await tester.enterText(find.byType(TextField).at(1), 'My submission.');
      await tester.pump();

      await tester.tap(find.text('Submit'));
      await tester.pump();

      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('Submit'), findsNothing);
      // Still no feedback while the sample "review" is in flight.
      expect(find.text('No feedback yet'), findsOneWidget);

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.enabled, isFalse);

      // Advance past the pending delay explicitly: nothing animates while
      // it's in flight, so `pumpAndSettle()` alone considers the tree
      // already "settled" and returns before the Future.delayed fires,
      // leaving a real Timer pending at teardown.
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
    });

    testWidgets('submitting shows the success card with mentor feedback', (
      tester,
    ) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'https://a.b/c');
      await tester.enterText(find.byType(TextField).at(1), 'My submission.');
      await tester.pump();

      await tester.tap(find.text('Submit'));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      expect(find.text('Assignment submitted successfully'), findsOneWidget);
      expect(find.text('Resubmit'), findsOneWidget);
      expect(find.text('Mentor Feedback'), findsOneWidget);
      expect(find.text('No feedback yet'), findsNothing);
      expect(find.text('Б.Пүрэв'), findsOneWidget);
      expect(find.text('Lead Mentor'), findsOneWidget);
      expect(
        find.text('Good foundation — improve validation accuracy.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'tapping Resubmit reopens the fields, and resubmitting shows the '
      'next mentor feedback',
      (tester) async {
        await pumpScreen(tester, FakeCourseLearningRepository());
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).at(0), 'https://a.b/c');
        await tester.enterText(find.byType(TextField).at(1), 'My submission.');
        await tester.pump();
        await tester.tap(find.text('Submit'));
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Resubmit'));
        await tester.pumpAndSettle();

        // Fields are back, still holding what was typed before.
        expect(find.text('Assignment submitted successfully'), findsNothing);
        final field = tester.widget<TextField>(find.byType(TextField).first);
        expect(field.enabled, isTrue);

        await tester.tap(find.text('Submit'));
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pumpAndSettle();

        expect(find.text('Assignment submitted successfully'), findsOneWidget);
        expect(find.text('Nice work — accepted.'), findsOneWidget);
      },
    );

    testWidgets('an exercise with no scripted feedback shows no feedback', (
      tester,
    ) async {
      final exercise = sampleExercise(assignmentFeedback: const []);
      await pumpScreen(
        tester,
        FakeCourseLearningRepository(exercise: exercise),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'https://a.b/c');
      await tester.enterText(find.byType(TextField).at(1), 'My submission.');
      await tester.pump();

      await tester.tap(find.text('Submit'));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      expect(find.text('Assignment submitted successfully'), findsOneWidget);
      expect(find.text('No feedback yet'), findsOneWidget);
    });
  });

  group('assignment attachment', () {
    testWidgets(
      'Submit stays disabled until the attachment is downloaded, even '
      'with the fields filled in',
      (tester) async {
        final exercise = sampleExercise(
          assignmentAttachment: sampleAttachment(),
        );
        await pumpScreen(
          tester,
          FakeCourseLearningRepository(exercise: exercise),
        );
        await tester.pumpAndSettle();

        expect(find.text('Upload File'), findsOneWidget);

        // One field only: with an attachment the reference draws the file
        // area in the link row's place, so the description is field 0.
        await tester.enterText(find.byType(TextField).at(0), 'My submission.');
        await tester.pump();

        await tester.tap(find.text('Submit'));
        await tester.pump();

        // A disabled Submit ignores the tap — still the editable,
        // not-submitted state.
        expect(find.text('Assignment submitted successfully'), findsNothing);
        final field = tester.widget<TextField>(find.byType(TextField).first);
        expect(field.enabled, isTrue);
      },
    );

    testWidgets('downloading can be cancelled mid-way, back to idle', (
      tester,
    ) async {
      final exercise = sampleExercise(assignmentAttachment: sampleAttachment());
      await pumpScreen(
        tester,
        FakeCourseLearningRepository(exercise: exercise),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Upload File'));
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('Downloading...'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.bySemanticsLabel('Remove'), findsNothing);

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(find.text('Upload File'), findsOneWidget);
      expect(find.text('Downloading...'), findsNothing);
    });

    testWidgets(
      'completing the download, plus filling the fields, enables Submit',
      (tester) async {
        final exercise = sampleExercise(
          assignmentAttachment: sampleAttachment(),
        );
        await pumpScreen(
          tester,
          FakeCourseLearningRepository(exercise: exercise),
        );
        await tester.pumpAndSettle();

        // One field only: with an attachment the reference draws the file
        // area in the link row's place, so the description is field 0.
        await tester.enterText(find.byType(TextField).at(0), 'My submission.');
        await tester.pump();

        await tester.tap(find.text('Upload File'));
        // Long enough for every simulated tick (10 x 150ms) to fire.
        await tester.pump(const Duration(milliseconds: 1600));

        expect(find.text('Complete'), findsOneWidget);
        expect(find.bySemanticsLabel('Remove'), findsOneWidget);

        await tester.tap(find.text('Submit'));
        await tester.pump();

        // The transient "pending review" state — the terminal success card
        // only shows once the sample delay below resolves.
        expect(find.text('Submitted'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 900));
        await tester.pumpAndSettle();

        expect(find.text('Assignment submitted successfully'), findsOneWidget);
      },
    );

    testWidgets('removing a completed attachment disables Submit again', (
      tester,
    ) async {
      final exercise = sampleExercise(assignmentAttachment: sampleAttachment());
      await pumpScreen(
        tester,
        FakeCourseLearningRepository(exercise: exercise),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'My submission.');
      await tester.pump();

      await tester.tap(find.text('Upload File'));
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.bySemanticsLabel('Remove'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Remove'));
      await tester.pump();

      expect(find.text('Upload File'), findsOneWidget);

      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(find.text('Assignment submitted successfully'), findsNothing);
    });
  });

  group('course materials tab', () {
    testWidgets('tapping the tab shows both material rows', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Course materials'));
      await tester.pumpAndSettle();

      expect(find.byType(CourseMaterialCard), findsNWidgets(2));
      expect(find.text('Course material 1'), findsNWidgets(2));
      expect(find.text('10 MB'), findsOneWidget);
      expect(find.text('12 MB'), findsOneWidget);
    });

    testWidgets('tapping a download button marks only that row downloaded', (
      tester,
    ) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Course materials'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Download'), findsNWidgets(2));
      expect(find.bySemanticsLabel('Downloaded'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Download').first);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Downloaded'), findsOneWidget);
      expect(find.bySemanticsLabel('Download'), findsOneWidget);

      // Already downloaded, so tapping it again does nothing further —
      // there is exactly one checked icon, not a toggle back and forth.
      await tester.tap(find.bySemanticsLabel('Downloaded'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Downloaded'), findsOneWidget);
    });

    testWidgets('the sample asks for no link and opens nothing', (
      tester,
    ) async {
      final repository = FakeCourseLearningRepository();
      final opened = <Uri>[];
      await pumpScreen(
        tester,
        repository,
        openUrl: (url) async {
          opened.add(url);
          return true;
        },
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Course materials'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Download').first);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Downloaded'), findsOneWidget);
      expect(repository.downloadCalls, isEmpty);
      expect(opened, isEmpty);
    });
  });

  group('note tab', () {
    testWidgets('empty state shows the textarea and submit, no note card', (
      tester,
    ) async {
      final exercise = sampleExercise(note: null);
      await pumpScreen(
        tester,
        FakeCourseLearningRepository(exercise: exercise),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Note'));
      await tester.pumpAndSettle();

      expect(find.text('Тайлбар'), findsOneWidget);
      expect(find.text('Энд бичнэ үү...'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
      expect(find.text('Болд Батаа'), findsNothing);
    });

    testWidgets(
      'existing note shows the author, message, timestamp and Засах',
      (tester) async {
        final exercise = sampleExercise();
        await pumpScreen(
          tester,
          FakeCourseLearningRepository(exercise: exercise),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Note'));
        await tester.pumpAndSettle();

        expect(find.text('Болд Батаа'), findsOneWidget);
        expect(find.text('Me'), findsOneWidget);
        expect(find.text('БП'), findsOneWidget);
        expect(find.textContaining('improve validation'), findsOneWidget);
        expect(find.text('Today, 14:20'), findsOneWidget);
        expect(find.text('Засах'), findsOneWidget);
      },
    );

    testWidgets(
      'whitespace-only input leaves Submit disabled — nothing is saved',
      (tester) async {
        final exercise = sampleExercise(note: null);
        await pumpScreen(
          tester,
          FakeCourseLearningRepository(exercise: exercise),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Note'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), '   ');
        await tester.pump();
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        // Still the empty/editable state — a disabled button ignores the
        // tap, so no saved-note card ever appears.
        expect(find.text('Энд бичнэ үү...'), findsOneWidget);
        expect(find.text('Болд Батаа'), findsNothing);
      },
    );

    testWidgets('submitting real content shows the saved note', (tester) async {
      final exercise = sampleExercise(note: null);
      await pumpScreen(
        tester,
        FakeCourseLearningRepository(exercise: exercise),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Note'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'This part is unclear.');
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.text('This part is unclear.'), findsOneWidget);
      expect(find.text('Болд Батаа'), findsOneWidget);
      expect(find.text('Me'), findsOneWidget);
      expect(find.text('БП'), findsOneWidget);
      expect(find.text('Just now'), findsOneWidget);
      expect(find.text('Засах'), findsOneWidget);
      // The textarea and its own Submit are gone — this is the saved state.
      expect(find.text('Энд бичнэ үү...'), findsNothing);
    });

    testWidgets('a saved note survives switching to another tab and back', (
      tester,
    ) async {
      final exercise = sampleExercise(note: null);
      await pumpScreen(
        tester,
        FakeCourseLearningRepository(exercise: exercise),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Note'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Saved once.');
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Assignment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Note'));
      await tester.pumpAndSettle();

      expect(find.text('Saved once.'), findsOneWidget);
      expect(find.text('Засах'), findsOneWidget);
    });

    testWidgets(
      'editing pre-fills the field, and resubmitting updates the message',
      (tester) async {
        final exercise = sampleExercise();
        await pumpScreen(
          tester,
          FakeCourseLearningRepository(exercise: exercise),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Note'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Засах'));
        await tester.pumpAndSettle();

        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, contains('improve validation'));

        await tester.enterText(
          find.byType(TextField),
          'Revised: fixed the validation split.',
        );
        await tester.pump();
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        expect(
          find.text('Revised: fixed the validation split.'),
          findsOneWidget,
        );
        expect(find.text('Just now'), findsOneWidget);
        expect(find.text('Today, 14:20'), findsNothing);
        // Same author identity as before the edit — only the message and
        // timestamp change.
        expect(find.text('Болд Батаа'), findsOneWidget);
        expect(find.text('БП'), findsOneWidget);
      },
    );
  });

  group('quiz preview card', () {
    testWidgets('an exercise with no quiz shows no preview card', (
      tester,
    ) async {
      final exercise = sampleExercise(quiz: null);
      await pumpScreen(
        tester,
        FakeCourseLearningRepository(exercise: exercise),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start quiz'), findsNothing);
    });

    testWidgets('shows the title, question count and Start quiz', (
      tester,
    ) async {
      final exercise = sampleExercise(quiz: sampleQuiz(title: 'Loops quiz'));
      await pumpScreen(
        tester,
        FakeCourseLearningRepository(exercise: exercise),
      );
      await tester.pumpAndSettle();

      expect(find.text('Loops quiz'), findsOneWidget);
      expect(find.text('Total 2 questions'), findsOneWidget);
      await tester.ensureVisible(find.text('Start quiz'));
      expect(find.text('Start quiz'), findsOneWidget);
    });
  });

  group('quiz flow', () {
    testWidgets(
      'the close button pops back to Exercise Detail without a result',
      (tester) async {
        final exercise = sampleExercise(quiz: sampleQuiz());
        await pumpScreen(
          tester,
          FakeCourseLearningRepository(exercise: exercise),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Start quiz'));
        await tester.tap(find.text('Start quiz'));
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel('Close'));
        await tester.pumpAndSettle();

        expect(find.text('Start quiz'), findsOneWidget);
        expect(find.text('Дахин quiz өгөх'), findsNothing);
      },
    );

    testWidgets('answering incorrectly shows the wrong feedback', (
      tester,
    ) async {
      final exercise = sampleExercise(quiz: sampleQuiz());
      await pumpScreen(
        tester,
        FakeCourseLearningRepository(exercise: exercise),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Start quiz'));
      await tester.tap(find.text('Start quiz'));
      await tester.pumpAndSettle();

      expect(find.text('1/2'), findsOneWidget);
      expect(
        find.text('Pick the right answer (first question)'),
        findsOneWidget,
      );

      // `sampleQuiz()`'s question 1: "Wrong" is option B, "Right" (index 0)
      // is correct.
      await tester.tap(find.text('Wrong'));
      await tester.pump();

      expect(find.text('Хариулт буруу байна.'), findsOneWidget);
      expect(find.text("Зөв хариулт нь 'A'."), findsOneWidget);
    });

    testWidgets(
      'completing both questions correctly shows the result, and Дахин '
      'quiz өгөх retakes it',
      (tester) async {
        final exercise = sampleExercise(quiz: sampleQuiz());
        await pumpScreen(
          tester,
          FakeCourseLearningRepository(exercise: exercise),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Start quiz'));
        await tester.tap(find.text('Start quiz'));
        await tester.pumpAndSettle();

        // Question 1: "Right" (index 0) is correct.
        await tester.tap(find.text('Right'));
        await tester.pump();
        expect(find.text('Хариул зөв байна.'), findsOneWidget);

        await tester.tap(find.text('Үргэлжлүүлэх'));
        await tester.pumpAndSettle();

        expect(find.text('2/2'), findsOneWidget);
        expect(
          find.text('Pick the right answer (second question)'),
          findsOneWidget,
        );

        // Question 2: "Right" (index 1) is correct.
        await tester.tap(find.text('Right'));
        await tester.pump();
        expect(find.text('Хариул зөв байна.'), findsOneWidget);

        await tester.tap(find.text('Үргэлжлүүлэх'));
        await tester.pumpAndSettle();

        expect(find.text('Sample result'), findsOneWidget);
        expect(find.text('100%'), findsOneWidget);
        expect(find.text('Та 2 асуултаас 2-д зөв хариуллаа'), findsOneWidget);

        await tester.tap(find.text('Дуусгах'));
        await tester.pumpAndSettle();

        // Back on Exercise Detail, the preview card now shows the result.
        expect(find.text('100%'), findsOneWidget);
        expect(find.text('Дахин quiz өгөх'), findsOneWidget);
      },
    );
  });

  group('navigation', () {
    testWidgets('the back button pops the screen', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();
      expect(find.byType(CourseExerciseDetailScreen), findsOneWidget);

      await tester.tap(backButton());
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      expect(find.byType(CourseExerciseDetailScreen), findsNothing);
    });

    testWidgets(
      'the back button still pops when a real status bar/notch inset is '
      'present, not just at zero inset',
      (tester) async {
        // Reproduces the actual on-device bug a plain `tester.tap` at zero
        // inset cannot: with no simulated notch, the button sat wherever
        // `Positioned(top: 16)` put it and a synthetic tap always reached it
        // — that's why the previous test above passed even though the real
        // app's back button did nothing. A real phone reports a non-zero top
        // view padding for its status bar/notch; simulating that here is
        // what actually exercises `ExerciseVideoHeader`'s safe-area offset.
        const topInset = 47.0; // a typical notched iPhone's status bar.

        await pumpScreen(tester, FakeCourseLearningRepository());
        // `pumpScreen`'s own `addTearDown(tester.view.reset)` already
        // resets this along with physicalSize/devicePixelRatio.
        tester.view.padding = FakeViewPadding(
          top: topInset * tester.view.devicePixelRatio,
        );
        await tester.pumpAndSettle();

        // The button must actually have moved below the inset — otherwise
        // this test would pass for the same wrong reason the old one did.
        expect(tester.getTopLeft(backButton()).dy, greaterThan(topInset));

        await tester.tap(backButton());
        await tester.pumpAndSettle();

        expect(find.text('open'), findsOneWidget);
        expect(find.byType(CourseExerciseDetailScreen), findsNothing);
      },
    );
  });

  group('loading', () {
    testWidgets('shows a spinner while the fetch is in flight', (tester) async {
      final repository = FakeCourseLearningRepository(holdExercise: true);
      await pumpScreen(tester, repository);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repository.releaseExercise();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Nesting loops'), findsWidgets);
    });

    testWidgets('loads the lesson id it was opened with', (tester) async {
      final repository = FakeCourseLearningRepository();
      await pumpScreen(tester, repository, lessonId: 204);
      await tester.pumpAndSettle();

      expect(repository.exerciseCalls, [204]);
    });
  });

  // What `HttpCourseLearningRepository` builds from `GET /me/lessons/{id}`:
  // real content, no simulated writes, no quiz, no canned assignment state.
  group('a lesson loaded from the backend', () {
    FakeCourseLearningRepository backendLesson({
      Object? note = _keepSampleNote,
      LessonType type = LessonType.recording,
      String recordingBadgeLabel = 'Live Classroom Recording',
    }) => FakeCourseLearningRepository(
      exercise: identical(note, _keepSampleNote)
          ? sampleExercise(
              lessonId: 204,
              title: 'Давталт',
              type: type,
              recordingBadgeLabel: recordingBadgeLabel,
              assignmentFeedback: const [],
              simulatesWrites: false,
            )
          : sampleExercise(
              lessonId: 204,
              title: 'Давталт',
              type: type,
              recordingBadgeLabel: recordingBadgeLabel,
              note: note,
              assignmentFeedback: const [],
              simulatesWrites: false,
            ),
    );

    Finder submitButtonLabelled(String label) =>
        find.widgetWithText(ExerciseSubmitButton, label);

    testWidgets('renders the lesson\'s own content', (tester) async {
      await pumpScreen(tester, backendLesson());
      await tester.pumpAndSettle();

      expect(find.text('Давталт'), findsOneWidget);
      expect(find.text('24:15'), findsOneWidget);
      expect(find.text('Live Classroom Recording'), findsOneWidget);
    });

    testWidgets('a lesson type with no badge copy draws no badge', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        backendLesson(type: LessonType.video, recordingBadgeLabel: ''),
      );
      await tester.pumpAndSettle();

      expect(find.text('Live Classroom Recording'), findsNothing);
      // The rest of the header is unchanged.
      expect(find.text('24:15'), findsOneWidget);
      expect(backButton(), findsOneWidget);
    });

    testWidgets('draws no quiz card', (tester) async {
      await pumpScreen(tester, backendLesson());
      await tester.pumpAndSettle();

      expect(find.text(CourseLearningStrings.startQuiz), findsNothing);
    });

    group('assignment state', () {
      FakeCourseLearningRepository withAssignment(
        CourseAssignment? assignment,
      ) => FakeCourseLearningRepository(
        exercise: sampleExercise(
          lessonId: 204,
          title: 'Давталт',
          assignmentFeedback: const [],
          simulatesWrites: false,
          assignment: assignment,
        ),
      );

      AssignmentSubmission submission({AssignmentMentorFeedback? feedback}) =>
          AssignmentSubmission(
            id: 301,
            version: 1,
            status: feedback == null
                ? AssignmentSubmissionStatus.submitted
                : AssignmentSubmissionStatus.reviewed,
            submittedAt: DateTime.utc(2026, 8, 5, 3),
            link: 'https://github.com/student/loops',
            feedback: feedback,
          );

      const review = AssignmentMentorFeedback(
        mentorInitials: 'ДБ',
        mentorName: 'Дорж Бат',
        mentorRole: 'Lead Mentor',
        message: 'Сайн ажил.',
        timestampLabel: 'Today, 14:20',
      );

      Finder linkField() => find.byType(TextField).first;
      Finder descriptionField() => find.byType(TextField).last;

      Future<void> fillAndSubmit(
        WidgetTester tester, {
        String link = 'https://github.com/student/loops',
        String description = '',
      }) async {
        await tester.enterText(linkField(), link);
        await tester.enterText(descriptionField(), description);
        await tester.pump();
        await tester.tap(submitButtonLabelled(CourseLearningStrings.submit));
        await tester.pump();
      }

      testWidgets('nothing submitted: the form is open, Submit waits', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          withAssignment(const CourseAssignment(id: 17)),
          lessonId: 204,
        );
        await tester.pumpAndSettle();

        expect(
          find.text(CourseLearningStrings.assignmentSubmittedSuccess),
          findsNothing,
        );
        final fields = tester.widgetList<ExerciseTextField>(
          find.byType(ExerciseTextField),
        );
        expect(fields, hasLength(2));
        expect(fields.every((field) => field.enabled), isTrue);
        // Nothing typed yet.
        final submit = tester.widget<ExerciseSubmitButton>(
          submitButtonLabelled(CourseLearningStrings.submit),
        );
        expect(submit.onPressed, isNull);
        expect(find.text(CourseLearningStrings.noFeedbackYet), findsOneWidget);
      });

      testWidgets('a link alone enables Submit — the description is optional', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          withAssignment(const CourseAssignment(id: 17)),
          lessonId: 204,
        );
        await tester.pumpAndSettle();

        await tester.enterText(linkField(), 'https://github.com/x');
        await tester.pump();

        final submit = tester.widget<ExerciseSubmitButton>(
          submitButtonLabelled(CourseLearningStrings.submit),
        );
        expect(submit.onPressed, isNotNull);
      });

      testWidgets('Submit sends the link and description to the assignment', (
        tester,
      ) async {
        final repository = withAssignment(const CourseAssignment(id: 17));
        await pumpScreen(tester, repository, lessonId: 204);
        await tester.pumpAndSettle();

        await fillAndSubmit(
          tester,
          link: '  https://github.com/student/loops  ',
          description: 'Давталтын дасгал',
        );
        await tester.pumpAndSettle();

        expect(repository.submitCalls, [
          (17, 'https://github.com/student/loops', 'Давталтын дасгал'),
        ]);
      });

      testWidgets('a blank description is sent as none', (tester) async {
        final repository = withAssignment(const CourseAssignment(id: 17));
        await pumpScreen(tester, repository, lessonId: 204);
        await tester.pumpAndSettle();

        await fillAndSubmit(tester, description: '   ');
        await tester.pumpAndSettle();

        expect(repository.submitCalls, [
          (17, 'https://github.com/student/loops', null),
        ]);
      });

      testWidgets('pending review lasts exactly as long as the request', (
        tester,
      ) async {
        final repository = withAssignment(const CourseAssignment(id: 17))
          ..holdSubmit = true;
        await pumpScreen(tester, repository, lessonId: 204);
        await tester.pumpAndSettle();

        await fillAndSubmit(tester);

        // The existing pending state: fields locked, the button reading
        // "Submitted" and off.
        final pending = tester.widget<ExerciseSubmitButton>(
          submitButtonLabelled(CourseLearningStrings.submitted),
        );
        expect(pending.onPressed, isNull);
        final fields = tester.widgetList<ExerciseTextField>(
          find.byType(ExerciseTextField),
        );
        expect(fields.every((field) => !field.enabled), isTrue);
        // Past the sample's 900 ms, still waiting on the server.
        await tester.pump(const Duration(seconds: 2));
        expect(
          find.text(CourseLearningStrings.assignmentSubmittedSuccess),
          findsNothing,
        );

        repository.releaseSubmit();
        await tester.pumpAndSettle();
        expect(
          find.text(CourseLearningStrings.assignmentSubmittedSuccess),
          findsOneWidget,
        );
        expect(repository.submitCalls, hasLength(1));
      });

      testWidgets('success shows the server\'s submission — No feedback yet', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          withAssignment(const CourseAssignment(id: 17)),
          lessonId: 204,
        );
        await tester.pumpAndSettle();

        await fillAndSubmit(tester);
        await tester.pumpAndSettle();

        expect(
          find.text(CourseLearningStrings.assignmentSubmittedSuccess),
          findsOneWidget,
        );
        expect(find.text(CourseLearningStrings.noFeedbackYet), findsOneWidget);
      });

      testWidgets('success with feedback in the answer shows it', (
        tester,
      ) async {
        final repository = withAssignment(const CourseAssignment(id: 17))
          ..submission = sampleSubmission(feedback: review);
        await pumpScreen(tester, repository, lessonId: 204);
        await tester.pumpAndSettle();

        await fillAndSubmit(tester);
        await tester.pumpAndSettle();

        expect(find.text('Дорж Бат'), findsOneWidget);
        expect(find.textContaining('Сайн ажил.'), findsOneWidget);
        expect(find.text(CourseLearningStrings.noFeedbackYet), findsNothing);
      });

      testWidgets('a validation error keeps the form, the text and shows why', (
        tester,
      ) async {
        final repository = withAssignment(const CourseAssignment(id: 17))
          ..submitFailure = const CourseLearningFailure(
            CourseLearningFailureKind.invalidLink,
          );
        await pumpScreen(tester, repository, lessonId: 204);
        await tester.pumpAndSettle();

        await fillAndSubmit(tester, link: 'not-a-link', description: 'Тайлбар');
        await tester.pumpAndSettle();

        expect(find.text(CourseLearningStrings.invalidLink), findsOneWidget);
        expect(
          find.text(CourseLearningStrings.assignmentSubmittedSuccess),
          findsNothing,
        );
        final link = tester.widget<TextField>(linkField());
        expect(link.controller!.text, 'not-a-link');
        final description = tester.widget<TextField>(descriptionField());
        expect(description.controller!.text, 'Тайлбар');
        final submit = tester.widget<ExerciseSubmitButton>(
          submitButtonLabelled(CourseLearningStrings.submit),
        );
        expect(submit.onPressed, isNotNull);

        // A retry that succeeds clears it.
        repository.submitFailure = null;
        await tester.enterText(linkField(), 'https://github.com/x');
        await tester.pump();
        await tester.tap(submitButtonLabelled(CourseLearningStrings.submit));
        await tester.pumpAndSettle();

        expect(find.text(CourseLearningStrings.invalidLink), findsNothing);
        expect(
          find.text(CourseLearningStrings.assignmentSubmittedSuccess),
          findsOneWidget,
        );
      });

      testWidgets('past_due reads as its own copy, not as locked', (
        tester,
      ) async {
        final repository = withAssignment(const CourseAssignment(id: 17))
          ..submitFailure = const CourseLearningFailure(
            CourseLearningFailureKind.pastDue,
          );
        await pumpScreen(tester, repository, lessonId: 204);
        await tester.pumpAndSettle();

        await fillAndSubmit(tester);
        await tester.pumpAndSettle();

        expect(find.text(CourseLearningStrings.pastDue), findsOneWidget);
        // The lesson stays — this is not the whole-screen locked error.
        expect(find.text(CourseLearningStrings.retry), findsNothing);
        expect(find.text('Давталт'), findsOneWidget);
      });

      testWidgets('a submission opens on the success card', (tester) async {
        await pumpScreen(
          tester,
          withAssignment(CourseAssignment(id: 17, submission: submission())),
          lessonId: 204,
        );
        await tester.pumpAndSettle();

        expect(
          find.text(CourseLearningStrings.assignmentSubmittedSuccess),
          findsOneWidget,
        );
        expect(find.byType(ExerciseTextField), findsNothing);
      });

      testWidgets('Resubmit reopens the form with the latest submission', (
        tester,
      ) async {
        final repository = withAssignment(
          CourseAssignment(id: 17, submission: submission()),
        )..submission = sampleSubmission(id: 302, version: 2);
        await pumpScreen(tester, repository, lessonId: 204);
        await tester.pumpAndSettle();

        await tester.tap(find.text(CourseLearningStrings.resubmit));
        await tester.pumpAndSettle();

        final link = tester.widget<TextField>(linkField());
        expect(link.controller!.text, 'https://github.com/student/loops');
        final fields = tester.widgetList<ExerciseTextField>(
          find.byType(ExerciseTextField),
        );
        expect(fields.every((field) => field.enabled), isTrue);

        // Resubmitting is the same call, to the same assignment.
        await tester.tap(submitButtonLabelled(CourseLearningStrings.submit));
        await tester.pumpAndSettle();

        expect(repository.submitCalls, [
          (17, 'https://github.com/student/loops', null),
        ]);
        expect(
          find.text(CourseLearningStrings.assignmentSubmittedSuccess),
          findsOneWidget,
        );
      });

      testWidgets('a submit in flight survives switching tabs', (tester) async {
        final repository = withAssignment(const CourseAssignment(id: 17))
          ..holdSubmit = true;
        await pumpScreen(tester, repository, lessonId: 204);
        await tester.pumpAndSettle();

        await fillAndSubmit(tester);
        await tester.tap(find.text(CourseLearningStrings.noteTab));
        await tester.pumpAndSettle();
        await tester.tap(find.text(CourseLearningStrings.assignmentTab));
        await tester.pumpAndSettle();

        // Still pending, and a second submit cannot start.
        expect(
          submitButtonLabelled(CourseLearningStrings.submitted),
          findsOneWidget,
        );

        repository.releaseSubmit();
        await tester.pumpAndSettle();
        expect(
          find.text(CourseLearningStrings.assignmentSubmittedSuccess),
          findsOneWidget,
        );
        expect(repository.submitCalls, hasLength(1));
      });

      testWidgets('an unreviewed submission shows No feedback yet', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          withAssignment(CourseAssignment(id: 17, submission: submission())),
          lessonId: 204,
        );
        await tester.pumpAndSettle();

        expect(find.text(CourseLearningStrings.noFeedbackYet), findsOneWidget);
      });

      testWidgets('a reviewed submission shows the mentor\'s real feedback', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          withAssignment(
            CourseAssignment(id: 17, submission: submission(feedback: review)),
          ),
          lessonId: 204,
        );
        await tester.pumpAndSettle();

        expect(find.text('Дорж Бат'), findsOneWidget);
        expect(find.text('ДБ'), findsOneWidget);
        expect(find.text('Lead Mentor'), findsOneWidget);
        expect(find.textContaining('Сайн ажил.'), findsOneWidget);
        expect(find.text('Today, 14:20'), findsOneWidget);
        expect(find.text(CourseLearningStrings.noFeedbackYet), findsNothing);
      });
    });

    group('assignment file', () {
      const picked = PickedFile(name: 'report.pdf', bytes: [1, 2, 3, 4]);

      FakeCourseLearningRepository withAssignment({
        CourseAssignment? assignment = const CourseAssignment(id: 17),
      }) => FakeCourseLearningRepository(
        exercise: sampleExercise(
          lessonId: 204,
          title: 'Давталт',
          assignmentFeedback: const [],
          simulatesWrites: false,
          assignment: assignment,
        ),
        // 1 MB exactly, so the rows read the reference's own "1 MB".
        uploadedFile: sampleUploadedFile(id: 501, sizeBytes: 1048576),
      );

      Finder dropzone() => find.byType(AssignmentUploadDropzone);
      Finder submit() => submitButtonLabelled(CourseLearningStrings.submit);

      // The file form, which no backend assignment selects yet — asked for
      // here so the flow behind it is exercised end to end.
      Future<void> open(
        WidgetTester tester,
        FakeCourseLearningRepository repository, {
        Future<PickedFile?> Function()? pickFile,
        AssignmentForm? form = AssignmentForm.file,
      }) async {
        await pumpScreen(
          tester,
          repository,
          lessonId: 204,
          pickFile: pickFile ?? () async => picked,
          assignmentForm: form,
        );
        await tester.pumpAndSettle();
      }

      Future<void> pickAFile(WidgetTester tester) async {
        await tester.ensureVisible(dropzone());
        await tester.tap(dropzone());
        // Not `pumpAndSettle`: a held upload's indicators never settle.
        await tester.pump();
        await tester.pump();
      }

      testWidgets('a backend assignment draws the link form, no file area', (
        tester,
      ) async {
        var picks = 0;
        await open(
          tester,
          withAssignment(),
          form: null,
          pickFile: () async {
            picks++;
            return picked;
          },
        );

        // BACKEND GAP: nothing says an assignment takes a file, so none
        // draws the file form on its own.
        expect(dropzone(), findsNothing);
        expect(find.byType(ExerciseTextField), findsNWidgets(2));
        expect(
          find.text(CourseLearningStrings.linkPlaceholder),
          findsOneWidget,
        );
        expect(picks, 0);
      });

      testWidgets('the file form draws the file area in the link\'s place', (
        tester,
      ) async {
        await open(tester, withAssignment());

        expect(dropzone(), findsOneWidget);
        expect(find.text(CourseLearningStrings.uploadFile), findsOneWidget);
        // Never both: the description is the only field left.
        expect(find.byType(ExerciseTextField), findsOneWidget);
        expect(find.text(CourseLearningStrings.linkPlaceholder), findsNothing);
        expect(tester.widget<ExerciseSubmitButton>(submit()).onPressed, isNull);
      });

      testWidgets('a lesson with no assignment draws no file area', (
        tester,
      ) async {
        await open(tester, withAssignment(assignment: null));

        expect(dropzone(), findsNothing);
      });

      testWidgets('the sample keeps its own simulated file area', (
        tester,
      ) async {
        var picks = 0;
        final repository = FakeCourseLearningRepository(
          exercise: sampleExercise(assignmentAttachment: sampleAttachment()),
        );
        await pumpScreen(
          tester,
          repository,
          pickFile: () async {
            picks++;
            return picked;
          },
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(dropzone());
        await tester.tap(dropzone());
        await tester.pump(const Duration(seconds: 2));

        expect(picks, 0);
        expect(repository.uploadCalls, isEmpty);
      });

      testWidgets('picking a file uploads it and shows the uploading card', (
        tester,
      ) async {
        final repository = withAssignment()..holdUpload = true;
        await open(tester, repository);

        await pickAFile(tester);

        expect(repository.uploadCalls.single.$1, 'report.pdf');
        expect(repository.uploadCalls.single.$2, [1, 2, 3, 4]);
        // Worded as the upload it is, not the reference's "download".
        expect(find.text('Your upload has started.'), findsOneWidget);
        expect(find.text('Uploading...'), findsOneWidget);
        expect(find.text(CourseLearningStrings.downloadStarted), findsNothing);
        expect(
          find.text(CourseLearningStrings.downloadingAttachment),
          findsNothing,
        );
        expect(find.text(CourseLearningStrings.cancelUpload), findsOneWidget);
        // The picked file's own size — all the progress there is to show.
        expect(find.text('4 B'), findsOneWidget);
        expect(dropzone(), findsNothing);
        // Nothing to send until the upload lands.
        expect(tester.widget<ExerciseSubmitButton>(submit()).onPressed, isNull);

        repository.releaseUpload();
        await tester.pumpAndSettle();
      });

      testWidgets('an uploaded file shows Complete, its size and its type', (
        tester,
      ) async {
        await open(tester, withAssignment());

        await pickAFile(tester);
        await tester.pumpAndSettle();

        expect(
          find.text(CourseLearningStrings.attachmentComplete),
          findsOneWidget,
        );
        expect(find.text('1 MB, PDF'), findsOneWidget);
        expect(dropzone(), findsNothing);
      });

      testWidgets('a file alone enables Submit, and is sent as file_id', (
        tester,
      ) async {
        final repository = withAssignment();
        await open(tester, repository);

        await pickAFile(tester);
        await tester.pumpAndSettle();
        expect(
          tester.widget<ExerciseSubmitButton>(submit()).onPressed,
          isNotNull,
        );

        await tester.enterText(find.byType(TextField).last, 'Тайлбар');
        await tester.pump();
        await tester.ensureVisible(submit());
        await tester.tap(submit());
        await tester.pumpAndSettle();

        expect(repository.submitCalls, [(17, null, 'Тайлбар')]);
        expect(repository.submitFileIds, [501]);
        expect(
          find.text(CourseLearningStrings.assignmentSubmittedSuccess),
          findsOneWidget,
        );
      });

      testWidgets('Resubmit after a file submission starts with no file', (
        tester,
      ) async {
        final repository = withAssignment()
          ..submission = sampleSubmission(link: null);
        await open(tester, repository);
        await pickAFile(tester);
        await tester.pumpAndSettle();
        await tester.ensureVisible(submit());
        await tester.tap(submit());
        await tester.pumpAndSettle();

        await tester.tap(find.text(CourseLearningStrings.resubmit));
        await tester.pumpAndSettle();

        expect(dropzone(), findsOneWidget);
        expect(
          find.text(CourseLearningStrings.attachmentComplete),
          findsNothing,
        );
        expect(tester.widget<ExerciseSubmitButton>(submit()).onPressed, isNull);
      });

      testWidgets('a resubmission in the file form sends no hidden link', (
        tester,
      ) async {
        // The latest submission carried a link; the file form has no field
        // for one, so it must not ride along unseen.
        final repository = withAssignment(
          assignment: CourseAssignment(id: 17, submission: sampleSubmission()),
        );
        await open(tester, repository);

        await tester.tap(find.text(CourseLearningStrings.resubmit));
        await tester.pumpAndSettle();
        await pickAFile(tester);
        await tester.pumpAndSettle();
        await tester.ensureVisible(submit());
        await tester.tap(submit());
        await tester.pumpAndSettle();

        expect(repository.submitCalls, [(17, null, null)]);
        expect(repository.submitFileIds, [501]);
      });

      testWidgets('Remove drops the file and Submit waits again', (
        tester,
      ) async {
        await open(tester, withAssignment());
        await pickAFile(tester);
        await tester.pumpAndSettle();

        await tester.tap(
          find.bySemanticsLabel(CourseLearningStrings.removeAttachment),
        );
        await tester.pumpAndSettle();

        expect(dropzone(), findsOneWidget);
        expect(tester.widget<ExerciseSubmitButton>(submit()).onPressed, isNull);
      });

      testWidgets('Cancel abandons the upload', (tester) async {
        final repository = withAssignment()..holdUpload = true;
        await open(tester, repository);
        await pickAFile(tester);

        await tester.tap(find.text(CourseLearningStrings.cancelUpload));
        await tester.pump();
        expect(dropzone(), findsOneWidget);

        // Its late answer changes nothing.
        repository.releaseUpload();
        await tester.pumpAndSettle();
        expect(dropzone(), findsOneWidget);
        expect(
          find.text(CourseLearningStrings.attachmentComplete),
          findsNothing,
        );
      });

      testWidgets('a refused upload shows why under the area, and can retry', (
        tester,
      ) async {
        final repository = withAssignment()
          ..uploadFailure = const CourseLearningFailure(
            CourseLearningFailureKind.unsupportedFileType,
          );
        await open(tester, repository);

        await pickAFile(tester);
        await tester.pumpAndSettle();

        expect(
          find.text(CourseLearningStrings.unsupportedFileType),
          findsOneWidget,
        );
        expect(dropzone(), findsOneWidget);
        // The lesson stays — this is not the whole-screen error.
        expect(find.text(CourseLearningStrings.retry), findsNothing);

        repository.uploadFailure = null;
        await pickAFile(tester);
        await tester.pumpAndSettle();

        expect(
          find.text(CourseLearningStrings.unsupportedFileType),
          findsNothing,
        );
        expect(
          find.text(CourseLearningStrings.attachmentComplete),
          findsOneWidget,
        );
      });

      testWidgets('dismissing the picker changes nothing', (tester) async {
        final repository = withAssignment();
        await open(tester, repository, pickFile: () async => null);

        await pickAFile(tester);
        await tester.pumpAndSettle();

        expect(repository.uploadCalls, isEmpty);
        expect(dropzone(), findsOneWidget);
        expect(find.text(CourseLearningStrings.unexpectedError), findsNothing);
      });

      testWidgets('an uploaded file survives switching tabs', (tester) async {
        await open(tester, withAssignment());
        await pickAFile(tester);
        await tester.pumpAndSettle();

        await tester.tap(find.text(CourseLearningStrings.noteTab));
        await tester.pumpAndSettle();
        await tester.tap(find.text(CourseLearningStrings.assignmentTab));
        await tester.pumpAndSettle();

        expect(find.text('1 MB, PDF'), findsOneWidget);
        expect(
          tester.widget<ExerciseSubmitButton>(submit()).onPressed,
          isNotNull,
        );
      });

      testWidgets('a refused submission keeps the file for the retry', (
        tester,
      ) async {
        final repository = withAssignment()
          ..submitFailure = const CourseLearningFailure(
            CourseLearningFailureKind.pastDue,
          );
        await open(tester, repository);
        await pickAFile(tester);
        await tester.pumpAndSettle();

        await tester.ensureVisible(submit());
        await tester.tap(submit());
        await tester.pumpAndSettle();

        expect(find.text(CourseLearningStrings.pastDue), findsOneWidget);
        expect(find.text('1 MB, PDF'), findsOneWidget);
      });
    });

    testWidgets('the assignment tab is drawn but cannot submit', (
      tester,
    ) async {
      await pumpScreen(tester, backendLesson());
      await tester.pumpAndSettle();

      final fields = tester.widgetList<ExerciseTextField>(
        find.byType(ExerciseTextField),
      );
      expect(fields, isNotEmpty);
      expect(fields.every((field) => !field.enabled), isTrue);

      final submit = tester.widget<ExerciseSubmitButton>(
        submitButtonLabelled(CourseLearningStrings.submit),
      );
      expect(submit.onPressed, isNull);
      // No canned mentor state either.
      expect(find.text(CourseLearningStrings.noFeedbackYet), findsOneWidget);
    });

    // The note the fake answers a save with — deliberately not the sample
    // student, so a test can tell the server's author from a local one.
    const serverNote = CourseExerciseNote(
      authorInitials: 'СД',
      authorName: 'Сараа Дорж',
      authorLabel: 'Me',
      message: 'Saved on the server.',
      timestampLabel: 'Today, 15:04',
    );

    Future<void> openNoteTab(WidgetTester tester) async {
      await tester.tap(find.text(CourseLearningStrings.noteTab));
      await tester.pumpAndSettle();
    }

    Future<void> typeAndSubmit(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
      await tester.tap(submitButtonLabelled(CourseLearningStrings.submit));
      await tester.pump();
    }

    testWidgets('an existing note can be edited and saved', (tester) async {
      final repository = backendLesson()..savedNote = serverNote;
      await pumpScreen(tester, repository, lessonId: 204);
      await tester.pumpAndSettle();
      await openNoteTab(tester);

      expect(find.text(sampleNote().message), findsOneWidget);
      final edit = tester.widget<ExerciseSubmitButton>(
        submitButtonLabelled(CourseLearningStrings.editNote),
      );
      expect(edit.onPressed, isNotNull);

      await tester.tap(find.text(CourseLearningStrings.editNote));
      await tester.pumpAndSettle();
      await typeAndSubmit(tester, '  Revised note.  ');
      await tester.pumpAndSettle();

      // Trimmed, and keyed by the lesson — then the server's note is shown.
      expect(repository.saveCalls, [(204, 'Revised note.')]);
      expect(find.text('Saved on the server.'), findsOneWidget);
      expect(find.text(sampleNote().message), findsNothing);
    });

    testWidgets('with no note, a first note can be written and saved', (
      tester,
    ) async {
      final repository = backendLesson(note: null)..savedNote = serverNote;
      await pumpScreen(tester, repository, lessonId: 204);
      await tester.pumpAndSettle();
      await openNoteTab(tester);

      final field = tester.widget<ExerciseTextField>(
        find.byType(ExerciseTextField),
      );
      expect(field.enabled, isTrue);

      await typeAndSubmit(tester, 'First note.');
      await tester.pumpAndSettle();

      expect(repository.saveCalls, [(204, 'First note.')]);
      expect(find.byType(ExerciseTextField), findsNothing);
      expect(find.text(CourseLearningStrings.editNote), findsOneWidget);
    });

    testWidgets('the saved card shows the server\'s author and time', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        backendLesson(note: null)..savedNote = serverNote,
      );
      await tester.pumpAndSettle();
      await openNoteTab(tester);

      await typeAndSubmit(tester, 'First note.');
      await tester.pumpAndSettle();

      expect(find.text('Сараа Дорж'), findsOneWidget);
      expect(find.text('СД'), findsOneWidget);
      expect(find.text('Today, 15:04'), findsOneWidget);
      // Not the sample student, and not a local "Just now".
      expect(find.text('Болд Батаа'), findsNothing);
      expect(find.text('Just now'), findsNothing);
    });

    testWidgets('Submit is off while the save is in flight', (tester) async {
      final repository = backendLesson(note: null)
        ..savedNote = serverNote
        ..holdSave = true;
      await pumpScreen(tester, repository);
      await tester.pumpAndSettle();
      await openNoteTab(tester);

      await typeAndSubmit(tester, 'First note.');

      final submit = tester.widget<ExerciseSubmitButton>(
        submitButtonLabelled(CourseLearningStrings.submit),
      );
      expect(submit.onPressed, isNull);
      // A second tap while saving sends nothing more.
      await tester.tap(submitButtonLabelled(CourseLearningStrings.submit));
      await tester.pump();
      expect(repository.saveCalls, hasLength(1));

      repository.releaseSave();
      await tester.pumpAndSettle();
      expect(find.text('Saved on the server.'), findsOneWidget);
    });

    testWidgets('a failed save keeps the typed text and shows why', (
      tester,
    ) async {
      final repository = backendLesson(note: null)
        ..savedNote = serverNote
        ..saveFailure = const CourseLearningFailure(
          CourseLearningFailureKind.contentTooLong,
        );
      await pumpScreen(tester, repository);
      await tester.pumpAndSettle();
      await openNoteTab(tester);

      await typeAndSubmit(tester, 'Too long, says the server.');
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Too long, says the server.');
      expect(
        find.text(CourseLearningStrings.noteContentTooLong),
        findsOneWidget,
      );
      expect(find.text('Saved on the server.'), findsNothing);

      // A retry that succeeds clears the error.
      repository.saveFailure = null;
      await tester.tap(submitButtonLabelled(CourseLearningStrings.submit));
      await tester.pumpAndSettle();

      expect(find.text('Saved on the server.'), findsOneWidget);
      expect(find.text(CourseLearningStrings.noteContentTooLong), findsNothing);
    });

    testWidgets('a network failure reads as its own copy', (tester) async {
      final repository = backendLesson(note: null)
        ..saveFailure = const CourseLearningFailure(
          CourseLearningFailureKind.network,
        );
      await pumpScreen(tester, repository);
      await tester.pumpAndSettle();
      await openNoteTab(tester);

      await typeAndSubmit(tester, 'Offline note.');
      await tester.pumpAndSettle();

      expect(find.text(CourseLearningStrings.networkError), findsOneWidget);
      // The lesson itself stays on screen — only the save failed.
      expect(find.text(CourseLearningStrings.retry), findsNothing);
      expect(find.text('Давталт'), findsOneWidget);
    });

    group('material download', () {
      /// Materials 1 and 2 (`sampleExercise`'s default pair) on a backend
      /// lesson, the tab already open.
      Future<List<Uri>> openMaterials(
        WidgetTester tester,
        FakeCourseLearningRepository repository, {
        bool launches = true,
      }) async {
        final opened = <Uri>[];
        await pumpScreen(
          tester,
          repository,
          lessonId: 204,
          openUrl: (url) async {
            opened.add(url);
            return launches;
          },
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(CourseLearningStrings.courseMaterialsTab));
        await tester.pumpAndSettle();
        return opened;
      }

      testWidgets('fetches the material\'s link and opens it', (tester) async {
        final repository = backendLesson();
        final opened = await openMaterials(tester, repository);

        await tester.tap(find.bySemanticsLabel('Download').last);
        await tester.pumpAndSettle();

        expect(repository.downloadCalls, [2]);
        expect(opened, [sampleDownload(materialId: 2).url]);
        // Only that row is checked.
        expect(find.bySemanticsLabel('Downloaded'), findsOneWidget);
        expect(find.bySemanticsLabel('Download'), findsOneWidget);
      });

      testWidgets('shows a spinner while the link is in flight', (
        tester,
      ) async {
        final repository = backendLesson()..holdDownload = true;
        final opened = await openMaterials(tester, repository);

        await tester.tap(find.bySemanticsLabel('Download').first);
        await tester.pump();

        expect(find.bySemanticsLabel('Downloading'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(CourseMaterialCard).first,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
        // A second tap while in flight asks for nothing more.
        await tester.tap(find.bySemanticsLabel('Downloading'));
        await tester.pump();
        expect(repository.downloadCalls, [1]);
        expect(opened, isEmpty);

        repository.releaseDownload();
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Downloading'), findsNothing);
        expect(find.bySemanticsLabel('Downloaded'), findsOneWidget);
      });

      testWidgets(
        'a failure shows its copy under the row, and can be retried',
        (tester) async {
          final repository = backendLesson()
            ..downloadFailure = const CourseLearningFailure(
              CourseLearningFailureKind.server,
            );
          final opened = await openMaterials(tester, repository);

          await tester.tap(find.bySemanticsLabel('Download').first);
          await tester.pumpAndSettle();

          expect(find.text(CourseLearningStrings.serverError), findsOneWidget);
          expect(find.bySemanticsLabel('Download'), findsNWidgets(2));
          expect(opened, isEmpty);

          repository.downloadFailure = null;
          await tester.tap(find.bySemanticsLabel('Download').first);
          await tester.pumpAndSettle();

          expect(find.text(CourseLearningStrings.serverError), findsNothing);
          expect(find.bySemanticsLabel('Downloaded'), findsOneWidget);
        },
      );

      testWidgets('a 404 reads as the file not being found', (tester) async {
        final repository = backendLesson()
          ..downloadFailure = const CourseLearningFailure(
            CourseLearningFailureKind.notFound,
          );
        await openMaterials(tester, repository);

        await tester.tap(find.bySemanticsLabel('Download').first);
        await tester.pumpAndSettle();

        expect(
          find.text(CourseLearningStrings.materialNotFound),
          findsOneWidget,
        );
      });

      testWidgets('a link the OS will not open is not "downloaded"', (
        tester,
      ) async {
        final repository = backendLesson();
        final opened = await openMaterials(tester, repository, launches: false);

        await tester.tap(find.bySemanticsLabel('Download').first);
        await tester.pumpAndSettle();

        expect(opened, hasLength(1));
        expect(find.bySemanticsLabel('Downloaded'), findsNothing);
        expect(
          find.text(CourseLearningStrings.unexpectedError),
          findsOneWidget,
        );
      });

      testWidgets('an opened material stays checked across a tab switch', (
        tester,
      ) async {
        await openMaterials(tester, backendLesson());

        await tester.tap(find.bySemanticsLabel('Download').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(CourseLearningStrings.noteTab));
        await tester.pumpAndSettle();
        await tester.tap(find.text(CourseLearningStrings.courseMaterialsTab));
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Downloaded'), findsOneWidget);
      });
    });
  });

  group('failure', () {
    testWidgets('shows the failure\'s own copy, a retry and a way back', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        FakeCourseLearningRepository(
          exerciseFailure: const CourseLearningFailure(
            CourseLearningFailureKind.notFound,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(CourseLearningStrings.notFound), findsOneWidget);
      expect(find.text(CourseLearningStrings.retry), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // The video header, which carries the usual back button, is not drawn;
      // the shared one stands in so the student is never stranded.
      expect(find.byIcon(AppIcons.caretLeft), findsOneWidget);

      await tester.tap(find.byIcon(AppIcons.caretLeft));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('409 lesson_locked shows the generic error, not the lesson', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        FakeCourseLearningRepository(
          exerciseFailure: const CourseLearningFailure(
            CourseLearningFailureKind.locked,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(CourseLearningStrings.unexpectedError), findsOneWidget);
      expect(find.text('Nesting loops'), findsNothing);
    });

    testWidgets('retry re-requests and renders the lesson on success', (
      tester,
    ) async {
      final repository = FakeCourseLearningRepository(
        exerciseFailure: const CourseLearningFailure(
          CourseLearningFailureKind.network,
        ),
      );
      await pumpScreen(tester, repository, lessonId: 204);
      await tester.pumpAndSettle();
      expect(find.text(CourseLearningStrings.networkError), findsOneWidget);

      repository.exerciseFailure = null;
      await tester.tap(find.text(CourseLearningStrings.retry));
      await tester.pumpAndSettle();

      expect(repository.exerciseCalls, [204, 204]);
      expect(find.text(CourseLearningStrings.networkError), findsNothing);
      expect(find.text('24:15'), findsOneWidget);
    });
  });

  group('default repository', () {
    testWidgets('is the HTTP one, not the sample', (tester) async {
      // No session is held in a test, so the HTTP repository refuses before
      // sending anything — its session-expired copy is the proof. The sample
      // repository would have drawn the "Nesting loops" exercise instead.
      await pumpScreen(tester, null);
      await tester.pumpAndSettle();

      expect(find.text(CourseLearningStrings.sessionExpired), findsOneWidget);
      expect(find.text('Nesting loops'), findsNothing);
    });
  });
}

/// Distinguishes "use the sample note" from an explicit `note: null`.
const Object _keepSampleNote = Object();
