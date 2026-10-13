import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/track_badge.dart';

/// Хичээлийн ирц / Шалгалтын дүн: a heading over a blue capsule.
class GradebookStatCard extends StatelessWidget {
  const GradebookStatCard({
    required this.title,
    required this.value,
    super.key,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // A card's faint edge (`outlineFaint`); the capsule is the live blue set
    // — `infoInk` at 30 % round an `infoFill`, the figure in `accentText`.
    return Container(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: palette.outlineFaint,
          width: AppDimens.borderWidthEmphasis,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _statTitleStyle.copyWith(color: palette.textStrong),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CardCapsule(
                label: value,
                outline: palette.infoInk.withValues(alpha: 0.3),
                fill: palette.infoFill,
                ink: palette.accentText,
                horizontalPadding: 11,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Хичээлийн ирц" / "Шалгалтын дүн" — the student summary cards' titles, as on
/// the attendance panels.
const TextStyle _statTitleStyle = AppTypography.itemTitle;
