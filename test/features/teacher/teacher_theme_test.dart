import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_session.dart';
import 'package:aia_mobile/features/teacher/presentation/gradebook_submission_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_profile_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_request_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/gradebook_widgets.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_class_card.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_pill_button.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_week_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../profile/fake_current_user_repository.dart';
import 'fake_teacher_gradebook_repository.dart';
import 'fake_teacher_schedule_repository.dart';
import 'teacher_gradebook_screen_test.dart' show assignments, submissionsOf;
import 'teacher_home_screen_test.dart' show sampleClass;
import 'teacher_profile_screen_test.dart' show teacher;

/// Dark Mode Phase 8 (Issue #274): Teacher draws its colours from the active
/// theme's `AppPalette`, each by its meaning.
///
/// Pumped under a palette whose roles are unmistakable sentinels — not a
/// dark palette, which is not approved. The pairs that share a light value
/// get distinct sentinels, so each must be read where it belongs: the band
/// (`scheduleBand`) against the blocks' `accent`; the sheet
/// (`surfaceElevated`) against `surface` and its rule (`teacherSheetRule`)
/// against `outline`; the danger pill's `dangerOutline` against its
/// `errorInk` label; the Gradebook avatar's `avatarPlaceholder` against
/// `divider` and its glyph against `disabledInk`; Teacher's own inks against
/// the text roles. Light mode is held by the goldens.
void main() {
  setUpAll(loadAppFonts);

  const surface = Color(0xFF010101);
  const surfaceElevated = Color(0xFF020202);
  const surfaceSubtle = Color(0xFF030303);
  const outline = Color(0xFF040404);
  const outlineFaint = Color(0xFF050505);
  const outlineSubtle = Color(0xFF060606);
  const divider = Color(0xFF070707);
  const accent = Color(0xFF080808);
  const accentText = Color(0xFF090909);
  const scheduleBand = Color(0xFF0A0A0A);
  const scheduleHeld = Color(0xFF0B0B0B);
  const scheduleHeldInk = Color(0xFF0C0C0C);
  const onPrimary = Color(0xFFFEFEFE);
  const textStrong = Color(0xFF0D0D0D);
  const textPrimary = Color(0xFF0E0E0E);
  const textInactive = Color(0xFF0F0F0F);
  const textMuted = Color(0xFF101010);
  const textTitle = Color(0xFF111111);
  const teacherTitle = Color(0xFF121212);
  const teacherNameInk = Color(0xFF131313);
  const teacherRoleInk = Color(0xFF141414);
  const teacherDetailInk = Color(0xFF151515);
  const teacherCaptionInk = Color(0xFF161616);
  const teacherSheetRule = Color(0xFF171717);
  const errorInk = Color(0xFF181818);
  const dangerOutline = Color(0xFF191919);
  const avatarPlaceholder = Color(0xFF1A1A1A);
  const avatarPlaceholderInk = Color(0xFF1B1B1B);
  const disabledInk = Color(0xFF1C1C1C);
  const sheetHandle = Color(0xFF1D1D1D);
  const infoInk = Color(0xFF1E1E1E);
  const infoFill = Color(0xFF1F1F1F);
  const linkInk = Color(0xFF202020);
  const successInk = Color(0xFF212121);

  final sentinel = AppPalette.light.copyWith(
    surface: surface,
    surfaceElevated: surfaceElevated,
    surfaceSubtle: surfaceSubtle,
    outline: outline,
    outlineFaint: outlineFaint,
    outlineSubtle: outlineSubtle,
    divider: divider,
    accent: accent,
    accentText: accentText,
    scheduleBand: scheduleBand,
    scheduleHeld: scheduleHeld,
    scheduleHeldInk: scheduleHeldInk,
    onPrimary: onPrimary,
    textStrong: textStrong,
    textPrimary: textPrimary,
    textInactive: textInactive,
    textMuted: textMuted,
    textTitle: textTitle,
    teacherTitle: teacherTitle,
    teacherNameInk: teacherNameInk,
    teacherRoleInk: teacherRoleInk,
    teacherDetailInk: teacherDetailInk,
    teacherCaptionInk: teacherCaptionInk,
    teacherSheetRule: teacherSheetRule,
    errorInk: errorInk,
    dangerOutline: dangerOutline,
    avatarPlaceholder: avatarPlaceholder,
    avatarPlaceholderInk: avatarPlaceholderInk,
    disabledInk: disabledInk,
    sheetHandle: sheetHandle,
    infoInk: infoInk,
    infoFill: infoFill,
    linkInk: linkInk,
    successInk: successInk,
  );

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    Size size = const Size(393, 852),
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light.copyWith(extensions: [sentinel]),
        home: home,
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget body(Widget child) => Scaffold(
    body: Center(child: SingleChildScrollView(child: child)),
  );

  Color? textColor(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text).first).style?.color;

  /// Every distinct [BoxDecoration] under [of].
  Set<BoxDecoration> decorations(WidgetTester tester, Finder of) => {
    for (final b in tester.widgetList<DecoratedBox>(
      find.descendant(of: of, matching: find.byType(DecoratedBox)),
    ))
      if (b.decoration case final BoxDecoration d) d,
  };

  Color? edge(BoxDecoration d) => (d.border as Border?)?.top.color;

  FakeTeacherScheduleRepository
  scheduleRepository() => FakeTeacherScheduleRepository(
    classes: [sampleClass()],
    sessions: {
      2: [
        sampleSession(id: 1, date: '2026-10-07', start: (9, 0), end: (13, 0)),
        sampleSession(id: 2, date: '2026-10-07', start: (14, 0), end: (17, 0)),
      ],
    },
    attendance: {
      1: const AttendanceCounts(present: 12, late: 2, absent: 9, excused: 1),
    },
  );

  DateTime clock() => DateTime(2026, 10, 7, 13, 30);

  group('Teacher Schedule', () {
    testWidgets('the band is scheduleBand (not accent) with onPrimary ink, '
        'under the light status-bar glyphs it always had', (tester) async {
      await pump(
        tester,
        TeacherScheduleScreen(repository: scheduleRepository(), clock: clock),
      );
      final bands = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .map((b) => b.color);
      expect(bands, contains(scheduleBand));

      final header = find.ancestor(
        of: find.byType(SvgPicture).first,
        matching: find.byType(ColoredBox),
      );
      expect(tester.widget<ColoredBox>(header.first).color, scheduleBand);
      expect(
        tester.widget<SvgPicture>(find.byType(SvgPicture).first).colorFilter,
        ColorFilter.mode(onPrimary, BlendMode.srcIn),
      );

      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
      );
      expect(region.value.statusBarIconBrightness, Brightness.light);
    });

    testWidgets('week strip: accent disc with onPrimary on the selected day, '
        'textStrong otherwise, textInactive weekdays', (tester) async {
      await pump(
        tester,
        TeacherScheduleScreen(repository: scheduleRepository(), clock: clock),
      );
      expect(textColor(tester, '7'), onPrimary);
      expect(textColor(tester, '8'), textStrong);
      expect(textColor(tester, 'Лх'), textInactive);
      expect(
        decorations(
          tester,
          find.byType(Scaffold),
        ).where((d) => d.shape == BoxShape.circle && d.color == accent),
        hasLength(1),
      );
    });

    testWidgets('grid: divider hairlines; an upcoming block accent with '
        'onPrimary, a held one scheduleHeld with scheduleHeldInk', (
      tester,
    ) async {
      await pump(
        tester,
        TeacherScheduleScreen(repository: scheduleRepository(), clock: clock),
      );
      final grid = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(TeacherWeekGrid),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((p) => p.painter)
          .whereType<CustomPainter>()
          .map((p) => (p as dynamic).line as Color);
      expect(grid, contains(divider));

      final blocks = {
        for (final block in tester.widgetList<SessionBlock>(
          find.byType(SessionBlock),
        ))
          block.held: decorations(tester, find.byWidget(block)).single.color,
      };
      expect(blocks, {true: scheduleHeld, false: accent});
      final heldTitle = tester.widget<Text>(
        find
            .descendant(
              of: find.byWidgetPredicate((w) => w is SessionBlock && w.held),
              matching: find.byType(Text),
            )
            .first,
      );
      expect(heldTitle.style?.color, scheduleHeldInk);
    });

    testWidgets('session sheet: surfaceElevated with sheetHandle; a '
        'teacherSheetRule (not outline); the summary inks', (tester) async {
      await pump(
        tester,
        TeacherScheduleScreen(repository: scheduleRepository(), clock: clock),
      );
      await tester.tap(find.bySemanticsLabel('AI Engineer, 09:00-13:00'));
      await tester.pumpAndSettle();

      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor, surfaceElevated);
      final colours = [
        for (final c in tester.widgetList<Container>(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Container),
          ),
        ))
          ?c.color,
      ];
      expect(colours, contains(teacherSheetRule));
      expect(colours, isNot(contains(outline)));
      expect(colours, contains(outlineSubtle));
      expect(
        decorations(tester, find.byType(BottomSheet)).map((d) => d.color),
        contains(sheetHandle),
      );
      expect(textColor(tester, '14'), accentText);
      expect(textColor(tester, ' / 24'), teacherDetailInk);
      expect(
        textColor(tester, TeacherScheduleStrings.attendedCaption),
        teacherCaptionInk,
      );
    });
  });

  group('TeacherPillButton', () {
    Future<(Material, Text)> pill(
      WidgetTester tester,
      TeacherPillVariant variant,
    ) async {
      await pump(
        tester,
        body(
          TeacherPillButton(label: 'Go', onPressed: () {}, variant: variant),
        ),
      );
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(TeacherPillButton),
              matching: find.byType(Material),
            )
            .first,
      );
      return (material, tester.widget<Text>(find.text('Go')));
    }

    Color side(Material m) => (m.shape! as RoundedRectangleBorder).side.color;

    testWidgets('danger: dangerOutline edge, errorInk label', (tester) async {
      final (m, label) = await pill(tester, TeacherPillVariant.danger);
      expect(m.color, surface);
      expect(side(m), dangerOutline);
      expect(label.style?.color, errorInk);
    });

    testWidgets('outlined: outline edge, textStrong label', (tester) async {
      final (m, label) = await pill(tester, TeacherPillVariant.outlined);
      expect(side(m), outline);
      expect(label.style?.color, textStrong);
    });

    testWidgets('filled: accent with onPrimary', (tester) async {
      final (m, label) = await pill(tester, TeacherPillVariant.filled);
      expect(m.color, accent);
      expect(label.style?.color, onPrimary);
    });
  });

  testWidgets('class card: outline edge, teacherTitle title (not '
      'textTitle), accentText details, success capsule', (tester) async {
    await pump(tester, body(TeacherClassCard(teacherClass: sampleClass())));
    final card = decorations(
      tester,
      find.byType(TeacherClassCard),
    ).firstWhere((d) => d.border != null && d.color == surface);
    expect(edge(card), outline);
    final title = sampleClass().cohort.course.title.preferred!;
    expect(textColor(tester, title), teacherTitle);
    expect(
      tester
          .widgetList<Icon>(
            find.descendant(
              of: find.byType(TeacherClassCard),
              matching: find.byType(Icon),
            ),
          )
          .map((i) => i.color),
      everyElement(accentText),
    );
  });

  group('Gradebook', () {
    testWidgets('placeholder avatar: avatarPlaceholder (not divider) with '
        'avatarPlaceholderInk (not disabledInk); initials textMuted', (
      tester,
    ) async {
      await pump(
        tester,
        body(
          const Column(
            children: [
              GradebookAvatar(),
              GradebookAvatar(initials: 'BT'),
            ],
          ),
        ),
      );
      final discs = {
        for (final d in decorations(tester, find.byType(GradebookAvatar)))
          d.color,
      };
      expect(discs, {avatarPlaceholder});
      expect(
        tester.widget<Icon>(find.byType(Icon)).color,
        avatarPlaceholderInk,
      );
      expect(textColor(tester, 'BT'), textMuted);
    });

    testWidgets('stat card: outlineFaint edge; infoInk @ 30 % round infoFill, '
        'accentText figure', (tester) async {
      await pump(
        tester,
        body(const GradebookStatCard(title: 'Title', value: '80%')),
      );
      final all = decorations(tester, find.byType(GradebookStatCard));
      expect(
        all.where((d) => d.color == surface).map(edge),
        contains(outlineFaint),
      );
      final capsule = all.singleWhere((d) => d.color == infoFill);
      expect(edge(capsule), infoInk.withValues(alpha: 0.3));
      expect(textColor(tester, '80%'), accentText);
      expect(textColor(tester, 'Title'), textStrong);
    });

    testWidgets('submission: accentText tab over an accent underline; '
        'divider tab rule; linkInk link; outline fields', (tester) async {
      await pump(
        tester,
        GradebookSubmissionScreen(
          courseTitle: 'AI Engineer',
          submissionId: 18,
          repository: FakeTeacherGradebookRepository(
            classes: [sampleClass()],
            assignments: {2: assignments},
            submissionsOf: submissionsOf,
            submissions: {18: submissionsOf[2]![0]},
          ),
        ),
      );
      final underlines = {
        for (final d in decorations(tester, find.byType(Scaffold)))
          if (d.border case final Border b
              when b.bottom.width == 2 && b.top == BorderSide.none)
            b.bottom.color,
      };
      expect(underlines, contains(accent));
      expect(
        decorations(tester, find.byType(Scaffold)).where(
          (d) =>
              d.border is Border &&
              (d.border! as Border).bottom.color == divider &&
              (d.border! as Border).bottom.width == 1,
        ),
        isNotEmpty,
      );
      final decorators = tester.widgetList<InputDecorator>(
        find.byType(InputDecorator),
      );
      expect(decorators, isNotEmpty);
      for (final d in decorators) {
        expect(
          (d.decoration.enabledBorder! as OutlineInputBorder).borderSide.color,
          outline,
        );
      }
    });
  });

  testWidgets('Request: teacherNameInk name, teacherRoleInk role, the '
      'placeholder glyph avatarPlaceholderInk on surfaceSubtle', (
    tester,
  ) async {
    await pump(
      tester,
      const TeacherRequestScreen(
        candidates: [
          TeacherRequestCandidate(
            name: 'Баатар',
            status: TeacherRequestStatus.rejected,
          ),
        ],
      ),
    );
    expect(textColor(tester, 'Баатар'), teacherNameInk);
    final avatar = decorations(
      tester,
      find.byType(Scaffold),
    ).firstWhere((d) => d.shape == BoxShape.circle);
    expect(avatar.color, surfaceSubtle);
    expect(
      tester
          .widgetList<Icon>(find.byType(Icon))
          .map((i) => i.color)
          .contains(avatarPlaceholderInk),
      isTrue,
    );
    final roles = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.style?.color)
        .toList();
    expect(roles, contains(teacherRoleInk));
    expect(roles, contains(errorInk));
  });

  testWidgets('Profile: the shared name style takes textPrimary; email and '
      'phone teacherDetailInk', (tester) async {
    await pump(
      tester,
      TeacherProfileScreen(
        repository: FakeCurrentUserRepository(user: teacher),
      ),
      size: const Size(393, 966),
    );
    expect(textColor(tester, 'Test Teacher'), textPrimary);
    expect(textColor(tester, 'test.teacher@example.mn'), teacherDetailInk);
    expect(textColor(tester, '99001122'), teacherDetailInk);
  });
}
