import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/data/sample_course_learning_repository.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_exercise_detail_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_module_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_module_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_course_learning_repository.dart';

/// Real font metrics, for the same reason the other screen tests load them.
Future<void> _loadFonts() async {
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
}

void main() {
  setUpAll(_loadFonts);

  Future<void> pumpScreen(
    WidgetTester tester,
    FakeCourseLearningRepository repository, {
    String courseSlug = 'how-ai-works',
    Size size = const Size(393, 852),
  }) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = size * 3;
    addTearDown(tester.view.reset);

    // Pushed onto a stack, like the real navigation, so the back button has
    // something real to pop back to — same harness shape as
    // course_detail_screen_test.dart's `pumpDetail`.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CourseModuleListScreen(
                      courseSlug: courseSlug,
                      repository: repository,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
  }

  /// Finds an [SvgPicture] by a fragment of its asset path.
  Finder svgAsset(String fragment) => find.byWidgetPredicate(
    (w) => w is SvgPicture && w.bytesLoader.toString().contains(fragment),
  );

  Finder backButton() => find.byIcon(AppIcons.caretLeft);

  group('hero', () {
    testWidgets('renders the course title and description', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      expect(find.text('How AI works'), findsOneWidget);
      expect(
        find.text(
          'Take a peek under the hood of generative AI and LLMs to understand how they work',
        ),
        findsOneWidget,
      );
    });
  });

  group('progress', () {
    testWidgets('renders the overall percent complete, twice', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      // Once in the hero row, once at the foot of the certification section.
      expect(find.text('30% complete'), findsNWidgets(2));
    });

    testWidgets('renders the Continue learning CTA, twice', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      expect(find.text('Continue learning'), findsNWidgets(2));
    });
  });

  group('modules', () {
    testWidgets('renders all five modules, in order', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      expect(find.byType(CourseModuleCard), findsNWidgets(5));
      expect(find.text('Prediction and Probabilities'), findsOneWidget);
      expect(find.text('Language Model Training'), findsOneWidget);
      expect(find.text('Deep network models'), findsOneWidget);
      expect(find.text('Neurons and Layers'), findsOneWidget);
      expect(find.text('Image Models'), findsOneWidget);
    });

    testWidgets('a completed module shows the completed check, not the lock', (
      tester,
    ) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      final card = tester.widget<CourseModuleCard>(
        find.widgetWithText(CourseModuleCard, 'Prediction and Probabilities'),
      );
      expect(card.module.completed, isTrue);
      expect(card.module.locked, isFalse);
      expect(card.onTap, isNotNull);
    });

    testWidgets(
      'a locked module shows the lock icon, not the completed check',
      (tester) async {
        await pumpScreen(tester, FakeCourseLearningRepository());
        await tester.pumpAndSettle();

        final card = tester.widget<CourseModuleCard>(
          find.widgetWithText(CourseModuleCard, 'Deep network models'),
        );
        expect(card.module.locked, isTrue);
        expect(card.module.completed, isFalse);
        expect(card.onTap, isNull);
      },
    );

    testWidgets(
      'exactly two completed checks and three lock glyphs are drawn',
      (tester) async {
        await pumpScreen(tester, FakeCourseLearningRepository());
        await tester.pumpAndSettle();

        // Both glyphs are the design's own artwork. The completed badge is
        // disc and tick in one asset, not a font glyph on a coloured circle.
        expect(svgAsset('course_detail_completed_check'), findsNWidgets(2));
        expect(svgAsset('course_detail_lock'), findsNWidgets(3));
      },
    );
  });

  group('exercise navigation', () {
    testWidgets('tapping an unlocked module opens Exercise Detail directly', (
      tester,
    ) async {
      // The Figma flow has no Lesson List step between Module List and
      // Exercise Detail.
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Prediction and Probabilities'));
      await tester.pumpAndSettle();

      // Unchanged by the lesson-detail integration: a module card knows no
      // lesson id, so it still opens the sample exercise it always showed —
      // through the sample repository, never the screen's own (HTTP in
      // production), which would be asked for a lesson id that is not one.
      final detail = tester.widget<CourseExerciseDetailScreen>(
        find.byType(CourseExerciseDetailScreen),
      );
      expect(detail.lessonId, SampleCourseLearningRepository.previewLessonId);
      expect(detail.repository, isA<SampleCourseLearningRepository>());
    });

    testWidgets('tapping Continue learning opens Exercise Detail directly', (
      tester,
    ) async {
      final repository = FakeCourseLearningRepository(
        path: samplePath(continueModuleId: 2, continueLessonId: 204),
      );
      await pumpScreen(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue learning').first);
      await tester.pumpAndSettle();

      // The server's `continue.lesson_id`, loaded through the screen's own
      // repository — the real lesson-detail flow.
      final detail = tester.widget<CourseExerciseDetailScreen>(
        find.byType(CourseExerciseDetailScreen),
      );
      expect(detail.lessonId, 204);
      expect(detail.repository, same(repository));
      expect(repository.exerciseCalls, [204]);
    });

    testWidgets('both Continue learning buttons open the same lesson', (
      tester,
    ) async {
      final repository = FakeCourseLearningRepository(
        path: samplePath(continueModuleId: 2, continueLessonId: 204),
      );
      await pumpScreen(tester, repository);
      await tester.pumpAndSettle();

      // The second button sits below the fold at this viewport.
      await tester.ensureVisible(find.text('Continue learning').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue learning').last);
      await tester.pumpAndSettle();

      final detail = tester.widget<CourseExerciseDetailScreen>(
        find.byType(CourseExerciseDetailScreen),
      );
      expect(detail.lessonId, 204);
    });

    testWidgets('opens the server\'s continue target, even a locked one', (
      tester,
    ) async {
      // `continue.module_id` from the API. Module 5 is locked and not
      // completed — no client rule would pick it, which is what makes it
      // proof the server's answer is the one being used.
      await pumpScreen(
        tester,
        FakeCourseLearningRepository(
          path: samplePath(continueModuleId: 5, continueLessonId: 501),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue learning').first);
      await tester.pumpAndSettle();

      final detail = tester.widget<CourseExerciseDetailScreen>(
        find.byType(CourseExerciseDetailScreen),
      );
      expect(detail.lessonId, 501);
    });

    // The contract makes the continue target server-selected, so the screen
    // never substitutes one: with no usable server answer both buttons stay
    // drawn — the layout is unchanged — but open nothing.
    // A lesson id alone is not enough either: it is used only while its
    // module half names a listed module, and never guessed at without one.
    for (final (label, continueModuleId, continueLessonId) in [
      ('continue: null', null, null),
      ('a continue target with no lesson id', 2, null),
      ('a continue target no module matches', 999, 204),
    ]) {
      testWidgets('$label leaves both buttons drawn but inert', (tester) async {
        await pumpScreen(
          tester,
          FakeCourseLearningRepository(
            path: samplePath(
              continueModuleId: continueModuleId,
              continueLessonId: continueLessonId,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Continue learning'), findsNWidgets(2));
        for (var i = 0; i < 2; i++) {
          await tester.tap(find.text('Continue learning').at(i));
          await tester.pumpAndSettle();
        }

        expect(find.byType(CourseExerciseDetailScreen), findsNothing);
      });
    }
  });

  group('failure', () {
    testWidgets('shows the failure\'s own copy and a retry, not a crash', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        FakeCourseLearningRepository(
          failure: const CourseLearningFailure(
            CourseLearningFailureKind.notEnrolled,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(CourseLearningStrings.notEnrolled), findsOneWidget);
      expect(find.text(CourseLearningStrings.retry), findsOneWidget);
      // The page's own content is gone, not half-drawn over an error.
      expect(find.byType(CourseModuleCard), findsNothing);
      expect(find.text('Continue learning'), findsNothing);
    });

    testWidgets('retry re-requests and renders the path on success', (
      tester,
    ) async {
      final repository = FakeCourseLearningRepository(
        failure: const CourseLearningFailure(CourseLearningFailureKind.network),
      );
      await pumpScreen(tester, repository);
      await tester.pumpAndSettle();
      expect(find.text(CourseLearningStrings.networkError), findsOneWidget);

      repository.failure = null;
      await tester.tap(find.text(CourseLearningStrings.retry));
      await tester.pumpAndSettle();

      expect(repository.calls, ['how-ai-works', 'how-ai-works']);
      expect(find.text(CourseLearningStrings.networkError), findsNothing);
      expect(find.byType(CourseModuleCard), findsNWidgets(5));
    });
  });

  group('certification', () {
    testWidgets('renders the certification label and title', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      expect(find.text('CERTIFICATION'), findsOneWidget);
      expect(find.text('Earn a Certificate of completion'), findsOneWidget);
    });

    testWidgets('renders the certificate preview image', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      final images = tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => (image.image as AssetImage).assetName)
          .toList();
      expect(images, contains('assets/images/certificate.png'));
      expect(images, contains('assets/images/certificate_backround.png'));
    });
  });

  group('back navigation', () {
    testWidgets('the back button pops the screen', (tester) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();
      expect(find.byType(CourseModuleListScreen), findsOneWidget);

      await tester.tap(backButton());
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      expect(find.byType(CourseModuleListScreen), findsNothing);
    });

    testWidgets('the full chain: Exercise Detail back returns to Module List, '
        'Module List back returns to the previous screen', (tester) async {
      // The normal flow this screen sits in: previous screen (Home/Cohort
      // List, stood in for here by a plain "open" button) → Module List →
      // Exercise Detail, with neither Course Detail nor Lesson List as an
      // intermediate step.
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Prediction and Probabilities'));
      await tester.pumpAndSettle();
      expect(find.byType(CourseExerciseDetailScreen), findsOneWidget);
      expect(find.byType(CourseModuleListScreen), findsNothing);

      // Exercise Detail's own back control is the video header's arrow, not
      // the caret the Module List uses.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(CourseExerciseDetailScreen), findsNothing);
      expect(find.byType(CourseModuleListScreen), findsOneWidget);

      await tester.tap(find.byIcon(AppIcons.caretLeft));
      await tester.pumpAndSettle();

      expect(find.byType(CourseModuleListScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('loading', () {
    testWidgets('shows a spinner while the fetch is in flight', (tester) async {
      final repository = FakeCourseLearningRepository(hold: true);
      await pumpScreen(tester, repository);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repository.release();
      await tester.pumpAndSettle();
    });
  });

  group('Figma reference geometry', () {
    // Measured off the 393 x 1391 reference frame at 1:1. The screenshot test
    // beside this one captures the whole page at that frame; these pin the
    // handful of values most likely to drift silently.

    testWidgets('module cards are 86 tall, 361 wide, 102 apart', (
      tester,
    ) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      final cards = [
        for (var i = 0; i < 5; i++)
          tester.getRect(find.byType(CourseModuleCard).at(i)),
      ];
      for (final card in cards) {
        expect(card.width, 361);
        expect(card.height, 86);
      }
      // 86 of card and 16 of gap — 4 of which the card's own band fills.
      for (var i = 1; i < cards.length; i++) {
        expect(cards[i].top - cards[i - 1].top, 102);
      }
    });

    testWidgets('the connector runs down the centre of the content', (
      tester,
    ) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      // Four rules, one between each pair of cards — and on the content
      // column's midpoint, not under the icon tile.
      final rules = find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 2 && w.height == 12,
      );
      expect(rules, findsNWidgets(4));

      final card = tester.getRect(find.byType(CourseModuleCard).first);
      for (var i = 0; i < 4; i++) {
        expect(tester.getRect(rules.at(i)).center.dx, card.center.dx);
      }
    });

    testWidgets('the progress bar is 8 tall in the reference colours', (
      tester,
    ) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      // Two of them: the hero's and the certification panel's.
      final bars = find.byType(LinearProgressIndicator);
      expect(bars, findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        final bar = tester.widget<LinearProgressIndicator>(bars.at(i));
        expect(bar.minHeight, 8);
        expect(bar.backgroundColor, const Color(0xFFD6DBE1));
        expect(bar.valueColor!.value, const Color(0xFF2970FF));
        expect(bar.value, closeTo(0.30, 0.001));
      }
    });

    testWidgets('both CTAs are 40 tall and land on the frame\'s x213', (
      tester,
    ) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      final buttons = find.text('Continue learning');
      expect(buttons, findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        final rect = tester.getRect(
          find
              .ancestor(of: buttons.at(i), matching: find.byType(SizedBox))
              .first,
        );
        expect(rect.height, 40);
        // The reference keeps the button's left edge on x213 in both places
        // and lets its width change instead.
        expect(rect.left, closeTo(213, 1));
      }
    });

    testWidgets('a locked module keeps the full 56 tile and dims its title', (
      tester,
    ) async {
      await pumpScreen(tester, FakeCourseLearningRepository());
      await tester.pumpAndSettle();

      expect(svgAsset('course_detail_lock'), findsNWidgets(3));
      final tile = tester.getSize(
        find
            .ancestor(
              of: svgAsset('course_detail_lock').first,
              matching: find.byType(Container),
            )
            .first,
      );
      expect(tile, const Size(56, 56));

      expect(
        tester.widget<Text>(find.text('Deep network models')).style!.color,
        const Color(0xFFB5B5B5),
      );
      expect(
        tester
            .widget<Text>(find.text('Prediction and Probabilities'))
            .style!
            .color,
        const Color(0xFF191919),
      );
    });
  });
}
