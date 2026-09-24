import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_module_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_module_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

        expect(find.byIcon(AppIcons.check), findsNWidgets(2));
        expect(find.byIcon(Icons.lock_outline), findsNWidgets(3));
      },
    );
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
}
