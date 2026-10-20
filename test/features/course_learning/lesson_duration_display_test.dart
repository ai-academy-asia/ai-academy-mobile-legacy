import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/domain/lesson.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/exercise_video_header.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/lesson_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A lesson with no duration (`duration_seconds: null`, Issue #477) draws
/// no duration — never an empty line or an invented `0:00` — while one with
/// a duration draws it as before.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: child),
      ),
    );
    await tester.pump();
  }

  /// A `Text` drawing nothing — what an empty duration would leave behind.
  Finder emptyText() =>
      find.byWidgetPredicate((w) => w is Text && (w.data ?? '').isEmpty);

  Lesson lesson(String durationLabel) => Lesson(
    id: 1,
    moduleId: 2,
    order: 1,
    title: 'Давталт',
    type: LessonType.video,
    durationLabel: durationLabel,
    completed: false,
    locked: false,
  );

  group('Lesson List row', () {
    testWidgets('draws the duration under the title', (tester) async {
      await pump(tester, LessonListItem(lesson: lesson('24:15')));

      expect(find.text('Давталт'), findsOneWidget);
      expect(find.text('24:15'), findsOneWidget);
    });

    testWidgets('no duration: the title alone, no empty line', (tester) async {
      await pump(tester, LessonListItem(lesson: lesson('')));

      expect(find.text('Давталт'), findsOneWidget);
      expect(emptyText(), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('lesson video header', () {
    testWidgets('draws the duration over the video', (tester) async {
      await pump(
        tester,
        const ExerciseVideoHeader(
          durationLabel: '24:15',
          recordingBadgeLabel: 'Live Classroom Recording',
        ),
      );

      expect(find.text('24:15'), findsOneWidget);
    });

    testWidgets('no duration: the video and its badge, no empty label', (
      tester,
    ) async {
      await pump(
        tester,
        const ExerciseVideoHeader(
          durationLabel: '',
          recordingBadgeLabel: 'Live Classroom Recording',
        ),
      );

      expect(find.text('Live Classroom Recording'), findsOneWidget);
      expect(emptyText(), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
