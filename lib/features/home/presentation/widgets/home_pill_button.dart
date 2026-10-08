import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_palette.dart';
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
    this.raised = true,
    this.labelSize = 14,
    this.labelWeight = FontWeight.w700,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  final HomePillVariant variant;

  /// 40 for the attendance action, 36 for a statistic card's.
  final double height;

  /// Drawn 20pt ahead of the label, 6pt from it.
  final IconData? icon;

  /// Whether a primary pill sits on its [_depth] band. False — the payment
  /// tiles' "Төлбөр төлөх", drawn flat in the frames, live or muted — gives
  /// it only the faint band the secondary pill wears. The attendance action
  /// keeps its band: the frames draw one under it.
  final bool raised;

  /// 14 on the Home frames; the Payment screen's full-width "Төлбөр төлөх"
  /// draws its label at 16.
  final double labelSize;

  /// Bold on the Home frames; semi-bold on the Payment screen's button.
  final FontWeight labelWeight;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final secondary = variant == HomePillVariant.secondary;
    final filled = !secondary && enabled;

    final Color fill;
    final Color? outline;
    final Color ink;
    final BoxShadow depth;

    final faintDepth = BoxShadow(
      color: context.palette.subtleDepth,
      offset: Offset(0, _secondaryDepth),
    );

    if (secondary) {
      fill = context.palette.surface;
      outline = enabled ? context.palette.outline : context.palette.divider;
      ink = enabled ? context.palette.textPrimary : context.palette.disabledInk;
      depth = faintDepth;
    } else if (filled) {
      fill = context.palette.accent;
      outline = null;
      ink = context.palette.onPrimary;
      depth = raised
          ? BoxShadow(
              color: context.palette.primaryDepth,
              offset: Offset(0, _depth),
            )
          : faintDepth;
    } else {
      fill = context.palette.surfaceSubtle;
      outline = context.palette.divider;
      ink = context.palette.disabledInk;
      depth = raised
          ? BoxShadow(
              color: context.palette.neutralDepth,
              offset: Offset(0, _depth),
            )
          : faintDepth;
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
            splashColor: filled
                ? context.palette.onPrimary.withAlpha(0x3D)
                : null,
            highlightColor: filled
                ? context.palette.onPrimary.withAlpha(0x1A)
                : null,
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
                      color: secondary ? ink : context.palette.onPrimary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: AppTypography.buttonLabel.copyWith(
                        fontSize: labelSize,
                        fontWeight: labelWeight,
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
