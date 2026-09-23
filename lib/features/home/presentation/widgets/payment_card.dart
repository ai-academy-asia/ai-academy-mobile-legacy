import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/home_dashboard.dart';
import '../home_strings.dart';

/// "Дараанийн төлөлт" — what the student owes next.
///
/// Two states, exactly as the reference draws them:
///
///   * **due** — a white card like every other, the countdown in blue, and the
///     pay action flat: there is nothing to settle yet.
///   * **overdue** — the card tinted and outlined in [AppColors.error], the
///     status in red, and the pay action live in brand blue. Red states the
///     problem; blue offers the way out, which is the one rule the palette
///     documents about its action colour.
class PaymentCard extends StatelessWidget {
  const PaymentCard({required this.payment, super.key, this.onPay});

  final PaymentStatus payment;

  /// What the pay action does. Only ever pressable while the payment is
  /// overdue — the reference draws it flat otherwise.
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final overdue = payment.isOverdue;

    return Container(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      decoration: BoxDecoration(
        color: overdue
            ? AppColors.error.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
        border: Border.all(
          color: overdue
              ? AppColors.error.withValues(alpha: 0.35)
              : AppColors.border,
          width: AppDimens.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: AppDimens.statIconTile,
              height: AppDimens.statIconTile,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimens.cardRadius),
              ),
              child: const Icon(
                Icons.payments_outlined,
                size: 20,
                color: AppColors.blue,
              ),
            ),
          ),
          const SizedBox(height: 14),

          Text(
            HomeStrings.paymentLabel,
            style: AppTypography.statLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            overdue
                ? HomeStrings.paymentOverdue
                : HomeStrings.paymentDueIn(payment.daysUntilDue!),
            style: AppTypography.statValue.copyWith(
              color: overdue ? AppColors.error : AppColors.blue,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 14),
          AppButton(
            label: HomeStrings.payAction,
            onPressed: overdue ? onPay : null,
          ),
        ],
      ),
    );
  }
}
