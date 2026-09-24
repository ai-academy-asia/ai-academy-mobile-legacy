import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
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
    FakeCourseLearningRepository repository, {
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
    });
  });
}
