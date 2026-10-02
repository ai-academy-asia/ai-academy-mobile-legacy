import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../course_learning/presentation/widgets/course_learning_back_button.dart';
import '../../junior_home/domain/junior_progress.dart';
import '../../junior_home/presentation/junior_progress_strings.dart';
import '../../junior_home/presentation/widgets/attendance_panel_parts.dart';
import '../../junior_home/presentation/widgets/junior_home_palette.dart';
import '../../junior_home/presentation/widgets/junior_progress_calendar.dart';
import '../domain/home_dashboard.dart';
import '../domain/lesson_schedule.dart';
import 'home_strings.dart';
import 'widgets/home_palette.dart';

// Measured off the Figma "HomePage - Adult / attendance" frame at 1:1 (393
// wide, a 44pt status-bar inset).

/// The back control's bottom (56 + 40) to the header card.
const double _backToHeader = 28;

/// The header card: 56 tall, and 8 above the panel.
const double _headerHeight = 56;
const double _headerToPanel = 8;

/// The cards' outline — the Junior panel's 2pt hairline-twice.
const double _cardBorder = 2;

/// Content inside a card sits 14 in from its inner edge; the calendar,
/// which needs the width, only 6.
const double _cardInset = 14;
const double _calendarInset = 6;

/// The panel's border to the next-lesson label — 3 less than the Junior
/// panel's band under its rule, as the frame draws it.
const double _panelTop = 13;

/// The last legend row to the panel's border — 7 more than the Junior
/// panel's, as the frame draws it.
const double _panelBottom = 16;

/// Below the panel, above the home indicator.
const double _pageBottom = 12;

/// The Adult attendance screen — "Хичээлийн ирц" → "Дэлгэрэнгүй" on Adult
/// Home (Issue #172).
///
/// **Data.** Nothing is fetched here: Home already loaded every figure —
/// [attendance] is `GET /me/attendance`'s server summary and its sessions'
/// dates, [schedule] the cohort's `GET /cohorts` schedule, [nextLesson]
/// derived from it — so this screen draws exactly what the card it was opened
/// from summarised. The calendar marks a month with [JuniorCalendarSource]'s
/// one rule: scheduled lesson days, then `absent` sessions missed, then
/// `present`/`late` sessions attended. A session not held yet (`status`
/// null) marks nothing.
///
/// **Reuse.** The frame is the Junior "Сурлагын явц" panel under its own
/// header card, so the panel's parts are the Junior screen's own
/// ([AttendanceNextLesson], [AttendanceMonthHeader], [JuniorProgressCalendar],
/// [AttendanceLegend], [AttendancePill]). Two things are the Adult frame's:
/// the missed stamp's red ring in the calendar, and the legend's wording for
/// it ([HomeStrings.attendanceMissed]). The back control is
/// [CourseLearningBackButton] with the frame's arrow.
///
/// The calendar opens on today's month with today selected, and its arrows
/// page to any other month locally — the same behaviour as the Junior one.
class AttendanceDetailScreen extends StatefulWidget {
  const AttendanceDetailScreen({
    required this.attendance,
    super.key,
    this.schedule,
    this.nextLesson,
    this.clock,
  });

  final AttendanceSummary attendance;

  /// Null when the cohort has no parseable schedule: no lesson days marked.
  final LessonSchedule? schedule;

  /// Null when the schedule names none: the next-lesson lines are left out.
  final NextLesson? nextLesson;

  /// Today — which month opens and which day is selected. Injected in tests.
  final DateTime Function()? clock;

  @override
  State<AttendanceDetailScreen> createState() => _AttendanceDetailScreenState();
}

class _AttendanceDetailScreenState extends State<AttendanceDetailScreen> {
  late final DateTime _today = (widget.clock ?? DateTime.now)();
  late DateTime _month = DateTime(_today.year, _today.month);

  late final JuniorCalendarSource _calendar = JuniorCalendarSource(
    schedule: widget.schedule,
    attendedDates: widget.attendance.attendedDates,
    missedDates: widget.attendance.missedDates,
  );

  void _page(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final attendance = widget.attendance;
    final showingToday =
        _month.year == _today.year && _month.month == _today.month;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimens.maxContentWidth,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + _pageBottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CourseLearningBackButton(icon: AppIcons.arrowLeft),
                    const SizedBox(height: _backToHeader),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.screenPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _HeaderCard(
                            value: JuniorProgressStrings.attendanceValue(
                              attendance.attended,
                              attendance.total,
                              attendance.percent,
                            ),
                          ),
                          const SizedBox(height: _headerToPanel),
                          _Panel(
                            nextLesson: widget.nextLesson,
                            month: _month,
                            days: _calendar.marksIn(_month),
                            selectedDay: showingToday ? _today.day : null,
                            onPreviousMonth: () => _page(-1),
                            onNextMonth: () => _page(1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration get _cardDecoration => BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
  border: Border.all(color: JuniorPalette.mutedFill, width: _cardBorder),
);

/// "Хичээлийн ирц" with the server's `attended/total · percent%` pill at the
/// trailing edge.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: _cardInset),
      decoration: _cardDecoration,
      child: Row(
        children: [
          const Expanded(
            child: Text(
              HomeStrings.attendanceLabel,
              style: attendanceCardTitleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          AttendancePill(value),
        ],
      ),
    );
  }
}

/// The next lesson, the month and its legend, ruled into two bands.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.nextLesson,
    required this.month,
    required this.days,
    required this.selectedDay,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final NextLesson? nextLesson;
  final DateTime month;
  final Map<int, JuniorDayStatus> days;
  final int? selectedDay;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _cardInset,
              _panelTop,
              _cardInset,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (nextLesson case final lesson?) ...[
                  AttendanceNextLesson(lesson),
                  const SizedBox(height: 22),
                ],
                AttendanceMonthHeader(
                  month: month,
                  onPrevious: onPreviousMonth,
                  onNext: onNextMonth,
                ),
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
              month: month,
              selectedDay: selectedDay,
              days: days,
              missedRing: HomePalette.overdueOutline,
            ),
          ),
          Container(
            height: AppDimens.borderWidth,
            color: JuniorPalette.mutedFill,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              _cardInset,
              14,
              _cardInset,
              _panelBottom,
            ),
            child: AttendanceLegend(missedLabel: HomeStrings.attendanceMissed),
          ),
        ],
      ),
    );
  }
}
