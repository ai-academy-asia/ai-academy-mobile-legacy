/// Deterministic full-screen captures, for comparing a rendered screen against
/// its Figma reference.
///
/// There is no golden/screenshot infrastructure elsewhere in this repo and no
/// integration-test harness; this is the smallest thing that makes a screen
/// reproducibly capturable, and it deliberately adds no package dependency —
/// `matchesGoldenFile` is part of `flutter_test`.
///
/// Two things make a capture comparable to a Figma export rather than merely
/// stable:
///
///  * **Real font metrics.** Without [loadAppFonts] every glyph renders as
///    Ahem's filled boxes, so nothing about text position or width can be
///    checked. Widget tests elsewhere in this repo load fonts the same way.
///  * **A 1:1 logical viewport.** At `devicePixelRatio: 1` a capture's pixels
///    *are* logical points, so a measurement taken off the PNG is directly a
///    Flutter dimension — no scale factor to divide out and no rounding to
///    argue about.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled Manrope and Phosphor faces so text renders with real
/// metrics instead of Ahem boxes, plus Material's icon font. Call from
/// `setUpAll`.
///
/// Material icons are not in this app's own bundle — they ship with the SDK,
/// and a widget test leaves them unloaded, so any `Icons.*` glyph captures as
/// an empty box. That is a harness artifact rather than anything wrong with
/// the screen, but it makes a screenshot useless for checking a screen that
/// draws one, so the SDK's own copy is loaded when it can be found.
Future<void> loadAppFonts() async {
  const families = <String, List<String>>{
    'Manrope': [
      'assets/fonts/Manrope-Regular.ttf',
      'assets/fonts/Manrope-Medium.ttf',
      'assets/fonts/Manrope-SemiBold.ttf',
      'assets/fonts/Manrope-Bold.ttf',
      'assets/fonts/Manrope-ExtraBold.ttf',
    ],
    'Phosphor': ['assets/fonts/Phosphor.ttf'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
  await _loadMaterialIcons();
}

Future<void> _loadMaterialIcons() async {
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      // `which flutter` is .../flutter/bin/flutter, so the root is two up.
      File(Platform.resolvedExecutable).parent.parent.parent.path;
  final file = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!file.existsSync()) return;
  final bytes = await file.readAsBytes();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
}

/// Sizes [tester]'s window to [size] logical points at 1:1, with [padding] for
/// the device's own status-bar/home-indicator insets, and restores it after the
/// test.
///
/// The insets matter: a screen's absolute positions only line up with a Figma
/// frame's when the frame's own status bar is accounted for. At a zero inset
/// every measurement below the top of the page is off by the status bar's
/// height.
void useLogicalViewport(
  WidgetTester tester,
  Size size, {
  FakeViewPadding padding = FakeViewPadding.zero,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = padding;
  addTearDown(tester.view.reset);
}

/// An iPhone-class inset pair, as the Figma frames for this app are drawn.
const FakeViewPadding iPhonePadding = FakeViewPadding(top: 44, bottom: 34);

/// Turns on the platform's reduce-motion setting for the rest of the test,
/// and restores it after.
///
/// Junior Home's scenery drifts on a ticker that never stops, so a test that
/// waits for the screen to settle (`pumpAndSettle`) or compares it with a
/// still capture has to ask for the still scenery — exactly as a student with
/// Reduce Motion on sees it.
void useReducedMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// Decodes every [Image] currently in the tree, then settles.
///
/// `Image.asset` resolves its bytes asynchronously, and a widget test's clock
/// is fake, so a capture taken straight after `pumpAndSettle` shows empty
/// boxes where the images should be. Decoding has to happen on the real clock,
/// which is what [WidgetTester.runAsync] provides.
Future<void> precacheImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element);
    }
  });
  await tester.pumpAndSettle();
}
