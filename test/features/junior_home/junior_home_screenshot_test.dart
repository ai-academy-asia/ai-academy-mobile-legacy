import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_screen.dart';
import 'package:aia_mobile/features/junior_home/data/sample_junior_learning_map.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_learning_map.dart';
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
        home: JuniorHomeScreen(
          repository: FakeJuniorHomeRepository(),
          // The frame draws its check-in node open.
          clock: () => sampleLessonTime,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/junior_home.png'),
    );
  });

  /// The sample's card and lesson with [states] as its modules (Issue #202).
  JuniorLearningMap withModules(List<JuniorNodeState> states) {
    final sample = sampleJuniorLearningMap();
    return JuniorLearningMap(
      progress: sample.progress,
      certificate: sample.certificate,
      nextLesson: sample.nextLesson,
      nodes: [
        for (final (i, state) in states.indexed)
          JuniorMapNode(id: i + 1, state: state),
      ],
    );
  }

  Future<void> capture(
    WidgetTester tester,
    JuniorLearningMap map,
    DateTime now,
    String golden,
  ) async {
    useLogicalViewport(tester, const Size(393, 1428), padding: iPhonePadding);
    useReducedMotion(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: JuniorHomeScreen(
          repository: FakeJuniorHomeRepository(map: map),
          clock: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/$golden.png'),
    );
  }

  testWidgets('a completed program ends at the certificate (Issue #202)', (
    tester,
  ) async {
    await capture(
      tester,
      withModules(List.filled(3, JuniorNodeState.completed)),
      sampleLessonTime,
      'junior_home_completed',
    );
  });

  testWidgets('outside a lesson the check-in node is grey (Issue #202)', (
    tester,
  ) async {
    await capture(
      tester,
      sampleJuniorLearningMap(),
      DateTime(2026, 10, 6, 12),
      'junior_home_check_in_closed',
    );
  });
}
