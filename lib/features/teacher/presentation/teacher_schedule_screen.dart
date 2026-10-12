import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/app_button.dart';
import '../../home/presentation/home_strings.dart';
import '../../notifications/presentation/notification_screen.dart';
import '../data/http_teacher_schedule_repository.dart';
import '../domain/teacher_schedule_repository.dart';
import '../domain/teacher_session.dart';
import 'teacher_home_strings.dart';
import 'teacher_schedule_controller.dart';
import 'teacher_schedule_strings.dart';
import 'widgets/teacher_bottom_nav.dart';
import 'widgets/teacher_day_session_list.dart';
import 'widgets/teacher_session_sheet.dart';
import 'widgets/teacher_tabs.dart';
import 'widgets/teacher_week_grid.dart';

/// The teacher's Хуваарь tab (Issue #231), built against the `huvaari`
/// reference: a blue header naming the selected date, a strip of the
/// week's seven days, and an hourly grid with a block per real session.
///
/// The sessions are each running class's
/// `GET /teacher/cohorts/{id}/sessions` for the week on screen — nothing is
/// generated from `meeting_days`. A tap on a block opens its sheet; a tap on
/// a day selects it; the header's date opens a date picker to reach another
/// week. The reference draws no loading, empty or error state, so they
/// follow Teacher Home's: a spinner, the empty line over the grid, the
/// failure's message with a retry. The grid pulls to refresh.
class TeacherScheduleScreen extends StatefulWidget {
  const TeacherScheduleScreen({
    super.key,
    this.repository,
    this.clock,
    this.showBottomNav = true,
  });

  /// Defaults to the real API. Injected in tests.
  final TeacherScheduleRepository? repository;

  /// Decides which day is "today" and which sessions are over. Injected in
  /// tests.
  final DateTime Function()? clock;

  /// Whether this screen draws its tab bar itself. False inside
  /// `TeacherShell`, which owns the one persistent bar (Issue #241).
  final bool showBottomNav;

  @override
  State<TeacherScheduleScreen> createState() => _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends State<TeacherScheduleScreen> {
  late final TeacherScheduleRepository _repository;
  late final TeacherScheduleController _controller;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? HttpTeacherScheduleRepository();
    _controller = TeacherScheduleController(
      repository: _repository,
      clock: widget.clock,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = _controller.selectedDay;
    final picked = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(selected.year - 2),
      lastDate: DateTime(selected.year + 2, 12, 31),
    );
    if (picked != null) _controller.selectDay(picked);
  }

  /// The mode last decided — kept while a week loads, when the sessions the
  /// content rule reads are not there yet, so the screen does not flash the
  /// grid on every week change.
  bool _dayList = false;

  /// Whether to show the selected day as a list instead of the week strip
  /// and grid (Issue #357). Never at the default text size: there the week
  /// grid always shows, whatever the sessions. Above it, the list when the
  /// strip's labels or numbers no longer fit their columns, or when any
  /// session of the loaded week cannot show its time or title legibly in
  /// the block the grid would give it — both measured, never a fixed scale,
  /// and the text size is never capped. The mode can change with the week.
  bool _usesDayList(BuildContext context, double width) {
    const probe = 14.0;
    if (MediaQuery.textScalerOf(context).scale(probe) <= probe) {
      return _dayList = false;
    }
    if (!_weekStripFits(context, width, _controller.weekDays)) {
      return _dayList = true;
    }
    final sessions = _controller.sessions;
    if (sessions == null) return _dayList;
    return _dayList = !weekBlocksLegible(
      context,
      sessions: sessions,
      weekStart: _controller.weekStart,
      width: width,
    );
  }

  /// One day back or forward — across a week boundary, the controller loads
  /// that week, as a tap on the strip or the date picker would.
  void _stepDay(int days) {
    final day = _controller.selectedDay;
    _controller.selectDay(DateTime(day.year, day.month, day.day + days));
  }

