import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_request_controller.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_request_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_confirmation_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_schedule_change_repository.dart';

/// "Багш нар" sending a schedule-change request (Issue #449): the copy for
/// each documented refusal, the controller, and the live screen — on a fake
/// repository only, so nothing reaches the network.
void main() {
  const sessionId = 41;

  TeacherFailure refused(String? code) =>
      TeacherFailure(TeacherFailureKind.rejected, code: code);

  group('requestFailure copy', () {
    test('each documented code has its own line', () {
      final lines = {
        'recipient_busy': TeacherScheduleStrings.requestRecipientBusy,
        'request_pending': TeacherScheduleStrings.requestAlreadyPending,
        'session_already_covered': TeacherScheduleStrings.requestSessionCovered,
        'session_started': TeacherScheduleStrings.requestSessionStarted,
        'session_not_found': TeacherScheduleStrings.requestSessionNotFound,
        'recipient_not_found': TeacherScheduleStrings.requestRecipientNotFound,
      };
      for (final entry in lines.entries) {
        expect(
          TeacherScheduleStrings.requestFailure(refused(entry.key)),
          entry.value,
          reason: entry.key,
        );
      }
      expect(lines.values.toSet(), hasLength(lines.length));
    });

    test('a refusal with no code — a backend without these routes — is the '
        'unavailable line', () {
      expect(
        TeacherScheduleStrings.requestFailure(refused(null)),
        TeacherScheduleStrings.requestsUnavailable,
      );
    });

    test('any other failure is the shared line for its kind', () {
      expect(
        TeacherScheduleStrings.requestFailure(
          const TeacherFailure(TeacherFailureKind.network),
        ),
        HomeStrings.networkError,
      );
      expect(
        TeacherScheduleStrings.requestFailure(
          const TeacherFailure(TeacherFailureKind.sessionExpired),
        ),
        HomeStrings.sessionExpired,
      );
      expect(
        TeacherScheduleStrings.requestFailure(refused('cannot_request_self')),
        TeacherHomeStrings.messageFor(TeacherFailureKind.rejected),
      );
    });
  });

  group('TeacherRequestController', () {
    TeacherRequestController controllerFor(FakeScheduleChangeRepository r) =>
        TeacherRequestController(repository: r, sessionId: sessionId);

    test('loads the session\'s eligible teachers, each not sent yet', () async {
      final repository = FakeScheduleChangeRepository(
        teachers: sampleEligibleTeachers,
      );
      final controller = controllerFor(repository);

      await controller.load();

      expect(repository.loadCalls, [sessionId]);
      expect([for (final t in controller.teachers) t.id], [5, 8]);
      expect(controller.statusOf(5), TeacherRequestStatus.notSent);
      expect(controller.loadError, isNull);
    });

    test('a failed read keeps no teachers and says why', () async {
      final controller = controllerFor(
        FakeScheduleChangeRepository(loadFailure: refused('session_started')),
      );

      await controller.load();

      expect(controller.teachers, isEmpty);
      expect(
        controller.loadError,
        TeacherScheduleStrings.requestSessionStarted,
      );
    });

    test('a confirmed send marks only that teacher pending', () async {
      final repository = FakeScheduleChangeRepository(
        teachers: sampleEligibleTeachers,
      );
      final controller = controllerFor(repository);
      await controller.load();

      final outcome = await controller.send(5);

      expect(outcome, isA<TeacherRequestSent>());
      expect(repository.sendCalls, [(sessionId, 5)]);
      expect(controller.statusOf(5), TeacherRequestStatus.pending);
      expect(controller.statusOf(8), TeacherRequestStatus.notSent);
    });

    test(
      'a refused send is its copy, and the teacher stays not sent',
      () async {
        final controller = controllerFor(
          FakeScheduleChangeRepository(
            teachers: sampleEligibleTeachers,
            sendFailure: refused('recipient_busy'),
          ),
        );
        await controller.load();

        final outcome = await controller.send(5);

        expect(outcome, isA<TeacherRequestFailed>());
        expect(
          (outcome as TeacherRequestFailed).message,
          TeacherScheduleStrings.requestRecipientBusy,
        );
        expect(controller.statusOf(5), TeacherRequestStatus.notSent);
      },
    );

    test('a second send while one is in flight sends nothing', () async {
      final repository = FakeScheduleChangeRepository(
        teachers: sampleEligibleTeachers,
        holdSend: true,
      );
      final controller = controllerFor(repository);
      await controller.load();

      final first = controller.send(5);
      expect(controller.sendingTeacherId, 5);
      expect(await controller.send(8), isA<TeacherRequestIgnored>());
      expect(await controller.send(5), isA<TeacherRequestIgnored>());

      repository.releaseSend();
      expect(await first, isA<TeacherRequestSent>());
      expect(repository.sendCalls, [(sessionId, 5)]);
      expect(controller.sendingTeacherId, isNull);
    });

    test('a teacher already confirmed is not sent to again', () async {
      final repository = FakeScheduleChangeRepository(
        teachers: sampleEligibleTeachers,
      );
      final controller = controllerFor(repository);
      await controller.load();
      await controller.send(5);

      expect(await controller.send(5), isA<TeacherRequestIgnored>());
      expect(repository.sendCalls, hasLength(1));
    });
  });

  group('"Багш нар" (TeacherScheduleChangeScreen)', () {
    Future<void> pumpScreen(
      WidgetTester tester,
      FakeScheduleChangeRepository repository,
    ) async {
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: TeacherScheduleChangeScreen(
            sessionId: sessionId,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder sendPill() => find.text(TeacherScheduleStrings.requestSend);

    testWidgets('lists the server\'s eligible teachers, each with "Хүсэлт '
        'илгээх"', (tester) async {
      await pumpScreen(
        tester,
        FakeScheduleChangeRepository(teachers: sampleEligibleTeachers),
      );

      expect(find.byType(TeacherRequestRow), findsNWidgets(2));
      expect(find.text('Болд Бат'), findsOneWidget);
      expect(find.text('Сараа Ганбат'), findsOneWidget);
      expect(sendPill(), findsNWidgets(2));
    });

    testWidgets('an empty list says no teacher is free, not unavailable', (
      tester,
    ) async {
      await pumpScreen(tester, FakeScheduleChangeRepository());

      expect(find.text(TeacherScheduleStrings.requestsEmpty), findsOneWidget);
      expect(
        find.text(TeacherScheduleStrings.requestsUnavailable),
        findsNothing,
      );
      expect(find.byType(TeacherRequestRow), findsNothing);
    });

    testWidgets('a backend without these routes reads as unavailable — '
        'never an empty list', (tester) async {
      await pumpScreen(
        tester,
        FakeScheduleChangeRepository(
          teachers: sampleEligibleTeachers,
          loadFailure: refused(null),
        ),
      );

      expect(
        find.text(TeacherScheduleStrings.requestsUnavailable),
        findsOneWidget,
      );
      expect(find.text(TeacherScheduleStrings.requestsEmpty), findsNothing);
      expect(find.byType(TeacherRequestRow), findsNothing);
    });

    testWidgets('a failed read shows its copy and retries', (tester) async {
      final repository = FakeScheduleChangeRepository(
        teachers: sampleEligibleTeachers,
        loadFailure: const TeacherFailure(TeacherFailureKind.network),
      );
      await pumpScreen(tester, repository);
      expect(find.text(HomeStrings.networkError), findsOneWidget);

      repository.loadFailure = null;
      await tester.tap(find.text(TeacherHomeStrings.retry));
      await tester.pumpAndSettle();

      expect(repository.loadCalls, [sessionId, sessionId]);
      expect(find.byType(TeacherRequestRow), findsNWidgets(2));
    });

    testWidgets('"Хүсэлт илгээгдлээ" shows only once the server confirms, '
        'and the row then reads "Хүлээгдэж байна"', (tester) async {
      final repository = FakeScheduleChangeRepository(
        teachers: sampleEligibleTeachers,
        holdSend: true,
      );
      await pumpScreen(tester, repository);

      await tester.tap(sendPill().first);
      await tester.pump();
      // In flight: no acknowledgement, no pending row yet.
      expect(find.byType(TeacherConfirmationCard), findsNothing);
      expect(find.text(TeacherScheduleStrings.requestPending), findsNothing);

      repository.releaseSend();
      await tester.pumpAndSettle();

      expect(repository.sendCalls, [(sessionId, 5)]);
      expect(find.byType(TeacherConfirmationCard), findsOneWidget);
      expect(
        find.text(TeacherScheduleStrings.requestSentTitle),
        findsOneWidget,
      );

      await tester.tap(find.text(TeacherScheduleStrings.requestSentDismiss));
      await tester.pumpAndSettle();
      expect(find.byType(TeacherConfirmationCard), findsNothing);
      expect(find.text(TeacherScheduleStrings.requestPending), findsOneWidget);
      expect(sendPill(), findsOneWidget);
    });

    testWidgets('a double tap while sending sends once', (tester) async {
      final repository = FakeScheduleChangeRepository(
        teachers: sampleEligibleTeachers,
        holdSend: true,
      );
      await pumpScreen(tester, repository);

      await tester.tap(sendPill().first);
      await tester.pump();
      await tester.tap(sendPill().first);
      await tester.tap(sendPill().last);
      await tester.pump();
      repository.releaseSend();
      await tester.pumpAndSettle();

      expect(repository.sendCalls, [(sessionId, 5)]);
    });

    for (final (code, line) in [
      ('recipient_busy', TeacherScheduleStrings.requestRecipientBusy),
      ('request_pending', TeacherScheduleStrings.requestAlreadyPending),
      ('session_already_covered', TeacherScheduleStrings.requestSessionCovered),
      ('session_started', TeacherScheduleStrings.requestSessionStarted),
      ('session_not_found', TeacherScheduleStrings.requestSessionNotFound),
      ('recipient_not_found', TeacherScheduleStrings.requestRecipientNotFound),
      (null, TeacherScheduleStrings.requestsUnavailable),
    ]) {
      testWidgets('a send refused with ${code ?? 'no code'} shows its line '
          'and no acknowledgement', (tester) async {
        await pumpScreen(
          tester,
          FakeScheduleChangeRepository(
            teachers: sampleEligibleTeachers,
            sendFailure: refused(code),
          ),
        );

        await tester.tap(sendPill().first);
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text(line), findsOneWidget);
        expect(find.byType(TeacherConfirmationCard), findsNothing);
        expect(find.text(TeacherScheduleStrings.requestPending), findsNothing);
        expect(sendPill(), findsNWidgets(2));
      });
    }

    testWidgets('network and session failures on send show their lines', (
      tester,
    ) async {
      final repository = FakeScheduleChangeRepository(
        teachers: sampleEligibleTeachers,
        sendFailure: const TeacherFailure(TeacherFailureKind.network),
      );
      await pumpScreen(tester, repository);

      await tester.tap(sendPill().first);
      await tester.pumpAndSettle();
      expect(find.text(HomeStrings.networkError), findsOneWidget);

      ScaffoldMessenger.of(
        tester.element(find.byType(TeacherRequestScreen)),
      ).removeCurrentSnackBar();
      repository.sendFailure = const TeacherFailure(
        TeacherFailureKind.sessionExpired,
      );
      await tester.tap(sendPill().first);
      await tester.pumpAndSettle();
      expect(find.text(HomeStrings.sessionExpired), findsOneWidget);
      expect(find.byType(TeacherConfirmationCard), findsNothing);
    });
  });
}
