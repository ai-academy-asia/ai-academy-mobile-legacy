import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../contract_strings.dart';

// Measured off the supplied E-Contract signing-screen screenshot (Issue #304)
// at 1:1 — a design reference, not a Figma frame, so these are close reads,
// not specified values.

/// The pad's height; it takes its parent's width (361 on a 393 screen).
const double _padHeight = 158;

/// The title's gap to the pad, and the pad's to Clear's tap area — whose
/// own 10 of padding puts the label 15 under the pad.
const double _titleToPad = 12;
const double _padToClear = 5;

/// Clear's label sits 15 in from the pad's trailing edge.
const double _clearInset = 15;

/// The drawn line.
const double _strokeWidth = 3;

/// The exported PNG's scale, kept under the 0.6 megapixels the backend scales
/// signatures down to (`pdf/signature.py`), far inside its 2 MB / 8 MP limits.
const double _exportPixelRatio = 2;
const double _maxExportPixels = 600000;

/// The ink the exported PNG is drawn in, whatever the theme: the backend
/// turns near-white pixels transparent, so a light on-screen ink (a dark
/// theme's) could vanish from the signed PDF. The screenshot's dark blue —
/// `AppColors.linkInk`, kept as the authored constant it is.
const Color _exportInk = AppColors.linkInk;

/// The signature section of the E-Contract signing screen (Issue #304):
/// "Гарын үсэг зурна уу · Sign here", a rounded pad the student draws in,
/// and "Цэвэрлэх / Clear" under it.
///
/// **Standalone.** It holds no contract and calls no API: [controller] says
/// whether anything is drawn and exports it as a PNG for `signatureDataUrl`
/// (Issue #302). The signing screen it belongs to is not built — its contract
/// display, form and agreement still need decisions.
///
/// **Drawing never scrolls the page.** The pad claims a touch the moment it
/// lands, so a parent scroll view cannot take a vertical stroke from it; a
/// stroke that leaves the pad keeps only its points inside.
///
/// Clear is drawn in the palette's disabled-label role while nothing is
/// drawn — the screenshot shows it only with a signature. The screenshot's
/// faint circled "×" in the middle of the pad is not drawn: whether it is a
/// hint or a control is not known.
class ContractSignaturePad extends StatefulWidget {
  const ContractSignaturePad({super.key, required this.controller});

  final ContractSignatureController controller;

  @override
  State<ContractSignaturePad> createState() => _ContractSignaturePadState();
}

class _ContractSignaturePadState extends State<ContractSignaturePad> {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final controller = widget.controller;
    final radius = BorderRadius.circular(AppDimens.homeCardRadius);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Announced once, as the pad's own label below — not twice.
        ExcludeSemantics(
          child: Text(
            ContractStrings.signHere,
            style: _titleStyle.copyWith(color: palette.textPrimary),
          ),
        ),
        const SizedBox(height: _titleToPad),
        Semantics(
          container: true,
          label: ContractStrings.signHere,
          child: Container(
            height: _padHeight,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: radius,
              border: Border.all(
                color: palette.outline,
                width: AppDimens.borderWidth,
              ),
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  controller._canvasSize = constraints.biggest;
                  return RawGestureDetector(
                    behavior: HitTestBehavior.opaque,
                    gestures: {
                      _ImmediatePanRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            _ImmediatePanRecognizer
                          >(_ImmediatePanRecognizer.new, (recognizer) {
                            recognizer.dragStartBehavior =
                                DragStartBehavior.down;
                            recognizer.onStart = (details) {
                              controller._start(details.localPosition);
                            };
                            recognizer.onUpdate = (details) {
                              controller._extend(details.localPosition);
                            };
                            recognizer.onEnd = (_) => controller._end();
                            recognizer.onCancel = controller._end;
                          }),
                    },
                    child: ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) => CustomPaint(
                        size: constraints.biggest,
                        painter: _SignaturePainter(
                          strokes: controller._strokes,
                          ink: palette.linkInk,
                          revision: controller._revision,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: _padToClear),
        Align(
          alignment: Alignment.centerRight,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => _ClearButton(
              onPressed: controller.isEmpty ? null : controller.clear,
            ),
          ),
        ),
      ],
    );
  }
}

