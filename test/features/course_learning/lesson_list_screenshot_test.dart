import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/presentation/lesson_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_course_learning_repository.dart';

/// A deterministic capture of the Lesson List at the Figma level-detail
/// reference's width (Issue #215), for comparing its hero, header and cards
/// against the reference.
///
/// 393 wide at 1:1, with the project's iPhone insets, so a measurement taken
/// off the capture is directly a Flutter dimension. Module 2, as the
/// reference draws: its artwork and accent are the ones Course Detail's
/// second module card shows.
///
/// Run `flutter test --update-goldens <this file>` to refresh the capture,
/// then compare `test/goldens/lesson_list.png` against the reference.
void main() {
  setUpAll(loadAppFonts);

  testWidgets('Lesson List at the reference width', (tester) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: LessonListScreen(
          moduleId: 2,
          moduleOrder: 2,
          moduleTitle: 'Language Model Training',
          repository: FakeCourseLearningRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/lesson_list.png'),
    );
  });
}
