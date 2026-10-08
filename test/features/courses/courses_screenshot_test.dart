import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/courses/presentation/course_catalog_screen.dart';
import 'package:aia_mobile/features/courses/presentation/course_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_course_repository.dart';

/// Light-mode captures of the Course catalog and Course detail, taken before
/// any theme migration touches them (Dark Mode Phase 0, Issue #252). Test
/// values, no banner images (they would reach the network). They must stay
/// byte-identical while colours move onto `AppPalette`.
void main() {
  setUpAll(loadAppFonts);

  Future<void> capture(WidgetTester tester, String name) async {
    await precacheImages(tester);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/$name.png'),
    );
  }

  testWidgets('Course catalog', (tester) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: CourseCatalogScreen(
          repository: FakeCourseRepository(
            courses: [
              sampleCourse(id: 1, slug: 'one'),
              sampleCourse(id: 2, slug: 'two', status: 'closed'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'course_catalog');
  });

  testWidgets('Course detail', (tester) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: CourseDetailScreen(
          slug: 'summer-bootcamp',
          repository: FakeCourseRepository(courseDetail: sampleCourse()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'course_detail');
  });
}
