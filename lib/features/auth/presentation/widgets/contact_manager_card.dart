import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';

/// The card pinned to the bottom of the login screen.
///
/// Figma `Frame 1000005654`: 361 x 80, inner content inset 16pt, a two-line
/// text block (20pt supporting line over a 24pt title) and a 20pt `CaretRight`
/// centred on the right edge. The reference draws it as a white surface with
/// the same thin border as the fields — not as a filled grey block.
///
/// Its destination does not exist yet, so [onTap] is optional and the card
/// simply sits inert until there is somewhere for it to go.
class ContactManagerCard extends StatelessWidget {
  const ContactManagerCard({
    required this.supportingText,
    required this.title,
    super.key,
    this.onTap,
  });

  final String supportingText;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        child: Container(
          height: AppDimens.cardHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.cardRadius),
            border: Border.all(color: AppColors.border, width: AppDimens.borderWidth),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supportingText,
                      style: AppTypography.cardSupporting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimens.cardLineGap),
                    Text(
                      title,
                      style: AppTypography.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                AppIcons.caretRight,
                size: AppDimens.caretSize,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
