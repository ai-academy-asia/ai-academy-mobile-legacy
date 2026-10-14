import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_screen.dart';
import 'package:aia_mobile/features/junior_home/data/sample_junior_learning_map.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_learning_map.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_learning_map_view.dart';
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

  /// The sample's card and lesson with [states] as its lessons (Issues
  /// #202, #410).
  JuniorLearningMap withLessons(List<JuniorNodeState> states) {
    final sample = sampleJuniorLearningMap();
    return JuniorLearningMap(
      progress: sample.progress,
      certificate: sample.certificate,
      nextLesson: sample.nextLesson,
      attendanceRecorded: false,
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
    String golden, {
    Size size = const Size(393, 1428),
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
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
      withLessons(List.filled(3, JuniorNodeState.completed)),
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

  testWidgets('the whole lesson path, down to the certificate and its '
      'clouds — the updated reference\'s full height (Issue #410)', (
    tester,
  ) async {
    // `junior-homepage-u[date.png` is 1179 x 6285 at 3x: 393 x 2095.
    await capture(
      tester,
      sampleJuniorLearningMap(),
      sampleLessonTime,
      'junior_home_lesson_path',
      size: const Size(393, 2095),
    );
  });

  testWidgets('three lessons the server leaves open: the continue lesson '
      'picked out, the other two waiting their turn (Issue #410)', (
    tester,
  ) async {
    final open = withLessons(List.filled(3, JuniorNodeState.open));
    await capture(
      tester,
      JuniorLearningMap(
        progress: open.progress,
        certificate: open.certificate,
        nextLesson: open.nextLesson,
        attendanceRecorded: false,
        // As the repository picks the resume lesson out.
        nodes: withResumeLesson(open.nodes, continueLessonId: 1),
      ),
      DateTime(2026, 10, 6, 12),
      'junior_home_open_lessons',
    );
  });

  testWidgets('a phone at the end of the path: the certificate in front of '
      'the background\'s cloud bank (Issue #410)', (tester) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
    useReducedMotion(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: JuniorHomeScreen(
          repository: FakeJuniorHomeRepository(),
          clock: () => DateTime(2026, 10, 7),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.descendant(
        of: find.byType(JuniorLearningMapView),
        matching: find.byType(Scrollable),
      ),
      const Offset(0, -10000),
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/junior_home_path_end.png'),
    );
  });

  testWidgets('the device report\'s course: seeded progress with gaps — '
      'ticks, the lesson to continue with, and padlocks where lessons wait '
      '(Issue #410)', (tester) async {
    // `jr10.s10` in the backend's summer-kids seed: `·✓✓✓·✓✓·✓··`, every
    // module unlocked, the continue lesson the first gap. See
    // junior_lesson_audit_test.dart.
    const pattern = '·✓✓✓·✓✓·✓··';
    final sample = sampleJuniorLearningMap();
    await capture(
      tester,
      JuniorLearningMap(
        progress: const JuniorCourseProgress(
          title: 'Junior AI Summer Camp 10–14',
          percentComplete: 54,
        ),
        certificate: sample.certificate,
        nextLesson: sample.nextLesson,
        attendanceRecorded: false,
        continueLessonId: 1,
        nodes: withResumeLesson(continueLessonId: 1, [
          for (var i = 0; i < pattern.length; i++)
            JuniorMapNode(
              id: i + 1,
              state: pattern[i] == '✓'
                  ? JuniorNodeState.completed
                  : JuniorNodeState.open,
            ),
        ]),
      ),
      DateTime(2026, 10, 14, 12),
      'junior_home_seeded_gaps',
      size: const Size(393, 2095),
    );
  });
}
