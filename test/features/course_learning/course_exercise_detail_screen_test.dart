import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_exercise_detail_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_material_card.dart';
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
    FakeCourseLearningRepository repository, {
    int moduleId = 2,
    Size size = const Size(393, 852),
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
                      moduleId: moduleId,
                      repository: repository,
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

  Finder backButton() => find.byIcon(AppIcons.caretLeft);

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

    testWidgets('first submission resolves to Resubmit with mentor feedback', (
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

      expect(find.text('Resubmit'), findsOneWidget);
      expect(find.text('Mentor Feedback'), findsOneWidget);
      expect(find.text('No feedback yet'), findsNothing);
      expect(find.text('Ганбаатар Эрдэнэ'), findsOneWidget);
      expect(
        find.text('Please check the matrix traversal and resubmit.'),
        findsOneWidget,
      );

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.enabled, isTrue);
    });

    testWidgets('resubmitting resolves to the accepted, terminal state', (
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
      await tester.tap(find.text('Resubmit'));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      expect(find.text('Resubmit'), findsNothing);
      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('Nice work — accepted.'), findsOneWidget);

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.enabled, isFalse);
    });

    testWidgets('an exercise with no scripted feedback stays accepted', (
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

      expect(find.text('Submitted'), findsOneWidget);
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

        expect(find.bySemanticsLabel('Download'), findsOneWidget);

        await tester.enterText(find.byType(TextField).at(0), 'https://a.b/c');
        await tester.enterText(find.byType(TextField).at(1), 'My submission.');
        await tester.pump();

        await tester.tap(find.text('Submit'));
        await tester.pump();

        // A disabled Submit ignores the tap — still the editable,
        // not-submitted state.
        expect(find.text('Submitted'), findsNothing);
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

      await tester.tap(find.bySemanticsLabel('Download'));
      await tester.pump(const Duration(milliseconds: 150));

      expect(
        find.bySemanticsLabel('Downloading, tap to cancel'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Downloaded'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Downloading, tap to cancel'));
      await tester.pump();

      expect(find.bySemanticsLabel('Download'), findsOneWidget);
      expect(find.bySemanticsLabel('Downloading, tap to cancel'), findsNothing);
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

        await tester.enterText(find.byType(TextField).at(0), 'https://a.b/c');
        await tester.enterText(find.byType(TextField).at(1), 'My submission.');
        await tester.pump();

        await tester.tap(find.bySemanticsLabel('Download'));
        // Long enough for every simulated tick (10 x 150ms) to fire.
        await tester.pump(const Duration(milliseconds: 1600));

        expect(find.bySemanticsLabel('Downloaded'), findsOneWidget);

        await tester.tap(find.text('Submit'));
        await tester.pump();

        expect(find.text('Submitted'), findsOneWidget);

        // Flush the pending review delay, same reason the other assignment
        // tests do — otherwise a real Timer is still pending at teardown.
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pumpAndSettle();
      },
    );
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

  group('quiz tab', () {
    testWidgets('an exercise with no quiz shows an empty tab', (tester) async {
      final exercise = sampleExercise(quiz: null);
      await pumpScreen(
        tester,
        FakeCourseLearningRepository(exercise: exercise),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quiz'));
      await tester.pumpAndSettle();

      expect(find.text('Start Quiz'), findsNothing);
    });

    testWidgets('shows the intro card, then the questions once started', (
      tester,
    ) async {
      final exercise = sampleExercise(quiz: sampleQuiz(title: 'Loops quiz'));
      await pumpScreen(
        tester,
        FakeCourseLearningRepository(exercise: exercise),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quiz'));
      await tester.pumpAndSettle();

      expect(find.text('Loops quiz'), findsOneWidget);
      expect(find.text('2 questions · ~2 min'), findsOneWidget);
      expect(find.text('Start Quiz'), findsOneWidget);
      expect(find.text('Question 1'), findsNothing);

      await tester.ensureVisible(find.text('Start Quiz'));
      await tester.tap(find.text('Start Quiz'));
      await tester.pumpAndSettle();

      expect(find.text('Question 1'), findsOneWidget);
      expect(find.text('Question 2'), findsOneWidget);
      await tester.ensureVisible(find.text('Submit Quiz'));
      expect(find.text('Submit Quiz'), findsOneWidget);
    });

    testWidgets(
      'Submit Quiz stays disabled until every question has an answer',
      (tester) async {
        final exercise = sampleExercise(quiz: sampleQuiz());
        await pumpScreen(
          tester,
          FakeCourseLearningRepository(exercise: exercise),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Quiz'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Start Quiz'));
        await tester.tap(find.text('Start Quiz'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Right').first);
        await tester.tap(find.text('Right').first);
        await tester.pump();
        await tester.ensureVisible(find.text('Submit Quiz'));
        await tester.tap(find.text('Submit Quiz'));
        await tester.pump();

        // Only one of two questions answered — still on the questions.
        expect(find.text('Question 1'), findsOneWidget);
        expect(find.textContaining('You scored'), findsNothing);
      },
    );

    testWidgets('submitting once every question is answered scores it, '
        'and Retry Quiz clears the answers', (tester) async {
      final exercise = sampleExercise(quiz: sampleQuiz());
      await pumpScreen(
        tester,
        FakeCourseLearningRepository(exercise: exercise),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quiz'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start Quiz'));
      await tester.tap(find.text('Start Quiz'));
      await tester.pumpAndSettle();

      // `sampleQuiz()`'s own correct answers: question 1 → "Right" (index
      // 0), question 2 → "Right" (index 1, labelled second there).
      await tester.ensureVisible(find.text('Right').first);
      await tester.tap(find.text('Right').first);
      await tester.pump();
      await tester.ensureVisible(find.text('Right').last);
      await tester.tap(find.text('Right').last);
      await tester.pump();

      await tester.ensureVisible(find.text('Submit Quiz'));
      await tester.tap(find.text('Submit Quiz'));
      await tester.pumpAndSettle();

      expect(find.text('You scored 2/2'), findsOneWidget);
      expect(find.text('Well done!'), findsOneWidget);
      expect(find.text('Retry Quiz'), findsOneWidget);

      await tester.ensureVisible(find.text('Retry Quiz'));
      await tester.tap(find.text('Retry Quiz'));
      await tester.pumpAndSettle();

      // Back to the questions, nothing pre-selected.
      expect(find.text('Question 1'), findsOneWidget);
      expect(find.textContaining('You scored'), findsNothing);
    });
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
    });
  });
}
