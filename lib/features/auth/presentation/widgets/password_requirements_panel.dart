import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/password_policy.dart';
import '../reset_password_strings.dart';

/// The strength meter and rule list under the new-password field.
///
/// Figma `Sign in - 6` … `10`. Three states per rule, which the reference shows
/// directly: neutral grey before anything is typed, green once the rule passes,
/// red once it is being typed at and still fails. The meter fills and changes
/// colour with the number of rules passed.
///
/// Presentation only — [satisfied] and [strength] are computed by
/// [PasswordPolicy] and handed in, so this widget has no rules of its own.
class PasswordRequirementsPanel extends StatelessWidget {
  const PasswordRequirementsPanel({
    required this.satisfied,
    required this.strength,
    required this.evaluated,
    super.key,
  });

  /// The rules the current password passes.
  final Set<PasswordRequirement> satisfied;

  /// 0.0–1.0.
  final double strength;

  /// False while the field is untouched, which keeps every rule neutral
  /// instead of opening the screen covered in red.
  final bool evaluated;

  /// Red until the password is close, amber on the way, green when every rule
  /// passes — the three meter colours the reference uses.
  Color get _meterColor {
    if (!evaluated || strength == 0) return AppColors.error;
    if (strength >= 1) return AppColors.success;
    return strength >= 0.6 ? AppColors.warning : AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(ResetPasswordStrings.requirementsTitle, style: AppTypography.cardTitle),
        const SizedBox(height: 12),
        _StrengthBar(value: strength, color: _meterColor),
        const SizedBox(height: 12),
        for (final requirement in PasswordPolicy.all) ...[
          _RequirementRow(
            label: ResetPasswordStrings.requirement(requirement),
            met: satisfied.contains(requirement),
            evaluated: evaluated,
          ),
          if (requirement != PasswordPolicy.all.last)
            const SizedBox(height: AppDimens.requirementRowGap),
        ],
      ],
    );
  }
}

class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      value: '${(value * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.strengthBarHeight / 2),
        child: SizedBox(
          height: AppDimens.strengthBarHeight,
          child: Stack(
            children: [
              const ColoredBox(color: AppColors.border, child: SizedBox.expand()),
              // A sliver of colour even at zero, so the meter reads as a meter
              // rather than as an empty rule — the reference shows one.
              FractionallySizedBox(
                widthFactor: value.clamp(0.03, 1.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    required this.label,
    required this.met,
    required this.evaluated,
  });

  final String label;
  final bool met;
  final bool evaluated;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;

    if (!evaluated) {
      color = AppColors.textSecondary;
      icon = AppIcons.checkCircle;
    } else if (met) {
      color = AppColors.success;
      icon = AppIcons.checkCircle;
    } else {
      color = AppColors.error;
      icon = AppIcons.xCircle;
    }

    return Semantics(
      label: label,
      checked: evaluated && met,
      child: ExcludeSemantics(
        child: SizedBox(
          height: AppDimens.requirementRowHeight,
          child: Row(
            children: [
              Icon(icon, size: AppDimens.requirementIconSize, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.cardSupporting.copyWith(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
