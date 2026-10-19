import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/schedule_change.dart';
import '../../domain/teacher_attendance.dart';
import '../../domain/teacher_failure.dart';
import '../../domain/teacher_schedule_repository.dart';
import '../../domain/teacher_session.dart';
import '../../data/http_teacher_attendance_repository.dart';
import '../attendance_qr_screen.dart';
import '../manual_attendance_screen.dart';
import '../teacher_attendance_strings.dart';
import '../teacher_home_strings.dart';
import '../teacher_request_screen.dart';
import '../teacher_schedule_strings.dart';
import 'attendance_tally.dart';
import 'teacher_class_card.dart';
import 'teacher_pill_button.dart';
import 'teacher_request_parts.dart';

/// Opens a tapped session's sheet (Issue #231): the class action sheet —
/// "Цаг солих" and "Ирц бүртгэх" (Issues #372, #374) — while the session is
/// still ahead or under way, the `huvaari-deerh-orson-angi` sheet with its
/// attendance summary once it is over.
///
/// [attendanceOpen]: the session is on today's date in Ulaanbaatar
/// (`attendanceOpenOn`) — the only day the backend issues its QR — so
/// "Ирц бүртгэх" opens [AttendanceQrScreen]; any other day it is drawn
/// disabled.
Future<void> showTeacherSessionSheet(
  BuildContext context, {
  required ScheduledSession entry,
  required bool held,
  required TeacherScheduleRepository repository,
  bool attendanceOpen = false,
  TeacherAttendanceRepository? attendanceRepository,
  ScheduleChangeRepository? scheduleChangeRepository,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  // A sheet sits above the cards (`surfaceElevated`, as Phase 5's payment
  // sheets); the reference's scrim, `#666666` over a white screen, is
  // `barrier`.
  backgroundColor: context.palette.surfaceElevated,
  barrierColor: context.palette.barrier,
  constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (_) => TeacherSessionSheet(
    entry: entry,
    held: held,
    repository: repository,
    attendanceOpen: attendanceOpen,
    attendanceRepository: attendanceRepository,
    scheduleChangeRepository: scheduleChangeRepository,
  ),
);

/// The sheet: a drag handle over Teacher Home's class card, filled with the
/// session's own data — never the reference's sample figures.
///
/// A held session on its own date (Ulaanbaatar) keeps its attendance summary
/// and adds "Гар аргаар бүртгэх" (Issue #376): the backend takes a manual mark
/// at any time, so attendance can still be registered or corrected once the
/// class is over. The summary re-reads when the teacher comes back.
class TeacherSessionSheet extends StatefulWidget {
  const TeacherSessionSheet({
    required this.entry,
    required this.held,
    required this.repository,
    super.key,
    this.attendanceOpen = false,
    this.attendanceRepository,
    this.scheduleChangeRepository,
  });

  final ScheduledSession entry;

  /// The session is over: draw its attendance instead of "Цаг солих".
  final bool held;

  final TeacherScheduleRepository repository;

  /// Today is the session's date (Ulaanbaatar): "Ирц бүртгэх" is live on an
  /// upcoming session, "Гар аргаар бүртгэх" on a held one.
  final bool attendanceOpen;

  /// For the attendance screens; defaults to the HTTP repository.
  final TeacherAttendanceRepository? attendanceRepository;

  /// For "Цаг солих"'s "Багш нар" (Issue #449); defaults to the HTTP
  /// repository.
  final ScheduleChangeRepository? scheduleChangeRepository;

  @override
  State<TeacherSessionSheet> createState() => _TeacherSessionSheetState();
}

class _TeacherSessionSheetState extends State<TeacherSessionSheet> {
  /// Bumped when manual attendance closes, so the summary reads again.
  int _summaryRead = 0;

  Future<void> _openManual() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ManualAttendanceScreen(
          sessionId: widget.entry.session.id,
          repository:
              widget.attendanceRepository ?? HttpTeacherAttendanceRepository(),
        ),
      ),
    );
    if (mounted) setState(() => _summaryRead++);
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final held = widget.held;
    final attendanceOpen = widget.attendanceOpen;
    final session = entry.session;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          8,
          AppDimens.screenPadding,
          AppDimens.screenPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TeacherSheetHandle(),
            const SizedBox(height: 16),
            TeacherClassCard(
              teacherClass: entry.teacherClass,
              timeLabel: '${session.startLabel}-${session.endLabel}',
              footer: held
                  ? SessionAttendanceSummary(
                      key: ValueKey(_summaryRead),
                      sessionId: session.id,
                      repository: widget.repository,
                    )
                  : null,
            ),
            // Held, on its date: the summary stays, and the class can still
            // be marked by hand — the QR is for the class while it runs.
            if (held && attendanceOpen) ...[
              const SizedBox(height: 24),
              TeacherPillButton(
                label: TeacherAttendanceStrings.manualEntry,
                variant: TeacherPillVariant.filled,
                wrapLabel: true,
                onPressed: _openManual,
              ),
            ],
            if (!held) ...[
              const SizedBox(height: 24),
              TeacherPillPair(
                first: TeacherPillButton(
                  label: TeacherScheduleStrings.changeTime,
                  wrapLabel: true,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TeacherScheduleChangeScreen(
                        sessionId: entry.session.id,
                        repository: widget.scheduleChangeRepository,
                      ),
                    ),
                  ),
                ),
                // Live only on the session's date (Issue #374) — the backend
                // issues its QR on no other day. Any other day it is drawn
                // disabled and calls nothing.
                second: attendanceOpen
                    ? TeacherPillButton(
                        label: TeacherScheduleStrings.registerAttendance,
                        wrapLabel: true,
                        variant: TeacherPillVariant.filled,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AttendanceQrScreen(
                              sessionId: entry.session.id,
                              repository: widget.attendanceRepository,
                            ),
                          ),
                        ),
                      )
                    : const TeacherPillButton(
                        label: TeacherScheduleStrings.registerAttendance,
                        wrapLabel: true,
                        variant: TeacherPillVariant.disabled,
                        onPressed: null,
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The held sheet's footer: a rule, "14 / 24", "оюутан ирцэд бүртгэгдсэн"
/// and the bar — [AttendanceCounts.attended] of [AttendanceCounts.total]
/// from `GET /teacher/sessions/{id}/attendance`. Loading shows a spinner and
/// a failure its message with a retry; no figure is shown that the
/// response did not give.
class SessionAttendanceSummary extends StatefulWidget {
  const SessionAttendanceSummary({
    required this.sessionId,
    required this.repository,
    super.key,
  });

  final int sessionId;
  final TeacherScheduleRepository repository;

  @override
  State<SessionAttendanceSummary> createState() =>
      _SessionAttendanceSummaryState();
}

class _SessionAttendanceSummaryState extends State<SessionAttendanceSummary> {
  AttendanceCounts? _counts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _counts = null;
      _error = null;
    });
    try {
      final counts = await widget.repository.getAttendance(widget.sessionId);
      if (mounted) setState(() => _counts = counts);
    } on TeacherFailure catch (failure) {
      if (mounted) {
        setState(() => _error = TeacherHomeStrings.messageFor(failure.kind));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = TeacherHomeStrings.messageFor(
            TeacherFailureKind.unexpected,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = _counts;
    final error = _error;

    final Widget body;
    if (counts != null) {
      body = AttendanceTally(
        counts: counts,
        caption: TeacherScheduleStrings.attendedCaption,
      );
    } else if (error != null) {
      body = Column(
        children: [
          Text(
            error,
            style: AppTypography.supporting.copyWith(
              color: context.palette.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          AppButton(
            label: TeacherHomeStrings.retry,
            variant: AppButtonVariant.outlined,
            onPressed: _load,
          ),
        ],
      );
    } else {
      body = SizedBox(
        height: 92,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: context.palette.primary,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Container(
          height: AppDimens.borderWidth,
          color: context.palette.teacherSheetRule,
        ),
        const SizedBox(height: 24),
        body,
      ],
    );
  }
}
