import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/presentation/student_tabs.dart';
import '../../home/presentation/widgets/contract_banner.dart';
import '../../home/presentation/widgets/home_header.dart';
import '../../home/presentation/widgets/home_palette.dart';
import '../data/sample_junior_progress.dart';
import '../domain/junior_progress.dart';
import 'junior_progress_strings.dart';
import 'widgets/junior_bottom_nav.dart';
import 'widgets/junior_home_palette.dart';
import 'widgets/junior_progress_calendar.dart';

// Measured off the Junior Learning Progress frame at 1:1 (393 wide, a 44pt
// status-bar inset). Every vertical gap below is the frame's own.

/// Header rule to the first card, and the page's bottom margin.
const double _pageTop = 16;
const double _pageBottom = 30;

/// Between the three stacked blocks: banner, payment card, panel.
const double _blockGap = 8;

/// The panel's outline — twice the hairline the cards above it use.
const double _panelBorder = 2;

/// Content inside the panel sits 14 in from its inner edge; the calendar,
/// which needs the width, only 6.
const double _panelInset = 14;
const double _calendarInset = 6;

/// The legend's discs, smaller than the calendar's.
const double _legendDisc = 24;

/// The junior student's "Сурлагын явц" (learning progress) — the Figma
/// "Junior Learning Progress" frame.
///
/// **Reuse.** The header is [HomeHeader] and the contract notice is
/// [ContractBanner], both unchanged in geometry: the frame draws the same
/// lockup, bell and 80pt amber banner the adult dashboard does, only with the
/// junior banner's own two lines. The tab bar is [JuniorBottomNav]. The
/// payment card and the panel below it are this frame's own: neither matches
/// an adult card's layout (the payment card stacks three lines and a pill
/// with no depth band; the adult tile stacks two and a banded pill).
///
/// **Data — BACKEND GAP.** No confirmed endpoint reports per-day attendance,
/// an exam score, the next payment or the contract state for a junior
/// student, so the screen renders [SampleJuniorProgress.reference] — the
/// frame's own design state — unless a [progress] is passed in. No action on
/// it has a destination: the banner, the pay button and the month arrows are
/// drawn as the frame draws them and do nothing, for the reason the adult
/// dashboard's own unwired actions document.
class JuniorProgressScreen extends StatelessWidget {
  const JuniorProgressScreen({super.key, this.progress});

  /// Defaults to [SampleJuniorProgress.reference].
  final JuniorProgress? progress;

  @override
  Widget build(BuildContext context) {
    final progress = this.progress ?? SampleJuniorProgress.reference;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
      ),
      child: Scaffold(
        // The page grey under the header; the header paints its own white.
        backgroundColor: AppColors.surfaceSubtle,
        bottomNavigationBar: const JuniorBottomNav(
          current: StudentTab.progress,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // White behind the status bar as well as the header, as the
            // frame draws it; the page grey starts under the rule.
            ColoredBox(
              color: AppColors.surface,
              child: SafeArea(
                bottom: false,
                child: _constrained(const HomeHeader()),
              ),
            ),
            Container(
              height: AppDimens.borderWidth,
              color: HomePalette.headerRule,
            ),
            Expanded(
              child: _constrained(
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.screenPadding,
                    _pageTop,
                    AppDimens.screenPadding,
                    _pageBottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!progress.contractSigned) ...[
                        const ContractBanner(
                          title: JuniorProgressStrings.contractTitle,
                          supporting: JuniorProgressStrings.showParent,
                        ),
                        const SizedBox(height: _blockGap),
                      ],
                      _PaymentCard(daysLeft: progress.paymentDaysLeft),
                      const SizedBox(height: _blockGap),
                      _ProgressPanel(progress: progress),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Caps the column at [AppDimens.maxContentWidth], centred, as every other
  /// screen does on a wide window.
  static Widget _constrained(Widget child) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
      child: child,
    ),
  );
}

/// "Дараанийн төлөлт:" — the outlined money tile, three lines, and the pay
/// pill under them. 144 tall in the frame.
class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.daysLeft});

  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12 - AppDimens.borderWidth),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
        border: Border.all(color: HomePalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HomePalette.iconTileFill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: HomePalette.border),
                ),
                child: const Icon(
                  AppIcons.money,
                  size: 24,
                  color: JuniorPalette.accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      JuniorProgressStrings.paymentTitle,
                      style: _labelStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      JuniorProgressStrings.showParent,
                      style: _bodyStyle.copyWith(color: HomePalette.statLabel),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      JuniorProgressStrings.paymentDueIn(daysLeft),
                      style: _statusStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // No destination yet — see the screen's class doc. An empty
          // callback rather than null keeps the pill in the frame's full
          // blue instead of a disabled treatment.
          _PayButton(onPressed: () {}),
        ],
      ),
    );
  }
}

