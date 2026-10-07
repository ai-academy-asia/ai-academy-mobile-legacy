import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../home/presentation/widgets/home_palette.dart';
import '../../domain/teacher_failure.dart';
import '../../domain/teacher_schedule_repository.dart';
import '../../domain/teacher_session.dart';
import '../teacher_home_strings.dart';
import '../teacher_request_screen.dart';
import '../teacher_schedule_strings.dart';
import 'teacher_class_card.dart';
import 'teacher_pill_button.dart';
import 'teacher_week_grid.dart';

/// Opens a tapped session's sheet (Issue #231): the
/// `huvaari-deerh-oroh-angi` sheet with "Цаг солих" while the session is
/// still ahead or under way, the `huvaari-deerh-orson-angi` sheet with its
/// attendance summary once it is over.
Future<void> showTeacherSessionSheet(
  BuildContext context, {
  required ScheduledSession entry,
  required bool held,
  required TeacherScheduleRepository repository,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: AppColors.surface,
  // The reference's scrim: `#666666` over a white screen.
  barrierColor: const Color(0x99000000),
  constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (_) =>
      TeacherSessionSheet(entry: entry, held: held, repository: repository),
);

/// The sheet: a drag handle over Teacher Home's class card, filled with the
/// session's own data — never the reference's sample figures.
class TeacherSessionSheet extends StatelessWidget {
  const TeacherSessionSheet({
    required this.entry,
    required this.held,
    required this.repository,
    super.key,
  });

  final ScheduledSession entry;

  /// The session is over: draw its attendance instead of "Цаг солих".
  final bool held;

  final TeacherScheduleRepository repository;

  @override
  Widget build(BuildContext context) {
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
            Center(
              child: Container(
                width: 72,
                height: 6,
                decoration: BoxDecoration(
                  color: TeacherScheduleColors.handle,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TeacherClassCard(
              teacherClass: entry.teacherClass,
              timeLabel: '${session.startLabel}-${session.endLabel}',
              footer: held
                  ? SessionAttendanceSummary(
                      sessionId: session.id,
                      repository: repository,
                    )
                  : null,
            ),
            if (!held) ...[
              const SizedBox(height: 24),
              TeacherPillButton(
                label: TeacherScheduleStrings.changeTime,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TeacherRequestScreen(),
                  ),
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
      body = _Summary(counts: counts);
    } else if (error != null) {
      body = Column(
        children: [
          Text(
            error,
            style: AppTypography.cardSupporting,
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
      body = const SizedBox(
        height: 92,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.blue,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Container(height: AppDimens.borderWidth, color: HomePalette.border),
        const SizedBox(height: 24),
        body,
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.counts});

  final AttendanceCounts counts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: '${counts.attended} / ${counts.total}',
          excludeSemantics: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${counts.attended}', style: _countStyle),
              Text(' / ${counts.total}', style: _totalStyle),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          TeacherScheduleStrings.attendedCaption,
          style: _captionStyle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        // A plain bar: Material 3's indicator adds a stop dot and a gap the
        // reference does not draw.
        ClipRRect(
          key: const ValueKey('attendance-bar'),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 8,
            color: TeacherScheduleColors.barTrack,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: counts.fraction.clamp(0, 1),
              heightFactor: 1,
              child: const ColoredBox(
                key: ValueKey('attendance-fill'),
                color: HomePalette.accent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final TextStyle _countStyle = AppTypography.programTitle.copyWith(
  fontSize: 36,
  height: 44 / 36,
  fontWeight: FontWeight.w800,
  color: HomePalette.accent,
);

final TextStyle _totalStyle = AppTypography.programTitle.copyWith(
  fontSize: 16,
  height: 1.2,
  fontWeight: FontWeight.w700,
  color: TeacherScheduleColors.totalInk,
);

final TextStyle _captionStyle = AppTypography.cardSupporting.copyWith(
  fontSize: 16,
  height: 24 / 16,
  fontWeight: FontWeight.w400,
  color: TeacherScheduleColors.captionInk,
);
