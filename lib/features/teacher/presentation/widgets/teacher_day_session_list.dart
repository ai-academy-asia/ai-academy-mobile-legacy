import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/track_badge.dart';
import '../../domain/teacher_session.dart';
import '../teacher_schedule_strings.dart';
import 'teacher_class_card.dart';

/// The Teacher Schedule's selected day as a list — what the screen shows in
/// place of the week strip and grid once an enlarged text size leaves the
/// grid illegible (Issue #357).
///
/// One [TeacherDaySessionCard] per session of [sessions] on [day], earliest
/// first, or the day's own empty line. Pulls to refresh, as the grid does.
/// Spaced as Teacher Home spaces its class cards.
class TeacherDaySessionList extends StatelessWidget {
  const TeacherDaySessionList({
    required this.day,
    required this.sessions,
    required this.now,
    required this.onSessionTap,
    required this.onRefresh,
    super.key,
  });

  final DateTime day;

  /// The loaded week's sessions; only [day]'s are listed.
  final List<ScheduledSession> sessions;

  /// What decides a session is over.
  final DateTime now;

  final ValueChanged<ScheduledSession> onSessionTap;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final ofDay = [
      for (final entry in sessions)
        if (isSameDay(entry.session.date, day)) entry,
    ]..sort((a, b) => a.session.startsAt.compareTo(b.session.startsAt));

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: context.palette.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          AppDimens.screenPadding,
          AppDimens.screenPadding,
          24,
        ),
        // Always scrollable, so pull-to-refresh works on an empty day too.
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (ofDay.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Text(
                TeacherScheduleStrings.emptyDay,
                style: AppTypography.supporting.copyWith(
                  color: context.palette.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            for (final (index, entry) in ofDay.indexed)
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : _cardGap),
                child: TeacherDaySessionCard(
                  entry: entry,
                  held: entry.session.isOverAt(now),
                  onTap: () => onSessionTap(entry),
                ),
              ),
        ],
      ),
    );
  }
}

/// One session of the day list: Teacher Home's class card with the
/// session's own times, the whole of it one accessible button that opens
/// the session's sheet. A finished session says so in words — "Дууссан"
/// over the card — and its card is muted, so neither rests on colour alone.
class TeacherDaySessionCard extends StatelessWidget {
  const TeacherDaySessionCard({
    required this.entry,
    required this.held,
    required this.onTap,
    super.key,
  });

  final ScheduledSession entry;

  /// Whether the session is over.
  final bool held;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final session = entry.session;
    final palette = context.palette;
    final card = scheduledSessionCard(
      entry,
      timeLabel: '${session.startLabel}-${session.endLabel}',
    );
    // A covered or covering session's label (Issue #455), beside
    // "Дууссан" when it is over.
    final label = TeacherScheduleStrings.assignmentLabel(entry);

    // One node for assistive tech: the card's title, class, room and time,
    // and "Дууссан" when it is over — a button that opens the sheet.
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (label != null) ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (held) _FinishedCapsule(palette: palette),
                      AssignmentCapsule(label: label),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                held ? Opacity(opacity: _heldOpacity, child: card) : card,
              ] else if (held) ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _FinishedCapsule(palette: palette),
                ),
                const SizedBox(height: 8),
                Opacity(opacity: _heldOpacity, child: card),
              ] else
                card,
            ],
          ),
        ),
      ),
    );
  }
}

/// "Дууссан", over a finished session's card.
class _FinishedCapsule extends StatelessWidget {
  const _FinishedCapsule({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) => CardCapsule(
    label: TeacherScheduleStrings.finished,
    // The grid's own finished-block roles.
    outline: palette.outline,
    fill: palette.scheduleHeld,
    ink: palette.scheduleHeldInk,
    horizontalPadding: 11,
  );
}

/// Between two cards — Teacher Home's gap.
const double _cardGap = 16;

/// A finished session's card, muted. The "Дууссан" label above it stays at
/// full strength.
const double _heldOpacity = 0.6;
