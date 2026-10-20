import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/back_title_header.dart';
import '../../../shared/widgets/content_column.dart';
import '../../junior_home/domain/junior_progress.dart';
import '../../junior_home/presentation/junior_progress_strings.dart';
import '../../junior_home/presentation/widgets/attendance_panel_parts.dart';
import '../../junior_home/presentation/widgets/junior_progress_calendar.dart';
import '../domain/home_dashboard.dart';
import '../domain/lesson_schedule.dart';
import 'home_strings.dart';

// Measured off the Figma "HomePage - Adult / attendance" frame at 1:1 (393
// wide, a 44pt status-bar inset).

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
/// [AppBackButton] with the frame's arrow.
///
/// The calendar opens on today's month with today selected — or, outside
/// the course, on its nearest month — and its arrows page locally — back no
/// further than the cohort's start month, forward no further than its end
/// month — the same behaviour as the Junior one.
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
  // Today's month, or the nearest course month outside the course
  // (Issue #457).
  late DateTime _month = _calendar.openingMonth(_today);

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
      value: AppSystemUi.page(context, navigationBar: context.palette.surface),
      child: Scaffold(
        backgroundColor: context.palette.surface,
        body: SafeArea(
          bottom: false,
          child: ContentColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // A pushed page's shared header carries the title the frame
                // drew on a card (Issue #368); the card's summary pill stays,
                // first under it.
                const BackTitleHeader(title: HomeStrings.attendanceLabel),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      AppDimens.screenPadding,
                      AppDimens.pageContentTop,
                      AppDimens.screenPadding,
                      AppDimens.pageBottom +
                          MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: AttendancePill(
                            JuniorProgressStrings.attendanceValue(
                              attendance.attended,
                              attendance.total,
                              attendance.percent,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimens.cardGap),
                        _Panel(
                          nextLesson: widget.nextLesson,
                          month: _month,
                          days: _calendar.marksIn(_month),
                          selectedDay: showingToday ? _today.day : null,
                          // Not before the cohort's start month
                          // (Issue #200).
                          onPreviousMonth: _calendar.hasMonthBefore(_month)
                              ? () => _page(-1)
                              : null,
                          // Not after its end month (Issue #457).
                          onNextMonth: _calendar.hasMonthAfter(_month)
                              ? () => _page(1)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
  color: context.palette.surface,
  borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
  border: Border.all(color: context.palette.divider, width: _cardBorder),
);

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

  /// Null at the student's cohort start month: "<" is drawn disabled.
  final VoidCallback? onPreviousMonth;

  /// Null at the student's cohort end month: ">" is drawn disabled.
  final VoidCallback? onNextMonth;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(context),
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
              missedRing: context.palette.errorOutline,
            ),
          ),
          Container(
            height: AppDimens.borderWidth,
            color: context.palette.divider,
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
