import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_typography.dart';
import '../../course_learning/presentation/widgets/course_learning_back_button.dart';
import '../../payments/domain/payment_plan.dart';
import 'payment_strings.dart';
import 'widgets/home_palette.dart';
import 'widgets/home_pill_button.dart';

// Measured off the three Figma "Төлбөр" references at 1:1 (393 wide, a 44pt
// status-bar inset, a 34pt home-indicator inset). Every text is placed by its
// baseline: Manrope's line box is 1.366em with the baseline 1.066em down, so a
// box of height H puts it (H - 1.366·size) / 2 + 1.066·size from its top.

/// The two colours the Home palette does not already hold.
///
/// The next installment's badge outline — a deeper blue than the badge's
/// [HomePalette.liveFill] and the app's [HomePalette.accent].
const Color _nextOutline = Color(0xFF155EEF);

/// The dotted line joining the schedule's badges.
const Color _connector = Color(0xFFBAC5FF);

/// An upcoming installment's label and number — 30% black, `#B2B2B2` on the
/// badge's white.
const Color _upcomingInk = Color(0x4D000000);

/// The header below the status bar: the back control's 12 + 40, and 11 under
/// it to the rule.
const double _headerHeight = 63;

const double _badgeSize = 56;
const double _badgeRadius = 12;

/// A row's badge to the next row's: 56, then the 24 the dotted line spans.
const double _rowGap = 24;

/// The progress bar.
const double _barHeight = 8;

/// The bottom bar: the button 15 below the bar's rule and 16 above the
/// home-indicator inset.
const double _barTop = 15;
const double _barBottom = 16;
const double _buttonHeight = 44;

/// The Adult Payment screen ("Төлбөр") — the plan for one enrollment and its
/// installment schedule, drawn from three Figma references (Issue #196):
/// partly paid, fully paid and overdue.
///
/// **Data.** Nothing is fetched here: the screen draws the [plan] it is given
/// on [today]. No real source fills one yet — `GET /me/ledger`'s installments
/// are unconfirmed — so for now only the temporary `PaymentPlanUiFixtures`
/// do, and only outside release builds (see `HomeScreen`).
///
/// **Inert controls.** "Төлбөр төлөх" is drawn as the references draw it —
/// live while anything is owed, disabled once the plan is paid off — but
/// leads nowhere yet, and neither do the rows' chevrons: there are no frames
/// for paying or for an installment's detail.
///
/// **Figma is the source of truth.** The progress bar is filled to the
/// plan's own [PaymentPlan.paidFraction], the rows print the plan's own date
/// labels, and each row is placed by its [rowGeometry] — so the fixtures can
/// reproduce each reference exactly as drawn, including where the three
/// references differ from one another.
class PaymentScreen extends StatelessWidget {
  const PaymentScreen({
    required this.plan,
    required this.today,
    super.key,
    this.rowGeometry = const [],
  });

  final PaymentPlan plan;

  /// The day the states are worked out on — "3 хоног дутуу", overdue.
  final DateTime today;

  /// Where each schedule row's parts sit, by row; a row with no entry uses
  /// [PaymentRowGeometry]'s defaults. The references do not place every row
  /// alike, and the UI fixtures reproduce each one as drawn — see
  /// `PaymentReferenceRows`.
  final List<PaymentRowGeometry> rowGeometry;

