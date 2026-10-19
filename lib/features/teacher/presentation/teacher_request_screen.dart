import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/back_title_header.dart';
import '../../../shared/widgets/content_column.dart';
import '../data/http_schedule_change_repository.dart';
import '../domain/schedule_change.dart';
import 'teacher_home_strings.dart';
import 'teacher_request_controller.dart';
import 'teacher_schedule_strings.dart';
import 'widgets/teacher_confirmation_card.dart';
import 'widgets/teacher_pill_button.dart';
import 'widgets/teacher_request_parts.dart';

/// Where a row's request stands, as the `tsag-solih` reference draws it.
///
/// A screen state, not the backend's status set: [pending] is drawn only
/// after the server has confirmed a send (Issue #449). The contract's
/// `rejected` reaches the sender through incoming responses — a later phase
/// — so nothing produces [rejected] yet.
enum TeacherRequestStatus {
  /// "Хүсэлт илгээх" — outlined.
  notSent,

  /// "Хүлээгдэж байна" — blue.
  pending,

  /// "Татгалзсан" — red outline.
  rejected,
}

/// One teacher row's data — an eligible teacher and where their request
/// stands (Issue #449).
class TeacherRequestCandidate {
  const TeacherRequestCandidate({
    required this.name,
    required this.status,
    this.id,
  });

  final String name;
  final TeacherRequestStatus status;

  /// The teacher's id — what a send names as `recipient_teacher_id`. Null
  /// for a row nothing can send to: its pill stays inert.
  final int? id;
}

/// "Багш нар" for [sessionId] (Issue #449): reads who the session can be
/// handed to from `GET /teacher/sessions/{id}/eligible-teachers` and sends
/// the request with `POST /teacher/schedule-change-requests`, through
/// [TeacherRequestController], then draws [TeacherRequestScreen].
///
/// "Хүсэлт илгээгдлээ" shows only once the server has confirmed the send; a
/// failure shows its copy in a SnackBar. A backend that does not serve these
/// routes reads as the unavailable line, never an empty list or a success.
class TeacherScheduleChangeScreen extends StatefulWidget {
  const TeacherScheduleChangeScreen({
    required this.sessionId,
    super.key,
    this.repository,
  });

  final int sessionId;

  /// Defaults to the real API. Injected in tests.
  final ScheduleChangeRepository? repository;

  @override
  State<TeacherScheduleChangeScreen> createState() =>
      _TeacherScheduleChangeScreenState();
}

class _TeacherScheduleChangeScreenState
    extends State<TeacherScheduleChangeScreen> {
  late final TeacherRequestController _controller = TeacherRequestController(
    repository: widget.repository ?? HttpScheduleChangeRepository(),
    sessionId: widget.sessionId,
  )..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(TeacherRequestCandidate candidate) async {
    final id = candidate.id;
    if (id == null) return;
    final outcome = await _controller.send(id);
    if (!mounted) return;
    switch (outcome) {
      case TeacherRequestSent():
        await showRequestSentCard(context);
      case TeacherRequestFailed(:final message):
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(message)));
      case TeacherRequestIgnored():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => TeacherRequestScreen(
        loading: !_controller.hasLoaded || _controller.loading,
        errorMessage: _controller.loadError,
        onRetry: _controller.load,
        emptyMessage: TeacherScheduleStrings.requestsEmpty,
        candidates: [
          for (final teacher in _controller.teachers)
            TeacherRequestCandidate(
              id: teacher.id,
              name: teacher.name,
              status: _controller.statusOf(teacher.id),
            ),
        ],
        onSend: _controller.sendingTeacherId == null ? _send : null,
      ),
    );
  }
}

/// Shows "Хүсэлт илгээгдлээ" / "Ойлголоо" at the foot of the screen, as
/// `showAttendanceSavedCard` does, and completes when it is dismissed. Call
/// it only after the server has confirmed the request.
Future<void> showRequestSentCard(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: context.palette.barrier,
      elevation: 0,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.screenPadding),
          child: TeacherConfirmationCard(
            title: TeacherScheduleStrings.requestSentTitle,
            onDismiss: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      ),
    );

/// "Багш нар", opened from the upcoming session sheet's "Цаг солих"
/// (Issue #231), built against the `tsag-solih` reference: a back control,
/// the centred title, then one [TeacherRequestRow] per teacher.
///
/// The view only: [TeacherScheduleChangeScreen] fills it from the backend
/// (Issue #449). On its own, with no [candidates] and no [emptyMessage], it
/// draws the unavailable line — what it drew before the contract existed —
/// and sends nothing.
class TeacherRequestScreen extends StatelessWidget {
  const TeacherRequestScreen({
    super.key,
    this.candidates = const [],
    this.loading = false,
    this.errorMessage,
    this.onRetry,
    this.emptyMessage,
    this.onSend,
  });

  final List<TeacherRequestCandidate> candidates;

  /// True while the list is being read: a spinner in place of the rows.
  final bool loading;

  /// A failed read's copy, drawn with a retry in place of the rows.
  final String? errorMessage;
  final VoidCallback? onRetry;

  /// What an empty list says once read. Null keeps the unavailable line.
  final String? emptyMessage;

  /// Sends to a "not sent" row's teacher. Null leaves every pill inert —
  /// while a send is in flight, or with nothing to send through.
  final ValueChanged<TeacherRequestCandidate>? onSend;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Its own style: the page below stops painting once covered,
      // and its style would stay (Issue #400).
      value: AppSystemUi.page(context, navigationBar: context.palette.surface),
      child: Scaffold(
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
                  child: loading
                      ? const _Loading()
                      : errorMessage != null
                      ? _Message(text: errorMessage!, onRetry: onRetry)
                      : candidates.isEmpty
                      ? _Message(
                          text:
                              emptyMessage ??
                              TeacherScheduleStrings.requestsUnavailable,
                        )
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
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 32),
                          itemBuilder: (_, index) => TeacherRequestRow(
                            candidate: candidates[index],
                            onSend: onSend,
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

/// Below the header to the first row: the `tsag-solih` reference's 40 (the
/// back button's foot at 96, the first avatar's top at 136) — wider than
/// the pages' standard `pageContentTop` 24, a screen-specific exception
/// (`SCREEN_PATTERNS.md` §3). The header itself is the shared one.
const double _headerToFirstRow = 40;

class _Loading extends StatelessWidget {
  const _Loading();

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

/// A line in place of the rows — the unavailable line, the empty line, or a
/// failed read's copy with its retry, as the other Teacher screens draw it.
class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

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
              text,
              style: AppTypography.supporting.copyWith(
                color: context.palette.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              AppButton(
                label: TeacherHomeStrings.retry,
                variant: AppButtonVariant.outlined,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A teacher: the 64pt avatar, the name over "Teacher", and the request
/// pill at the trailing edge. "Хүсэлт илгээх" sends through [onSend] when
/// the row has an id; every other pill, and any without [onSend], is inert.
/// The contract's `photo_url` is always null, so the avatar stays a neutral
/// placeholder.
class TeacherRequestRow extends StatelessWidget {
  const TeacherRequestRow({required this.candidate, super.key, this.onSend});

  final TeacherRequestCandidate candidate;
  final ValueChanged<TeacherRequestCandidate>? onSend;

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
            onPressed:
                candidate.status == TeacherRequestStatus.notSent &&
                    candidate.id != null &&
                    onSend != null
                ? () => onSend!(candidate)
                : null,
            height: 40,
            fontSize: AppTypography.buttonSmall.fontSize!,
          ),
        ),
      ],
    );
  }
}
