import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../payments/domain/payment_checkout.dart';
import '../payment_strings.dart';
import '../widgets/home_palette.dart';
import 'payment_flow_strings.dart';
import 'payment_flow_widgets.dart';
import 'payment_method_screen.dart';

/// Where the slider's thumb sits for an amount, as a share of the track:
/// straight lines between [knots], each an (amount, share) pair in rising
/// order.
///
/// The default runs evenly from the range's minimum to its maximum. The
/// references do not: they put 750,000₮ a third of the way along a
/// 500,000–1,500,000₮ track, and the minimum's thumb inside the track's
/// start but the maximum's centred on its end. Figma being the source of
/// truth, the preview passes those drawn positions as knots
/// (`PaymentReferenceSlider`).
class PaymentSliderScale {
  /// At least two knots: the scale's two ends.
  const PaymentSliderScale(this.knots);

  PaymentSliderScale.linear(PaymentAmountRange range)
    : knots = [(range.min, 0), (range.max, 1)];

  final List<(num, double)> knots;

  double shareOf(num amount) {
    if (amount <= knots.first.$1) return knots.first.$2;
    for (var i = 1; i < knots.length; i++) {
      final (a1, s1) = knots[i];
      if (amount <= a1) {
        final (a0, s0) = knots[i - 1];
        return s0 + (s1 - s0) * (amount - a0) / (a1 - a0);
      }
    }
    return knots.last.$2;
  }

  num amountAt(double share) {
    if (share <= knots.first.$2) return knots.first.$1;
    for (var i = 1; i < knots.length; i++) {
      final (a1, s1) = knots[i];
      if (share <= s1) {
        final (a0, s0) = knots[i - 1];
        return a0 + (a1 - a0) * (share - s0) / (s1 - s0);
      }
    }
    return knots.last.$1;
  }
}

/// "Төлбөр төлөх" — the amount step of the Adult payment flow (Issue #198,
/// references 1–3): choose how much to pay, from the installment that is due
/// up to everything still owed, and a way to pay.
///
/// UI only: the methods here select locally, and "Төлбөр шалгах" goes on to
/// the method screen ([PaymentMethodScreen]) without contacting anything.
class PaymentAmountScreen extends StatefulWidget {
  const PaymentAmountScreen({
    required this.checkout,
    super.key,
    this.scale,
    this.initialAmount,
    this.showTooltip = false,
  });

  final PaymentCheckout checkout;

  /// Null spreads the range evenly along the track.
  final PaymentSliderScale? scale;

  /// Null starts at the minimum, as reference 1 does.
  final num? initialAmount;

  /// Whether the amount bubble shows before the slider is first moved —
  /// for drawing references 2 and 3 at rest.
  final bool showTooltip;

  @override
  State<PaymentAmountScreen> createState() => _PaymentAmountScreenState();
}

class _PaymentAmountScreenState extends State<PaymentAmountScreen> {
  late num _amount = widget.checkout.range.snap(
    widget.initialAmount ?? widget.checkout.range.min,
  );
  late bool _moved = widget.showTooltip;
  PaymentMethod _method = PaymentMethod.qpay;

  PaymentAmountRange get _range => widget.checkout.range;

