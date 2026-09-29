import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'junior_home_palette.dart';
import 'junior_map_geometry.dart';

/// Draws the route between the nodes.
///
/// Each connector is a right-angle elbow with a true quarter-circle fillet —
/// `conicTo` with a weight of √2⁄2, which is the exact circular arc rather
/// than the near-miss a plain quadratic gives. Straight lines between the
/// nodes would read as a list with dividers, which is what the reference is
/// not.
///
/// Painted *under* the nodes, so every line runs behind a node's rounded
/// square instead of stopping short of it.
class JuniorMapPathPainter extends CustomPainter {
  const JuniorMapPathPainter({required this.scale});

  final double scale;

  static const double _circularWeight = math.sqrt2 / 2;

  @override
  void paint(Canvas canvas, Size size) {
    for (final connector in JuniorMapGeometry.connectors) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = JuniorMapGeometry.connectorStroke * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = connector.active ? JuniorPalette.accent : JuniorPalette.muted;
      canvas.drawPath(_elbow(connector), paint);
    }
  }

  Path _elbow(JuniorConnector c) {
    final from = c.from * scale;
    final corner = c.corner * scale;
    final to = c.to * scale;
    final radius = JuniorMapGeometry.connectorRadius * scale;

    // Where the fillet starts and ends: `radius` back along each leg from the
    // vertex, never past the leg's own far end.
    final entry = _towards(corner, from, radius);
    final exit = _towards(corner, to, radius);

    return Path()
      ..moveTo(from.dx, from.dy)
      ..lineTo(entry.dx, entry.dy)
      ..conicTo(corner.dx, corner.dy, exit.dx, exit.dy, _circularWeight)
      ..lineTo(to.dx, to.dy);
  }

  /// [distance] from [origin] in the direction of [target], stopping at
  /// [target] when the leg is shorter than that.
  static Offset _towards(Offset origin, Offset target, double distance) {
    final delta = target - origin;
    final length = delta.distance;
    if (length <= distance || length == 0) return target;
    return origin + delta * (distance / length);
  }

  @override
  bool shouldRepaint(JuniorMapPathPainter old) => old.scale != scale;
}
