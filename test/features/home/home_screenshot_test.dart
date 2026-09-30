import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_home_dashboard_repository.dart';

/// Deterministic captures of Adult Home, one per Figma frame, at each frame's
/// own size — 393 x 944, and 393 x 1073 for the contract frame, which is
/// drawn taller to fit its extra cards.
///
/// The dashboards are the frames' sample figures. Two of them cannot be
/// matched exactly, both because the reference contradicts itself:
///
///  * the progress bar is drawn 40% full under "35% complete" — the capture
///    draws the bar from the stated 35%;
///  * "1/20 · 10%" does not add up — the percentage is computed from the
///    tally, so the capture reads "1/20 · 5%".
///
/// Run `flutter test --update-goldens <this file>` to refresh, then compare
/// `test/goldens/home_*.png` against the references.
void main() {
  setUpAll(loadAppFonts);

  final beforeLesson = DateTime(2026, 4, 8, 8);
  final duringLesson = DateTime(2026, 4, 8, 10);

  final program = sampleProgram(
    progress: const ModuleProgress(percent: 35, completed: 2, total: 5),
    nextLesson: sampleLesson(start: DateTime(2026, 4, 8, 9)),
  );

  const attendance = AttendanceSummary(attended: 1, total: 20);

  Future<void> capture(
    WidgetTester tester, {
    required String name,
    required HomeDashboard dashboard,
    required DateTime now,
    double height = 944,
  }) async {
    useLogicalViewport(tester, Size(393, height), padding: iPhonePadding);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: HomeScreen(
          repository: FakeHomeDashboardRepository(dashboard: dashboard),
          clock: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/home_$name.png'),
    );
  }

  testWidgets('1 default — statistics as rows', (tester) async {
    await capture(
      tester,
      name: '1_default',
      now: beforeLesson,
      dashboard: HomeDashboard(
        program: program,
        stats: const [
          AttendanceStat(attendance, layout: HomeStatLayout.row),
          PaymentStat(PaymentStatus.dueIn(3), layout: HomeStatLayout.row),
        ],
      ),
    );
  });

  testWidgets('2 contract required, payment overdue', (tester) async {
    await capture(
      tester,
      name: '2_contract_overdue',
      now: beforeLesson,
      height: 1073,
      dashboard: HomeDashboard(
        program: program,
        contract: const ContractStatus(signed: false),
        stats: const [
          PaymentStat(PaymentStatus.overdue(), layout: HomeStatLayout.tile),
          AttendanceStat(attendance, layout: HomeStatLayout.tile),
          PaymentStat(PaymentStatus.dueIn(3), layout: HomeStatLayout.row),
        ],
      ),
    );
  });

  const tiles = [
    PaymentStat(PaymentStatus.dueIn(3), layout: HomeStatLayout.tile),
    AttendanceStat(attendance, layout: HomeStatLayout.tile),
  ];

  testWidgets('3 payment action disabled', (tester) async {
    await capture(
      tester,
      name: '3_payment_disabled',
      now: beforeLesson,
      dashboard: HomeDashboard(program: program, stats: tiles),
    );
  });

  testWidgets('4 live lesson', (tester) async {
    await capture(
      tester,
      name: '4_live',
      now: duringLesson,
      dashboard: HomeDashboard(program: program, stats: tiles),
    );
  });
}
