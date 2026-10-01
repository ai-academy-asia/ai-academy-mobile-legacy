import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_profile_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../profile/fake_current_user_repository.dart';

/// Deterministic captures of the two junior tab screens, for comparing
/// against their reference exports (each 1179 wide — 3x the 393 frame — so a
/// reference pixel divided by 3 is a point on these captures).
///
/// Junior "Сурлагын явц" is captured 64 taller than its 1286 frame: the real
/// August 2026 needs a sixth row of days, which the frame's drawing — not a
/// real calendar — does without. Junior Profile is captured at its frame's
/// own 1274, with the name fetch held so the header shows the frame's
/// fallback name.
///
/// Run `flutter test --update-goldens <this file>` to refresh, then compare
/// `test/goldens/junior_progress.png` and `test/goldens/junior_profile.png`
/// against the references.
void main() {
  setUpAll(loadAppFonts);

  Future<void> capture(
    WidgetTester tester,
    Widget screen,
    Size size,
    String golden,
  ) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: screen,
      ),
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/$golden'),
    );
  }

  testWidgets('Junior Learning Progress at the reference frame', (
    tester,
  ) async {
    await capture(
      tester,
      const JuniorProgressScreen(),
      const Size(393, 1350),
      'junior_progress.png',
    );
  });

  testWidgets('Junior Profile at the reference frame', (tester) async {
    await capture(
      tester,
      JuniorProfileScreen(repository: FakeCurrentUserRepository(hold: true)),
      const Size(393, 1274),
      'junior_profile.png',
    );
  });
}
