import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../home/presentation/home_strings.dart';
import '../../home/presentation/widgets/home_palette.dart';
import '../../notifications/presentation/notification_screen.dart';
import '../data/http_teacher_schedule_repository.dart';
import '../domain/teacher_schedule_repository.dart';
import '../domain/teacher_session.dart';
import 'teacher_home_strings.dart';
import 'teacher_schedule_controller.dart';
import 'teacher_schedule_strings.dart';
import 'widgets/teacher_bottom_nav.dart';
import 'widgets/teacher_pill_button.dart';
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
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        bottomNavigationBar: widget.showBottomNav
            ? const TeacherBottomNav(current: TeacherTab.schedule)
            : null,
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(day: _controller.selectedDay, onPickDate: _pickDate),
              _WeekStrip(
                days: _controller.weekDays,
                selected: _controller.selectedDay,
                onSelect: _controller.selectDay,
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
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
      color: AppColors.blue,
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
              const Positioned(
                left: TeacherWeekGridMetrics.timeColumnWidth,
                right: 0,
                top: TeacherWeekGridMetrics.topInset + 24,
                child: Text(
                  TeacherScheduleStrings.empty,
                  style: AppTypography.cardSupporting,
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
class _Header extends StatelessWidget {
  const _Header({required this.day, required this.onPickDate});

  final DateTime day;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HomePalette.accent,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.screenPadding,
              0,
              18,
              0,
            ),
            child: Row(
              children: [
                Semantics(
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
                        Text(
                          TeacherScheduleStrings.headerDate(day),
                          style: _headerStyle,
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          AppIcons.caretDown,
                          size: 16,
                          color: AppColors.onPrimary,
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
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
                      colorFilter: const ColorFilter.mode(
                        AppColors.onPrimary,
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
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: TeacherWeekGridMetrics.timeColumnWidth),
          for (final (index, day) in days.indexed)
            Expanded(
              child: _DayCell(
                weekday: TeacherScheduleStrings.weekdays[index],
                day: day,
                selected: isSameDay(day, selected),
                onTap: () => onSelect(day),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.weekday,
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final String weekday;
  final DateTime day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            Text(weekday, style: _weekdayStyle),
            const SizedBox(height: 6),
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: selected
                  ? const BoxDecoration(
                      color: HomePalette.accent,
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Text(
                '${day.day}',
                style: _dateStyle.copyWith(
                  color: selected ? AppColors.onPrimary : TeacherPillColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.blue,
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
              style: AppTypography.cardSupporting,
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
  color: AppColors.onPrimary,
);

const TextStyle _weekdayStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 12,
  height: 17 / 12,
  fontWeight: FontWeight.w500,
  color: TeacherScheduleColors.weekday,
);

const TextStyle _dateStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w500,
);
