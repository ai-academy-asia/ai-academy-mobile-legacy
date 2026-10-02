import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_current_user_repository.dart';

/// A deterministic capture of the adult Profile, for comparing against its
/// reference export, `Adults - Profile.png` (1179 wide — 3x the 393 frame —
/// so a reference pixel divided by 3 is a point on this capture).
///
/// Captured at the frame's own 1219 tall, with the name fetch held so the
/// header shows the frame's fallback name.
///
/// Run `flutter test --update-goldens <this file>` to refresh, then compare
/// `test/goldens/profile.png` against the reference.
void main() {
  setUpAll(loadAppFonts);

  testWidgets('Adult Profile at the reference frame', (tester) async {
    useLogicalViewport(tester, const Size(393, 1219), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: ProfileScreen(repository: FakeCurrentUserRepository(hold: true)),
      ),
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/profile.png'),
    );
  });
}
