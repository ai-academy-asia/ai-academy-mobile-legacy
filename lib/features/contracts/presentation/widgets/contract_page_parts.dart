import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';

/// A centred line, with an optional action under it — the E-Contract
/// screens' empty and failure states.
class ContractMessage extends StatelessWidget {
  const ContractMessage({super.key, required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: AppTypography.statLabel.copyWith(
                color: context.palette.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (action case final action?) ...[
              const SizedBox(height: AppDimens.fieldGap),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
