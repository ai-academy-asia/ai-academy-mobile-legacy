import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_module_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_course_learning_repository.dart';

/// A deterministic capture of the Course Learning overview at the Figma
/// reference frame's own size, for comparing against `Course Detail.png`.
///
/// 393 x 1392 at 1:1, the reference frame (whose PNG exports one row short
/// at 1391). At 1:1 the capture's pixels are
/// logical points and a measurement taken off it is directly a Flutter
/// dimension. The frame is tall enough to hold the whole scroll body, which is
/// the point — the reference is the full page, not one viewport of it.
///
/// Run `flutter test --update-goldens <this file>` to refresh the capture, then
/// compare `test/goldens/course_module_list.png` against the reference.
void main() {
  setUpAll(loadAppFonts);

  testWidgets('Course Learning overview at the reference frame', (
    tester,
  ) async {
    useLogicalViewport(tester, const Size(393, 1392), padding: iPhonePadding);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: CourseModuleListScreen(
          courseSlug: 'how-ai-works',
          repository: FakeCourseLearningRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/course_module_list.png'),
    );
  });
}
