import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_system_ui.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../course_learning/presentation/widgets/course_learning_back_button.dart';
import '../../../payments/domain/payment_checkout.dart';
import '../widgets/home_pill_button.dart';
import 'payment_flow_strings.dart';

// The pieces the Adult payment flow's screens share (Issue #198), measured
// off its Figma references at 1:1 (393 wide, a 44pt status-bar inset, a 34pt
// home-indicator inset). As on the Payment screen, every text is placed by
// its baseline: Manrope's line box is 1.366em with the baseline 1.066em down,
// so a box of height H puts it (H - 1.366·size) / 2 + 1.066·size from its
// top.

/// The colours the shared palettes do not already hold.
abstract final class PaymentFlowPalette {
  /// Behind a sheet: the references darken white to #666666.
  static const Color barrier = AppColors.barrier;

  /// A sheet's drag handle.
  static const Color handle = AppColors.sheetHandle;

  /// The bank sheet's names — a cooler near-black than the text tokens.
  static const Color bankName = AppColors.textDeep;

  /// Inside the success tick's ring: its green at 20%.
  static const Color successFill = AppColors.successFillStrong;
}

/// **TEMPORARY** (Issue #198): the logos, method icons and eBarimt QR are cut
/// from the references' 3x exports — no official assets were supplied. Each
/// keeps the reference's own size, so swapping in an official export of the
/// same size changes nothing else.
abstract final class PaymentFlowAssets {
  static const String _dir = 'assets/images/payments';

  static const String qpay = '$_dir/qpay.png';
  static const String storePay = '$_dir/storepay.png';
  static const String card = '$_dir/card.png';
  static const String transfer = '$_dir/transfer.png';
  static const String ebarimtQr = '$_dir/ebarimt_qr.png';

  /// A [PaymentBank.id]'s logo: a 40pt circle with its grey ring.
  static String bank(String id) => '$_dir/bank_$id.png';
}

/// The screens' header height under the status bar, as on the Payment
/// screen.
const double paymentFlowHeaderHeight = 63;

/// One line of Manrope in a fixed line box of [box] points.
Widget paymentFlowText(
  String text, {
  required double size,
  required double box,
  FontWeight weight = FontWeight.w400,
  Color? color,
  TextAlign align = TextAlign.start,
  bool header = false,
}) {
  return Semantics(
    header: header,
    // A `Builder` for the theme's context: it adds no render object, so the
    // text lays out exactly as before (Dark Mode Phase 5).
    child: Builder(
      builder: (context) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: align,
        style: paymentFlowStyle(
          context,
          size: size,
          box: box,
          weight: weight,
          color: color,
        ),
      ),
    ),
  );
}

TextStyle paymentFlowStyle(
  BuildContext context, {
  required double size,
  required double box,
  FontWeight weight = FontWeight.w400,
  Color? color,
}) {
  return TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: size,
    height: box / size,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: weight,
    color: color ?? context.palette.textPrimary,
  );
}