  @override
  Widget build(BuildContext context) {
    final paidOff = plan.isPaidOff;
    final statuses = plan.statusesOn(today);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surfaceSubtle,
        body: Column(
          children: [
            const _Header(),
            Expanded(
              child: SingleChildScrollView(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppDimens.maxContentWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Summary(plan: plan),
                        const _Rule(),
                        _Schedule(
                          plan: plan,
                          statuses: statuses,
                          geometry: rowGeometry,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const _Rule(),
            // The references draw the bar white while there is something to
            // pay, and in the page's grey under the disabled button.
            ColoredBox(
              color: paidOff ? AppColors.surfaceSubtle : AppColors.surface,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  _barTop,
                  AppDimens.screenPadding,
                  _barBottom + bottomInset,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth:
                          AppDimens.maxContentWidth -
                          2 * AppDimens.screenPadding,
                    ),
                    child: HomePillButton(
                      label: PaymentStrings.payAction,
                      height: _buttonHeight,
                      raised: false,
                      labelSize: 16,
                      labelWeight: FontWeight.w600,
                      // Live but leading nowhere: no payment flow is
                      // designed or integrated yet.
                      onPressed: paidOff ? null : _noDestinationYet,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _noDestinationYet() {}
}

/// The 1pt rule between the header, the summary, the schedule and the bar.
class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: HomePalette.headerRule);
}

/// White, under the status bar: the back control and the centred title.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: _headerHeight,
              child: Stack(
                children: [
                  const Positioned(
                    left: 0,
                    top: 0,
                    child: CourseLearningBackButton(icon: AppIcons.arrowLeft),
                  ),
                  // Centred on the back control's own centre line.
                  Positioned(
                    left: 64,
                    right: 64,
                    top: 20.07,
                    child: _text(
                      PaymentStrings.title,
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
            const _Rule(),
          ],
        ),
      ),
    );
  }
}

/// The total, and either the paid/remaining split under its bar or — paid
/// off — the green "Төлөгдөж дуссан".
class _Summary extends StatelessWidget {
  const _Summary({required this.plan});

  final PaymentPlan plan;

  @override
  Widget build(BuildContext context) {
    final paidOff = plan.isPaidOff;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        24.39,
        AppDimens.screenPadding,
        paidOff ? 23.95 : 24.03,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _text(
            PaymentStrings.totalLabel(plan.courseTitle),
            size: 14,
            box: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 0),
          _text(
            PaymentStrings.amount(plan.totalDue),
            size: 32,
            box: 40,
            weight: FontWeight.w700,
          ),
          if (paidOff) ...[
            const SizedBox(height: 16.67),
            _text(
              PaymentStrings.paidOff,
              size: 16,
              box: 22,
              weight: FontWeight.w700,
              color: HomePalette.activeInk,
            ),
          ] else ...[
            const SizedBox(height: 39.62),
            _ProgressBar(fraction: plan.paidFraction),
            const SizedBox(height: 8.06),
            Row(
              children: [
                Expanded(
                  child: _text(
                    PaymentStrings.paid,
                    size: 14,
                    box: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
                _text(
                  PaymentStrings.unpaidInstallments(plan.unpaidCount),
                  size: 14,
                  box: 20,
                  color: AppColors.textSecondary,
                  align: TextAlign.end,
                ),
              ],
            ),
            const SizedBox(height: 0.91),
            Row(
              children: [
                Expanded(
                  child: _text(
                    PaymentStrings.amount(plan.totalPaid),
                    size: 16,
                    box: 22,
                    weight: FontWeight.w700,
                  ),
                ),
                _text(
                  PaymentStrings.amount(plan.balance),
                  size: 16,
                  box: 22,
                  weight: FontWeight.w700,
                  align: TextAlign.end,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The share paid, on the screen's grey track.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_barHeight / 2),
      child: SizedBox(
        height: _barHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: HomePalette.border),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: HomePalette.accent,
                  borderRadius: BorderRadius.circular(_barHeight / 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Төлбөрийн хуваарь" and one row per installment, joined by a dotted line.
class _Schedule extends StatelessWidget {
  const _Schedule({
    required this.plan,
    required this.statuses,
    required this.geometry,
  });

  final PaymentPlan plan;
  final List<InstallmentStatus> statuses;
  final List<PaymentRowGeometry> geometry;

  @override
  Widget build(BuildContext context) {
    final installments = plan.installments;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        17.06,
        AppDimens.screenPadding,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _text(
            PaymentStrings.schedule,
            size: 16,
            box: 22,
            weight: FontWeight.w700,
            header: true,
          ),
          const SizedBox(height: 24.94),
          for (var i = 0; i < installments.length; i++) ...[
            if (i != 0) const _Connector(),
            _InstallmentRow(
              installment: installments[i],
              status: statuses[i],
              geometry: i < geometry.length
                  ? geometry[i]
                  : const PaymentRowGeometry(),
            ),
          ],
        ],
      ),
    );
  }
}

/// The dotted line between two badges: 2pt dashes 2pt apart, down the badge
/// column's centre.
class _Connector extends StatelessWidget {
  const _Connector();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _rowGap,
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: _badgeSize / 2 - 2 / 3, top: 3),
          child: Column(
            children: [
              for (var i = 0; i < 5; i++) ...[
                if (i != 0) const SizedBox(height: 2),
                Container(width: 4 / 3, height: 2, color: _connector),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One installment: its badge, its date (and, for the next one, how it
/// stands), its amount and a chevron.
class _InstallmentRow extends StatelessWidget {
  const _InstallmentRow({
    required this.installment,
    required this.status,
    required this.geometry,
  });

  final PaymentInstallment installment;
  final InstallmentStatus status;
  final PaymentRowGeometry geometry;

  /// Where the caret's ink sits inside its 20pt glyph box (Phosphor's
  /// `caret-right`: 88–184 across and 40–216 down, of 256).
  static const double _caretInkLeft = 20 * 88 / 256;
  static const double _caretInkTop = 20 * 40 / 256;

  @override
  Widget build(BuildContext context) {
    final date = installment.dueDateLabel;
    final amount = PaymentStrings.amount(installment.amount);
    final (String? note, Color? noteColor) = switch (status.kind) {
      InstallmentKind.next => (
        PaymentStrings.dueIn(status.daysLeft!),
        HomePalette.accent,
      ),
      InstallmentKind.overdue => (
        PaymentStrings.overdue,
        HomePalette.overdueInk,
      ),
      _ => (null, null),
    };
    final textLeft = geometry.badgeLeft + _badgeSize + 16;

    return Semantics(
      container: true,
      label: [
        date,
        ?note,
        amount,
        if (status.kind == InstallmentKind.paid) PaymentStrings.paidInstallment,
      ].join(', '),
      child: ExcludeSemantics(
        child: SizedBox(
          height: _badgeSize,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: geometry.badgeLeft,
                    top: 0,
                    child: _InstallmentBadge(
                      number: installment.number,
                      kind: status.kind,
                    ),
                  ),
                  // One line sits on the badge's centre; two straddle it.
                  Positioned(
                    left: textLeft,
                    right: width - geometry.amountRight + 80,
                    top: note == null ? 18.39 : 6.39,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _text(date, size: 14, box: 20),
                        if (note != null) ...[
                          const SizedBox(height: 3.67),
                          _text(note, size: 14, box: 20, color: noteColor),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    right: width - geometry.amountRight,
                    top: 18.27,
                    child: _text(
                      amount,
                      size: 14,
                      box: 20,
                      weight: FontWeight.w700,
                      align: TextAlign.end,
                    ),
                  ),
                  // Drawn as the references draw it; there is no installment
                  // detail to open yet.
                  Positioned(
                    left: geometry.caretLeft - _caretInkLeft,
                    top: 21 - _caretInkTop,
                    child: const Icon(
                      AppIcons.caretRight,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Where one schedule row's parts sit, in points from the row's left edge
/// (the screen's 16pt content inset). The defaults are the first row of the
/// partly-paid reference.
class PaymentRowGeometry {
  const PaymentRowGeometry({
    this.badgeLeft = 0,
    this.amountRight = 313,
    this.caretLeft = 337.67,
  });

  /// The badge's left edge; the date follows it 16pt after the badge.
  final double badgeLeft;

  /// Where the amount ends.
  final double amountRight;

  /// Where the chevron's ink begins.
  final double caretLeft;
}

/// The 56pt square at a row's start: a tick once paid; otherwise "Төлөлт" over
/// the installment's number — outlined in blue when it is next, red when
/// overdue, grey when it is still to come.
class _InstallmentBadge extends StatelessWidget {
  const _InstallmentBadge({required this.number, required this.kind});

  final int number;
  final InstallmentKind kind;

  @override
  Widget build(BuildContext context) {
    final (Color fill, Color outline, double outlineWidth) = switch (kind) {
      InstallmentKind.paid => (
        HomePalette.activeFill,
        HomePalette.activeOutline,
        1.0,
      ),
      InstallmentKind.next => (HomePalette.liveFill, _nextOutline, 4 / 3),
      InstallmentKind.overdue => (
        HomePalette.overdueFill,
        HomePalette.overdueOutline,
        4 / 3,
      ),
      InstallmentKind.upcoming => (AppColors.surface, HomePalette.border, 1.0),
    };
    final upcoming = kind == InstallmentKind.upcoming;

    return Container(
      width: _badgeSize,
      height: _badgeSize,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(_badgeRadius),
        border: Border.all(color: outline, width: outlineWidth),
      ),
      child: kind == InstallmentKind.paid
          ? const Icon(
              AppIcons.check,
              size: 24,
              color: HomePalette.activeOutline,
            )
          : Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 7.37 - outlineWidth,
                  child: _text(
                    PaymentStrings.installment,
                    size: 12,
                    box: 18,
                    color: upcoming ? _upcomingInk : AppColors.textSecondary,
                    align: TextAlign.center,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 25.0 - outlineWidth,
                  child: _text(
                    '$number',
                    size: 18,
                    box: 24,
                    weight: FontWeight.w700,
                    color: upcoming ? _upcomingInk : AppColors.textPrimary,
                    align: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }
}

/// One line of Manrope in a fixed line box of [box] points, so the column it
/// sits in places its baseline where the reference does.
Widget _text(
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
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: align,
      style: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: size,
        height: box / size,
        leadingDistribution: TextLeadingDistribution.even,
        fontWeight: weight,
        color: color ?? AppColors.textPrimary,
      ),
    ),
  );
}
