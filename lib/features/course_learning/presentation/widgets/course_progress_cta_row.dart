import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../course_learning_strings.dart';

/// The progress/CTA row the Course Learning frames draw — Course Module
/// List's hero and certification panel, and the Certificate screen's
/// not-yet-issued card (Issue #155): the bar and "N% complete" side by side,
/// then the blue "Continue learning" pill. Measured off the Module List frame
/// at 1:1.
///
/// The bar flexes; everything right of it is fixed, so the same widget lands
/// the button on the frame's x213 in every container — which is why the
/// button's width differs between them and is passed in.
///
/// The bar itself is the exact `ClipRRect` + `LinearProgressIndicator`
/// treatment `ProgramCard`/`CohortCard` already use. The button is not
/// `AppButton`: that widget is fixed at a 44pt *full-width* block, while the
/// reference measures this one at 40 tall beside the progress section; see
/// [ContinueLearningButton].
class CourseProgressCtaRow extends StatelessWidget {
  const CourseProgressCtaRow({
    required this.percent,
    required this.buttonWidth,
    required this.onContinue,
    super.key,
  });

  /// 0–100.
  final int percent;

  final double buttonWidth;

  /// Where "Continue learning" goes. Null draws it inert.
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: _barHeight,
              backgroundColor: context.palette.outline,
              valueColor: AlwaysStoppedAnimation<Color>(context.palette.accent),
            ),
          ),
        ),
        const SizedBox(width: _barToPercent),
        Text(
          CourseLearningStrings.percentComplete(percent),
          style: AppTypography.catalogSectionValue.copyWith(
            fontSize: 14,
            height: 20 / 14,
            color: context.palette.textTitle,
          ),
        ),
        const SizedBox(width: _percentToButton),
        ContinueLearningButton(width: buttonWidth, onTap: onContinue),
      ],
    );
  }
}

/// The blue "Continue learning" pill: 40 tall, radius 20, with its depth — a
/// flat darker-blue band under it, not a glow: beside the button's edge the
/// reference is pure white, so there is no blur to reproduce. A zero-blur
/// shadow of the button's own rounded rect, offset down, gives exactly that
/// band — the same way `CourseModuleCard` draws its own. Painted on a
/// wrapping `DecoratedBox` rather than via `Material.elevation`, whose shadow
/// is a neutral blurred grey; the box adds no size, so the button's footprint
/// is unchanged and the band paints below it.
class ContinueLearningButton extends StatelessWidget {
  const ContinueLearningButton({
    required this.width,
    required this.onTap,
    super.key,
  });

  final double width;

  /// Null draws it inert.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: CourseLearningStrings.continueLearning,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_ctaRadius),
          boxShadow: [
            BoxShadow(
              color: palette.primaryDepth,
              offset: const Offset(0, _ctaDepthOffset),
            ),
          ],
        ),
        child: Material(
          color: palette.accent,
          borderRadius: BorderRadius.circular(_ctaRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(_ctaRadius),
            // `Colors.white24` / `white10`, as tints of [AppPalette.onPrimary]
            // — `AppButton`'s own ripple.
            splashColor: palette.onPrimary.withAlpha(0x3D),
            highlightColor: palette.onPrimary.withAlpha(0x1A),
            child: SizedBox(
              width: width,
              height: _ctaHeight,
              child: Center(
                child: Text(
                  CourseLearningStrings.continueLearning,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w600,
                    color: palette.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Measured off the Module List frame at 1:1: an `AppPalette.accent` bar on
/// an `outline` track, the label in `textTitle`.
const double _barHeight = 8;
const double _barToPercent = 13;
const double _percentToButton = 31;
const double _ctaHeight = 40;
const double _ctaRadius = 20;

/// The button's depth: a flat darker-blue band under it
/// (`AppPalette.primaryDepth`), the same idiom the module cards use. Sampled
/// at 1:1 — the reference has *no* blur around the button at all (the pixel
/// beside its edge is pure white), so this is a zero-blur shadow of the
/// button's own shape, not a glow.
const double _ctaDepthOffset = 4;
