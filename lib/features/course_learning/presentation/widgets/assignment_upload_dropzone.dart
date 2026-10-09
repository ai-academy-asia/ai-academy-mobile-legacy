import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../course_learning_strings.dart';

/// Measured off the reference frames at 1:1: a 329 x 125 dashed area, its
/// content centred, with the accepted-types line under the label.
const double _height = 125;
const double _radius = 12;
const double _dashLength = 6;
const double _dashGap = 5;

/// The box is the asset's own 24 square, not the 22 x 19 the frame measures:
/// `exercise_upload.svg`'s artwork fills only 21.6 x 19.3 of its viewBox, so
/// `BoxFit.contain` on a 22 x 19 box fitted the *viewBox* and drew the glyph
/// at 17 x 16. At 24 the drawing itself lands on the reference's bounds.
const double _iconBox = 24;

/// Measured from the *box*, which is taller than the glyph it holds (the
/// artwork sits 1.2 high in its own viewBox and leaves ~3.5 below), so this is
/// smaller than the 17 of clear space the reference shows between their ink.
const double _iconToLabel = 8;
const double _labelToTypes = 16;
const double _labelSize = 14;
const double _typesSize = 12;

/// The Assignment tab's "no file yet" area — the dashed drop target the
/// reference draws before anything is attached.
///
/// The accepted-types line is always drawn. Only two reference frames show
/// this area at all: Exercise-2 draws the line, Exercise-6 draws no line —
/// and those two also disagree about the card around them (Exercise-2 has two
/// tabs, Exercise-6 none, against ten frames with three), so the difference is
/// iteration drift rather than a state. Nothing in `CourseExercise` says which
/// types an assignment accepts, so there is no condition to branch on either.
///
/// **[onTap] is the caller's.** The sample's `AssignmentAttachmentCard`
/// starts its simulated transfer from it; a backend assignment's
/// `AssignmentFileUploadCard` opens the file picker. Null leaves the area
/// drawn but inert.
class AssignmentUploadDropzone extends StatelessWidget {
  const AssignmentUploadDropzone({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // No explicit `label`: the child `Text` already supplies it, and setting
    // both merges them into one doubled string that an exact-match finder
    // then misses.
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedBorderPainter(color: context.palette.outline),
          child: SizedBox(
            height: _height,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/images/course_learning/exercise_upload.svg',
                  width: _iconBox,
                  height: _iconBox,
                ),
                const SizedBox(height: _iconToLabel),
                Text(
                  CourseLearningStrings.uploadFile,
                  style: AppTypography.cardHeading.copyWith(
                    fontSize: _labelSize,
                    fontWeight: FontWeight.w500,
                    color: context.palette.textPrimary,
                  ),
                ),
                const SizedBox(height: _labelToTypes),
                Text(
                  CourseLearningStrings.uploadFileTypes,
                  style: AppTypography.cardSupporting.copyWith(
                    fontSize: _typesSize,
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded rectangle stroked with dashes. Flutter's `Border` only draws
/// solid strokes, and the reference's drop area is dashed, so the outline is
/// painted rather than declared.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  /// The dashes' colour — `AppPalette.outline`, passed in: a painter has no
  /// context.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + _dashLength),
          paint,
        );
        distance += _dashLength + _dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
