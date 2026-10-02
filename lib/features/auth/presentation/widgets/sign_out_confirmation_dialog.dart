import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../sign_out_strings.dart';

/// Asks the student to confirm "Гарах" before `signOutToLogin` runs.
///
/// Completes with true only when they confirm. "Цуцлах", a tap on the barrier
/// and the system back gesture all complete with false — nothing is signed
/// out and no request is sent.
Future<bool> confirmSignOut(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => const SignOutConfirmationDialog(),
  );
  return confirmed ?? false;
}

/// The confirmation itself.
///
/// No Figma frame draws it, so nothing here is new design: it is a white
/// card on the app's own tokens ([AppDimens.cardRadius],
/// [AppDimens.cardPadding]) holding the Login screen's established button
/// pair — the filled blue [AppButton] for the action, the outlined one under
/// it at [AppDimens.buttonGap] for the way back.
class SignOutConfirmationDialog extends StatefulWidget {
  const SignOutConfirmationDialog({super.key});

  @override
  State<SignOutConfirmationDialog> createState() =>
      _SignOutConfirmationDialogState();
}

class _SignOutConfirmationDialogState extends State<SignOutConfirmationDialog> {
  // A second tap landing before the route is gone would pop whatever is
  // under the dialog — the Profile itself. Only the first answer counts.
  bool _answered = false;

  void _answer(bool confirmed) {
    if (_answered) return;
    _answered = true;
    Navigator.of(context).pop(confirmed);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppDimens.screenPadding,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppDimens.contentWidth),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.cardPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A card's heading over its supporting line — the existing
              // styles for exactly that pairing.
              const Text(
                SignOutStrings.title,
                style: AppTypography.cardHeading,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimens.titleToSupporting),
              const Text(
                SignOutStrings.message,
                style: AppTypography.statLabel,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimens.headingToForm),
              AppButton(
                label: SignOutStrings.confirm,
                onPressed: () => _answer(true),
              ),
              const SizedBox(height: AppDimens.buttonGap),
              AppButton(
                label: SignOutStrings.cancel,
                variant: AppButtonVariant.outlined,
                onPressed: () => _answer(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
