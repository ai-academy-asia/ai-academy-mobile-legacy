import 'package:flutter/material.dart';

import '../widgets/home_pill_button.dart';
import 'payment_flow_strings.dart';
import 'payment_flow_widgets.dart';
import '../../../../core/theme/app_palette.dart';

/// Shows [PaymentSuccessDialog] and completes once "Ойлголоо" closes it.
///
/// The reference is the dialog alone, so what lies behind it is not drawn:
/// the barrier is the sheets' 60% black.
Future<void> showPaymentSuccessDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: context.palette.barrier,
    builder: (_) => const PaymentSuccessDialog(),
  );
}

/// "Төлбөр амжилттай төлөгдлөө" (Issue #198, reference 8). Shown straight
/// after "Төлбөр шалгах": nothing is checked — there is no payment to check
/// and no "checking" frame.
class PaymentSuccessDialog extends StatelessWidget {
  const PaymentSuccessDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      backgroundColor: context.palette.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: context.palette.divider, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 29, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.palette.successFillStrong,
                  border: Border.all(
                    color: context.palette.successInk,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: PaymentBoldGlyph(
                    PaymentGlyph.check,
                    color: context.palette.successInk,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22.1),
            paymentFlowText(
              PaymentFlowStrings.success,
              size: 18,
              box: 24,
              weight: FontWeight.w700,
              align: TextAlign.center,
              header: true,
            ),
            const SizedBox(height: 40.9),
            HomePillButton(
              label: PaymentFlowStrings.understood,
              height: 44,
              raised: false,
              labelSize: 16,
              labelWeight: FontWeight.w600,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