  void _openSession(ScheduledSession entry) {
    showTeacherSessionSheet(
      context,
      entry: entry,
      held: entry.session.isOverAt(_controller.now()),
      repository: _repository,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.overDarkContent(
        navigationBar: context.palette.surface,
      ),
      child: Scaffold(
        backgroundColor: context.palette.surface,
        bottomNavigationBar: widget.showBottomNav
            ? const TeacherBottomNav(current: TeacherTab.schedule)
            : null,
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              final dayList = _usesDayList(context, constraints.maxWidth);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    day: _controller.selectedDay,
                    onPickDate: _pickDate,
                    onPreviousDay: dayList ? () => _stepDay(-1) : null,
                    onNextDay: dayList ? () => _stepDay(1) : null,
                  ),
                  if (!dayList)
                    _WeekStrip(
                      days: _controller.weekDays,
                      selected: _controller.selectedDay,
                      onSelect: _controller.selectDay,
                    ),
                  Expanded(child: dayList ? _buildDayList() : _buildBody()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// The day list's body: the same loading and failure states as the grid,
  /// then the selected day's sessions (Issue #357).
  Widget _buildDayList() {
    if (_controller.errorMessage case final message?) {
      return _ErrorView(message: message, onRetry: _controller.load);
    }
    final sessions = _controller.sessions;
    if (sessions == null) return const _LoadingView();
    return TeacherDaySessionList(
      day: _controller.selectedDay,
      sessions: sessions,
      now: _controller.now(),
      onSessionTap: _openSession,
      onRefresh: _controller.load,
    );
  }

  Widget _buildBody() {
    final sessions = _controller.sessions;

    if (_controller.errorMessage case final message?) {
      return _ErrorView(message: message, onRetry: _controller.load);
    }
    if (sessions == null) return const _LoadingView();

    return RefreshIndicator(
      onRefresh: _controller.load,
      color: context.palette.primary,
      child: SingleChildScrollView(
        // Always scrollable, so pull-to-refresh works on any screen height.
        physics: const AlwaysScrollableScrollPhysics(),
        child: Stack(
          children: [
            TeacherWeekGrid(
              weekStart: _controller.weekStart,
              sessions: sessions,
              now: _controller.now(),
              onSessionTap: _openSession,
            ),
            if (_controller.isEmpty)
              Positioned(
                left: timeColumnWidthOf(context),
                right: 0,
                top: TeacherWeekGridMetrics.topInset + 24,
                child: Text(
                  TeacherScheduleStrings.empty,
                  style: AppTypography.cardSupporting.copyWith(
                    color: context.palette.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The blue band, behind the status bar too: the selected date with its
/// caret — which opens the date picker — and the inert bell.
///
/// Its own role, `AppPalette.scheduleBand` — Teacher's identity, not a page
/// surface — with `onPrimary` ink, under the light status-bar glyphs the
/// screen keeps (`AppSystemUi.overDarkContent`).
class _Header extends StatelessWidget {
  const _Header({
    required this.day,
    required this.onPickDate,
    this.onPreviousDay,
    this.onNextDay,
  });

  final DateTime day;
  final VoidCallback onPickDate;

  /// The day list's previous- and next-day controls, drawn around the date
  /// (Issue #357). Null — the week grid — draws the header as before.
  final VoidCallback? onPreviousDay;
  final VoidCallback? onNextDay;

  /// The date and its caret — the date picker's button, the only tap
  /// target of the date itself. It wraps rather than push anything off the
  /// band.
  Widget _dateControl(AppPalette palette) => Semantics(
    button: true,
    label:
        '${TeacherScheduleStrings.pickDate}, '
        '${TeacherScheduleStrings.headerDate(day)}',
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onPickDate,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              TeacherScheduleStrings.headerDate(day),
              style: _headerStyle.copyWith(color: palette.onPrimary),
            ),
          ),
          const SizedBox(width: 10),
          Icon(AppIcons.caretDown, size: 16, color: palette.onPrimary),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ColoredBox(
      color: palette.scheduleBand,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        // At least the reference's 46, and taller when a larger system text
        // size wraps the date (Issue #353). At the default size it is the
        // one 46-tall row it always was.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 46),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.screenPadding,
              0,
              18,
              0,
            ),
            child: Row(
              children: [
                // The date takes what the bell leaves, and wraps in it
                // rather than pushing the bell off the band; only the date
                // and its caret are the tap target, as before.
                Expanded(
                  child: switch ((onPreviousDay, onNextDay)) {
                    (final previous?, final next?) => Row(
                      children: [
                        _DayStep(
                          icon: AppIcons.caretLeft,
                          label: TeacherScheduleStrings.previousDay,
                          onTap: previous,
                        ),
                        Flexible(child: _dateControl(palette)),
                        _DayStep(
                          icon: AppIcons.caretRight,
                          label: TeacherScheduleStrings.nextDay,
                          onTap: next,
                        ),
                      ],
                    ),
                    _ => Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _dateControl(palette),
                    ),
                  },
                ),
                const SizedBox(width: 12),
                // Opens the shared Notification Center (Issue #246). Drawn as
                // the reference draws it, white on the blue header, with no
                // unread dot: no frame shows one here (Teacher Home's bell
                // carries it).
                Semantics(
                  button: true,
                  label: TeacherScheduleStrings.notifications,
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => NotificationScreen.open(context),
                    behavior: HitTestBehavior.opaque,
                    child: SvgPicture.asset(
                      HomeIcons.notification,
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        palette.onPrimary,
                        BlendMode.srcIn,
                      ),
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

/// One step of the day list's header: a 44pt control with its caret, read
/// out as [label] (Issue #357).
class _DayStep extends StatelessWidget {
  const _DayStep({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: 44,
          child: Icon(icon, size: 20, color: context.palette.onPrimary),
        ),
      ),
    );
  }
}

/// Whether every weekday label and day number of [days] fits its strip
/// column at this context's text size, a screen [width] wide — the strip's
/// own column maths, measured as its `Text`s draw (Issue #357).
bool _weekStripFits(BuildContext context, double width, List<DateTime> days) {
  final column = (width - timeColumnWidthOf(context)) / DateTime.daysPerWeek;
  final ambient = DefaultTextStyle.of(context).style;
  double widthOf(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: ambient.merge(style)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  return [
    for (final weekday in TeacherScheduleStrings.weekdays)
      widthOf(weekday, _weekdayStyle),
    for (final day in days) widthOf('${day.day}', _dateStyle),
  ].every((needed) => needed <= column);
}

/// The week's seven days under their weekday letters, the selected one in
/// the reference's blue circle. A tap selects the day.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.days,
    required this.selected,
    required this.onSelect,
  });

  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    // At least the reference's 68, and as tall as its tallest cell when a
    // larger system text size needs more (Issue #353). Every cell is
    // stretched to the strip's height, so each stays tappable over the
    // whole strip — at the default size, exactly as before.
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      decoration: BoxDecoration(
        color: context.palette.surface,
        boxShadow: [
          BoxShadow(
            color: context.palette.shadow,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Aligned with the grid's day columns, whose hour-label column
          // can widen with the text size (Issue #355).
          final timeColumn = timeColumnWidthOf(context);
          final columnWidth =
              (constraints.maxWidth - timeColumn) / DateTime.daysPerWeek;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: timeColumn),
                for (final (index, day) in days.indexed)
                  Expanded(
                    child: _DayCell(
                      weekday: TeacherScheduleStrings.weekdays[index],
                      day: day,
                      selected: isSameDay(day, selected),
                      columnWidth: columnWidth,
                      onTap: () => onSelect(day),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.weekday,
    required this.day,
    required this.selected,
    required this.columnWidth,
    required this.onTap,
  });

  final String weekday;
  final DateTime day;
  final bool selected;

  /// The cell's width — the most the marker can take.
  final double columnWidth;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final number = '${day.day}';
    // The day number as it will be drawn, at the user's text size.
    final painter = TextPainter(
      text: TextSpan(text: number, style: _dateStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final numberSize = painter.size;
    painter.dispose();
    final marker = _markerSize(numberSize, columnWidth);

    return Semantics(
      button: true,
      selected: selected,
      label: '$weekday ${day.day}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            const SizedBox(height: 4),
            Text(
              weekday,
              style: _weekdayStyle.copyWith(
                color: context.palette.textInactive,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: marker.width,
              height: marker.height,
              alignment: Alignment.center,
              decoration: selected
                  ? BoxDecoration(
                      color: context.palette.accent,
                      // A circle while it fits the column, as before; taller
                      // than wide, an upright rounded rectangle.
                      shape: marker.width == marker.height
                          ? BoxShape.circle
                          : BoxShape.rectangle,
                      borderRadius: marker.width == marker.height
                          ? null
                          : BorderRadius.circular(marker.width / 2),
                    )
                  : null,
              child: Text(
                number,
                style: _dateStyle.copyWith(
                  color: selected
                      ? context.palette.onPrimary
                      : context.palette.textStrong,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The day marker: the reference's 30 circle, grown to hold its number at a
/// larger text size (Issue #353). While that circle fits the column it stays
/// a circle; once the number's line is taller than the column is wide — 2.0×
/// on a 320-wide phone — it is the column's width and the number's height, a
/// rounded rectangle standing upright, rather than a clipped number.
Size _markerSize(Size number, double columnWidth) {
  const reference = 30.0;
  final diameter = [
    reference,
    number.width,
    number.height,
  ].reduce((a, b) => a > b ? a : b);
  if (diameter <= columnWidth) return Size.square(diameter);
  return Size(
    columnWidth,
    number.height < reference ? reference : number.height,
  );
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: context.palette.primary,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.screenPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: AppTypography.cardSupporting.copyWith(
                color: context.palette.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: TeacherHomeStrings.retry,
              variant: AppButtonVariant.outlined,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

final TextStyle _headerStyle = AppTypography.programTitle.copyWith(
  fontSize: 20,
  height: 28 / 20,
  fontWeight: FontWeight.w700,
);

const TextStyle _weekdayStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 12,
  height: 17 / 12,
  fontWeight: FontWeight.w500,
);

const TextStyle _dateStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w500,
);
