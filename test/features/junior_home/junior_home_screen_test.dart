import 'package:aia_mobile/core/theme/app_colors.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_learning_map.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_strings.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_certificate_card.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_course_progress_card.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_learning_map_view.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_node.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_progress_ring.dart';
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_junior_home_repository.dart';

/// Junior Home against the sample map it ships with.
///
/// Pumped at a real phone viewport rather than the reference frame's full
/// height, so the assertions also prove the screen survives its content being
/// taller than the window — the certificate panel sits well below the fold
/// here and is still in the tree, because the map builds every child rather
/// than lazily.
void main() {
  setUpAll(loadAppFonts);

  Future<void> pumpScreen(
    WidgetTester tester, {
    JuniorLearningMap? map,
    FakeJuniorHomeRepository? repository,
    Size size = const Size(393, 852),
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: JuniorHomeScreen(
          repository: repository ?? FakeJuniorHomeRepository(map: map),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The tiles drawn for one state.
  Iterable<JuniorMapNodeTile> tilesIn(WidgetTester tester, JuniorNodeState s) =>
      tester
          .widgetList<JuniorMapNodeTile>(find.byType(JuniorMapNodeTile))
          .where((tile) => tile.node.state == s);

  testWidgets('renders without overflowing a phone viewport', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(JuniorHomeScreen), findsOneWidget);
    expect(find.byType(JuniorLearningMapView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('course progress card', () {
    testWidgets('shows the course title and the percentage', (tester) async {
      await pumpScreen(tester);

      expect(find.byType(JuniorCourseProgressCard), findsOneWidget);
      expect(find.text('Prediction and Probabilities'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
    });

    testWidgets('the dial is given the map\'s own percentage', (tester) async {
      await pumpScreen(tester);

      final ring = tester.widget<JuniorProgressRing>(
        find.byType(JuniorProgressRing),
      );
      expect(ring.percent, 40);
    });
  });

  group('learning path', () {
    testWidgets('draws all five nodes', (tester) async {
      await pumpScreen(tester);

      expect(find.byType(JuniorMapNodeTile), findsNWidgets(5));
    });

    testWidgets('two completed, one current, two locked', (tester) async {
      await pumpScreen(tester);

      expect(tilesIn(tester, JuniorNodeState.completed).length, 2);
      expect(tilesIn(tester, JuniorNodeState.current).length, 1);
      expect(tilesIn(tester, JuniorNodeState.locked).length, 2);
    });

    testWidgets('each node carries a state label for a screen reader', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.bySemanticsLabel('Lesson 1, completed'), findsOneWidget);
      expect(find.bySemanticsLabel('Lesson 3, current lesson'), findsOneWidget);
      expect(find.bySemanticsLabel('Lesson 5, locked'), findsOneWidget);
    });

    testWidgets('the nodes follow the frame\'s route, not a column', (
      tester,
    ) async {
      await pumpScreen(tester);

      final centres = [
        for (var i = 0; i < 5; i++)
          tester.getCenter(find.byType(JuniorMapNodeTile).at(i)),
      ];
      // Node 2 sits right of node 1, node 4 left of node 3: a straightened
      // list would put all five on one x.
      expect(centres[1].dx, greaterThan(centres[0].dx));
      expect(centres[3].dx, lessThan(centres[2].dx));
      // …and every node is lower than the one before it.
      for (var i = 1; i < centres.length; i++) {
        expect(centres[i].dy, greaterThan(centres[i - 1].dy));
      }
    });
  });

  group('certificate panel', () {
    testWidgets('shows the track, the course and what is earned', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.byType(JuniorCertificateCard), findsOneWidget);
      expect(find.text('Junior'), findsOneWidget);
      expect(find.text('AI BootCamp'), findsOneWidget);
      expect(find.text('Earn a Certificate of completion'), findsOneWidget);
    });
  });

  group('bottom navigation', () {
    testWidgets('draws the three Junior tabs', (tester) async {
      await pumpScreen(tester);

      expect(find.byType(AppBottomNav), findsOneWidget);
      expect(find.text(JuniorHomeStrings.navHome), findsOneWidget);
      expect(find.text(JuniorHomeStrings.navProgress), findsOneWidget);
      expect(find.text(JuniorHomeStrings.navProfile), findsOneWidget);
    });

    testWidgets('Home is the active tab', (tester) async {
      await pumpScreen(tester);

      final nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
      expect(nav.currentIndex, 0);
      expect(nav.items[0].label, JuniorHomeStrings.navHome);

      // And it is *drawn* active: the frame puts the selected tab's icon and
      // label in the brand blue and leaves the other two grey. Asserted on
      // the paint rather than on a semantics flag, because `AppBottomNav`
      // labels each tab with the same string its `Text` already carries, and
      // the two merge into one node.
      Color labelColour(String text) =>
          tester.widget<Text>(find.text(text)).style!.color!;
      expect(labelColour(JuniorHomeStrings.navHome), AppColors.blue);
      expect(labelColour(JuniorHomeStrings.navProgress), isNot(AppColors.blue));
      expect(labelColour(JuniorHomeStrings.navProfile), isNot(AppColors.blue));

      final homeIcon = tester.widget<Icon>(
        find.descendant(
          of: find
              .ancestor(
                of: find.text(JuniorHomeStrings.navHome),
                matching: find.byType(Column),
              )
              .first,
          matching: find.byType(Icon),
        ),
      );
      expect(homeIcon.color, AppColors.blue);
    });
  });

  group('data states', () {
    testWidgets('shows a spinner while the map is loading', (tester) async {
      final repository = FakeJuniorHomeRepository(hold: true);
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: JuniorHomeScreen(repository: repository),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(JuniorLearningMapView), findsNothing);
      // The chrome is there throughout — only the map band waits.
      expect(find.byType(AppBottomNav), findsOneWidget);

      repository.release();
      await tester.pumpAndSettle();
      expect(find.byType(JuniorLearningMapView), findsOneWidget);
    });

    testWidgets('a failure shows that failure\'s copy and a retry', (
      tester,
    ) async {
      final repository = FakeJuniorHomeRepository(
        failure: const CourseLearningFailure(
          CourseLearningFailureKind.notEnrolled,
        ),
      );
      await pumpScreen(tester, repository: repository);

      expect(find.text(JuniorHomeStrings.notEnrolled), findsOneWidget);
      expect(find.text(JuniorHomeStrings.retry), findsOneWidget);
      expect(find.byType(JuniorLearningMapView), findsNothing);

      repository.failure = null;
      await tester.tap(find.text(JuniorHomeStrings.retry));
      await tester.pumpAndSettle();

      expect(repository.calls, 2);
      expect(find.byType(JuniorLearningMapView), findsOneWidget);
      expect(find.text(JuniorHomeStrings.notEnrolled), findsNothing);
    });

    testWidgets('enrolled in nothing shows the empty line, no retry', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        repository: FakeJuniorHomeRepository(empty: true),
      );

      expect(find.text(JuniorHomeStrings.empty), findsOneWidget);
      // Nothing to retry — this is not a failure.
      expect(find.text(JuniorHomeStrings.retry), findsNothing);
      expect(find.byType(JuniorLearningMapView), findsNothing);
    });

    testWidgets('the map is drawn from the repository, not a constant', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        map: const JuniorLearningMap(
          progress: JuniorCourseProgress(
            title: 'Corporate Leaders AI',
            percentComplete: 72,
          ),
          nodes: [JuniorMapNode(id: 9, state: JuniorNodeState.completed)],
          certificate: JuniorCertificate(
            track: 'Junior',
            courseName: 'Corporate Leaders AI',
            description: 'Earn a Certificate of completion',
          ),
        ),
      );

      expect(find.text('Corporate Leaders AI'), findsNWidgets(2));
      expect(find.text('72%'), findsOneWidget);
      // The old hardcoded sample values are gone.
      expect(find.text('40%'), findsNothing);
      expect(find.text('Prediction and Probabilities'), findsNothing);
    });
  });

  group('layout', () {
    testWidgets('keeps the frame\'s proportions on a wider phone', (
      tester,
    ) async {
      await pumpScreen(tester, size: const Size(430, 932));

      // The map is laid out in a 393-wide space and scaled, so a node's
      // centre stays at the same fraction of the width rather than drifting.
      final map = tester.getRect(find.byType(JuniorLearningMapView));
      final node = tester.getCenter(find.byType(JuniorMapNodeTile).first);
      expect((node.dx - map.left) / map.width, closeTo(196.7 / 393, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty map still renders the chrome', (tester) async {
      await pumpScreen(
        tester,
        map: const JuniorLearningMap(
          progress: JuniorCourseProgress(
            title: 'Nothing yet',
            percentComplete: 0,
          ),
          nodes: [],
          certificate: JuniorCertificate(
            track: 'Junior',
            courseName: 'AI BootCamp',
            description: 'Earn a Certificate of completion',
          ),
        ),
      );

      expect(find.byType(JuniorMapNodeTile), findsNothing);
      expect(find.text('0%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
