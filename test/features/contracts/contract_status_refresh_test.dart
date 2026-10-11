import 'dart:async';

import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/contracts/domain/student_contract.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_screen.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_learning_back_button.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/home/presentation/home_controller.dart';
import 'package:aia_mobile/features/home/presentation/home_screen.dart';
import 'package:aia_mobile/features/home/presentation/widgets/contract_banner.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_progress_controller.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_progress_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_progress_strings.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_progress_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../home/fake_home_dashboard_repository.dart';
import '../junior_home/fake_junior_progress_repository.dart';
import 'fake_contract_repository.dart';

/// Contract status after the signing flow and on return from the contract
/// list (Issue #322): the list reloads when a sign flow it pushed closes,
/// and the Home and Junior "Сурлагын явц" banners re-read their status alone
/// when the student comes back from the list. Fakes only; the production
/// list still offers no signing. Test values only.
void main() {
  // The app's own fonts, so the header's back button is where it really is.
  setUpAll(loadAppFonts);

  const unsigned = ContractStatus(signed: false);
  const signedStatus = ContractStatus(signed: true);

  const pendingContract = StudentContract(
    id: '12',
    status: StudentContractStatus.pending,
    canSign: true,
    canView: true,
    isCurrent: true,
    course: ContractCourse(titleEn: 'Test Course', level: 'adult'),
    cohort: ContractCohort(name: 'Test Cohort'),
  );
  const signedContract = StudentContract(
    id: '12',
    status: StudentContractStatus.signed,
    canView: true,
    isCurrent: true,
    documentUrl: '/me/contracts/12/download',
    course: ContractCourse(titleEn: 'Test Course', level: 'adult'),
    cohort: ContractCohort(name: 'Test Cohort'),
  );

  /// The header's back circle, not its full-width row.
  Future<void> tapBack(WidgetTester tester) async {
    await tester.tap(
      find
          .descendant(
            of: find.byType(CourseLearningBackButton),
            matching: find.byType(InkWell),
          )
          .last,
    );
    await tester.pumpAndSettle();
  }

  group('HomeController.refreshContract', () {
    HomeDashboard dashboard({ContractStatus? contract = unsigned}) =>
        HomeDashboard(
          program: sampleProgram(),
          contract: contract,
          stats: const [
            PaymentStat(PaymentStatus.dueIn(3), layout: HomeStatLayout.row),
          ],
        );

    test(
      'swaps the banner alone: one notice call, no dashboard reload',
      () async {
        final repository = FakeHomeDashboardRepository(dashboard: dashboard());
        final controller = HomeController(repository: repository);
        addTearDown(controller.dispose);
        await controller.load();
        final before = controller.dashboard!;

        repository.contractNotice = () => signedStatus;
        await controller.refreshContract();

        final after = controller.dashboard!;
        expect(after.contract?.signed, isTrue);
        expect(identical(after.program, before.program), isTrue);
        expect(identical(after.stats, before.stats), isTrue);
        expect(repository.callCount, 1);
        expect(repository.contractNoticeCalls, 1);
      },
    );

    test('no notice any more: the banner goes, the dashboard stays', () async {
      final repository = FakeHomeDashboardRepository(dashboard: dashboard());
      final controller = HomeController(repository: repository);
      addTearDown(controller.dispose);
      await controller.load();

      repository.contractNotice = () => null;
      // `null` from the notice must win over the dashboard's own contract.
      repository.dashboard = dashboard(contract: null);
      await controller.refreshContract();

      expect(controller.dashboard?.contract, isNull);
      expect(controller.dashboard?.program, isNotNull);
    });

    test('a failure keeps the banner as it was', () async {
      final repository = FakeHomeDashboardRepository(dashboard: dashboard());
      final controller = HomeController(repository: repository);
      addTearDown(controller.dispose);
      await controller.load();

      repository.contractNoticeFailure = StateError('offline');
      await controller.refreshContract();

      expect(controller.dashboard?.contract?.signed, isFalse);
      expect(controller.errorMessage, isNull);
    });

    test('nothing before a dashboard, or while a load is in flight', () async {
      final repository = FakeHomeDashboardRepository(dashboard: dashboard());
      final controller = HomeController(repository: repository);
      addTearDown(controller.dispose);

      await controller.refreshContract();
      expect(repository.contractNoticeCalls, 0);

      await controller.load();
      repository.hold = true;
      final reload = controller.load();
      await controller.refreshContract();
      expect(repository.contractNoticeCalls, 0);
      repository.release();
      await reload;
    });

    test('nothing once disposed — the banner it served is gone', () async {
      final repository = FakeHomeDashboardRepository(dashboard: dashboard());
      final controller = HomeController(repository: repository);
      await controller.load();
      controller.dispose();

      await controller.refreshContract();
      expect(repository.contractNoticeCalls, 0);
    });

    test('an answer after a load replaced the dashboard is dropped', () async {
      final repository = FakeHomeDashboardRepository(dashboard: dashboard());
      final controller = HomeController(repository: repository);
      addTearDown(controller.dispose);
      await controller.load();

      repository
        ..contractNotice = (() => signedStatus)
        ..contractNoticeGate = Completer<void>();
      final refresh = controller.refreshContract();
      // A newer dashboard — a new object, as every real load builds one —
      // still unsigned.
      repository.dashboard = dashboard();
      await controller.load();
      repository.contractNoticeGate!.complete();
      await refresh;

      expect(controller.dashboard?.contract?.signed, isFalse);
    });
  });

  group('JuniorProgressController.refreshContract', () {
    test(
      'swaps the banner alone and keeps the month the student paged to',
      () async {
        final repository = FakeJuniorProgressRepository(
          progress: figmaReferenceProgress(contract: unsigned),
        );
        final controller = JuniorProgressController(repository: repository);
        addTearDown(controller.dispose);
        await controller.load();
        controller.showNextMonth();
        final month = controller.displayedMonth;

        repository.contractNotice = () => signedStatus;
        await controller.refreshContract();

        expect(controller.progress?.contract?.signed, isTrue);
        expect(controller.displayedMonth, month);
        expect(repository.callCount, 1);
        expect(repository.contractNoticeCalls, 1);
      },
    );

    test('a failure keeps the banner; nothing before a first load', () async {
      final repository = FakeJuniorProgressRepository(
        progress: figmaReferenceProgress(contract: unsigned),
      );
      final controller = JuniorProgressController(repository: repository);
      addTearDown(controller.dispose);

      await controller.refreshContract();
      expect(repository.contractNoticeCalls, 0);

      await controller.load();
      repository.contractNoticeFailure = StateError('offline');
      await controller.refreshContract();
      expect(controller.progress?.contract?.signed, isFalse);
      expect(controller.errorMessage, isNull);
    });
  });

  group('ContractScreen reloads after a sign flow it pushed', () {
    Future<void> pumpList(
      WidgetTester tester,
      FakeContractRepository repository,
      FutureOr<void> Function(BuildContext, StudentContract) onSign,
    ) async {
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ContractScreen(repository: repository, onSign: onSign),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a flow route closes: the list loads again and shows it '
        'signed', (tester) async {
      final repository = FakeContractRepository(contracts: [pendingContract]);
      await pumpList(
        tester,
        repository,
        // A stand-in for the signing flow: a route the test closes.
        (context, contract) => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('signing flow')),
          ),
        ),
      );
      expect(find.text(ContractStrings.statusPending), findsOneWidget);

      await tester.tap(find.text(ContractStrings.sign));
      await tester.pumpAndSettle();
      expect(find.text('signing flow'), findsOneWidget);

      repository.contracts = [signedContract];
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      expect(repository.callCount, 2);
      expect(find.text(ContractStrings.statusSigned), findsOneWidget);
      expect(find.text(ContractStrings.statusPending), findsNothing);
    });

    testWidgets('an onSign that hands back no future reloads nothing', (
      tester,
    ) async {
      final repository = FakeContractRepository(contracts: [pendingContract]);
      var taps = 0;
      await pumpList(tester, repository, (_, _) => taps++);

      await tester.tap(find.text(ContractStrings.sign));
      await tester.pumpAndSettle();

      expect(taps, 1);
      expect(repository.callCount, 1);
    });

    testWidgets('production: ContractScreen.open still offers no signing', (
      tester,
    ) async {
      final repository = FakeContractRepository(contracts: [pendingContract]);
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  ContractScreen.open(context, repository: repository),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(ContractScreen), findsOneWidget);
      expect(
        tester.widget<ContractScreen>(find.byType(ContractScreen)).onSign,
        isNull,
      );
      await tester.tap(find.text(ContractStrings.sign), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(ContractScreen), findsOneWidget);
      expect(repository.callCount, 1);
    });
  });

  group('the banners re-read their status on return from the list', () {
    Future<FakeHomeDashboardRepository> pumpHome(WidgetTester tester) async {
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      final repository = FakeHomeDashboardRepository(
        dashboard: HomeDashboard(program: sampleProgram(), contract: unsigned),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: HomeScreen(
            repository: repository,
            clock: () => DateTime(2026, 4, 8, 7),
            contractRepository: FakeContractRepository(
              contracts: [signedContract],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repository;
    }

    testWidgets('Home: signed meanwhile — the banner goes, nothing else is '
        'reloaded', (tester) async {
      final repository = await pumpHome(tester);
      expect(find.byType(ContractBanner), findsOneWidget);

      await tester.tap(find.byType(ContractBanner));
      await tester.pumpAndSettle();
      expect(find.byType(ContractScreen), findsOneWidget);

      repository.contractNotice = () => signedStatus;
      await tapBack(tester);

      expect(find.byType(ContractScreen), findsNothing);
      expect(find.byType(ContractBanner), findsNothing);
      expect(repository.contractNoticeCalls, 1);
      expect(repository.callCount, 1, reason: 'no dashboard reload');
    });

    testWidgets('Home: a failed refresh keeps the banner', (tester) async {
      final repository = await pumpHome(tester);
      await tester.tap(find.byType(ContractBanner));
      await tester.pumpAndSettle();

      repository.contractNoticeFailure = StateError('offline');
      await tapBack(tester);

      expect(find.byType(ContractBanner), findsOneWidget);
      expect(repository.contractNoticeCalls, 1);
    });

    testWidgets('Junior Progress: signed meanwhile — the banner goes and the '
        'calendar keeps its month', (tester) async {
      useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
      final repository = FakeJuniorProgressRepository(
        progress: figmaReferenceProgress(contract: unsigned),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: JuniorProgressScreen(
            repository: repository,
            contractRepository: FakeContractRepository(
              contracts: [signedContract],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel(JuniorProgressStrings.nextMonth));
      await tester.pumpAndSettle();
      final month = tester
          .widget<JuniorProgressCalendar>(find.byType(JuniorProgressCalendar))
          .month;

      await tester.ensureVisible(
        find.text(JuniorProgressStrings.contractTitle),
      );
      await tester.tap(find.text(JuniorProgressStrings.contractTitle));
      await tester.pumpAndSettle();
      expect(find.byType(ContractScreen), findsOneWidget);

      repository.contractNotice = () => signedStatus;
      await tapBack(tester);

      expect(find.text(JuniorProgressStrings.contractTitle), findsNothing);
      expect(
        tester
            .widget<JuniorProgressCalendar>(find.byType(JuniorProgressCalendar))
            .month,
        month,
      );
      expect(repository.callCount, 1, reason: 'no progress reload');
      expect(repository.contractNoticeCalls, 1);
    });
  });
}
