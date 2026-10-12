import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
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
///
/// **When the row does not fit** (Issue #347) — a narrow phone, or a larger
/// system text size — the button moves to its own line under the bar and
/// the label, at the row's end and its design width, rather than squeezing
/// the bar to nothing and running off the screen. "Fits" means the bar keeps
/// at least [_minBarWidth]; every width the frames draw keeps the one row.
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
    final label = CourseLearningStrings.percentComplete(percent);
    final labelStyle = AppTypography.catalogSectionValue.copyWith(
      fontSize: 14,
      height: 20 / 14,
      color: context.palette.textTitle,
    );
    final bar = Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: percent / 100,
          minHeight: _barHeight,
          backgroundColor: context.palette.outline,
          valueColor: AlwaysStoppedAnimation<Color>(context.palette.accent),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        // The label as it will be drawn — at the user's text size.
        final painter = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final labelWidth = painter.width;
        painter.dispose();
        final fits =
            _minBarWidth +
                _barToPercent +
                labelWidth +
                _percentToButton +
                buttonWidth <=
            available;

        if (fits) {
          return Row(
            children: [
              bar,
              const SizedBox(width: _barToPercent),
              Text(label, style: labelStyle),
              const SizedBox(width: _percentToButton),
              ContinueLearningButton(width: buttonWidth, onTap: onContinue),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                bar,
                const SizedBox(width: _barToPercent),
                // Whatever the bar's minimum leaves; the label wraps in it
                // rather than taking the bar's room.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: available - _minBarWidth - _barToPercent,
                  ),
                  child: Text(label, style: labelStyle),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.fieldGap),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ContinueLearningButton(
                width: buttonWidth < available ? buttonWidth : available,
                onTap: onContinue,
              ),
            ),
          ],
        );
      },
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
            // At least 40 tall, and taller when a larger text size wraps
            // the label, which is then shown whole rather than clipped
            // (Issue #347). At the default size it is one line, centred in
            // the 40 exactly as before.
            child: ConstrainedBox(
              constraints: BoxConstraints.tightFor(
                width: width,
              ).copyWith(minHeight: _ctaHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: _ctaLabelInset),
                child: Center(
                  heightFactor: 1,
                  // The button's [Semantics] already reads the label;
                  // without this a screen reader read it twice (Issue #347).
                  child: ExcludeSemantics(
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

/// The least the bar may keep and still count as fitting on the button's
/// row: twice its own height, so it still reads as a bar. Every frame keeps
/// more — the narrowest, the certification panel at 393, keeps 36.5.
const double _minBarWidth = 2 * _barHeight;

/// Above and below a label that has wrapped. At the default size the one
/// line sits inside the 40 without reaching it.
const double _ctaLabelInset = 8;
const double _ctaRadius = 20;

/// The button's depth: a flat darker-blue band under it
/// (`AppPalette.primaryDepth`), the same idiom the module cards use. Sampled
/// at 1:1 — the reference has *no* blur around the button at all (the pixel
/// beside its edge is pure white), so this is a zero-blur shadow of the
/// button's own shape, not a glow.
const double _ctaDepthOffset = 4;
