import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../payments/domain/payment_checkout.dart';
import '../widgets/home_palette.dart';
import 'payment_flow_strings.dart';
import 'payment_flow_widgets.dart';

/// "eBarimt · Баримт" — the receipt at the end of the Adult payment flow
/// (Issue #198, reference 9).
///
/// UI only: the [receipt] is fixture data, the QR is the reference's own
/// image, and "Татаж авах" is drawn live but leads nowhere — there is no
/// receipt file or eBarimt integration to download from.
class EbarimtReceiptScreen extends StatelessWidget {
  const EbarimtReceiptScreen({required this.receipt, super.key});

  final PaymentReceipt receipt;

  static void _noFileYet() {}

  @override
  Widget build(BuildContext context) {
    return PaymentFlowScaffold(
      action: PaymentFlowStrings.download,
      onAction: _noFileYet,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.screenPadding,
              17.87,
              AppDimens.screenPadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                paymentFlowText(
                  PaymentFlowStrings.receiptTitle,
                  size: 16,
                  box: 22,
                  weight: FontWeight.w700,
                  header: true,
                ),
                const SizedBox(height: 17.27),
                paymentFlowText(
                  PaymentFlowStrings.transaction(receipt.transactionId),
                  size: 14,
                  box: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 8.13),
                paymentFlowText(
                  PaymentFlowStrings.date(receipt.dateLabel),
                  size: 14,
                  box: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 7.95),
                paymentFlowText(
                  PaymentFlowStrings.vatIncluded,
                  size: 14,
                  box: 20,
                  color: HomePalette.activeInk,
                ),
                const SizedBox(height: 23.28),
                const PaymentFlowRule(color: HomePalette.headerRule),
                const SizedBox(height: 24.34),
                paymentFlowText(
                  PaymentFlowStrings.qrTitle,
                  size: 16,
                  box: 22,
                  weight: FontWeight.w700,
                  align: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 29),
          Center(
            child: Semantics(
              image: true,
              label: PaymentFlowStrings.qrTitle,
              child: Image.asset(
                PaymentFlowAssets.ebarimtQr,
                width: 237,
                height: 237,
                filterQuality: FilterQuality.none,
                excludeFromSemantics: true,
              ),
            ),
          ),
          const SizedBox(height: 26.34),
          _CopyField(
            label: PaymentFlowStrings.lottery,
            value: receipt.lotteryNumber,
          ),
          const SizedBox(height: 15.22),
          _CopyField(label: PaymentFlowStrings.ddtd, value: receipt.ddtd),
          const SizedBox(height: 14.82),
          const PaymentFlowRule(color: HomePalette.headerRule),
        ],
      ),
    );
  }
}

/// A caption over a bold value, with the copy control on the right.
class _CopyField extends StatelessWidget {
  const _CopyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.screenPadding),
      child: SizedBox(
        height: 44.5,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: PaymentCopyButton.size + 8,
              top: 0,
              child: paymentFlowText(
                label,
                size: 14,
                box: 20,
                color: AppColors.textSecondary,
              ),
            ),
            Positioned(
              left: 0,
              right: PaymentCopyButton.size + 8,
              top: 24.16,
              child: paymentFlowText(
                value,
                size: 14,
                box: 20,
                weight: FontWeight.w700,
              ),
            ),
            Positioned(
              right: 0,
              top: 4.0,
              child: PaymentCopyButton(value: value, label: label),
            ),
          ],
        ),
      ),
    );
  }
}
