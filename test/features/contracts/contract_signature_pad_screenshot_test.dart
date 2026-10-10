import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_strings.dart';
import 'package:aia_mobile/features/contracts/presentation/widgets/contract_signature_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';

/// Deterministic captures of the E-Contract signature section (Issue #304)
/// at 393 wide, 1:1 — empty and signed in light, signed in dark — for
/// comparing against the supplied signing-screen screenshot's lower half.
/// The stroke is a fixed test gesture, not the screenshot's signature.
///
/// Run `flutter test --update-goldens <this file>` to refresh.
void main() {
  setUpAll(loadAppFonts);

  for (final (name, theme, signed) in [
    ('contract_signature_pad_empty', AppTheme.light, false),
    ('contract_signature_pad_signed', AppTheme.light, true),
    ('contract_signature_pad_signed_dark', AppTheme.dark, true),
  ]) {
    testWidgets(name, (tester) async {
      final controller = ContractSignatureController();
      addTearDown(controller.dispose);
      useLogicalViewport(tester, const Size(393, 300));
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: ContractSignaturePad(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      if (signed) {
        final pad = tester.getRect(
          find.bySemanticsLabel(ContractStrings.signHere),
        );
        final start = pad.center + const Offset(-100, 10);
        final gesture = await tester.startGesture(start);
        for (final step in const [
          Offset(20, -25),
          Offset(20, 20),
          Offset(15, 15),
          Offset(20, -30),
          Offset(25, 10),
          Offset(30, 5),
        ]) {
          await gesture.moveBy(step);
        }
        await gesture.up();
        await tester.pumpAndSettle();
      }

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/$name.png'),
      );
    });
  }
}
