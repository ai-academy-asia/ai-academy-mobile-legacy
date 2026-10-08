import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../payments/domain/payment_checkout.dart';
import '../payment_strings.dart';
import 'ebarimt_receipt_screen.dart';
import 'payment_flow_strings.dart';
import 'payment_flow_widgets.dart';
import 'payment_sheets.dart';
import 'payment_success_dialog.dart';

/// "Төлбөр төлөх" — the method step of the Adult payment flow (Issue #198,
/// references 4–7): the installment being paid and the four ways to pay.
///
/// "Шилжүүлэх" opens the bank sheet ([BankSelectSheet]); choosing a bank
/// shows its transfer details in a second sheet ([BankTransferSheet]), and
/// closing that leaves "Шилжүүлэх" selected with the details under the
/// methods (reference 7). The references draw Qpay still selected behind
/// both sheets, so the selection moves only once the details are closed.
/// "Төлбөр шалгах" shows the success dialog, then the eBarimt receipt.
///
/// UI only: nothing is paid, checked or fetched — every value comes from
/// the [checkout] fixture.
class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({
    required this.checkout,
    super.key,
    this.initialMethod = PaymentMethod.qpay,
    this.initialTransferShown = false,
  });

  final PaymentCheckout checkout;
  final PaymentMethod initialMethod;

  /// Starts on reference 7 — for drawing it at rest.
  final bool initialTransferShown;

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  late PaymentMethod _method = widget.initialMethod;
  late bool _transferShown = widget.initialTransferShown;

  Future<void> _onTap(PaymentMethod method) async {
    if (method != PaymentMethod.transfer) {
      setState(() {
        _method = method;
        _transferShown = false;
      });
      return;
    }
    if (_transferShown) return;
    final bank = await showPaymentSheet<PaymentBank>(
      context,
      (_) => BankSelectSheet(banks: widget.checkout.banks),
    );
    if (bank == null || !mounted) return;
    await showPaymentSheet<void>(
      context,
      (_) => BankTransferSheet(details: widget.checkout.transfer),
    );
    if (!mounted) return;
    setState(() {
      _method = PaymentMethod.transfer;
      _transferShown = true;
    });
  }

  Future<void> _check() async {
    final navigator = Navigator.of(context);
    await showPaymentSuccessDialog(context);
    if (!mounted) return;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => EbarimtReceiptScreen(receipt: widget.checkout.receipt),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkout = widget.checkout;
    // The references draw two headers: reference 7's matches the amount
    // screen's, while the one behind the sheets sits 16pt higher with a
    // smaller amount. Each state keeps its own.
    final full = _transferShown;
    return PaymentFlowScaffold(
      title: PaymentFlowStrings.title,
      action: PaymentFlowStrings.check,
      onAction: _check,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimens.screenPadding,
              full ? 16.97 : 1.06,
              AppDimens.screenPadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                paymentFlowText(
                  PaymentFlowStrings.installment(checkout.installmentNumber),
                  size: 14,
                  box: 20,
                  color: context.palette.textSecondary,
                ),
                SizedBox(height: full ? 1.34 : 0.90),
                paymentFlowText(
                  PaymentStrings.amount(checkout.installmentAmount),
                  size: full ? 18 : 16,
                  box: full ? 24 : 22,
                  weight: FontWeight.w700,
                ),
              ],
            ),
          ),
          SizedBox(height: full ? 15.69 : 16.04),
          const PaymentFlowRule(),
          const SizedBox(height: 16),
          PaymentMethodCard(
            methods: PaymentMethod.values,
            selected: _method,
            onTap: _onTap,
            footer: _transferShown
                ? BankTransferDetailsView(
                    details: checkout.transfer,
                    bottom: 31.56,
                  )
                : null,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
