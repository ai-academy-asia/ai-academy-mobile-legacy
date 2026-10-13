import 'dart:io';

import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/presentation/home_route.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_gradebook_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_tabs.dart';
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_teacher_gradebook_repository.dart';
import 'teacher_home_screen_test.dart' show sampleClass, tuesday;
import 'teacher_schedule_screen_test.dart' show weekRepository;

/// The first Teacher redesign task (Issue #370): the bar drops Нүүр — three
/// tabs, Хуваарь first and the default — and the Schedule date header's
/// dropdown is the design's own chevron.
void main() {
  test('the tab order is Хуваарь, Дүнгийн хуудас, Профайл', () {
    expect(TeacherTab.values, [
      TeacherTab.schedule,
      TeacherTab.grades,
      TeacherTab.profile,
    ]);
  });

  group('the date header\'s dropdown chevron', () {
    const supplied =
        'M0.256282 0.256282C0.59799 -0.0854272 1.15201 -0.0854272 1.49372 '
        '0.256282L5.25 4.01256L9.00628 0.256282C9.34799 -0.0854272 9.90201 '
        '-0.0854272 10.2437 0.256282C10.5854 0.59799 10.5854 1.15201 10.2437 '
        '1.49372L5.86872 5.86872C5.52701 6.21043 4.97299 6.21043 4.63128 '
        '5.86872L0.256282 1.49372C-0.0854272 1.15201 -0.0854272 0.59799 '
        '0.256282 0.256282Z';

    test('is the supplied SVG: its path, 11 x 7 and white fill, verbatim', () {
      final svg = File('assets/icons/date_dropdown.svg').readAsStringSync();
      expect(svg, contains('width="11" height="7" viewBox="0 0 11 7"'));
      expect(svg, contains('d="$supplied"'));
      expect(svg, contains('fill="white"'));
      expect(svg, contains('fill-rule="evenodd"'));
    });

    Future<void> pumpSchedule(WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: TeacherScheduleScreen(
            repository: weekRepository(),
            clock: tuesday,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder chevron() => find.byWidgetPredicate(
      (w) =>
          w is SvgPicture &&
          w.bytesLoader.toString().contains('date_dropdown.svg'),
    );

    testWidgets('sits after the date, centred on its line, at 11 x 7', (
      tester,
    ) async {
      await pumpSchedule(tester);

      expect(chevron(), findsOneWidget);
      final icon = tester.getRect(chevron());
      expect(icon.size, const Size(11, 7));
      final date = tester.getRect(
        find.text(TeacherScheduleStrings.headerDate(tuesday())),
      );
      // The design's gap: its ink 25 after the date's (24 of box, measured).
      expect(icon.left - date.right, 24);
      expect(icon.center.dy, closeTo(date.center.dy, 0.5));
    });

    testWidgets('still opens the date picker when tapped', (tester) async {
      await pumpSchedule(tester);

      await tester.tap(chevron());
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });

  testWidgets('a bar drawn outside the shell returns to the Teacher landing '
      'route — Хуваарь — on Хуваарь', (tester) async {
    tester.view.physicalSize = const Size(393, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        initialRoute: HomeRoutes.teacher,
        routes: {
          HomeRoutes.teacher: (_) => TeacherScheduleScreen(
            repository: weekRepository(),
            clock: tuesday,
          ),
          TeacherTabRoutes.gradebook: (_) => TeacherGradebookScreen(
            repository: FakeTeacherGradebookRepository(
              classes: [sampleClass()],
            ),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(TeacherHomeStrings.navGrades));
    await tester.pumpAndSettle();
    expect(find.byType(TeacherGradebookScreen), findsOneWidget);
    expect(
      tester.widget<AppBottomNav>(find.byType(AppBottomNav)).currentIndex,
      TeacherTab.grades.index,
    );

    await tester.tap(find.text(TeacherHomeStrings.navSchedule));
    await tester.pumpAndSettle();
    expect(find.byType(TeacherScheduleScreen), findsOneWidget);
    expect(find.byType(TeacherGradebookScreen), findsNothing);
    expect(
      tester.widget<AppBottomNav>(find.byType(AppBottomNav)).currentIndex,
      TeacherTab.schedule.index,
    );
  });
}
