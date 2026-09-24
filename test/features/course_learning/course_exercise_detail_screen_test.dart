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

      await tester.tap(find.text('Submit'));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('No feedback yet'), findsOneWidget);
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