/// The white header: the round back control and, when given, a centred
/// [title]. No rule under it — none of the flow's references draws one.
class PaymentFlowHeader extends StatelessWidget {
  const PaymentFlowHeader({super.key, this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.palette.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: paymentFlowHeaderHeight,
          child: Stack(
            children: [
              const Positioned(
                left: 0,
                top: 0,
                child: CourseLearningBackButton(icon: AppIcons.arrowLeft),
              ),
              if (title case final title?)
                // Centred on the back control's own centre line.
                Positioned(
                  left: 64,
                  right: 64,
                  top: 20.07,
                  child: paymentFlowText(
                    title,
                    size: 18,
                    box: 24,
                    weight: FontWeight.w700,
                    align: TextAlign.center,
                    header: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A screen of the flow: [PaymentFlowHeader], a scrolling body, and a white
/// bar holding one full-width button 16pt above the home indicator.
class PaymentFlowScaffold extends StatelessWidget {
  const PaymentFlowScaffold({
    required this.body,
    required this.action,
    required this.onAction,
    super.key,
    this.title,
  });

  final String? title;
  final Widget body;
  final String action;

  /// Null draws the button disabled.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.page(context, navigationBar: context.palette.surface),
      child: Scaffold(
        backgroundColor: context.palette.surface,
        body: Column(
          children: [
            PaymentFlowHeader(title: title),
            Expanded(
              child: SingleChildScrollView(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppDimens.maxContentWidth,
                    ),
                    child: body,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                16,
                AppDimens.screenPadding,
                16 + bottomInset,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth:
                        AppDimens.maxContentWidth - 2 * AppDimens.screenPadding,
                  ),
                  child: HomePillButton(
                    label: action,
                    height: 44,
                    raised: false,
                    labelSize: 16,
                    labelWeight: FontWeight.w600,
                    onPressed: onAction,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A full-width hairline in the Home border grey.
class PaymentFlowRule extends StatelessWidget {
  const PaymentFlowRule({super.key, this.color});

  /// Null is the theme's [AppPalette.outline].
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1,
    child: ColoredBox(color: color ?? context.palette.outline),
  );
}

/// "Төлбөрийн хэлбэр": the bordered card of payment methods, each a row
/// with its logo, its name and a radio. [footer] sits under the rows inside
/// the same card — the transfer details on the full transfer reference.
class PaymentMethodCard extends StatelessWidget {
  const PaymentMethodCard({
    required this.methods,
    required this.selected,
    required this.onTap,
    super.key,
    this.footer,
  });

  final List<PaymentMethod> methods;
  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.screenPadding),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.palette.surface,
          border: Border.all(color: context.palette.outline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 17.1, 16, 0),
              child: paymentFlowText(
                PaymentFlowStrings.methods,
                size: 16,
                box: 22,
                weight: FontWeight.w700,
                header: true,
              ),
            ),
            const SizedBox(height: 16.9),
            for (final (i, method) in methods.indexed) ...[
              if (i != 0) const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _MethodRow(
                  method: method,
                  selected: method == selected,
                  onTap: () => onTap(method),
                ),
              ),
            ],
            if (footer case final footer?)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: footer,
              ),
            if (footer == null) const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  static const double _height = 64;

  /// Each logo as the references place it: asset, left, top, width, height
  /// inside the row. They are not aligned to one another, and are kept as
  /// drawn.
  static const Map<PaymentMethod, (String, double, double, double, double)>
  _logos = {
    PaymentMethod.qpay: (PaymentFlowAssets.qpay, 18, 11, 42, 42),
    PaymentMethod.storePay: (PaymentFlowAssets.storePay, 15, 11, 42, 42),
    PaymentMethod.card: (PaymentFlowAssets.card, 16, 11, 40, 42),
    PaymentMethod.transfer: (PaymentFlowAssets.transfer, 16, 10, 40, 42),
  };

  /// Where each name starts — Qpay's sits further right, as drawn.
  static const Map<PaymentMethod, double> _labelLeft = {
    PaymentMethod.qpay: 80,
    PaymentMethod.storePay: 72,
    PaymentMethod.card: 72,
    PaymentMethod.transfer: 72,
  };

  static String label(PaymentMethod method) => switch (method) {
    PaymentMethod.qpay => PaymentFlowStrings.qpay,
    PaymentMethod.storePay => PaymentFlowStrings.storePay,
    PaymentMethod.card => PaymentFlowStrings.card,
    PaymentMethod.transfer => PaymentFlowStrings.transfer,
  };

  @override
  Widget build(BuildContext context) {
    final (asset, left, top, width, height) = _logos[method]!;
    final shape = RoundedRectangleBorder(
      side: BorderSide(color: context.palette.outline),
      borderRadius: BorderRadius.circular(16),
    );
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: label(method),
      excludeSemantics: true,
      child: Material(
        color: context.palette.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: _height,
            child: Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  child: Image.asset(asset, width: width, height: height),
                ),
                Positioned(
                  left: _labelLeft[method],
                  right: 52,
                  top: 20.89,
                  child: paymentFlowText(
                    label(method),
                    size: 16,
                    box: 22,
                    weight: FontWeight.w700,
                  ),
                ),
                Positioned(
                  right: 16,
                  top: 22,
                  child: PaymentRadio(selected: selected),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 20pt radio: a thin grey ring, or a thick blue one round a white dot.
class PaymentRadio extends StatelessWidget {
  const PaymentRadio({required this.selected, super.key});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.palette.surface,
        border: selected
            ? Border.all(color: context.palette.accent, width: 6)
            : Border.all(color: context.palette.outline),
      ),
    );
  }
}

/// The 36pt round copy control: copies [value] to the clipboard. Nothing is
/// drawn to confirm it — no reference shows a confirmation.
class PaymentCopyButton extends StatelessWidget {
  const PaymentCopyButton({
    required this.value,
    required this.label,
    super.key,
  });

  final String value;

  /// What is copied, for assistive technology.
  final String label;

  static const double size = 36;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: PaymentFlowStrings.copy(label),
      excludeSemantics: true,
      child: Material(
        color: context.palette.surface,
        shape: CircleBorder(side: BorderSide(color: context.palette.outline)),
        shadowColor: context.palette.shadowSubtle.withValues(alpha: 0.08),
        elevation: 1,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Clipboard.setData(ClipboardData(text: value)),
          child: const SizedBox.square(
            dimension: size,
            child: Center(child: PaymentBoldGlyph(PaymentGlyph.copy, size: 20)),
          ),
        ),
      ),
    );
  }
}

/// The bank transfer details — reference 6's sheet and the box under the
/// methods on reference 7 draw the same block, 16pt in from whatever holds
/// it, with a rule running edge to edge above the payment reference.
class BankTransferDetailsView extends StatelessWidget {
  const BankTransferDetailsView({
    required this.details,
    super.key,
    this.top = 29.43,
    this.bottom = 16.56,
  });

  final BankTransferDetails details;

  /// From the block's top to the title's line box.
  final double top;

  /// From the payment reference's line box to the block's end.
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, top, 16, 0),
          child: paymentFlowText(
            PaymentFlowStrings.transferTitle,
            size: 18,
            box: 24,
            weight: FontWeight.w700,
            header: true,
          ),
        ),
        const SizedBox(height: 22.44),
        _DetailRow(label: PaymentFlowStrings.bank, value: details.bankName),
        const SizedBox(height: 28),
        _DetailRow(
          label: PaymentFlowStrings.recipient,
          value: details.recipient,
        ),
        const SizedBox(height: 28),
        _DetailRow(
          label: PaymentFlowStrings.accountNumber,
          value: details.accountNumber,
          copyable: true,
        ),
        const SizedBox(height: 28),
        _DetailRow(
          label: PaymentFlowStrings.iban,
          value: details.iban,
          copyable: true,
        ),
        const SizedBox(height: 25.13),
        // A hairline with a fainter third of a point under it, as drawn.
        const PaymentFlowRule(),
        SizedBox(
          height: 0.67,
          child: ColoredBox(color: context.palette.divider),
        ),
        const SizedBox(height: 15.77),
        _DetailRow(
          label: PaymentFlowStrings.reference,
          value: details.reference,
        ),
        SizedBox(height: bottom),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 20,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: paymentFlowText(
                label,
                size: 14,
                box: 20,
                color: context.palette.textSecondary,
              ),
            ),
            Positioned(
              left: 96,
              right: copyable ? PaymentCopyButton.size + 10 : 0,
              top: 0,
              child: paymentFlowText(
                value,
                size: 14,
                box: 20,
                weight: FontWeight.w600,
                align: TextAlign.end,
              ),
            ),
            if (copyable)
              Positioned(
                right: 0,
                top: -7.77,
                child: PaymentCopyButton(value: value, label: label),
              ),
          ],
        ),
      ),
    );
  }
}

