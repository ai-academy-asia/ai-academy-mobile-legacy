import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_junior_home_repository.dart';

/// A deterministic capture of Junior Home at the Figma frame's own size, for
/// comparing against the reference export.
///
/// 393 x 1428 at 1:1 — the reference frame. At that height the whole map is
/// on screen at once, which is the point: the reference is the full page, not
/// one viewport of it, so a measurement taken off this capture is directly
/// comparable with one taken off the PNG.
///
/// Run `flutter test --update-goldens <this file>` to refresh, then compare
/// `test/goldens/junior_home.png` against the reference.
void main() {
  setUpAll(loadAppFonts);

  testWidgets('Junior Home at the reference frame', (tester) async {
    useLogicalViewport(tester, const Size(393, 1428), padding: iPhonePadding);
    // The still scenery: the reference is a still frame.
    useReducedMotion(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: JuniorHomeScreen(repository: FakeJuniorHomeRepository()),
      ),
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/junior_home.png'),
    );
  });
}
