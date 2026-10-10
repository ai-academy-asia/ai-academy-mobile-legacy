import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/contracts/domain/student_contract.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_contract_repository.dart';

/// Deterministic captures of the E-Contract list (Issue #312) at the
/// export's 393 × 854, 1:1 — a signed card over a pending one, as
/// `e-contract1.png` draws them — in light and dark. The cards carry test
/// values, not the export's sample names.
///
/// Run `flutter test --update-goldens <this file>` to refresh.
void main() {
  setUpAll(loadAppFonts);

  const contracts = [
    StudentContract(
      id: '1',
      status: StudentContractStatus.signed,
      course: ContractCourse(titleEn: 'Test Course One', level: 'adult'),
      cohort: ContractCohort(name: 'Test Cohort A'),
      documentUrl: '/me/contracts/1/download',
    ),
    StudentContract(
      id: '2',
      status: StudentContractStatus.pending,
      canSign: true,
      course: ContractCourse(titleEn: 'Test Course Two', level: 'adult'),
      cohort: ContractCohort(name: 'Test Cohort B'),
    ),
  ];

  for (final (name, theme) in [
    ('contract_list', AppTheme.light),
    ('contract_list_dark', AppTheme.dark),
  ]) {
    testWidgets(name, (tester) async {
      useLogicalViewport(tester, const Size(393, 854), padding: iPhonePadding);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          home: ContractScreen(
            repository: FakeContractRepository(contracts: contracts),
            // As if a signing screen existed, so the pending action draws
            // enabled as the export shows it.
            onSign: (_, _) {},
          ),
        ),
      );
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
