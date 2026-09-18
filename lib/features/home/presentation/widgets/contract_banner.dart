import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../home_strings.dart';

/// "Та гэрээ хийгдээгүй байна" — the warning the dashboard shows while the
/// student's e-contract is unsigned.
///
/// The one amber element on the screen, in [AppColors.warning] at low alpha
/// so it reads as a notice rather than an error: a refused payment is red,
/// this is a task still open. Drawn as a single tappable row with a trailing
/// caret, the same shape `ContactManagerCard` uses on the login screen.
class ContractBanner extends StatelessWidget {
  const ContractBanner({super.key, this.onTap});

  /// Where the banner leads. Null leaves it a notice with no destination.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: HomeStrings.contractTitle,
      child: Material(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.4),
                width: AppDimens.borderWidth,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: AppDimens.statIconTile,
                  height: AppDimens.statIconTile,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppDimens.cardRadius),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      HomeIcons.contract,
                      width: 20,
                      height: 20,
                      colorFilter: const ColorFilter.mode(
                        AppColors.warning,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        HomeStrings.contractTitle,
                        style: AppTypography.cardHeading,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        HomeStrings.contractSupporting,
                        style: AppTypography.statLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  AppIcons.caretRight,
                  size: AppDimens.caretSize,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
