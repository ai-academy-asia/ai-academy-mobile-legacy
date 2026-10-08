import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_profile_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_shell.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../profile/fake_current_user_repository.dart';
import 'teacher_profile_screen_test.dart' show teacher;

/// A deterministic capture of the Teacher Profile inside `TeacherShell`, for
/// comparing against the supplied Teacher "Profile" frame (Issue #243) —
/// 1179 x 2898, 3x the 393 x 966 frame, so a reference pixel divided by 3 is
/// a point here. The account is test data; the frame's person is not drawn.
///
/// Run `flutter test --update-goldens <this file>` to refresh, then compare
/// `test/goldens/teacher_profile.png` against the reference.
void main() {
  setUpAll(loadAppFonts);

  testWidgets('Teacher Profile at the reference frame', (tester) async {
    useLogicalViewport(tester, const Size(393, 966), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: TeacherShell(
          initialTab: TeacherTab.profile,
          profile: TeacherProfileScreen(
            repository: FakeCurrentUserRepository(user: teacher),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/teacher_profile.png'),
    );
  });
}
