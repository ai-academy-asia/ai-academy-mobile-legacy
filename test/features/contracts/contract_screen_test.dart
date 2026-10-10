import 'dart:async';

import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/domain/current_user_failure.dart';
import 'package:aia_mobile/features/contracts/domain/contract_detail.dart';
import 'package:aia_mobile/features/contracts/domain/contract_failure.dart';
import 'package:aia_mobile/features/contracts/domain/contract_repository.dart';
import 'package:aia_mobile/features/contracts/domain/student_contract.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_screen.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_strings.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_profile_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_profile_strings.dart';
import 'package:aia_mobile/features/profile/presentation/profile_screen.dart';
import 'package:aia_mobile/features/profile/presentation/profile_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../profile/fake_current_user_repository.dart';

/// Answers each `getContracts` from [answers] in turn: a list, a
/// [ContractFailure], or a [Completer] whose future is returned.
class _FakeContracts implements ContractRepository {
  _FakeContracts(this.answers);

  final List<Object> answers;
  int calls = 0;

  @override
  Future<List<StudentContract>> getContracts() async {
    final answer = answers[calls++ % answers.length];
    return switch (answer) {
      final List<StudentContract> list => list,
      final ContractFailure failure => throw failure,
      final Completer<List<StudentContract>> pending => pending.future,
      _ => throw StateError('unsupported answer'),
    };
  }

  // The list screen reads only the list (Issue #302 adds no UI).
  @override
  Future<ContractDetail> getContractDetail(String contractId) =>
      throw UnimplementedError();

  @override
  Future<ContractDetail> signContract(
    String contractId, {
    required ContractForm form,
    required bool agreed,
    required String signature,
  }) => throw UnimplementedError();

  @override
  Future<ContractDownload> getContractDownload(String contractId) =>
      throw UnimplementedError();
}

/// The E-Contract screen (Issue #294) and the two Profile rows that open it.
void main() {
  Future<void> pumpScreen(WidgetTester tester, _FakeContracts repository) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ContractScreen(repository: repository),
        ),
      );

  testWidgets('shows a loader until the list answers', (tester) async {
    final pending = Completer<List<StudentContract>>();
    await pumpScreen(tester, _FakeContracts([pending]));
    await tester.pump();

    expect(find.text(ContractStrings.title), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(const []);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('the verified empty list shows the empty line', (tester) async {
    await pumpScreen(tester, _FakeContracts([const <StudentContract>[]]));
    await tester.pumpAndSettle();

    expect(find.text(ContractStrings.empty), findsOneWidget);
    expect(find.text(ContractStrings.retry), findsNothing);
  });

  testWidgets('contracts that cannot be drawn show no invented title, status '
      'or date', (tester) async {
    await pumpScreen(
      tester,
      _FakeContracts([
        const [StudentContract(id: '12')],
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text(ContractStrings.notShownYet), findsOneWidget);
    expect(find.text(ContractStrings.empty), findsNothing);
    expect(find.text('12'), findsNothing);
    expect(find.textContaining('Гэрээ байгуулаагүй'), findsNothing);
  });

  testWidgets('a failure shows its message, and retry loads again', (
    tester,
  ) async {
    final repository = _FakeContracts([
      const ContractFailure(ContractFailureKind.network),
      const <StudentContract>[],
    ]);
    await pumpScreen(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text(ProfileStrings.networkError), findsOneWidget);

    await tester.tap(find.text(ContractStrings.retry));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text(ProfileStrings.networkError), findsNothing);
    expect(find.text(ContractStrings.empty), findsOneWidget);
  });

  test('each failure kind has its own message', () {
    expect(
      ContractStrings.messageFor(ContractFailureKind.sessionExpired),
      ProfileStrings.sessionExpired,
    );
    expect(
      ContractStrings.messageFor(ContractFailureKind.server),
      ProfileStrings.serverError,
    );
    expect(
      ContractStrings.messageFor(ContractFailureKind.unexpected),
      ProfileStrings.unexpectedError,
    );
  });

  group('entry points', () {
    final signedOut = FakeCurrentUserRepository(
      failure: const CurrentUserFailure(CurrentUserFailureKind.sessionExpired),
    );

    testWidgets('the Adult Profile\'s E-Contract row opens the screen', (
      tester,
    ) async {
      final repository = _FakeContracts([const <StudentContract>[]]);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ProfileScreen(
            repository: signedOut,
            contractRepository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(ProfileStrings.eContract));
      await tester.pumpAndSettle();

      expect(find.byType(ContractScreen), findsOneWidget);
      expect(repository.calls, 1);
      expect(find.text(ContractStrings.empty), findsOneWidget);
    });

    testWidgets('the Junior Profile\'s E-Contract row opens the same screen', (
      tester,
    ) async {
      final repository = _FakeContracts([const <StudentContract>[]]);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: JuniorProfileScreen(
            repository: signedOut,
            contractRepository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(JuniorProfileStrings.eContract));
      await tester.pumpAndSettle();

      expect(find.byType(ContractScreen), findsOneWidget);
      expect(repository.calls, 1);
    });
  });
}
