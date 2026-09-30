import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_exercise_detail_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/lesson_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/lesson_list_item.dart';
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
    int moduleId = 2,
    String moduleTitle = 'Language Model Training',
    Size size = const Size(393, 852),
  }) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = size * 3;
    addTearDown(tester.view.reset);

    // Same "push onto a real stack" harness as
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
                    builder: (_) => LessonListScreen(
                      moduleId: moduleId,
                      moduleTitle: moduleTitle,
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

  group('header', () {
    testWidgets('renders the module title', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      expect(find.text('Language Model Training'), findsOneWidget);
      expect(find.text('LESSONS'), findsOneWidget);
    });
  });

  group('lessons', () {
    testWidgets('renders all three sample lessons, in order', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      expect(find.byType(LessonListItem), findsNWidgets(3));
      expect(find.text('Introduction to loops'), findsOneWidget);
      expect(find.text('Nesting loops'), findsOneWidget);
      expect(find.text('Practice: matrix traversal'), findsOneWidget);
    });

    testWidgets('a locked lesson has no tap target', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      final item = tester.widget<LessonListItem>(
        find.widgetWithText(LessonListItem, 'Practice: matrix traversal'),
      );
      expect(item.lesson.locked, isTrue);
      expect(item.onTap, isNull);
    });

    testWidgets('an unlocked lesson has a tap target', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      final item = tester.widget<LessonListItem>(
        find.widgetWithText(LessonListItem, 'Nesting loops'),
      );
      expect(item.lesson.locked, isFalse);
      expect(item.onTap, isNotNull);
    });
  });

  group('navigation', () {
    testWidgets('tapping an unlocked lesson opens Exercise Detail', (
      tester,
    ) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nesting loops'));
      await tester.pumpAndSettle();

      expect(find.byType(CourseExerciseDetailScreen), findsOneWidget);
    });

    testWidgets('a lesson opens Exercise Detail with its own lesson id', (
      tester,
    ) async {
      final repository = FakeCourseLearningRepository(
        lessons: [
          sampleLesson(id: 204, moduleId: 31, title: 'First'),
          sampleLesson(id: 205, moduleId: 31, order: 3, title: 'Second'),
        ],
      );
      await pumpScreen(tester, repository, moduleId: 31);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();

      // The lesson's id, never the module's — through the same repository.
      final detail = tester.widget<CourseExerciseDetailScreen>(
        find.byType(CourseExerciseDetailScreen),
      );
      expect(detail.lessonId, 205);
      expect(detail.repository, same(repository));
      expect(repository.exerciseCalls, [205]);
    });

    testWidgets('the back button pops the screen', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();
      expect(find.byType(LessonListScreen), findsOneWidget);

      await tester.tap(backButton());
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      expect(find.byType(LessonListScreen), findsNothing);
    });
  });

  group('loading', () {
    testWidgets('shows a spinner while the fetch is in flight', (tester) async {
      final repository = FakeCourseLearningRepository(holdLessons: true);
      await pumpScreen(tester, repository);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repository.releaseLessons();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LessonListItem), findsNWidgets(3));
    });
  });

  group('failure', () {
    testWidgets('shows the failure\'s own copy and a retry, not a crash', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        FakeCourseLearningRepository(
          lessonsFailure: const CourseLearningFailure(
            CourseLearningFailureKind.notFound,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(CourseLearningStrings.notFound), findsOneWidget);
      expect(find.text(CourseLearningStrings.retry), findsOneWidget);
      // The list is gone, not half-drawn under the error.
      expect(find.byType(LessonListItem), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // The back button stays, so the student is never stranded.
      expect(backButton(), findsOneWidget);
    });

    testWidgets('retry re-requests and renders the lessons on success', (
      tester,
    ) async {
      final repository = FakeCourseLearningRepository(
        lessonsFailure: const CourseLearningFailure(
          CourseLearningFailureKind.network,
        ),
      );
      await pumpScreen(tester, repository);
      await tester.pumpAndSettle();
      expect(find.text(CourseLearningStrings.networkError), findsOneWidget);

      repository.lessonsFailure = null;
      await tester.tap(find.text(CourseLearningStrings.retry));
      await tester.pumpAndSettle();

      expect(repository.lessonCalls, [2, 2]);
      expect(find.text(CourseLearningStrings.networkError), findsNothing);
      expect(find.byType(LessonListItem), findsNWidgets(3));
    });
  });

  group('default repository', () {
    testWidgets('is the HTTP one, not the sample', (tester) async {
      // No session is held in a test, so the HTTP repository refuses before
      // sending anything — its session-expired copy is the proof. The sample
      // repository would have drawn three lessons instead.
      await pumpScreen(tester, null);
      await tester.pumpAndSettle();

      expect(find.text(CourseLearningStrings.sessionExpired), findsOneWidget);
      expect(find.byType(LessonListItem), findsNothing);
    });
  });
}
