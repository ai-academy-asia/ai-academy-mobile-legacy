import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/junior_learning_map.dart';
import 'junior_home_palette.dart';
import 'junior_map_geometry.dart';
import 'junior_progress_ring.dart';

/// Title on the left, dial on the right, inside the pale lavender card at the
/// top of the map.
///
/// The title is allowed exactly the two lines the frame wraps it onto; a
/// longer course name ellipsises rather than growing the card, because the
/// card's 88 is a measured height the map's node route is positioned against.
class JuniorCourseProgressCard extends StatelessWidget {
  const JuniorCourseProgressCard({
    required this.progress,
    required this.scale,
    super.key,
  });

  final JuniorCourseProgress progress;

  /// The map's design-space-to-pixels factor.
  final double scale;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: JuniorPalette.cardFill,
        borderRadius: BorderRadius.circular(
          JuniorMapGeometry.courseCardRadius * scale,
        ),
        border: Border.all(color: JuniorPalette.cardBorder, width: 1 * scale),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: JuniorMapGeometry.courseCardPadding * scale,
        ),
        child: Row(
          children: [
            // A fixed box, not `Expanded`: the frame wraps "Prediction and
            // Probabilities" onto two lines even though the card is wide
            // enough to hold it on one — the title's own text box is narrow,
            // and the clear space between it and the dial is deliberate. At
            // full width the line would not wrap and the card would read as a
            // different design.
            SizedBox(
              width: JuniorMapGeometry.courseTitleWidth * scale,
              child: Text(
                progress.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.heading.copyWith(
                  fontSize: 18 * scale,
                  height: 26 / 18,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Spacer(),
            JuniorProgressRing(
              percent: progress.percentComplete,
              size: JuniorMapGeometry.ringSize * scale,
              stroke: JuniorMapGeometry.ringStroke * scale,
              labelSize: 12 * scale,
            ),
          ],
        ),
      ),
    );
  }
}
