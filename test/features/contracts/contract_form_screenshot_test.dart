import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/contracts/domain/contract_detail.dart';
import 'package:aia_mobile/features/contracts/domain/student_contract.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_form_screen.dart';
import 'package:aia_mobile/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_contract_repository.dart';

/// Deterministic captures of the E-Contract form (Issue #314), in light and
/// dark. No frame draws the form, so these record the app's own layout for
/// review, not a match to a design. A junior contract with a balance owed
/// shows every section; Continue has been pressed on the backend-style
/// prefill, so the missing fields show their errors. 393 wide, tall enough
/// for the whole form at 1:1. Test values only.
///
/// Run `flutter test --update-goldens <this file>` to refresh.
void main() {
  setUpAll(loadAppFonts);

  final detail = ContractDetail(
    contract: const StudentContract(
      id: '12',
      status: StudentContractStatus.pending,
      canSign: true,
      canView: true,
      isCurrent: true,
    ),
    form: const ContractForm(
      lastName: 'Тест',
      firstName: 'Сурагч',
      phone: '00000000',
      email: 'student@example.test',
    ),
    rules: ContractRules(
      guardianRequired: true,
      finalPaymentDateRequired: true,
      finalPaymentDateMin: DateTime(2026, 10, 10),
      finalPaymentDateMax: DateTime(2026, 10, 30),
    ),
    finance: const ContractFinance(
      totalDue: 1000000,
      totalPaid: 0,
      balance: 1000000,
      discountPercent: 0,
      currency: 'MNT',
    ),
    document: const ContractDocument(format: 'pdf'),
  );

  for (final (name, theme) in [
    ('contract_form_errors', AppTheme.light),
    ('contract_form_errors_dark', AppTheme.dark),
  ]) {
    testWidgets(name, (tester) async {
      useLogicalViewport(tester, const Size(393, 1420), padding: iPhonePadding);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          home: ContractFormScreen(
            contractId: '12',
            repository: FakeContractRepository(detail: detail),
            onContinue: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/$name.png'),
      );
    });
  }
}
