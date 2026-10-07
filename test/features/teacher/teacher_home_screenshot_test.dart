import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_teacher_home_repository.dart';
import 'teacher_home_screen_test.dart' show sampleClass, tuesday;

/// A deterministic capture of Teacher Home at the `teacher-homepage`
/// reference's 393pt width (Issue #229), two classes as the reference
/// draws them, for comparing against it.
///
/// Run `flutter test --update-goldens <this file>` to refresh the capture.
void main() {
  setUpAll(loadAppFonts);

  testWidgets('Teacher Home at the reference width', (tester) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: TeacherHomeScreen(
          repository: FakeTeacherHomeRepository(
            classes: [sampleClass(), sampleClass(id: 3)],
          ),
          clock: tuesday,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/teacher_home.png'),
    );
  });
}
