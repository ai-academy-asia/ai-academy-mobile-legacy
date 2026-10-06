import 'package:flutter/widgets.dart';

import '../../payments/data/payment_checkout_ui_fixtures.dart';
import '../../payments/data/payment_plan_ui_fixtures.dart';
import 'payment_flow/payment_amount_screen.dart';
import 'payment_screen.dart';

/// **TEMPORARY — for design review and tests only.** (Issue #196)
///
/// The three Figma "Төлбөр" references, each reproduced by a
/// [PaymentPlanUiFixtures] plan on the [PaymentScreen] with the reference's
/// own row placement. Opened from the Adult Home payment card outside release
/// builds only, and by the screenshot tests; never with a real student's
/// data. Removed once `/me/ledger` feeds the screen.
class PaymentPreview {
  const PaymentPreview._(this.fixture, this.rows);

  final PaymentPlanFixture fixture;

  /// The reference's own row placement — see [PaymentReferenceRows].
  final List<PaymentRowGeometry> rows;

  PaymentScreen screen() => PaymentScreen(
    plan: fixture.plan,
    today: fixture.today,
    rowGeometry: rows,
    payFlow: (_) => paymentFlowPreview(),
  );
}

abstract final class PaymentPreviews {
  /// Reference 1.
  static final PaymentPreview partlyPaid = PaymentPreview._(
    PaymentPlanUiFixtures.partlyPaid,
    PaymentReferenceRows.reference1,
  );

  /// Reference 2.
  static final PaymentPreview paidOff = PaymentPreview._(
    PaymentPlanUiFixtures.paidOff,
    PaymentReferenceRows.reference2,
  );

  /// Reference 3.
  static final PaymentPreview overdue = PaymentPreview._(
    PaymentPlanUiFixtures.overdue,
    PaymentReferenceRows.reference3,
  );
}

/// Where each reference places its schedule rows, measured at 1:1 — they do
/// not all agree, and each is reproduced as drawn (Figma is the source of
/// truth). Points from the row's left edge, 16pt in from the screen's.
abstract final class PaymentReferenceRows {
  /// Reference 1: amounts end at 313; the second row's badge sits 2pt
  /// further right and its amount and chevron 2pt further left.
  static const List<PaymentRowGeometry> reference1 = [
    PaymentRowGeometry(),
    PaymentRowGeometry(badgeLeft: 2, amountRight: 311, caretLeft: 335.67),
    PaymentRowGeometry(),
    PaymentRowGeometry(),
  ];

  /// Reference 2: every amount ends at 317.67.
  static const List<PaymentRowGeometry> reference2 = [
    PaymentRowGeometry(amountRight: 317.67),
    PaymentRowGeometry(amountRight: 317.67),
    PaymentRowGeometry(amountRight: 317.67),
    PaymentRowGeometry(amountRight: 317.67),
  ];

  /// Reference 3: amounts end at 317.67; the second row's badge sits 2pt
  /// further right, its amount 2pt further right and its chevron 2pt
  /// further left.
  static const List<PaymentRowGeometry> reference3 = [
    PaymentRowGeometry(amountRight: 317.67),
    PaymentRowGeometry(badgeLeft: 2, amountRight: 319.67, caretLeft: 335.67),
    PaymentRowGeometry(amountRight: 317.67),
    PaymentRowGeometry(amountRight: 317.67),
  ];
}

/// The preview a Home payment card opens: the overdue reference when the
/// card is overdue, the partly-paid one otherwise.
Widget paymentPreviewFor({required bool overdue}) =>
    (overdue ? PaymentPreviews.overdue : PaymentPreviews.partlyPaid).screen();

/// **TEMPORARY** (Issue #198): the payment flow on its UI fixtures, with the
/// slider placed as references 1–3 draw it.
PaymentAmountScreen paymentFlowPreview({
  num? amount,
  bool showTooltip = false,
}) => PaymentAmountScreen(
  checkout: PaymentCheckoutUiFixtures.checkout,
  scale: PaymentReferenceSlider.scale,
  initialAmount: amount,
  showTooltip: showTooltip,
);

/// Where references 1–3 put the slider's thumb: centred 12pt into the 361pt
/// track at 500,000₮, 119pt at 750,000₮, and on the track's end at
/// 1,500,000₮ — not evenly spread, and kept as drawn.
abstract final class PaymentReferenceSlider {
  static const PaymentSliderScale scale = PaymentSliderScale([
    (500000, 12 / 361),
    (750000, 119 / 361),
    (1500000, 1),
  ]);
}