/// The frame's flat blue pill: 36 tall, white label, no depth band.
class _PayButton extends StatelessWidget {
  const _PayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(18));
    return Semantics(
      button: true,
      label: JuniorProgressStrings.payAction,
      excludeSemantics: true,
      child: Material(
        color: JuniorPalette.accent,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: const SizedBox(
            height: 36,
            child: Center(
              child: Text(
                JuniorProgressStrings.payAction,
                style: _payStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The white panel holding the two summaries, the next lesson, the month and
/// its legend, ruled into three bands.
class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.progress});

  final JuniorProgress progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
        border: Border.all(color: JuniorPalette.mutedFill, width: _panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _panelInset,
              18,
              _panelInset,
              11,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: JuniorProgressStrings.attendance,
                      value: JuniorProgressStrings.attendanceValue(
                        progress.attendedLessons,
                        progress.totalLessons,
                        progress.attendancePercent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryCard(
                      title: JuniorProgressStrings.exam,
                      value: JuniorProgressStrings.percent(
                        progress.examPercent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const _PanelRule(),
          Padding(
            padding: const EdgeInsets.fromLTRB(_panelInset, 16, _panelInset, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  JuniorProgressStrings.nextLesson,
                  style: _labelStyle,
                ),
                const SizedBox(height: 3),
                Text(
                  JuniorProgressStrings.nextLessonTime(
                    progress.nextLessonStart,
                    progress.nextLessonEnd,
                  ),
                  style: _timeStyle,
                ),
                const SizedBox(height: 22),
                _MonthHeader(month: progress.month),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _calendarInset,
              0,
              _calendarInset,
              8,
            ),
            child: JuniorProgressCalendar(
              month: progress.month,
              selectedDay: progress.selectedDay,
              days: progress.days,
            ),
          ),
          const _PanelRule(),
          const Padding(
            padding: EdgeInsets.fromLTRB(_panelInset, 14, _panelInset, 9),
            child: _Legend(),
          ),
        ],
      ),
    );
  }
}

/// "Хичээлийн ирц" / "Шалгалтын дүн": a bold caption over a blue pill.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
        border: Border.all(color: JuniorPalette.mutedFill, width: _panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: _cardTitleStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Container(
            // Sized by its label: 2 + a 20 line + 2 is the frame's 24.
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: JuniorPalette.dayLesson,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: JuniorPalette.badgeOutline),
            ),
            child: Text(value, style: _badgeStyle, maxLines: 1),
          ),
        ],
      ),
    );
  }
}

/// "Наймдугаар сар, 2026" with the previous/next arrows at the trailing
/// edge, centred on the label's line.
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    Widget arrow(IconData icon, String label) => Semantics(
      button: true,
      enabled: false,
      label: label,
      child: Container(
        width: 36,
        height: 24,
        // The frame centres the carets 2 above the label's own centre.
        padding: const EdgeInsets.only(bottom: 4),
        // 19 inks the frame's 7 x 14 caret.
        child: Icon(icon, size: 19, color: AppColors.textPrimary),
      ),
    );

    return Row(
      children: [
        Expanded(
          child: Text(
            JuniorProgressStrings.monthLabel(month),
            style: _monthStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        arrow(AppIcons.caretLeft, JuniorProgressStrings.previousMonth),
        arrow(AppIcons.caretRight, JuniorProgressStrings.nextMonth),
      ],
    );
  }
}

/// "Тайлбар:", its hint, and one row per mark.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget row(JuniorDayStatus status, String label) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          JuniorDayMark(status: status, size: _legendDisc),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: _legendLabelStyle)),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(JuniorProgressStrings.legendTitle, style: _labelStyle),
        const SizedBox(height: 8),
        const Text(JuniorProgressStrings.legendHint, style: _hintStyle),
        const SizedBox(height: 7),
        row(JuniorDayStatus.lesson, JuniorProgressStrings.lessonDay),
        row(JuniorDayStatus.missed, JuniorProgressStrings.lessonMissed),
        row(JuniorDayStatus.attended, JuniorProgressStrings.lessonAttended),
      ],
    );
  }
}

class _PanelRule extends StatelessWidget {
  const _PanelRule();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimens.borderWidth,
      color: JuniorPalette.mutedFill,
    );
  }
}

// --- Type ------------------------------------------------------------------
//
// Sizes read off the frame's cap heights (Manrope's cap height is 0.72 em).

/// The two summary cards' titles. 16 bold.
const TextStyle _cardTitleStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 16,
  height: 24 / 16,
  fontWeight: FontWeight.w700,
  color: AppColors.textPrimary,
  leadingDistribution: TextLeadingDistribution.even,
);

/// The smaller titles — "Дараанийн төлөлт:", "Дараагийн хичээл:",
/// "Тайлбар:". 14 semibold.
const TextStyle _labelStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w600,
  color: AppColors.textPrimary,
  leadingDistribution: TextLeadingDistribution.even,
);

/// "3 хоног дутуу". 14 bold, blue.
const TextStyle _statusStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w700,
  color: JuniorPalette.accent,
  leadingDistribution: TextLeadingDistribution.even,
);

/// A card's supporting line. 14 regular.
const TextStyle _bodyStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w400,
  leadingDistribution: TextLeadingDistribution.even,
);

/// "Төлбөр төлөх". 14 semibold, white.
const TextStyle _payStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 16,
  fontWeight: FontWeight.w600,
  color: AppColors.onPrimary,
  leadingDistribution: TextLeadingDistribution.even,
);

/// The summary badges. 14 medium, blue.
const TextStyle _badgeStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w500,
  color: JuniorPalette.accent,
  leadingDistribution: TextLeadingDistribution.even,
);

/// "08/08 • 09:00 – 11:00". 15 regular, blue.
const TextStyle _timeStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 15,
  height: 22 / 15,
  fontWeight: FontWeight.w400,
  color: JuniorPalette.accent,
  leadingDistribution: TextLeadingDistribution.even,
);

/// "Наймдугаар сар, 2026". 14 regular, grey.
const TextStyle _monthStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 22 / 14,
  fontWeight: FontWeight.w400,
  color: AppColors.textSecondary,
  leadingDistribution: TextLeadingDistribution.even,
);

/// The legend's hint, two lines. 14 regular, grey.
const TextStyle _hintStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w400,
  color: AppColors.textSecondary,
  leadingDistribution: TextLeadingDistribution.even,
);

/// A legend row's label. 14 regular, grey.
const TextStyle _legendLabelStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w400,
  color: AppColors.textSecondary,
  leadingDistribution: TextLeadingDistribution.even,
);
