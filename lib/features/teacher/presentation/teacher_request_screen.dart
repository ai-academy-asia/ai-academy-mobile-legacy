import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_typography.dart';
import '../../course_learning/presentation/widgets/course_learning_back_button.dart';
import '../../home/presentation/widgets/home_palette.dart';
import 'teacher_schedule_strings.dart';
import 'widgets/teacher_pill_button.dart';
import 'widgets/teacher_week_grid.dart';

/// Where a row's request stands, as the `tsag-solih` reference draws it.
///
/// **UI states only — not a backend contract.** No verified endpoint lists
/// the teachers a session can be handed to or reports a request's status
/// (BACKEND GAP, Issue #231), so nothing maps a response onto these.
enum TeacherRequestStatus {
  /// "Хүсэлт илгээх" — outlined.
  notSent,

  /// "Хүлээгдэж байна" — blue.
  pending,

  /// "Татгалзсан" — red outline.
  rejected,
}

/// One teacher row's data. Nothing in the app produces one yet — see
/// [TeacherRequestScreen].
class TeacherRequestCandidate {
  const TeacherRequestCandidate({required this.name, required this.status});

  final String name;
  final TeacherRequestStatus status;
}

/// "Багш нар", opened from the upcoming session sheet's "Цаг солих"
/// (Issue #231), built against the `tsag-solih` reference: a back control,
/// the centred title, then one [TeacherRequestRow] per teacher.
///
/// **Blocked by a BACKEND GAP.** The read endpoints the schedule uses are
/// verified; nothing that lists candidate teachers, sends a session-change
/// request, or reports its status is. So the screen sends nothing and shows
/// no fabricated row: with no [candidates] — the only case the app has —
/// it says the feature is not available yet. The rows are built and tested
/// so the screen is ready once a contract exists.
class TeacherRequestScreen extends StatelessWidget {
  const TeacherRequestScreen({super.key, this.candidates = const []});

  final List<TeacherRequestCandidate> candidates;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The back control's 12 + 40, with the title centred on it.
            SizedBox(
              height: 52,
              child: Stack(
                children: [
                  const CourseLearningBackButton(icon: AppIcons.arrowLeft),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: Text(
                        TeacherScheduleStrings.teachersTitle,
                        style: _titleStyle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: candidates.isEmpty
                  ? const _Unavailable()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimens.screenPadding,
                        40,
                        AppDimens.screenPadding,
                        24,
                      ),
                      itemCount: candidates.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 32),
                      itemBuilder: (_, index) =>
                          TeacherRequestRow(candidate: candidates[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppDimens.screenPadding),
        child: Text(
          TeacherScheduleStrings.requestsUnavailable,
          style: AppTypography.cardSupporting,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// A teacher: the 64pt avatar, the name over "Teacher", and the request
/// pill at the trailing edge. The pill is inert — sending is not wired
/// (BACKEND GAP). No photo field is known, so the avatar is a neutral
/// placeholder.
class TeacherRequestRow extends StatelessWidget {
  const TeacherRequestRow({required this.candidate, super.key});

  final TeacherRequestCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final (label, variant) = switch (candidate.status) {
      TeacherRequestStatus.notSent => (
        TeacherScheduleStrings.requestSend,
        TeacherPillVariant.outlined,
      ),
      TeacherRequestStatus.pending => (
        TeacherScheduleStrings.requestPending,
        TeacherPillVariant.filled,
      ),
      TeacherRequestStatus.rejected => (
        TeacherScheduleStrings.requestRejected,
        TeacherPillVariant.danger,
      ),
    };

    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: HomePalette.mutedFill,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            AppIcons.user,
            size: 28,
            color: HomePalette.mutedInk,
          ),
        ),
        const SizedBox(width: 17),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                candidate.name,
                style: _nameStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(TeacherScheduleStrings.teacherRole, style: _roleStyle),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Wide enough for the reference's longest label; a longer one is
        // cut short rather than pushing the row past the screen.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: TeacherPillButton(
            label: label,
            variant: variant,
            onPressed: null,
            height: 40,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

final TextStyle _titleStyle = AppTypography.programTitle.copyWith(
  fontSize: 20,
  height: 28 / 20,
  fontWeight: FontWeight.w700,
  color: TeacherPillColors.ink,
);

/// 17, not the 20 the cap height suggests: sized to the reference's name
/// widths, as [TeacherPillButton]'s labels are.
final TextStyle _nameStyle = AppTypography.programTitle.copyWith(
  fontSize: 17,
  height: 24 / 17,
  fontWeight: FontWeight.w700,
  color: TeacherScheduleColors.teacherName,
);

final TextStyle _roleStyle = AppTypography.cardSupporting.copyWith(
  fontSize: 13,
  height: 18 / 13,
  fontWeight: FontWeight.w400,
  color: TeacherScheduleColors.teacherRole,
);