  void _setAmount(num amount) {
    setState(() {
      _amount = _range.snap(amount);
      _moved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    return PaymentFlowScaffold(
      title: PaymentFlowStrings.title,
      action: PaymentFlowStrings.check,
      onAction: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PaymentMethodScreen(checkout: widget.checkout),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.screenPadding,
              16.97,
              AppDimens.screenPadding,
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Bound(
                    label: PaymentFlowStrings.yourAmount,
                    amount: _amount,
                    caption: PaymentFlowStrings.minimum,
                  ),
                ),
                Expanded(
                  child: _Bound(
                    label: PaymentFlowStrings.balance,
                    amount: range.max,
                    caption: PaymentFlowStrings.maximum,
                    end: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24.73),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.screenPadding,
            ),
            child: _AmountSlider(
              range: range,
              scale: widget.scale ?? PaymentSliderScale.linear(range),
              amount: _amount,
              showTooltip: _moved,
              onChanged: _setAmount,
            ),
          ),
          const SizedBox(height: 8.41),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.screenPadding,
            ),
            child: Text.rich(
              TextSpan(
                text: PaymentFlowStrings.eachLater(range.laterInstallments),
                children: [
                  TextSpan(
                    text: PaymentStrings.amount(
                      range.eachLaterInstallment(_amount),
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: paymentFlowStyle(
                size: 14,
                box: 20,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 14.59),
          const PaymentFlowRule(),
          const SizedBox(height: 16),
          PaymentMethodCard(
            methods: const [
              PaymentMethod.qpay,
              PaymentMethod.storePay,
              PaymentMethod.transfer,
            ],
            selected: _method,
            onTap: (method) => setState(() => _method = method),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// One end of the range: its caption, its amount, and "доод/дээд хязгаар".
class _Bound extends StatelessWidget {
  const _Bound({
    required this.label,
    required this.amount,
    required this.caption,
    this.end = false,
  });

  final String label;
  final num amount;
  final String caption;
  final bool end;

  @override
  Widget build(BuildContext context) {
    final align = end ? TextAlign.end : TextAlign.start;
    return Column(
      crossAxisAlignment: end
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        paymentFlowText(
          label,
          size: 14,
          box: 20,
          color: AppColors.textSecondary,
          align: align,
        ),
        const SizedBox(height: 1.34),
        paymentFlowText(
          PaymentStrings.amount(amount),
          size: 18,
          box: 24,
          weight: FontWeight.w700,
          align: align,
        ),
        const SizedBox(height: 1.96),
        paymentFlowText(
          caption,
          size: 12,
          box: 16,
          color: AppColors.textSecondary,
          align: align,
        ),
      ],
    );
  }
}

/// The amount slider: an 8pt track, filled blue up to a 24pt white thumb
/// ringed in blue, and — once moved — a bubble with the amount above the
/// thumb, kept within the thumb's own reach at either end.
class _AmountSlider extends StatelessWidget {
  const _AmountSlider({
    required this.range,
    required this.scale,
    required this.amount,
    required this.showTooltip,
    required this.onChanged,
  });

  final PaymentAmountRange range;
  final PaymentSliderScale scale;
  final num amount;
  final bool showTooltip;
  final ValueChanged<num> onChanged;

  static const double _thumb = 24;
  static const double _track = 8;
  static const double _tipHeight = 32;
  static const double _tipGap = 10;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final centre = scale.shareOf(amount) * width;
        void seek(double dx) =>
            onChanged(scale.amountAt((dx / width).clamp(0.0, 1.0)));

        return Semantics(
          slider: true,
          label: PaymentFlowStrings.yourAmount,
          value: PaymentStrings.amount(amount),
          increasedValue: PaymentStrings.amount(
            range.snap(amount + range.step),
          ),
          decreasedValue: PaymentStrings.amount(
            range.snap(amount - range.step),
          ),
          onIncrease: () => onChanged(amount + range.step),
          onDecrease: () => onChanged(amount - range.step),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => seek(details.localPosition.dx),
            onHorizontalDragStart: (details) => seek(details.localPosition.dx),
            onHorizontalDragUpdate: (details) => seek(details.localPosition.dx),
            child: SizedBox(
              height: _thumb,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: (_thumb - _track) / 2,
                    height: _track,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: HomePalette.border,
                        borderRadius: BorderRadius.circular(_track / 2),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    width: math.max(centre, _track),
                    top: (_thumb - _track) / 2,
                    height: _track,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: HomePalette.accent,
                        borderRadius: BorderRadius.circular(_track / 2),
                      ),
                    ),
                  ),
                  Positioned(
                    left: centre - _thumb / 2,
                    top: 0,
                    child: Container(
                      width: _thumb,
                      height: _thumb,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                        border: Border.all(color: HomePalette.accent, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowSubtle,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (showTooltip)
                    _Tooltip(
                      label: PaymentStrings.amount(amount),
                      centre: centre,
                      min: -_thumb / 2,
                      max: width + _thumb / 2,
                      top: -(_tipGap + _tipHeight),
                      height: _tipHeight,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The amount bubble, centred over the thumb but kept between [min] and
/// [max].
class _Tooltip extends StatelessWidget {
  const _Tooltip({
    required this.label,
    required this.centre,
    required this.min,
    required this.max,
    required this.top,
    required this.height,
  });

  final String label;
  final double centre;
  final double min;
  final double max;
  final double top;
  final double height;

  static const double _padding = 12.5;

  @override
  Widget build(BuildContext context) {
    final style = paymentFlowStyle(size: 11, box: 14, weight: FontWeight.w600);
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width = painter.width + 2 * _padding;
    painter.dispose();
    final left = (centre - width / 2)
        .clamp(min, math.max(min, max - width))
        .toDouble();

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: HomePalette.border),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowSubtle,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(child: Text(label, maxLines: 1, style: style)),
        ),
      ),
    );
  }
}
