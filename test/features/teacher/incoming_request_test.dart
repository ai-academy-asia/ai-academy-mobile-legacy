import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:aia_mobile/features/teacher/presentation/incoming_request_controller.dart';
import 'package:aia_mobile/features/teacher/presentation/incoming_request_sheet.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_request_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_schedule_change_repository.dart';

/// Answering an incoming schedule-change request (Issue #453): the
/// controller and the sheet, on a fake repository only — nothing reaches
/// the network.
void main() {
  const requestId = 12;

  TeacherFailure refused(String? code) =>
      TeacherFailure(TeacherFailureKind.rejected, code: code);

  group('IncomingRequestController', () {
    Future<IncomingRequestController> loaded(
      FakeScheduleChangeRepository repository,
    ) async {
      final controller = IncomingRequestController(
        repository: repository,
        requestId: requestId,
      );
      await controller.load();
      return controller;
    }

    test('a pending request offers both answers', () async {
      final repository = FakeScheduleChangeRepository(
        request: sampleIncomingRequest(),
      );
      final controller = await loaded(repository);

      expect(repository.requestReads, [requestId]);
      expect(controller.showActions, isTrue);
      expect(controller.canAccept, isTrue);
      expect(controller.canReject, isTrue);
      expect(controller.message, isNull);
    });

    test('a resolved request — a stale notification — offers none, and '
        'says where it stands', () async {
      for (final (status, line) in [
        ('accepted', TeacherScheduleStrings.incomingAccepted),
        ('rejected', TeacherScheduleStrings.incomingRejected),
        ('cancelled', TeacherScheduleStrings.incomingCancelled),
        ('expired', TeacherScheduleStrings.incomingExpired),
      ]) {
        final controller = await loaded(
          FakeScheduleChangeRepository(
            request: sampleIncomingRequest(status: status),
          ),
        );
        expect(controller.showActions, isFalse, reason: status);
        expect(controller.canAccept, isFalse, reason: status);
        expect(controller.canReject, isFalse, reason: status);
        expect(controller.message, line, reason: status);
      }
    });

    test(
      'a request that cannot be read says why, with nothing to answer',
      () async {
        for (final (failure, line) in [
          (
            refused('request_not_found'),
            TeacherScheduleStrings.requestNotFound,
          ),
          (refused(null), TeacherScheduleStrings.requestsUnavailable),
          (
            const TeacherFailure(TeacherFailureKind.network),
            HomeStrings.networkError,
          ),
        ]) {
          final controller = await loaded(
            FakeScheduleChangeRepository(requestFailures: [failure]),
          );
          expect(controller.request, isNull);
          expect(controller.loadError, line);
          expect(controller.showActions, isFalse);
        }
      },
    );

    test('accept: only the server\'s accepted request resolves it, and '
        'nothing more can be sent', () async {
      final repository = FakeScheduleChangeRepository(
        request: sampleIncomingRequest(),
      );
      final controller = await loaded(repository);

      await controller.accept();

      expect(repository.decisions, [(requestId, 'accept', null)]);
      expect(controller.request!.status, 'accepted');
      expect(controller.showActions, isFalse);
      expect(controller.message, TeacherScheduleStrings.incomingAccepted);

      await controller.accept();
      await controller.reject();
      expect(repository.decisions, hasLength(1));
    });

    test('reject: no reason is sent, and the request is resolved', () async {
      final repository = FakeScheduleChangeRepository(
        request: sampleIncomingRequest(),
      );
      final controller = await loaded(repository);

      await controller.reject();

      expect(repository.decisions, [(requestId, 'reject', null)]);
      expect(controller.request!.status, 'rejected');
      expect(controller.showActions, isFalse);
      expect(controller.message, TeacherScheduleStrings.incomingRejected);
    });

    test('a second answer while one is in flight sends nothing', () async {
      final repository = FakeScheduleChangeRepository(
        request: sampleIncomingRequest(),
        holdDecision: true,
      );
      final controller = await loaded(repository);

      final first = controller.accept();
      expect(controller.busy, isTrue);
      expect(controller.canAccept, isFalse);
      expect(controller.canReject, isFalse);
      await controller.accept();
      await controller.reject();

      repository.releaseDecision();
      await first;
      expect(repository.decisions, [(requestId, 'accept', null)]);
      expect(controller.busy, isFalse);
    });

    test('request_already_resolved re-reads it and shows no actions', () async {
      final repository = FakeScheduleChangeRepository(
        request: sampleIncomingRequest(),
        decisionFailure: refused('request_already_resolved'),
      );
      final controller = await loaded(repository);
      // Elsewhere, meanwhile, the sender cancelled it.
      repository.request = sampleIncomingRequest(status: 'cancelled');

      await controller.accept();

      expect(repository.requestReads, [requestId, requestId]);
      expect(controller.request!.status, 'cancelled');
      expect(controller.showActions, isFalse);
      expect(controller.message, TeacherScheduleStrings.requestAlreadyResolved);
    });

    test('session_started re-reads it as expired', () async {
      final repository = FakeScheduleChangeRepository(
        request: sampleIncomingRequest(),
        decisionFailure: refused('session_started'),
      );
      final controller = await loaded(repository);
      repository.request = sampleIncomingRequest(status: 'expired');

      await controller.reject();

      expect(controller.request!.status, 'expired');
      expect(controller.showActions, isFalse);
      expect(controller.message, TeacherScheduleStrings.requestSessionStarted);
    });

    test('a failed re-read after a stale answer closes the actions', () async {
      final repository = FakeScheduleChangeRepository(
        request: sampleIncomingRequest(),
        decisionFailure: refused('request_already_resolved'),
      );
      final controller = await loaded(repository);
      repository.requestFailures = [
        const TeacherFailure(TeacherFailureKind.network),
      ];

      await controller.accept();

      expect(controller.showActions, isFalse);
      expect(controller.message, TeacherScheduleStrings.requestAlreadyResolved);
    });

    test('schedule_conflict and session_already_covered turn accept off, '
        'reject stays', () async {
      for (final (code, line) in [
        ('schedule_conflict', TeacherScheduleStrings.requestScheduleConflict),
        (
          'session_already_covered',
          TeacherScheduleStrings.requestSessionCovered,
        ),
      ]) {
        final repository = FakeScheduleChangeRepository(
          request: sampleIncomingRequest(),
          decisionFailure: refused(code),
        );
        final controller = await loaded(repository);

        await controller.accept();
        expect(controller.showActions, isTrue, reason: code);
        expect(controller.canAccept, isFalse, reason: code);
        expect(controller.canReject, isTrue, reason: code);
        expect(controller.message, line, reason: code);

        await controller.accept();
        expect(repository.decisions, hasLength(1), reason: code);
      }
    });

    test('not_recipient and request_not_found close the actions', () async {
      for (final (code, line) in [
        ('not_recipient', TeacherScheduleStrings.requestNotRecipient),
        ('request_not_found', TeacherScheduleStrings.requestNotFound),
      ]) {
        final controller = await loaded(
          FakeScheduleChangeRepository(
            request: sampleIncomingRequest(),
            decisionFailure: refused(code),
          ),
        );

        await controller.reject();
        expect(controller.showActions, isFalse, reason: code);
        expect(controller.message, line, reason: code);
      }
    });

    test('a network failure keeps the actions, for a retry', () async {
      final repository = FakeScheduleChangeRepository(
        request: sampleIncomingRequest(),
        decisionFailure: const TeacherFailure(TeacherFailureKind.network),
      );
      final controller = await loaded(repository);

      await controller.accept();
      expect(controller.canAccept, isTrue);
      expect(controller.message, HomeStrings.networkError);
      expect(controller.request!.status, 'pending');

      repository.decisionFailure = null;
      await controller.accept();
      expect(controller.request!.status, 'accepted');
      expect(controller.message, TeacherScheduleStrings.incomingAccepted);
    });
  });

  group('the sheet', () {
    Future<void> openSheet(
      WidgetTester tester,
      FakeScheduleChangeRepository repository,
    ) async {
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showIncomingScheduleChangeRequest(
                  context,
                  requestId: requestId,
                  repository: repository,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
    }

    Finder accept() => find.text(TeacherScheduleStrings.requestAccept);
    Finder decline() => find.text(TeacherScheduleStrings.requestDecline);

    testWidgets('a spinner while the request is read, then the request', (
      tester,
    ) async {
      await openSheet(
        tester,
        FakeScheduleChangeRepository(request: sampleIncomingRequest()),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(accept(), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byType(TeacherIncomingRequestSheet), findsOneWidget);
      expect(find.text('Анар Бат'), findsOneWidget);
      expect(find.text('Corporate Leaders'), findsOneWidget);
      expect(find.text('CL-2026-10'), findsOneWidget);
      expect(find.text('Room 204'), findsOneWidget);
      expect(find.text('10-р сарын 20 • 09:00-11:00'), findsOneWidget);
      expect(accept(), findsOneWidget);
      expect(decline(), findsOneWidget);
    });

    testWidgets('accepting shows the resolved status and no more actions', (
      tester,
    ) async {
      final repository = FakeScheduleChangeRepository(
        request: sampleIncomingRequest(),
      );
      await openSheet(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(accept());
      await tester.pumpAndSettle();

      expect(repository.decisions, [(requestId, 'accept', null)]);
      expect(
        find.text(TeacherScheduleStrings.incomingAccepted),
        findsOneWidget,
      );
      expect(accept(), findsNothing);
      expect(decline(), findsNothing);
    });

    testWidgets('rejecting shows the resolved status and no more actions', (
      tester,
    ) async {
      final repository = FakeScheduleChangeRepository(
        request: sampleIncomingRequest(),
      );
      await openSheet(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(decline());
      await tester.pumpAndSettle();

      expect(repository.decisions, [(requestId, 'reject', null)]);
      expect(
        find.text(TeacherScheduleStrings.incomingRejected),
        findsOneWidget,
      );
      expect(decline(), findsNothing);
    });

    testWidgets('a double tap while answering sends once', (tester) async {
      final repository = FakeScheduleChangeRepository(
        request: sampleIncomingRequest(),
        holdDecision: true,
      );
      await openSheet(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(accept());
      await tester.pump();
      await tester.tap(accept());
      await tester.tap(decline());
      await tester.pump();
      repository.releaseDecision();
      await tester.pumpAndSettle();

      expect(repository.decisions, [(requestId, 'accept', null)]);
    });

    testWidgets('a stale notification shows where it stands, no actions', (
      tester,
    ) async {
      await openSheet(
        tester,
        FakeScheduleChangeRepository(
          request: sampleIncomingRequest(status: 'expired'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(TeacherScheduleStrings.incomingExpired), findsOneWidget);
      expect(accept(), findsNothing);
      expect(decline(), findsNothing);
    });

    testWidgets('a missing or unauthorized request shows why, no actions', (
      tester,
    ) async {
      await openSheet(
        tester,
        FakeScheduleChangeRepository(
          requestFailures: [refused('request_not_found')],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(TeacherScheduleStrings.requestNotFound), findsOneWidget);
      expect(find.byType(TeacherIncomingRequestSheet), findsNothing);
      expect(accept(), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a conflict says why and leaves only reject live', (
      tester,
    ) async {
      final repository = FakeScheduleChangeRepository(
        request: sampleIncomingRequest(),
        decisionFailure: refused('schedule_conflict'),
      );
      await openSheet(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(accept());
      await tester.pumpAndSettle();
      expect(
        find.text(TeacherScheduleStrings.requestScheduleConflict),
        findsOneWidget,
      );
      // Accept is inert now; a tap sends nothing more.
      await tester.tap(accept());
      await tester.pumpAndSettle();
      expect(repository.decisions, hasLength(1));

      repository.decisionFailure = null;
      await tester.tap(decline());
      await tester.pumpAndSettle();
      expect(repository.decisions.last, (requestId, 'reject', null));
      expect(
        find.text(TeacherScheduleStrings.incomingRejected),
        findsOneWidget,
      );
    });

    testWidgets('a session with neither course title nor cohort name, and no '
        'times, still draws', (tester) async {
      await openSheet(
        tester,
        FakeScheduleChangeRepository(
          request: sampleIncomingRequest(
            courseTitle: null,
            cohortName: null,
            room: null,
            endTime: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(TeacherScheduleStrings.incomingUntitled),
        findsOneWidget,
      );
      expect(find.text('10-р сарын 20'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
