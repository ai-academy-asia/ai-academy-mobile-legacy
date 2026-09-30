import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'home_palette.dart';

/// Which of the Home frames' two pill treatments a [HomePillButton] draws.
enum HomePillVariant {
  /// The call to action: [HomePalette.accent] on a flat
  /// [AppColors.primaryDepth] band, or — with no `onPressed` — the muted pill
  /// on its [AppColors.mutedDepth] band.
  primary,

  /// The white "Дэлгэрэнгүй" pill: hairline outline, dark label, and only a
  /// faint band under it.
  secondary,
}

/// The primary CTA's depth — a flat band of this many points under the pill.
const double _depth = 4;

/// The secondary pill's much fainter band.
const double _secondaryDepth = 1.5;

/// A full-width pill button, as every action on the Home frames is drawn.
///
/// The primary variant is the Course Learning CTA — the same flat, zero-blur
/// band of [AppColors.primaryDepth] under a blue pill that
/// `ExerciseSubmitButton` and "Continue learning" use, and the same muted
/// fill/outline/ink with [AppColors.mutedDepth] when it cannot be pressed.
/// Not `ExerciseSubmitButton` itself: that pill is fixed at 44 tall with a
/// 16pt label and no leading glyph, while the Home frames draw 40 (the
/// attendance action) and 36 (the statistic cards) with a 14pt label, and
/// put a QR glyph in front of one of them.
///
/// The band is a shadow, so it takes no layout space: the button measures
/// [height], and the band lands in the padding below it, exactly as the
/// reference's does.
class HomePillButton extends StatelessWidget {
  const HomePillButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = HomePillVariant.primary,
    this.height = 36,
    this.icon,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  final HomePillVariant variant;

  /// 40 for the attendance action, 36 for a statistic card's.
  final double height;

  /// Drawn 20pt ahead of the label, 6pt from it.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final secondary = variant == HomePillVariant.secondary;
    final filled = !secondary && enabled;

    final Color fill;
    final Color? outline;
    final Color ink;
    final BoxShadow depth;

    if (secondary) {
      fill = AppColors.surface;
      outline = enabled ? HomePalette.border : HomePalette.mutedOutline;
      ink = enabled ? AppColors.textPrimary : HomePalette.mutedInk;
      depth = const BoxShadow(
        color: HomePalette.secondaryDepth,
        offset: Offset(0, _secondaryDepth),
      );
    } else if (filled) {
      fill = HomePalette.accent;
      outline = null;
      ink = AppColors.onPrimary;
      depth = const BoxShadow(
        color: AppColors.primaryDepth,
        offset: Offset(0, _depth),
      );
    } else {
      fill = HomePalette.mutedFill;
      outline = HomePalette.mutedOutline;
      ink = HomePalette.mutedInk;
      depth = const BoxShadow(
        color: AppColors.mutedDepth,
        offset: Offset(0, _depth),
      );
    }

    final radius = BorderRadius.circular(height / 2);

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: [depth]),
        child: Material(
          color: fill,
          borderRadius: radius,
          child: InkWell(
            onTap: onPressed,
            borderRadius: radius,
            splashColor: filled ? Colors.white24 : null,
            highlightColor: filled ? Colors.white10 : null,
            child: Ink(
              height: height,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: outline == null ? null : Border.all(color: outline),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon case final icon?) ...[
                    // White on the muted pill too: all three frames that
                    // draw the attendance action disabled leave its QR glyph
                    // in the live state's white, barely there on the grey.
                    Icon(
                      icon,
                      size: 20,
                      color: secondary ? ink : AppColors.onPrimary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: AppTypography.buttonLabel.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
