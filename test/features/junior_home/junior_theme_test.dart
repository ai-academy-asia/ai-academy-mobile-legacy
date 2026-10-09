import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/home/domain/lesson_schedule.dart';
import 'package:aia_mobile/features/home/presentation/attendance_detail_screen.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/junior_home/data/sample_junior_learning_map.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_profile_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_progress_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_progress_strings.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/attendance_panel_parts.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_certificate_card.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_course_progress_card.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_node.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_path_painter.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_progress_calendar.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_progress_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../profile/fake_current_user_repository.dart';
import 'fake_junior_home_repository.dart';
import 'fake_junior_progress_repository.dart';

/// Dark Mode Phase 7 (Issue #272): Junior draws its colours from the active
/// theme's `AppPalette`, each by its meaning.
///
/// Pumped under a palette whose roles are unmistakable sentinels — not a
/// dark palette, which is not approved. The pairs that share a light value
/// get distinct sentinels, so each must be read where it belongs: the
/// summary pill's `accentSubtle` against the calendar's `calendarLesson`;
/// blue text (`accentText`) against blue fills (`accent`); a panel's
/// `outlineFaint` edge against the `divider` rule inside it; the map's
/// `juniorMutedFill` against `divider`; Junior Home's `juniorHeaderRule`
/// against `border` and `divider`; the sky spinner's `onJuniorMapSky`
/// against `onPrimary` and `surface`. Light mode is held by the goldens.
void main() {
  setUpAll(loadAppFonts);

  const surface = Color(0xFF010101);
  const surfaceSubtle = Color(0xFF020202);
  const surfaceMuted = Color(0xFF030303);
  const outline = Color(0xFF040404);
  const outlineFaint = Color(0xFF050505);
  const divider = Color(0xFF060606);
  const border = Color(0xFF070707);
  const accent = Color(0xFF080808);
  const accentText = Color(0xFF090909);
  const accentSubtle = Color(0xFF0A0A0A);
  const accentSubtleOutline = Color(0xFF0B0B0B);
  const calendarNeutral = Color(0xFF0C0C0C);
  const calendarLesson = Color(0xFF0D0D0D);
  const calendarMissed = Color(0xFF0E0E0E);
  const juniorCard = Color(0xFF0F0F0F);
  const juniorCardBorder = Color(0xFF101010);
  const juniorMapSky = Color(0xFF111111);
  const juniorMutedFill = Color(0xFF121212);
  const juniorHeaderRule = Color(0xFF131313);
  const onJuniorMapSky = Color(0xFF141414);
  const onPrimary = Color(0xFFFEFEFE);
  const textPrimary = Color(0xFF151515);
  const textSecondary = Color(0xFF161616);
  const textStatLabel = Color(0xFF171717);
  const errorInk = Color(0xFF181818);
  const linkInk = Color(0xFF191919);
  const shadow = Color(0xFF1A1A1A);

  final sentinel = AppPalette.light.copyWith(
    surface: surface,
    surfaceSubtle: surfaceSubtle,
    surfaceMuted: surfaceMuted,
    outline: outline,
    outlineFaint: outlineFaint,
    divider: divider,
    border: border,
    accent: accent,
    accentText: accentText,
    accentSubtle: accentSubtle,
    accentSubtleOutline: accentSubtleOutline,
    calendarNeutral: calendarNeutral,
    calendarLesson: calendarLesson,
    calendarMissed: calendarMissed,
    juniorCard: juniorCard,
    juniorCardBorder: juniorCardBorder,
    juniorMapSky: juniorMapSky,
    juniorMutedFill: juniorMutedFill,
    juniorHeaderRule: juniorHeaderRule,
    onJuniorMapSky: onJuniorMapSky,
    onPrimary: onPrimary,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    textStatLabel: textStatLabel,
    errorInk: errorInk,
    linkInk: linkInk,
    shadow: shadow,
  );

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    Size size = const Size(393, 1428),
    bool settle = true,
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    useReducedMotion(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light.copyWith(extensions: [sentinel]),
        home: home,
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Color? textColor(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text).first).style?.color;

  /// Every distinct [BoxDecoration] under [of] — a `Container` builds a
  /// `DecoratedBox` with its own decoration, so each is counted once.
  Set<BoxDecoration> decorations(WidgetTester tester, Finder of) => {
    for (final b in tester.widgetList<DecoratedBox>(
      find.descendant(of: of, matching: find.byType(DecoratedBox)),
    ))
      if (b.decoration case final BoxDecoration d) d,
  };

  Color? edge(BoxDecoration d) => (d.border as Border?)?.top.color;

  Iterable<Color> boxColours(WidgetTester tester) => [
    for (final c in tester.widgetList<Container>(find.byType(Container)))
      ?c.color,
    for (final b in tester.widgetList<ColoredBox>(find.byType(ColoredBox)))
      b.color,
  ];

  group('Junior Home', () {
    testWidgets('juniorHeaderRule under the header (not border or divider); '
        'the juniorMapSky field', (tester) async {
      await pump(
        tester,
        JuniorHomeScreen(
          repository: FakeJuniorHomeRepository(),
          clock: () => sampleLessonTime,
        ),
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        surface,
      );
      final colours = boxColours(tester).toList();
      expect(colours, contains(juniorHeaderRule));
      expect(colours, isNot(contains(border)));
      expect(colours, contains(juniorMapSky));
    });

    testWidgets('map nodes: completed juniorCard in accent, current surface '
        'in outline, locked juniorMutedFill (not divider) in outline — each '
        'on a band of its own outline', (tester) async {
      await pump(
        tester,
        JuniorHomeScreen(
          repository: FakeJuniorHomeRepository(),
          clock: () => sampleLessonTime,
        ),
      );
      final nodes = [
        for (final tile in tester.widgetList<JuniorMapNodeTile>(
          find.byType(JuniorMapNodeTile),
        ))
          decorations(
            tester,
            find.byWidget(tile),
          ).singleWhere((d) => d.boxShadow != null),
      ];
      final styles = {for (final d in nodes) (d.color, edge(d))};
      expect(styles, {
        (juniorCard, accent),
        (surface, outline),
        (juniorMutedFill, outline),
      });
      for (final d in nodes) {
        expect(d.boxShadow!.single.color, edge(d));
      }
      expect(nodes.map((d) => d.color), isNot(contains(divider)));

      final route = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<JuniorMapPathPainter>()
          .single;
      expect(route.travelled, accent);
      expect(route.untravelled, outline);
    });

    testWidgets('course card: juniorCard in juniorCardBorder; the ring an '
        'accent arc on an outline track', (tester) async {
      await pump(
        tester,
        JuniorHomeScreen(
          repository: FakeJuniorHomeRepository(),
          clock: () => sampleLessonTime,
        ),
      );
      final card = decorations(
        tester,
        find.byType(JuniorCourseProgressCard),
      ).firstWhere((d) => d.border != null);
      expect(card.color, juniorCard);
      expect(edge(card), juniorCardBorder);

      final ring =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byType(JuniorProgressRing),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as dynamic;
      expect(ring.track, outline);
      expect(ring.progress, accent);
    });

    testWidgets('loading: the spinner is onJuniorMapSky', (tester) async {
      final repository = FakeJuniorHomeRepository(hold: true);
      await pump(
        tester,
        JuniorHomeScreen(repository: repository),
        settle: false,
      );
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .color,
        onJuniorMapSky,
      );
      repository.release();
      await tester.pumpAndSettle();
    });
  });

  testWidgets('certificate panel: juniorMutedFill in outline, accentText '
      'course name, surfaceSubtle pill', (tester) async {
    await pump(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: JuniorCertificateCard(
            certificate: sampleJuniorLearningMap().certificate,
            scale: 1,
          ),
        ),
      ),
    );
    final panel = decorations(
      tester,
      find.byType(JuniorCertificateCard),
    ).where((d) => d.border != null).toList();
    expect(panel.map((d) => d.color), contains(juniorMutedFill));
    expect(panel.map((d) => d.color), contains(surfaceSubtle));
    expect(panel.map(edge), everyElement(outline));
    expect(
      textColor(tester, sampleJuniorLearningMap().certificate.courseName),
      accentText,
    );
  });

  group('Junior Learning Progress', () {
    Future<void> pumpProgress(
      WidgetTester tester, {
      PaymentStatus payment = const PaymentStatus.dueIn(3),
    }) => pump(
      tester,
      JuniorProgressScreen(
        repository: FakeJuniorProgressRepository(
          progress: figmaReferenceProgress(payment: payment),
        ),
      ),
      size: const Size(393, 1350),
    );

    testWidgets('page, header rule and panels: an outlineFaint edge, the '
        'divider rule inside', (tester) async {
      await pumpProgress(tester);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        surfaceSubtle,
      );
      final panels = {
        for (final d in decorations(tester, find.byType(Scaffold)))
          // Uniform edges only: the bottom bar's top-only `divider` rule is
          // a rule, not a panel edge.
          if (d.color == surface && (d.border as Border?)?.isUniform == true)
            edge(d),
      };
      expect(panels, containsAll([outlineFaint, outline]));
      expect(panels, isNot(contains(divider)));
      expect(boxColours(tester), contains(divider));
    });

    testWidgets('payment card: accentText status and glyph, accent pill '
        'with onPrimary label and ripple', (tester) async {
      await pumpProgress(tester);
      expect(textColor(tester, '3 хоног дутуу'), accentText);
      // The same line also sits under the contract banner; the payment
      // card's copy is the warm grey.
      expect(
        tester
            .widgetList<Text>(find.text(JuniorProgressStrings.showParent))
            .map((t) => t.style?.color),
        contains(textStatLabel),
      );
      expect(
        tester.widget<Icon>(find.byIcon(AppIcons.money)).color,
        accentText,
      );
      final pay = find.ancestor(
        of: find.text(JuniorProgressStrings.payAction),
        matching: find.byType(Material),
      );
      expect(tester.widget<Material>(pay.first).color, accent);
      expect(textColor(tester, JuniorProgressStrings.payAction), onPrimary);
      final ink = tester.widget<InkWell>(
        find.ancestor(
          of: find.text(JuniorProgressStrings.payAction),
          matching: find.byType(InkWell),
        ),
      );
      expect(ink.splashColor, onPrimary.withAlpha(0x3D));
    });

    testWidgets('overdue: errorInk status', (tester) async {
      await pumpProgress(tester, payment: const PaymentStatus.overdue());
      expect(textColor(tester, JuniorProgressStrings.paymentOverdue), errorInk);
    });

    testWidgets('summary pill: accentText on accentSubtle (not the calendar\'s '
        'calendarLesson) in accentSubtleOutline', (tester) async {
      await pumpProgress(tester);
      final pill = decorations(
        tester,
        find.byType(AttendancePill).first,
      ).single;
      expect(pill.color, accentSubtle);
      expect(edge(pill), accentSubtleOutline);
      final label = tester.widget<Text>(
        find.descendant(
          of: find.byType(AttendancePill).first,
          matching: find.byType(Text),
        ),
      );
      expect(label.style?.color, accentText);
    });

    testWidgets('calendar: the day tints; the selected day an accent outline '
        'and accentText number; legend and month textSecondary', (
      tester,
    ) async {
      await pumpProgress(tester);
      final grid = find.byType(JuniorProgressCalendar);
      final fills = {
        for (final d in decorations(tester, grid))
          if (d.shape == BoxShape.circle) d.color,
      };
      expect(
        fills,
        containsAll([calendarNeutral, calendarLesson, calendarMissed, accent]),
      );
      Color? inGrid(String text) => tester
          .widget<Text>(find.descendant(of: grid, matching: find.text(text)))
          .style
          ?.color;
      expect(inGrid('7'), accentText);
      expect(inGrid('8'), textSecondary);
      final selected = tester
          .widgetList<Container>(
            find.descendant(of: grid, matching: find.byType(Container)),
          )
          .map((c) => c.foregroundDecoration)
          .whereType<BoxDecoration>()
          .single;
      expect(edge(selected), accent);
      expect(
        textColor(tester, JuniorProgressStrings.legendHint),
        textSecondary,
      );
      expect(textColor(tester, JuniorProgressStrings.nextLesson), textPrimary);
    });
  });

  testWidgets('Junior Profile: Phase 3\'s profile_parts roles — switch, '
      'MN/EN, avatar, log out, rules', (tester) async {
    await pump(
      tester,
      JuniorProfileScreen(repository: FakeCurrentUserRepository(hold: true)),
      size: const Size(393, 1274),
    );
    final scaffold = find.byType(Scaffold);
    final all = decorations(tester, scaffold);

    // The switches: an accent or outline track with a surface knob, lifted
    // by `shadow`.
    final knobs = all.where(
      (d) => d.shape == BoxShape.circle && d.boxShadow != null,
    );
    expect(knobs, isNotEmpty);
    expect(knobs.map((d) => d.color), everyElement(surface));
    expect(knobs.map((d) => d.boxShadow!.single.color), everyElement(shadow));
    final tracks = {
      for (final c in tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      ))
        if (c.decoration case final BoxDecoration d) d.color,
    };
    expect(tracks, isNotEmpty);
    expect(tracks.difference({accent, outline}), isEmpty);

    // The avatar: a surfaceMuted disc in an outline ring.
    expect(
      all.where(
        (d) =>
            d.shape == BoxShape.circle &&
            d.color == surfaceMuted &&
            edge(d) == outline,
      ),
      hasLength(1),
    );

    // MN/EN: an accent capsule; linkInk on the selected half, onPrimary on
    // the other.
    expect(all.map((d) => d.color), contains(accent));
    final segments = {textColor(tester, 'MN'), textColor(tester, 'EN')};
    expect(segments, {linkInk, onPrimary});

    expect(boxColours(tester), contains(divider));
  });

  testWidgets('Adult attendance: the shared card title takes textPrimary at '
      'its one Adult call site', (tester) async {
    await pump(
      tester,
      AttendanceDetailScreen(
        attendance: AttendanceSummary(
          attended: 1,
          total: 20,
          percent: 10,
          attendedDates: {DateTime(2026, 8, 1)},
          missedDates: {DateTime(2026, 8, 4)},
        ),
        schedule: const LessonSchedule(
          weekdays: {DateTime.tuesday, DateTime.saturday},
          start: (9, 0),
          end: (11, 0),
        ),
        nextLesson: NextLesson(
          startsAt: DateTime(2026, 8, 8, 9),
          endsAt: DateTime(2026, 8, 8, 11),
        ),
        clock: () => DateTime(2026, 8, 7, 10),
      ),
      size: const Size(393, 910),
    );
    expect(textColor(tester, HomeStrings.attendanceLabel), textPrimary);
    final pill = decorations(tester, find.byType(AttendancePill)).single;
    expect(pill.color, accentSubtle);
    expect(edge(pill), accentSubtleOutline);
  });
}
