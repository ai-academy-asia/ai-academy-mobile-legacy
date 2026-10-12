import 'package:aia_mobile/features/contracts/presentation/contract_screen.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/back_button_header.dart';
import '../../support/screenshot.dart';
import 'fake_contract_repository.dart';

/// The E-Contract header's back button stays reachable at every width and
/// text size (Issue #318) — now the shared `BackTitleHeader` (Issue #327),
/// checked on the real list screen with the same grid as the Certificate
/// and Notification screens, up to 3.0× (it stopped at 2.0× before). Before
/// #318 the centred title lay over the button and took its taps: part of
/// the circle at 320 wide and 1.5×, all of it at 2.0× on both widths.
void main() {
  setUpAll(loadAppFonts);

  backButtonHeaderChecks(
    title: ContractStrings.title,
    // 1.3× kept from this file's earlier grid.
    scales: const [1.0, 1.3, 1.5, 2.0, 2.5, 3.0],
    // The real list, with nothing in it — the header is the subject.
    screen: () => ContractScreen(repository: FakeContractRepository()),
  );
}