/// Opens a flow sheet: white, 16pt top corners, over the references' 60%
/// black.
Future<T?> showPaymentSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surfaceElevated,
    barrierColor: context.palette.barrier,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: builder,
  );
}

/// A flow sheet's body under its 72×6 drag handle, 8pt down.
class PaymentSheetFrame extends StatelessWidget {
  const PaymentSheetFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 72,
              height: 6,
              decoration: BoxDecoration(
                color: context.palette.sheetHandle,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum PaymentGlyph { check, copy }

/// Phosphor's *bold* "Check" and "Copy", which the references draw. The
/// bundled Phosphor font is the regular weight only, so these two are
/// painted from Phosphor's own 256-unit geometry at its bold stroke (24).
class PaymentBoldGlyph extends StatelessWidget {
  const PaymentBoldGlyph(this.glyph, {super.key, this.size = 20, this.color});

  final PaymentGlyph glyph;
  final double size;

  /// Null is the theme's [AppPalette.textPrimary].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _BoldGlyphPainter(glyph, color ?? context.palette.textPrimary),
    );
  }
}

class _BoldGlyphPainter extends CustomPainter {
  const _BoldGlyphPainter(this.glyph, this.color);

  final PaymentGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 256;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24 * unit
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Offset p(double x, double y) => Offset(x * unit, y * unit);
    switch (glyph) {
      case PaymentGlyph.check:
        canvas.drawPath(
          Path()
            ..moveTo(p(40, 144).dx, p(40, 144).dy)
            ..lineTo(p(96, 200).dx, p(96, 200).dy)
            ..lineTo(p(224, 72).dx, p(224, 72).dy),
          paint,
        );
      case PaymentGlyph.copy:
        canvas
          ..drawPath(
            Path()
              ..moveTo(p(168, 168).dx, p(168, 168).dy)
              ..lineTo(p(216, 168).dx, p(216, 168).dy)
              ..lineTo(p(216, 40).dx, p(216, 40).dy)
              ..lineTo(p(88, 40).dx, p(88, 40).dy)
              ..lineTo(p(88, 88).dx, p(88, 88).dy),
            paint,
          )
          ..drawRect(Rect.fromPoints(p(40, 88), p(168, 216)), paint);
    }
  }

  @override
  bool shouldRepaint(_BoldGlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}
