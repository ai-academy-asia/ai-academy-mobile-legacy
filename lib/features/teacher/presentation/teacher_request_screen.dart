import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/back_title_header.dart';
import '../../../shared/widgets/content_column.dart';
import 'teacher_schedule_strings.dart';
import 'widgets/teacher_pill_button.dart';
import 'widgets/teacher_request_parts.dart';

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
      backgroundColor: context.palette.surface,
      body: SafeArea(
        bottom: false,
        // Capped at the content width, as every page is (Issue #368).
        child: ContentColumn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The shared back header (Issue #368): its title kept clear of
              // the button, and wrapping at larger text.
              const BackTitleHeader(
                title: TeacherScheduleStrings.teachersTitle,
              ),
              Expanded(
                child: candidates.isEmpty
                    ? const _Unavailable()
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          AppDimens.screenPadding,
                          _headerToFirstRow,
                          AppDimens.screenPadding,
                          AppDimens.pageBottom +
                              MediaQuery.paddingOf(context).bottom,
                        ),
                        itemCount: candidates.length,
                        // A row of its own kind — avatar, name, request pill —
                        // spaced as the reference draws it.
                        separatorBuilder: (_, _) => const SizedBox(height: 32),
                        itemBuilder: (_, index) =>
                            TeacherRequestRow(candidate: candidates[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Below the header to the first row: the `tsag-solih` reference's 40 (the
/// back button's foot at 96, the first avatar's top at 136) — wider than
/// the pages' standard `pageContentTop` 24, a screen-specific exception
/// (`SCREEN_PATTERNS.md` §3). The header itself is the shared one.
const double _headerToFirstRow = 40;

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.screenPadding,
        ),
        child: Text(
          TeacherScheduleStrings.requestsUnavailable,
          style: AppTypography.supporting.copyWith(
            color: context.palette.textSecondary,
          ),
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
        Expanded(child: TeacherIdentity(name: candidate.name)),
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
            fontSize: AppTypography.buttonSmall.fontSize!,
          ),
        ),
      ],
    );
  }
}