/// What the student has drawn on a [ContractSignaturePad], and its PNG.
class ContractSignatureController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];

  /// The stroke the finger is drawing now; null between strokes and while
  /// the finger is outside the pad.
  List<Offset>? _active;

  /// Bumped on every change, so the painter repaints for the same list.
  int _revision = 0;

  /// The pad's size at its last layout — what [toPng] renders at.
  Size? _canvasSize;

  /// Nothing drawn yet, or cleared since.
  bool get isEmpty => _strokes.isEmpty;

  /// How many separate strokes are drawn.
  @visibleForTesting
  int get strokeCount => _strokes.length;

  void clear() {
    _active = null;
    if (_strokes.isEmpty) return;
    _strokes.clear();
    _changed();
  }

  /// What is drawn, as a PNG on a transparent background in a fixed dark
  /// ink, at up to twice the pad's size (kept under 0.6 megapixels) — the
  /// bytes `signatureDataUrl` wraps. Null when nothing is drawn or the pad
  /// has not been laid out.
  Future<Uint8List?> toPng() async {
    final size = _canvasSize;
    if (_strokes.isEmpty || size == null || size.isEmpty) return null;

    final ratio = math.min(
      _exportPixelRatio,
      math.sqrt(_maxExportPixels / (size.width * size.height)),
    );
    final width = (size.width * ratio).floor();
    final height = (size.height * ratio).floor();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(ratio);
    _SignaturePainter(
      strokes: _strokes,
      ink: _exportInk,
      revision: _revision,
    ).paint(canvas, size);
    final image = await recorder.endRecording().toImage(width, height);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  void _start(Offset point) {
    _active = null;
    _extend(point);
  }

  /// A point inside the pad continues the active stroke, or starts one; a
  /// point outside ends it, so re-entering starts a new stroke rather than
  /// joining across the gap.
  void _extend(Offset point) {
    if (!_inside(point)) {
      _active = null;
      return;
    }
    final active = _active;
    if (active == null) {
      _strokes.add(_active = [point]);
    } else {
      active.add(point);
    }
    _changed();
  }

  void _end() => _active = null;

  bool _inside(Offset point) =>
      _canvasSize == null || (Offset.zero & _canvasSize!).contains(point);

  void _changed() {
    _revision++;
    notifyListeners();
  }
}

/// A pan recognizer that wins its gesture the moment the finger lands, so a
/// stroke is never handed to a scroll view around the pad.
class _ImmediatePanRecognizer extends PanGestureRecognizer {
  _ImmediatePanRecognizer() : super();

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter({
    required this.strokes,
    required this.ink,
    required this.revision,
  });

  final List<List<Offset>> strokes;
  final Color ink;
  final int revision;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = ink
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    final dot = Paint()
      ..color = ink
      ..isAntiAlias = true;

    for (final stroke in strokes) {
      if (stroke.length == 1) {
        // A tap is a dot — something is drawn, as the backend requires.
        canvas.drawCircle(stroke.first, _strokeWidth / 2, dot);
        continue;
      }
      // Through each pair's midpoint, so a quick stroke reads as a curve.
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length - 1; i++) {
        final mid = (stroke[i] + stroke[i + 1]) / 2;
        path.quadraticBezierTo(stroke[i].dx, stroke[i].dy, mid.dx, mid.dy);
      }
      path.lineTo(stroke.last.dx, stroke.last.dy);
      canvas.drawPath(path, line);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) =>
      old.revision != revision || old.ink != ink;
}

/// "Цэвэрлэх / Clear" — the screenshot's blue text action, flat in the
/// disabled-label role while there is nothing to clear.
class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: ContractStrings.clear,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_clearInset, 10, _clearInset, 10),
          child: Text(
            ContractStrings.clear,
            style: _clearStyle.copyWith(
              color: onPressed == null
                  ? palette.disabledInk
                  : palette.accentText,
            ),
          ),
        ),
      ),
    );
  }
}

const TextStyle _titleStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 16,
  height: 24 / 16,
  fontWeight: FontWeight.w400,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _clearStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 24 / 14,
  fontWeight: FontWeight.w600,
  leadingDistribution: TextLeadingDistribution.even,
);
