import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';

/// The course card's "40%" dial.
///
/// Not a [CircularProgressIndicator]: that draws a fixed-width arc with
/// square ends and no room for a label, while the frame draws a 5-wide
/// rounded arc over a full-circle track with the percentage centred inside.
/// Overriding the Material widget far enough to match would be more work than
/// painting the two arcs, which is all this is.
///
/// The arc opens at twelve o'clock and sweeps clockwise, as the reference
/// does.
class JuniorProgressRing extends StatelessWidget {
  const JuniorProgressRing({
    required this.percent,
    required this.size,
    required this.stroke,
    required this.labelSize,
    super.key,
  });

  /// 0–100. Clamped when painted, so a value outside the range cannot draw a
  /// sweep past the full circle.
  final int percent;

  final double size;
  final double stroke;

  /// Scaled by the map, so it is passed in rather than read off a token.
  final double labelSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          percent: percent,
          stroke: stroke,
          track: context.palette.outline,
          progress: context.palette.accent,
        ),
        child: Center(
          child: Text(
            '$percent%',
            style: AppTypography.heading.copyWith(
              fontSize: labelSize,
              height: 1,
              color: context.palette.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.percent,
    required this.stroke,
    required this.track,
    required this.progress,
  });

  final int percent;
  final double stroke;

  /// The untravelled arc — `AppPalette.outline`, a progress track — and the
  /// travelled one, `accent`. Passed in: a painter has no context.
  final Color track;
  final Color progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, trackPaint);

    final fraction = (percent / 100).clamp(0.0, 1.0);
    if (fraction == 0) return;

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = progress;
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * fraction,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.percent != percent ||
      old.stroke != stroke ||
      old.track != track ||
      old.progress != progress;
}
