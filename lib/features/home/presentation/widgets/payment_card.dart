import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../domain/home_dashboard.dart';
import '../home_strings.dart';
import 'home_palette.dart';
import 'home_pill_button.dart';
import 'home_stat_card.dart';

/// "Дараанийн төлөлт" — what the student owes next.
///
/// As a **tile** it carries the pay action, in the states the reference
/// draws:
///
///   * **due** — a white card like every other, the countdown in blue, and the
///     pay action muted: there is nothing to settle yet.
///   * **overdue** — the card tinted and outlined in red, the status in red,
///     and the pay action live in blue. Red states the problem; blue offers
///     the way out.
///
/// As a **row** it is a summary with a "Дэлгэрэнгүй" (details) action, as in
/// the default frame and under the overdue tile in the contract frame.
class PaymentCard extends StatelessWidget {
  const PaymentCard({
    required this.payment,
    super.key,
    this.layout = HomeStatLayout.tile,
    this.onPay,
    this.onDetails,
  });

  final PaymentStatus payment;
  final HomeStatLayout layout;

  /// What the tile's pay action does. Only ever pressable while the payment
  /// is overdue — the reference draws it muted otherwise.
  final VoidCallback? onPay;

  /// What the row's details action does.
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final overdue = payment.isOverdue;
    final isTile = layout == HomeStatLayout.tile;
    final tinted = overdue && isTile;

    return HomeStatCard(
      layout: layout,
      icon: AppIcons.money,
      label: HomeStrings.paymentLabel,
      value: overdue
          ? HomeStrings.paymentOverdue
          : HomeStrings.paymentDueIn(payment.daysUntilDue!),
      valueColor: overdue ? HomePalette.overdueInk : HomePalette.accent,
      fill: tinted ? HomePalette.overdueFill : AppColors.surface,
      outline: tinted ? HomePalette.overdueOutline : HomePalette.border,
      action: isTile
          ? HomePillButton(
              label: HomeStrings.payAction,
              height: statActionHeight,
              onPressed: overdue ? onPay : null,
            )
          : HomePillButton(
              label: HomeStrings.details,
              variant: HomePillVariant.secondary,
              height: statActionHeight,
              onPressed: onDetails,
            ),
    );
  }
}
