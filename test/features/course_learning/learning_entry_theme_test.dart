import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/domain/course_module.dart';
import 'package:aia_mobile/features/course_learning/domain/lesson.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_module_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/lesson_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/certificate_preview.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_module_card.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_progress_cta_row.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/lesson_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_course_learning_repository.dart';

/// Dark Mode Phase 6a (Issue #266): the Learning Flow's entry screens draw
/// their colours from the active theme's `AppPalette`, each by its meaning.
///
/// Pumped under a palette whose roles are unmistakable sentinels — not a
/// dark palette, which is not approved. In particular a card's edge
/// (`outlineFaint`), the band under it (`cardDepth`) and the rule between
/// cards (`divider`) share one light grey but must read three roles. Light
/// mode itself is held pixel-identical by the existing goldens.
void main() {
  // Real font metrics: the test font's wider glyphs overflow the CTA row.
  setUpAll(loadAppFonts);

  const surface = Color(0xFF010101);
  const pageBackground = Color(0xFF020202);
  const surfaceSubtle = Color(0xFF030303);
  const surfaceLocked = Color(0xFF040404);
  const learningHeroTint = Color(0xFF050505);
  const outlineFaint = Color(0xFF060606);
  const cardDepth = Color(0xFF070707);
  const divider = Color(0xFF080808);
  const outline = Color(0xFF090909);
  const textTitle = Color(0xFF0A0A0A);
  const textStrong = Color(0xFF0B0B0B);
  const textSupporting = Color(0xFF0C0C0C);
  const textMuted = Color(0xFF0D0D0D);
  const textLocked = Color(0xFF0E0E0E);
  const textPrimary = Color(0xFF0F0F0F);
  const textSecondary = Color(0xFF101010);
  const primary = Color(0xFF111111);
  const accent = Color(0xFF121212);
  const primaryDepth = Color(0xFF131313);
  const onPrimary = Color(0xFFFEFEFE);

  final sentinel = AppPalette.light.copyWith(
    surface: surface,
    pageBackground: pageBackground,
    surfaceSubtle: surfaceSubtle,
    surfaceLocked: surfaceLocked,
    learningHeroTint: learningHeroTint,
    outlineFaint: outlineFaint,
    cardDepth: cardDepth,
    divider: divider,
    outline: outline,
    textTitle: textTitle,
    textStrong: textStrong,
    textSupporting: textSupporting,
    textMuted: textMuted,
    textLocked: textLocked,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    primary: primary,
    accent: accent,
    primaryDepth: primaryDepth,
    onPrimary: onPrimary,
  );

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light.copyWith(extensions: [sentinel]),
        home: home,
      ),
    );
    await tester.pump();
  }

  Color? textColor(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  /// Every [BoxDecoration] under [of].
  Iterable<BoxDecoration> decorations(WidgetTester tester, Finder of) => tester
      .widgetList<Container>(
        find.descendant(of: of, matching: find.byType(Container)),
      )
      .map((c) => c.decoration)
      .whereType<BoxDecoration>();

  /// The lifted card's own decoration: the one carrying the band.
  BoxDecoration liftedCard(WidgetTester tester, Finder of) =>
      decorations(tester, of).singleWhere((d) => d.boxShadow != null);

  Iterable<Color> coloredBoxes(WidgetTester tester) => tester
      .widgetList<ColoredBox>(find.byType(ColoredBox))
      .map((b) => b.color);

  CourseModule module({required bool locked}) => CourseModule(
    id: 1,
    order: 1,
    title: 'Module title',
    scheduleLabel: 'Schedule',
    iconAsset: 'assets/images/course_learning/module_ai.svg',
    accentColor: const Color(0xFF408CFF),
    lessonCount: 4,
    completedLessons: 0,
    completed: false,
    locked: locked,
  );

  Lesson lesson({required bool locked}) => Lesson(
    id: 1,
    moduleId: 1,
    order: 3,
    title: 'Lesson title',
    type: LessonType.video,
    durationLabel: '12 min',
    completed: false,
    locked: locked,
  );

  group('CourseModuleCard', () {
    testWidgets('surface fill, outlineFaint edge, cardDepth band', (
      tester,
    ) async {
      await pump(
        tester,
        Scaffold(body: CourseModuleCard(module: module(locked: false))),
      );
      final card = liftedCard(tester, find.byType(CourseModuleCard));
      expect(card.color, surface);
      expect((card.border! as Border).top.color, outlineFaint);
      expect(card.boxShadow!.single.color, cardDepth);
      expect(
        tester
            .widget<Material>(
              find
                  .descendant(
                    of: find.byType(CourseModuleCard),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color,
        surface,
      );
      expect(textColor(tester, 'Module title'), textTitle);
      expect(textColor(tester, 'Schedule'), textSupporting);
      expect(
        textColor(tester, '${CourseLearningStrings.moduleCaption} 1'),
        textSupporting,
      );
    });

    testWidgets('locked: surfaceLocked tile, textLocked title', (tester) async {
      await pump(
        tester,
        Scaffold(body: CourseModuleCard(module: module(locked: true))),
      );
      expect(
        decorations(
          tester,
          find.byType(CourseModuleCard),
        ).where((d) => d.color == surfaceLocked),
        hasLength(1),
      );
      expect(textColor(tester, 'Module title'), textLocked);
    });
  });

  group('LessonListItem', () {
    testWidgets('surface fill, outlineFaint edge, cardDepth band, ink', (
      tester,
    ) async {
      await pump(
        tester,
        Scaffold(body: LessonListItem(lesson: lesson(locked: false))),
      );
      final card = liftedCard(tester, find.byType(LessonListItem));
      expect(card.color, surface);
      expect((card.border! as Border).top.color, outlineFaint);
      expect(card.boxShadow!.single.color, cardDepth);
      expect(textColor(tester, '03'), textMuted);
      expect(textColor(tester, 'Lesson title'), textStrong);
      expect(textColor(tester, '12 min'), textSupporting);
    });

    testWidgets('locked: textLocked number and title', (tester) async {
      await pump(
        tester,
        Scaffold(body: LessonListItem(lesson: lesson(locked: true))),
      );
      expect(textColor(tester, '03'), textLocked);
      expect(textColor(tester, 'Lesson title'), textLocked);
    });
  });

  testWidgets('CourseProgressCtaRow: accent on an outline track, '
      'textTitle label, accent pill on primaryDepth, onPrimary ink', (
    tester,
  ) async {
    await pump(
      tester,
      Scaffold(
        body: CourseProgressCtaRow(
          percent: 30,
          buttonWidth: 148,
          onContinue: () {},
        ),
      ),
    );
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.backgroundColor, outline);
    expect((bar.valueColor! as AlwaysStoppedAnimation<Color?>).value, accent);
    expect(textColor(tester, '30% complete'), textTitle);
    expect(textColor(tester, 'Continue learning'), onPrimary);

    final button = find.byType(ContinueLearningButton);
    final depth = tester.widget<DecoratedBox>(
      find.descendant(of: button, matching: find.byType(DecoratedBox)).first,
    );
    expect(
      (depth.decoration as BoxDecoration).boxShadow!.single.color,
      primaryDepth,
    );
    expect(
      tester
          .widget<Material>(
            find.descendant(of: button, matching: find.byType(Material)),
          )
          .color,
      accent,
    );
    final ink = tester.widget<InkWell>(
      find.descendant(of: button, matching: find.byType(InkWell)),
    );
    expect(ink.splashColor, onPrimary.withAlpha(0x3D));
    expect(ink.highlightColor, onPrimary.withAlpha(0x1A));
  });

  testWidgets('CertificatePreview: the outlined frame is outline', (
    tester,
  ) async {
    await pump(
      tester,
      const Scaffold(body: CertificatePreview(inset: 12, outlined: true)),
    );
    final frame = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(CertificatePreview),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      ((frame.decoration as BoxDecoration).border! as Border).top.color,
      outline,
    );
  });

  group('CourseModuleListScreen', () {
    testWidgets('surface page under a learningHeroTint wash; divider '
        'connectors; outlineFaint certification panel', (tester) async {
      await pump(
        tester,
        CourseModuleListScreen(
          courseSlug: 'how-ai-works',
          repository: FakeCourseLearningRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        surface,
      );
      final wash = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((b) => b.decoration)
          .whereType<BoxDecoration>()
          .singleWhere((d) => d.gradient != null);
      expect((wash.gradient! as LinearGradient).colors, [
        learningHeroTint,
        surface,
      ]);

      // Four rules join the five cards; none reads the card's own roles.
      expect(coloredBoxes(tester).where((c) => c == divider), hasLength(4));
      expect(
        coloredBoxes(tester).where((c) => c == cardDepth || c == outlineFaint),
        isEmpty,
      );

      final panel = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .singleWhere((d) => d.color == surfaceSubtle);
      expect((panel.border! as Border).top.color, outlineFaint);
    });

    testWidgets('loading: primary spinner', (tester) async {
      final repository = FakeCourseLearningRepository(hold: true);
      await pump(
        tester,
        CourseModuleListScreen(courseSlug: 'x', repository: repository),
      );
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .color,
        primary,
      );
      repository.release();
      await tester.pumpAndSettle();
    });
  });

  group('LessonListScreen', () {
    Widget screen(FakeCourseLearningRepository repository) => LessonListScreen(
      moduleId: 2,
      moduleOrder: 2,
      moduleTitle: 'Module heading',
      repository: repository,
    );

    testWidgets('pageBackground page, textPrimary heading, textSecondary '
        'caption, divider connectors', (tester) async {
      await pump(tester, screen(FakeCourseLearningRepository()));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        pageBackground,
      );
      expect(textColor(tester, 'Module heading'), textPrimary);
      expect(
        textColor(tester, '${CourseLearningStrings.moduleCaption} 2'),
        textSecondary,
      );
      final lessons = tester.widgetList(find.byType(LessonListItem)).length;
      expect(lessons, greaterThan(1));
      expect(
        coloredBoxes(tester).where((c) => c == divider),
        hasLength(lessons - 1),
      );
    });

    testWidgets('empty: textSecondary message', (tester) async {
      await pump(tester, screen(FakeCourseLearningRepository(lessons: [])));
      await tester.pumpAndSettle();
      expect(
        textColor(tester, CourseLearningStrings.lessonsEmpty),
        textSecondary,
      );
    });
  });
}
