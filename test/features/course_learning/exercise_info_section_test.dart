import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/domain/course_exercise.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/exercise_info_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_course_learning_repository.dart';

/// The lesson's description, expanded: a section with no title (the backend
/// allows `title: null`, Issue #481) draws its body and bullets with no
/// empty heading; a titled section draws its heading as before.
void main() {
  Future<void> pumpExpanded(
    WidgetTester tester,
    List<CourseExerciseSection> sections,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ExerciseInfoSection(
              exercise: sampleExercise(extraSections: sections),
              expanded: true,
              onToggle: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// A `Text` drawing nothing — what an empty heading would leave behind.
  Finder emptyText() =>
      find.byWidgetPredicate((w) => w is Text && (w.data ?? '').isEmpty);

  testWidgets('an untitled section draws its body and bullets, and no empty '
      'heading', (tester) async {
    await pumpExpanded(tester, const [
      CourseExerciseSection(
        title: '',
        body: 'Гарчиггүй хэсэг',
        bullets: ['Нэг'],
      ),
      CourseExerciseSection(title: 'Хоёр дахь', body: 'Бие'),
    ]);

    expect(find.text('Гарчиггүй хэсэг'), findsOneWidget);
    expect(find.text('•  Нэг'), findsOneWidget);
    expect(find.text('Хоёр дахь'), findsOneWidget);
    expect(find.text('Бие'), findsOneWidget);
    expect(emptyText(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a titled section draws its heading above its body', (
    tester,
  ) async {
    await pumpExpanded(tester, const [
      CourseExerciseSection(title: 'Гарчиг', body: 'Бие'),
    ]);

    final heading = tester.getTopLeft(find.text('Гарчиг'));
    final body = tester.getTopLeft(find.text('Бие'));
    expect(heading.dy, lessThan(body.dy));
  });
}
