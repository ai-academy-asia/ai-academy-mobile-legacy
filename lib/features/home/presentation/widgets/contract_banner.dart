import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../home_strings.dart';
import 'home_palette.dart';

/// "Та гэрээ хийгдээгүй байна" — the warning the dashboard shows while the
/// student's e-contract is unsigned.
///
/// The one amber element on the screen, in the reference's own flat amber
/// pair ([HomePalette.contractFill] under [HomePalette.contractOutline]) so
/// it reads as a notice rather than an error: a late payment is red, this is
/// a task still open. Drawn as a single tappable row — an outlined icon tile,
/// two lines, a trailing caret — the same shape `ContactManagerCard` uses on
/// the login screen. 80 tall in the reference: 16 of padding around a 48pt
/// pair of lines.
///
/// The Junior "Сурлагын явц" frame draws this same banner — same 80pt
/// geometry, outline, tile and caret — with its own two lines, so the copy
/// can be overridden; it defaults to the adult dashboard's.
class ContractBanner extends StatelessWidget {
  const ContractBanner({
    super.key,
    this.onTap,
    this.title = HomeStrings.contractTitle,
    this.supporting = HomeStrings.contractSupporting,
  });

  /// Where the banner leads. Null leaves it a notice with no destination.
  final VoidCallback? onTap;

  final String title;
  final String supporting;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimens.homeCardRadius);

    return Semantics(
      button: onTap != null,
      label: title,
      child: Material(
        color: HomePalette.contractFill,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.all(16 - AppDimens.borderWidth),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: HomePalette.contractOutline),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: HomePalette.contractOutline),
                  ),
                  child: SvgPicture.asset(
                    HomeIcons.contract,
                    width: 24,
                    height: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: _titleStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        supporting,
                        style: _supportingStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  AppIcons.caretRight,
                  size: 24,
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

/// 16 bold on a 24 line.
const TextStyle _titleStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 16,
  height: 24 / 16,
  fontWeight: FontWeight.w700,
  color: AppColors.textPrimary,
  leadingDistribution: TextLeadingDistribution.even,
);

/// 14 regular on a 20 line.
const TextStyle _supportingStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w400,
  color: AppColors.textSecondary,
  leadingDistribution: TextLeadingDistribution.even,
);
