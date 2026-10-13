import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/pill_button.dart';
import '../data/http_attendance_repository.dart';
import '../domain/attendance_repository.dart';
import 'attendance_scanner_strings.dart';
import 'qr_scan_view.dart';
import 'student_check_in_controller.dart';

export 'attendance_scanner_strings.dart';

/// The attendance check-in scanner (Issues #202, #384), drawn from its
/// Figma reference: the camera behind a darkened screen with a clear,
/// corner-bracketed square window, and the hint under it. Opened from the
/// Junior Home check-in node while a lesson is under way.
///
/// The first QR code read is the raw token the teacher's screen shows; it is
/// sent once to `POST /me/attendance/check-in`
/// ([AttendanceRepository.checkIn]) and the camera stops. What comes back is
/// shown as the server recorded it — `present`, `late`, or on a repeat a
/// teacher's `absent` or `excused` — never as a generic success. Refusals,
/// a failed request and an unusable camera each say why, with "scan again"
/// where it can help. The token is never shown or logged.
///
/// The reference's "Гараар оруулах" is not drawn: there is no manual
/// check-in to open (Issue #384).
///
/// [scanView] is the camera seam — the device camera by default; tests pass
/// a fake.
class AttendanceScannerScreen extends StatefulWidget {
  const AttendanceScannerScreen({
    super.key,
    this.repository,
    this.scanView = mobileScannerQrView,
  });

  /// Defaults to the HTTP repository.
  final AttendanceRepository? repository;

  final QrScanViewBuilder scanView;

  /// Measured off the 393 x 852 reference at 1:1.
  static const double _windowTop = 239;
  static const double windowSize = 300;
  static const double _windowToHint = 25.4;
  static const double _hintWidth = 300;

  @override
  State<AttendanceScannerScreen> createState() =>
      _AttendanceScannerScreenState();
}

class _AttendanceScannerScreenState extends State<AttendanceScannerScreen> {
  late final StudentCheckInController _controller = StudentCheckInController(
    repository: widget.repository ?? HttpAttendanceRepository(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.overDarkContent(),
      child: Scaffold(
        // Under the camera, and what shows before it starts: the
        // reference's own white, darkened by the scrim.
        backgroundColor: palette.surface,
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => Stack(
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  // A fresh camera each attempt after it was unavailable.
                  child: KeyedSubtree(
                    key: ValueKey(_controller.cameraAttempt),
                    child: widget.scanView(
                      active: _controller.scanning,
                      onCode: _controller.onCode,
                      onUnavailable: _controller.onUnavailable,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Semantics(
                  label: AttendanceScannerStrings.window,
                  child: CustomPaint(
                    painter: _ScrimPainter(
                      windowTop: AttendanceScannerScreen._windowTop,
                      windowSize: AttendanceScannerScreen.windowSize,
                      scrim: palette.scrim,
                      bracket: palette.onPrimary,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: MediaQuery.paddingOf(context).top,
                child: const AppBackButton(icon: AppIcons.arrowLeft),
              ),
              if (_controller.scanning)
                Positioned(
                  top:
                      AttendanceScannerScreen._windowTop +
                      AttendanceScannerScreen.windowSize +
                      AttendanceScannerScreen._windowToHint,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      width: AttendanceScannerScreen._hintWidth,
                      child: Text(
                        AttendanceScannerStrings.hint,
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(
                          color: palette.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              if (!_controller.scanning)
                Positioned(
                  left: AppDimens.screenPadding,
                  right: AppDimens.screenPadding,
                  bottom: AppDimens.screenPadding + bottomInset,
                  child: ConstrainedBox(
                    // Room for the back button above, at any text size.
                    constraints: BoxConstraints(
                      maxHeight:
                          MediaQuery.sizeOf(context).height -
                          MediaQuery.paddingOf(context).top -
                          bottomInset -
                          AppDimens.backButtonTop -
                          AppDimens.backButtonSize -
                          2 * AppDimens.screenPadding,
                    ),
                    child: CheckInPanel(
                      controller: _controller,
                      onDone: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the scanner says once it stops looking: checking in, the server's
/// record, or why it did not go through — on a card at the foot of the
/// screen, over the scrim.
class CheckInPanel extends StatelessWidget {
  const CheckInPanel({
    required this.controller,
    required this.onDone,
    super.key,
  });

  final StudentCheckInController controller;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final result = controller.result;

    final List<Widget> children;
    switch (controller.phase) {
      case CheckInPhase.scanning:
        return const SizedBox.shrink();
      case CheckInPhase.checkingIn:
        children = [
          Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: palette.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _message(context, AttendanceScannerStrings.checkingIn),
        ];
      case CheckInPhase.done:
        final record = result!;
        final body = AttendanceScannerStrings.resultBody(record);
        children = [
          Center(child: _StatusMark(status: record.status)),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              AttendanceScannerStrings.resultTitle(record.status),
              textAlign: TextAlign.center,
              style: AppTypography.sectionTitle.copyWith(
                color: palette.textPrimary,
              ),
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 8),
            _message(context, body),
          ],
          const SizedBox(height: 20),
          PillButton(
            label: AttendanceScannerStrings.done,
            height: 44,
            onPressed: onDone,
          ),
        ];
      case CheckInPhase.failed || CheckInPhase.unavailable:
        children = [
          Center(
            child: Icon(
              controller.phase == CheckInPhase.unavailable
                  ? AppIcons.qrCode
                  : AppIcons.xCircle,
              size: 32,
              color: palette.errorInk,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: _message(context, controller.error ?? ''),
          ),
          if (controller.canRescan) ...[
            const SizedBox(height: 20),
            PillButton(
              label: controller.phase == CheckInPhase.unavailable
                  ? AttendanceScannerStrings.retryCamera
                  : AttendanceScannerStrings.rescan,
              height: 44,
              onPressed: controller.rescan,
            ),
          ],
        ];
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [...children],
        ),
      ),
    );
  }

  Widget _message(BuildContext context, String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: AppTypography.supporting.copyWith(
      color: context.palette.textSecondary,
    ),
  );
}

/// The mark over a result: a success tick only for `present`; a clock for
/// `late`; for a teacher's `absent` or `excused`, or any other status, a
/// neutral calendar — never a success tick.
class _StatusMark extends StatelessWidget {
  const _StatusMark({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (icon, color) = switch (status) {
      'present' => (AppIcons.checkCircle, palette.successInk),
      'late' => (AppIcons.clock, palette.warningInk),
      'absent' => (AppIcons.xCircle, palette.errorInk),
      _ => (AppIcons.calendarCheck, palette.textSecondary),
    };
    return Icon(icon, size: 32, color: color);
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
