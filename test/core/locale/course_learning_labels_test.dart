import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/l10n.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_module_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_module_card.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_strings.dart';
import 'package:aia_mobile/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/course_learning/fake_course_learning_repository.dart';
import '../../support/screenshot.dart';

/// Issue #525: the Course Learning entry screen's not-enrolled and not-found
/// errors, its empty course and the "continue here" pill, in the selected
/// language. Mongolian reads exactly as before; the design's own English
/// ("Continue learning", "Modules", …) is untouched.
void main() {
  setUpAll(loadAppFonts);
  final locale = AppLocaleController.instance;
  tearDown(() => locale.setPreference(LocalePreference.mongolian));

  const copy = <String, ({String mongolian, String english})>{
    'learningNotEnrolled': (
      mongolian: 'Та энэ хөтөлбөрт бүртгэлгүй байна',
      english: 'You are not enrolled in this program',
    ),
    'learningNotFound': (
      mongolian: 'Хөтөлбөр олдсонгүй',
      english: 'Program not found',
    ),
    'learningLessonsEmpty': (
      mongolian: 'Одоогоор хичээл алга байна',
      english: 'No lessons yet',
    ),
    'learningContinueHere': (
      mongolian: 'Эндээс үргэлжлүүлнэ',
      english: 'Continue here',
    ),
    'commonRetry': (mongolian: 'Дахин оролдох', english: 'Try again.'),
  };

  String text(String key, LocalePreference language) =>
      language == LocalePreference.mongolian
      ? copy[key]!.mongolian
      : copy[key]!.english;

  String en(String key) => text(key, LocalePreference.english);
  String mn(String key) => text(key, LocalePreference.mongolian);

  group('the keys', () {
    for (final language in LocalePreference.values) {
      test(language.name, () {
        final s = L10n.of(language);
        expect(
          {
            'learningNotEnrolled': s.learningNotEnrolled,
            'learningNotFound': s.learningNotFound,
            'learningLessonsEmpty': s.learningLessonsEmpty,
            'learningContinueHere': s.learningContinueHere,
            'commonRetry': s.commonRetry,
          },
          {for (final key in copy.keys) key: text(key, language)},
        );
      });
    }

    for (final language in LocalePreference.values) {
      test('CourseLearningStrings in ${language.name}', () async {
        await locale.setPreference(language);
        expect(
          CourseLearningStrings.notEnrolled,
          text('learningNotEnrolled', language),
        );
        expect(
          CourseLearningStrings.notFound,
          text('learningNotFound', language),
        );
        expect(
          CourseLearningStrings.lessonsEmpty,
          text('learningLessonsEmpty', language),
        );
        expect(
          CourseLearningStrings.continueHere,
          text('learningContinueHere', language),
        );
        expect(CourseLearningStrings.retry, text('commonRetry', language));
      });

      test(
        'the 403 and 404 read as Junior Home\'s, in ${language.name}',
        () async {
          await locale.setPreference(language);
          for (final kind in [
            CourseLearningFailureKind.notEnrolled,
            CourseLearningFailureKind.notFound,
          ]) {
            expect(
              CourseLearningStrings.messageFor(kind),
              JuniorHomeStrings.messageFor(kind),
              reason: kind.name,
            );
          }
          expect(
            CourseLearningStrings.messageFor(
              CourseLearningFailureKind.notEnrolled,
            ),
            text('learningNotEnrolled', language),
          );
          expect(
            CourseLearningStrings.messageFor(
              CourseLearningFailureKind.notFound,
            ),
            text('learningNotFound', language),
          );
        },
      );
    }
  });

  /// The module list over a stand-in screen, as the app pushes it, under the
  /// language rebuild scope.
  Future<void> pumpScreen(
    WidgetTester tester,
    FakeCourseLearningRepository repository, {
    Size size = const Size(393, 852),
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    // A fresh tree: nothing carried over from an earlier pump.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      L10nRebuildScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: Text('home')),
        ),
      ),
    );
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) => CourseModuleListScreen(
              courseSlug: 'how-ai-works',
              repository: repository,
            ),
          ),
        );
    await tester.pumpAndSettle();
  }

  /// Module 2's three lessons — completed, the one to continue with, and
  /// locked — as `course_module_card_large_text_test.dart` lays them out.
  FakeCourseLearningRepository withContinueLesson() =>
      FakeCourseLearningRepository(
        path: samplePath(continueModuleId: 2, continueLessonId: 2),
        lessons: const [],
        lessonsByModule: {2: sampleLessons()},
      );

  FakeCourseLearningRepository failing(CourseLearningFailureKind kind) =>
      FakeCourseLearningRepository(failure: CourseLearningFailure(kind));

  Finder retryButton(String label) => find.widgetWithText(AppButton, label);

  group('in English', () {
    setUp(() => locale.setEnglish(true));

    for (final (kind, key) in [
      (CourseLearningFailureKind.notEnrolled, 'learningNotEnrolled'),
      (CourseLearningFailureKind.notFound, 'learningNotFound'),
    ]) {
      testWidgets('a ${kind.name} load reads "${en(key)}" with Try again., '
          'which loads again', (tester) async {
        final repository = failing(kind);
        await pumpScreen(tester, repository);

        expect(find.text(en(key)), findsOneWidget);
        expect(find.text(mn(key)), findsNothing);
        expect(retryButton(en('commonRetry')), findsOneWidget);
        expect(find.text(mn('commonRetry')), findsNothing);
        expect(find.byType(CourseLessonCard), findsNothing);

        final calls = repository.calls.length;
        repository.failure = null;
        await tester.tap(retryButton(en('commonRetry')));
        await tester.pumpAndSettle();

        expect(repository.calls.length, calls + 1);
        expect(find.text(en(key)), findsNothing);
        expect(find.byType(CourseLessonCard), findsWidgets);
      });
    }

    testWidgets('a course with no lessons says "No lessons yet"', (
      tester,
    ) async {
      await pumpScreen(tester, FakeCourseLearningRepository(lessons: const []));

      expect(find.byType(CourseLessonCard), findsNothing);
      expect(find.text(en('learningLessonsEmpty')), findsOneWidget);
      expect(find.text(mn('learningLessonsEmpty')), findsNothing);
    });

    testWidgets('only the lesson to continue with carries "Continue here"', (
      tester,
    ) async {
      await pumpScreen(tester, withContinueLesson());

      final cards = tester
          .widgetList<CourseLessonCard>(find.byType(CourseLessonCard))
          .toList();
      expect(cards.where((c) => c.current), hasLength(1));
      expect(find.text(en('learningContinueHere')), findsOneWidget);
      expect(find.text(mn('learningContinueHere')), findsNothing);
      for (final card in cards) {
        expect(
          find.descendant(
            of: find.byWidget(card),
            matching: find.text(en('learningContinueHere')),
          ),
          card.current ? findsOneWidget : findsNothing,
          reason: card.entry.lesson.title,
        );
      }
      // The design's own English beside it is unchanged.
      expect(find.text(CourseLearningStrings.continueLearning), findsWidgets);
    });
  });

  testWidgets('switching language on a loaded module list: the pill changes, '
      'the screen keeps its state and scroll, and nothing is fetched again', (
    tester,
  ) async {
    final repository = withContinueLesson();
    await pumpScreen(tester, repository);
    expect(find.text(mn('learningContinueHere')), findsOneWidget);

    final state = tester.state(find.byType(CourseModuleListScreen));
    final scrollable = find
        .descendant(
          of: find.byType(CourseModuleListScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    final offset = tester.state<ScrollableState>(scrollable).position.pixels;
    final pathCalls = repository.calls.length;
    final lessonCalls = repository.lessonCalls.length;

    await locale.setEnglish(true);
    await tester.pump();

    expect(find.text(en('learningContinueHere')), findsOneWidget);
    expect(find.text(mn('learningContinueHere')), findsNothing);
    expect(tester.state(find.byType(CourseModuleListScreen)), same(state));
    expect(tester.state<ScrollableState>(scrollable).position.pixels, offset);
    expect(repository.calls.length, pathCalls);
    expect(repository.lessonCalls.length, lessonCalls);

    await locale.setPreference(LocalePreference.mongolian);
    await tester.pump();
    expect(find.text(mn('learningContinueHere')), findsOneWidget);
  });

  testWidgets('switching language on the error view: Try again. changes at '
      'once and still reloads', (tester) async {
    final repository = failing(CourseLearningFailureKind.notFound);
    await pumpScreen(tester, repository);
    expect(retryButton(mn('commonRetry')), findsOneWidget);

    await locale.setEnglish(true);
    await tester.pump();
    expect(retryButton(en('commonRetry')), findsOneWidget);

    final calls = repository.calls.length;
    await tester.tap(retryButton(en('commonRetry')));
    await tester.pumpAndSettle();
    expect(repository.calls.length, calls + 1);
    // Reloaded in English: the stored message is computed again.
    expect(find.text(en('learningNotFound')), findsOneWidget);
  });

  // --- Large text -------------------------------------------------------------

  /// Each state at 2.0× text on a 320 pt phone, with the keys it shows.
  final states =
      <
        ({
          String name,
          List<String> keys,
          FakeCourseLearningRepository Function() repository,
        })
      >[
        (
          name: 'not-enrolled error',
          keys: ['learningNotEnrolled', 'commonRetry'],
          repository: () => failing(CourseLearningFailureKind.notEnrolled),
        ),
        (
          name: 'not-found error',
          keys: ['learningNotFound', 'commonRetry'],
          repository: () => failing(CourseLearningFailureKind.notFound),
        ),
        (
          name: 'empty course',
          keys: ['learningLessonsEmpty'],
          repository: () => FakeCourseLearningRepository(lessons: const []),
        ),
        (
          name: 'continue-here pill',
          keys: ['learningContinueHere'],
          repository: withContinueLesson,
        ),
      ];

  const width = 320.0;
  const height = 568.0;

  for (final state in states) {
    testWidgets('${state.name}: English at 2.0× text on a 320 pt phone has '
        'no overflow, every line whole and inside the screen, nothing cut '
        'short that Mongolian is not', (tester) async {
      Future<Set<String>> cutShort(LocalePreference language) async {
        await locale.setPreference(language);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpScreen(
          tester,
          state.repository(),
          size: const Size(width, height),
        );
        expect(tester.takeException(), isNull);

        final cut = <String>{};
        for (final key in state.keys) {
          final label = find.text(text(key, language));
          expect(label, findsOneWidget, reason: key);
          await tester.ensureVisible(label);
          await tester.pumpAndSettle();

          final rect = tester.getRect(label);
          expect(rect.left, greaterThanOrEqualTo(0), reason: key);
          expect(rect.right, lessThanOrEqualTo(width), reason: key);
          expect(rect.top, greaterThanOrEqualTo(0), reason: key);
          expect(rect.bottom, lessThanOrEqualTo(height), reason: key);

          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: label, matching: find.byType(RichText)).first,
          );
          if (paragraph.didExceedMaxLines) cut.add(key);
          // Drawn at its full height: nothing clipped.
          expect(
            paragraph.size.height,
            greaterThanOrEqualTo(
              paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
            ),
            reason: key,
          );

          if (key == 'learningContinueHere') {
            // The pill stays inside its card, clear of the card's edge, and
            // below the lesson's other lines rather than over them.
            final card = find.ancestor(
              of: label,
              matching: find.byType(CourseLessonCard),
            );
            final cardRect = tester.getRect(card);
            expect(rect.left, greaterThanOrEqualTo(cardRect.left + 12));
            expect(rect.right, lessThanOrEqualTo(cardRect.right - 12));
            expect(rect.bottom, lessThanOrEqualTo(cardRect.bottom - 12));
            final lesson = tester.widget<CourseLessonCard>(card).entry.lesson;
            for (final other in [
              lesson.title,
              if (lesson.durationLabel.isNotEmpty) lesson.durationLabel,
            ]) {
              final otherRect = tester.getRect(
                find.descendant(of: card, matching: find.text(other)),
              );
              expect(
                rect.top,
                greaterThanOrEqualTo(otherRect.bottom),
                reason: other,
              );
            }
          }
        }
        expect(tester.takeException(), isNull);
        return cut;
      }

      final mongolian = await cutShort(LocalePreference.mongolian);
      final english = await cutShort(LocalePreference.english);
      expect(english.difference(mongolian), isEmpty);
    });
  }
}
