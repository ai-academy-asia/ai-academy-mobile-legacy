import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';

/// The checkbox row under the two fields.
///
/// Figma: a 20pt-tall row whose instance is inset 8pt from the content edge.
/// Material's `Checkbox` brings a 48pt tap target and its own margins that
/// would blow that 20pt row open, so the box is drawn directly and the whole
/// row is made tappable instead — which keeps the target comfortable without
/// changing the layout.
class RememberMeCheckbox extends StatelessWidget {
  const RememberMeCheckbox({
    required this.value,
    required this.label,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final String label;

  /// Null while a request is in flight.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;

    return Semantics(
      checked: value,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: enabled ? () => onChanged!(!value) : null,
          borderRadius: BorderRadius.circular(AppDimens.checkboxRadius),
          child: Padding(
            padding: const EdgeInsets.only(left: AppDimens.checkboxInset),
            child: SizedBox(
              height: AppDimens.checkboxRowHeight,
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: AppDimens.checkboxSize,
                    height: AppDimens.checkboxSize,
                    decoration: BoxDecoration(
                      color: value ? AppColors.blue : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppDimens.checkboxRadius),
                      border: Border.all(
                        color: value
                            ? AppColors.blue
                            : (enabled ? AppColors.border : AppColors.disabled),
                        width: 1.5,
                      ),
                    ),
                    child: value
                        ? const Center(
                            child: Icon(
                              AppIcons.check,
                              size: 12,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: AppTypography.checkboxLabel.copyWith(
                      color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
