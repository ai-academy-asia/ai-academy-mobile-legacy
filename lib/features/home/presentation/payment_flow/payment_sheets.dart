import 'package:flutter/material.dart';

import '../../../payments/domain/payment_checkout.dart';
import 'payment_flow_widgets.dart';
import '../../../../core/theme/app_palette.dart';

/// The bank sheet (Issue #198, reference 5): the banks and wallets four to a
/// row, each a 40pt logo over its name. Choosing one closes the sheet with
/// it.
class BankSelectSheet extends StatelessWidget {
  const BankSelectSheet({required this.banks, super.key});

  final List<PaymentBank> banks;

  static const int _columns = 4;

  /// The references centre the four columns 91.83pt apart, the first
  /// 58.75pt in.
  static const double _sidePadding = 12.83;

  /// Wide enough for "Төрийн банк", too narrow for "Чингис хаан банк" —
  /// the reference cuts it to "Чингис хаа…".
  static const double _nameWidth = 68;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final rows = [
      for (var i = 0; i < banks.length; i += _columns)
        banks.sublist(i, (i + _columns).clamp(0, banks.length)),
    ];
    return PaymentSheetFrame(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _sidePadding,
          54,
          _sidePadding,
          37.71 + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, row) in rows.indexed) ...[
              if (i != 0) const SizedBox(height: 37.71),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < _columns; c++)
                    Expanded(
                      child: c < row.length
                          ? _BankTile(bank: row[c])
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BankTile extends StatelessWidget {
  const _BankTile({required this.bank});

  final PaymentBank bank;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: bank.name,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(bank),
        child: Column(
          children: [
            Image.asset(PaymentFlowAssets.bank(bank.id), width: 40, height: 40),
            const SizedBox(height: 8.29),
            SizedBox(
              width: BankSelectSheet._nameWidth,
              child: paymentFlowText(
                bank.name,
                size: 11,
                box: 14,
                color: context.palette.textDeep,
                align: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The transfer details sheet (Issue #198, reference 6): where to send the
/// money, with the account number and IBAN copyable.
class BankTransferSheet extends StatelessWidget {
  const BankTransferSheet({required this.details, super.key});

  final BankTransferDetails details;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return PaymentSheetFrame(
      child: BankTransferDetailsView(
        details: details,
        top: 38.1,
        bottom: 49.6 + bottomInset,
      ),
    );
  }
}
