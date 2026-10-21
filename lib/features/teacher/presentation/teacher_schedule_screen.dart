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
import '../domain/schedule_change.dart';
import '../domain/teacher_attendance.dart';
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

/// Whether the week grid focuses on [entry] for the selected [day]
/// (Issue #465, product decision "Option B"): a session the signed-in
/// teacher teaches — an own session nobody else covers
/// ([ScheduledSession.coveredBy] is null: no `covered_by` on its
/// `GET /teacher/sessions` item), or one they cover for someone else
/// ([ScheduledSession.isCovering]: `assignment_type: covering`) — and, when
/// [day] is today, one not yet over: a session under way still counts, one
/// whose end has passed does not. Past and future days take their earliest
/// such session. Times are the sessions' local wall-clock values against
/// [now], as the grid's held state ([TeacherSession.isOverAt]) reads them.
bool isScheduleFocusTarget(
  ScheduledSession entry, {
  required DateTime day,
  required DateTime now,
}) {
  if (entry.coveredBy != null) return false;
  if (isSameDay(day, now)) return !entry.session.isOverAt(now);
  return true;
}

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
    this.attendanceRepository,
    this.scheduleChangeRepository,
    this.attendanceOpen = attendanceOpenOn,
    this.clock,
    this.showBottomNav = true,
  });

  /// Defaults to the real API. Injected in tests.
  final TeacherScheduleRepository? repository;

  /// What a session sheet's "Ирц бүртгэх" uses (Issue #374). Defaults to
  /// the real API. Injected in tests.
  final TeacherAttendanceRepository? attendanceRepository;

  /// What a session sheet's "Цаг солих" sends through (Issue #449).
  /// Defaults to the real API. Injected in tests.
  final ScheduleChangeRepository? scheduleChangeRepository;

  /// Whether a session's "Ирц бүртгэх" is live at a moment: on its date in
  /// Ulaanbaatar ([attendanceOpenOn]). Injected in tests, whose local
  /// clocks name a different Ulaanbaatar date in different time zones.
  final bool Function(TeacherSession session, DateTime now) attendanceOpen;

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

  /// The week grid's vertical scroll, positioned on the selected day's
  /// first session (Issue #465).
  final _gridScroll = ScrollController();

  /// What the grid was last positioned for: the selected day and its
  /// target session's id — null when the day had none (Issue #467). The
  /// same pair is positioned once: rebuilds, a refresh, a tab switch, a
  /// sheet or the teacher's own scrolling never pull the grid back. A new
  /// pair — another day (Issue #499), or today's next lesson once the clock
  /// has moved on or a refresh brings one — is positioned again.
  (DateTime, int?)? _positionedFor;

  /// True while a positioning waits for its frame, so one build schedules
  /// at most one.
  bool _positionPending = false;

  /// Re-checks today's target when the app comes back to the foreground:
  /// the clock has moved on while it was away, and a kept-alive tab is not
  /// rebuilt by itself (Issue #467). A new calendar date moves a selected
  /// today to the new one first (Issue #471).
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? HttpTeacherScheduleRepository();
    _controller = TeacherScheduleController(
      repository: _repository,
      clock: widget.clock,
    )..load();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (!mounted) return;
        _controller.followToday();
        setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _gridScroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Once per target, once its week has loaded: positions the grid for the
  /// selected day's target session — its earliest [isScheduleFocusTarget]
  /// one: today, the next the teacher teaches; another day, the first —
  /// so it shows with an hour of the grid above it, derived from where the
  /// grid places that block, never a fixed time, and clamped to what the
  /// grid can scroll.
  ///
  /// **A new date** always takes that date's own position, whatever offset
  /// the last date left (Issue #499): the top when the date has no such
  /// session or when its block already shows from the top (a 09:00 class on
  /// a grid opening at 07:00), and the hour above the block otherwise — the
  /// same place the screen opens at for that date.
  ///
  /// **The same date** with a new target — today's next lesson once the
  /// clock has moved on, or one a refresh brings (Issue #467) — moves only
  /// when that block is not already on screen; a target that goes away
  /// moves nothing. Rebuilds, a refresh, a tab switch, a sheet or the
  /// teacher's own scrolling never pull the grid.
  ///
  /// The first time is a jump (the screen is just opening); later, it
  /// eases. A target is recorded only when its frame runs with the grid
  /// attached and the same day selected; otherwise the next build tries
  /// again (Issue #467).
  void _positionOnFirstSession(List<ScheduledSession> sessions) {
    if (_positionPending) return;
    final day = _controller.selectedDay;
    final now = _controller.now();
    final placement = firstSessionPlacement(
      sessions,
      weekStart: _controller.weekStart,
      day: day,
      where: (entry) => isScheduleFocusTarget(entry, day: day, now: now),
    );
    final key = (day, placement?.entry.session.id);
    if (_positionedFor == key) return;
    final first = _positionedFor == null;
    final newDate = first || _positionedFor!.$1 != day;
    if (placement == null && !newDate) {
      // The same date's target went away: nothing to move to.
      _positionedFor = key;
      return;
    }
    final top = placement?.top;
    _positionPending = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _positionPending = false;
      if (!mounted || !_gridScroll.hasClients) return;
      if (_controller.selectedDay != day) return;
      _positionedFor = key;
      const hourAbove = TeacherWeekGridMetrics.hourHeight;
      final position = _gridScroll.position;
      final double target;
      if (top == null) {
        // A date with nothing to show opens at the top.
        target = position.minScrollExtent;
      } else {
        final aligned = (top - hourAbove).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        // Shown from [from]: the hour above the block from the top of the
        // view, and the block's first hour above its bottom.
        bool shownFrom(double from) =>
            aligned >= from &&
            top + hourAbove <= from + position.viewportDimension;
        if (newDate) {
          target = shownFrom(position.minScrollExtent)
              ? position.minScrollExtent
              : aligned;
        } else {
          if (shownFrom(position.pixels)) return;
          target = aligned;
        }
      }
      if (target == position.pixels) return;
      if (first) {
        _gridScroll.jumpTo(target);
      } else {
        _gridScroll.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
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
      attendanceOpen: widget.attendanceOpen(entry.session, _controller.now()),
      attendanceRepository: widget.attendanceRepository,
      scheduleChangeRepository: widget.scheduleChangeRepository,
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
                      today: _controller.now(),
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
    _positionOnFirstSession(sessions);

    return RefreshIndicator(
      onRefresh: _controller.load,
      color: context.palette.primary,
      child: SingleChildScrollView(
        controller: _gridScroll,
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
                  style: AppTypography.supporting.copyWith(
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
    onTap: onPickDate,
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
          const SizedBox(width: _dateToDropdown),
          // The redesign's own chevron (Issue #370): the supplied 11 x 7
          // export, drawn at its own size in its own white — untinted, so
          // the geometry is exactly the design's.
          SvgPicture.asset(
            _dateDropdownIcon,
            width: _dateDropdownWidth,
            height: _dateDropdownHeight,
          ),
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
            // The page's gutter on both sides (Issue #368; the reference
            // set the bell 18 in).
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.screenPadding,
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
                  onTap: () => NotificationScreen.open(context),
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
      onTap: onTap,
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
/// the reference's blue circle. Today's column carries the grid's faint
/// wash whatever day is selected (Issue #499). A tap selects the day.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.days,
    required this.selected,
    required this.today,
    required this.onSelect,
  });

  final List<DateTime> days;
  final DateTime selected;

  /// Now — only its date is read.
  final DateTime today;
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
                      today: isSameDay(day, today),
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
    required this.today,
    required this.columnWidth,
    required this.onTap,
  });

  final String weekday;
  final DateTime day;
  final bool selected;

  /// Today: the column's wash behind the cell, and — when not selected —
  /// the number in the accent's ink (Issue #499).
  final bool today;

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
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ColoredBox(
          color: today ? context.palette.scheduleToday : Colors.transparent,
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
                        : today
                        ? context.palette.accentText
                        : context.palette.textStrong,
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
              style: AppTypography.supporting.copyWith(
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

/// The date header's dropdown chevron (Issue #370): the redesign's 11 x 7
/// export, its ink 25 after the date's — measured off the Teacher Schedule
/// reference at 3x.
const String _dateDropdownIcon = 'assets/icons/date_dropdown.svg';
const double _dateDropdownWidth = 11;
const double _dateDropdownHeight = 7;
const double _dateToDropdown = 24;

/// The date on the header band.
const TextStyle _headerStyle = AppTypography.headerTitle;

/// The week strip's weekday and date: a dense-grid exception to the type
/// scale (`DESIGN_SYSTEM.md` §3) — seven columns share the width.
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
