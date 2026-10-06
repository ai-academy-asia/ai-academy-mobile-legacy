import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/home/presentation/payment_previews.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';

/// Deterministic captures of the Adult Payment screen ("Төлбөр"), one per
/// Figma reference and in the references' own order (Issue #196): 1 partly
/// paid, 2 paid off, 3 overdue. The references are 1179×2838 — 3x the
/// 393×946 frame — so a reference pixel divided by 3 is a point here.
///
/// Each capture is the screen fed its temporary UI fixture and that
/// reference's own row placement (`PaymentPreviews`). Manrope renders about
/// 1–2% wider here than in Figma; that is left as is.
///
/// Run `flutter test --update-goldens <this file>` to refresh, then compare
/// `test/goldens/payment_*.png` against the references.
void main() {
  setUpAll(loadAppFonts);

  for (final (name, preview) in [
    ('payment_1_partly_paid', PaymentPreviews.partlyPaid),
    ('payment_2_paid_off', PaymentPreviews.paidOff),
    ('payment_3_overdue', PaymentPreviews.overdue),
  ]) {
    testWidgets('Payment at reference $name', (tester) async {
      useLogicalViewport(tester, const Size(393, 946), padding: iPhonePadding);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          home: preview.screen(),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/$name.png'),
      );
    });
  }
}
