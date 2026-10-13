import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Why the camera cannot scan (Issue #384).
enum QrScanUnavailable {
  /// The student refused camera access, or it is restricted.
  permissionDenied,

  /// This device has no usable camera — the iOS simulator, for one.
  unsupported,

  /// The camera failed to start for another reason.
  failed,
}

/// Builds the live view the attendance scanner shows behind its frame.
///
/// The seam that keeps the camera swappable: the app passes
/// [mobileScannerQrView]; tests pass a fake that reports codes and camera
/// failures by hand, so no test needs a real camera.
///
/// * [active] — scan only while true; the scanner stops while a check-in is
///   in flight or its result is shown.
/// * [onCode] — a QR code's raw string. It is a check-in credential: pass it
///   on, never log or display it.
/// * [onUnavailable] — the camera cannot scan, and why.
typedef QrScanViewBuilder =
    Widget Function({
      required bool active,
      required ValueChanged<String> onCode,
      required ValueChanged<QrScanUnavailable> onUnavailable,
    });

/// The app's [QrScanViewBuilder]: the device camera, through
/// `mobile_scanner`.
Widget mobileScannerQrView({
  required bool active,
  required ValueChanged<String> onCode,
  required ValueChanged<QrScanUnavailable> onUnavailable,
}) => MobileScannerQrView(
  active: active,
  onCode: onCode,
  onUnavailable: onUnavailable,
);

/// The device camera, QR codes only, through `mobile_scanner`. Owns its
/// controller: started while [active], stopped when not, disposed with the
/// widget.
class MobileScannerQrView extends StatefulWidget {
  const MobileScannerQrView({
    required this.active,
    required this.onCode,
    required this.onUnavailable,
    super.key,
  });

  final bool active;
  final ValueChanged<String> onCode;
  final ValueChanged<QrScanUnavailable> onUnavailable;

  @override
  State<MobileScannerQrView> createState() => _MobileScannerQrViewState();
}

class _MobileScannerQrViewState extends State<MobileScannerQrView> {
  // QR only; a code held in view is reported once, not every frame.
  late final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void didUpdateWidget(MobileScannerQrView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    // A failure here is the camera's; it surfaces through the error
    // builder, so it is not rethrown.
    unawaited(
      (widget.active ? _controller.start() : _controller.stop()).catchError(
        (Object _) {},
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_controller.dispose().catchError((Object _) {}));
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!widget.active) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        widget.onCode(raw);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _controller,
      onDetect: _onDetect,
      errorBuilder: (context, error) {
        final reason = switch (error.errorCode) {
          MobileScannerErrorCode.permissionDenied =>
            QrScanUnavailable.permissionDenied,
          MobileScannerErrorCode.unsupported => QrScanUnavailable.unsupported,
          _ => QrScanUnavailable.failed,
        };
        // Reported after the frame: a build must not change its parent.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onUnavailable(reason);
        });
        return const SizedBox.expand();
      },
    );
  }
}
