import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_palette.dart';
import '../../course_learning/presentation/widgets/course_learning_back_button.dart';
import '../../home/presentation/widgets/home_pill_button.dart';

/// Every word on the attendance scanner, read off its Figma reference.
abstract final class AttendanceScannerStrings {
  static const String hint = 'QR кодыг хүрээн дотор хөдөлгөөнгүй уншуулна уу.';
  static const String manualEntry = 'Гараар оруулах';

  /// Read out for the scan window, which draws no text.
  static const String window = 'QR код уншуулах хүрээ';
}

/// The attendance check-in scanner (Issue #202), drawn from its Figma
/// reference: a darkened screen with a clear, corner-bracketed square
/// window, the hint under it, and "Гараар оруулах" at the foot.
///
/// **UI only.** No QR check-in endpoint is confirmed (`BACKEND GAP`), so
/// nothing is scanned or sent: no camera plugin or camera permission is
/// added, and the window shows what the reference shows through it — the
/// screen's own white. "Гараар оруулах" is drawn live, as the reference
/// draws it, but has no frame to open and leads nowhere. Opened from the
/// Junior Home check-in node while a lesson is under way.
class AttendanceScannerScreen extends StatelessWidget {
  const AttendanceScannerScreen({super.key});

  /// Measured off the 393 x 852 reference at 1:1.
  static const double _windowTop = 239;
  static const double windowSize = 300;
  static const double _windowToHint = 25.4;
  static const double _hintWidth = 300;

  static void _noManualEntryYet() {}

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.overDarkContent(),
      child: Scaffold(
        // What the window shows with no camera behind it — the reference's
        // own white — and, under the scrim, the reference's #6B6B6B.
        backgroundColor: context.palette.surface,
        body: Stack(
          children: [
            Positioned.fill(
              child: Semantics(
                label: AttendanceScannerStrings.window,
                child: CustomPaint(
                  painter: _ScrimPainter(
                    windowTop: _windowTop,
                    windowSize: windowSize,
                    scrim: context.palette.scrim,
                    bracket: context.palette.onPrimary,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: MediaQuery.paddingOf(context).top,
              child: const CourseLearningBackButton(icon: AppIcons.arrowLeft),
            ),
            Positioned(
              top: _windowTop + windowSize + _windowToHint,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: _hintWidth,
                  child: Text(
                    AttendanceScannerStrings.hint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 16,
                      height: 24 / 16,
                      leadingDistribution: TextLeadingDistribution.even,
                      color: context.palette.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: AppDimens.screenPadding,
              right: AppDimens.screenPadding,
              bottom: AppDimens.screenPadding + bottomInset,
              child: const HomePillButton(
                label: AttendanceScannerStrings.manualEntry,
                height: 44,
                labelSize: 16,
                labelWeight: FontWeight.w600,
                onPressed: _noManualEntryYet,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The reference's 58% black over everything but the scan window, and the
/// window's four white corner brackets.
class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({
    required this.windowTop,
    required this.windowSize,
    required this.scrim,
    required this.bracket,
  });

  final double windowTop;
  final double windowSize;

  /// The theme's [AppPalette.scrim] and [AppPalette.onPrimary], from the
  /// widget: a painter has no context (Dark Mode Phase 5).
  final Color scrim;
  final Color bracket;

  static const double _radius = 32;

  /// How far each bracket runs along its two edges from the corner.
  static const double _bracket = 49.5;
  static const double _bracketStroke = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final window = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        (size.width - windowSize) / 2,
        windowTop,
        windowSize,
        windowSize,
      ),
      const Radius.circular(_radius),
    );
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(window),
      ),
      Paint()..color = scrim,
    );

    final stroke = Paint()
      ..color = bracket
      ..style = PaintingStyle.stroke
      ..strokeWidth = _bracketStroke;
    final r = window.outerRect;
    for (final corner in [
      r.topLeft,
      r.topRight - const Offset(_bracket, 0),
      r.bottomLeft - const Offset(0, _bracket),
      r.bottomRight - const Offset(_bracket, _bracket),
    ]) {
      canvas
        ..save()
        ..clipRect(
          (corner - const Offset(_bracketStroke, _bracketStroke)) &
              const Size(
                _bracket + 2 * _bracketStroke,
                _bracket + 2 * _bracketStroke,
              ),
        )
        ..drawRRect(window, stroke)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.windowTop != windowTop ||
      old.windowSize != windowSize ||
      old.scrim != scrim ||
      old.bracket != bracket;
}
