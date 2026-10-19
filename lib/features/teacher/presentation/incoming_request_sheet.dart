import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../data/http_schedule_change_repository.dart';
import '../domain/schedule_change.dart';
import 'incoming_request_controller.dart';
import 'teacher_schedule_strings.dart';
import 'widgets/teacher_request_parts.dart';

/// Opens the incoming schedule-change request [requestId] in
/// [TeacherIncomingRequestSheet] (Issue #453) — what tapping a
/// `schedule_change_request` notification does.
///
/// The sheet reads the request's current state first: a notification can be
/// stale, so "Татгалзах" / "Зөвшөөрөх" show only while the server says the
/// request is `pending`. A request that cannot be read shows why, with no
/// actions.
Future<void> showIncomingScheduleChangeRequest(
  BuildContext context, {
  required int requestId,
  ScheduleChangeRepository? repository,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  // As every Teacher sheet: `surfaceElevated` over the `barrier` scrim.
  backgroundColor: context.palette.surfaceElevated,
  barrierColor: context.palette.barrier,
  constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (_) => IncomingRequestHost(
    requestId: requestId,
    repository: repository ?? HttpScheduleChangeRepository(),
  ),
);

/// The sheet's contents for one request, driven by
/// [IncomingRequestController]: a spinner while it is read, the request in
/// [TeacherIncomingRequestSheet.brief] once it is, or why it could not be.
class IncomingRequestHost extends StatefulWidget {
  const IncomingRequestHost({
    required this.requestId,
    required this.repository,
    super.key,
  });

  final int requestId;
  final ScheduleChangeRepository repository;

  @override
  State<IncomingRequestHost> createState() => _IncomingRequestHostState();
}

class _IncomingRequestHostState extends State<IncomingRequestHost> {
  late final IncomingRequestController _controller = IncomingRequestController(
    repository: widget.repository,
    requestId: widget.requestId,
  )..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final request = _controller.request;
        if (request != null) {
          return TeacherIncomingRequestSheet.brief(
            senderName: request.senderName,
            courseTitle:
                request.courseTitle ??
                request.cohortName ??
                TeacherScheduleStrings.incomingUntitled,
            // The cohort name as the caption only when the title is the
            // course's own — never the same name twice.
            cohortName: request.courseTitle == null ? null : request.cohortName,
            room: request.room,
            sessionLabel: incomingSessionLabel(request),
            message: _controller.message,
            showActions: _controller.showActions,
            onDecline: _controller.canReject ? _controller.reject : null,
            onAccept: _controller.canAccept ? _controller.accept : null,
          );
        }
        return _Placeholder(
          message: _controller.hasLoaded && !_controller.loading
              ? _controller.loadError
              : null,
        );
      },
    );
  }
}

/// The session's date and times, as the sheet draws them: "10-р сарын 20 •
/// 09:00-11:00" — the date alone when a time is missing.
String incomingSessionLabel(ScheduleChangeRequest request) {
  final date = TeacherScheduleStrings.headerDate(request.sessionDate);
  final start = request.startTime;
  final end = request.endTime;
  if (start == null || end == null) return date;
  return '$date • $start-$end';
}

/// The sheet before the request is known: the handle over a spinner, or —
/// when it could not be read — over why, with no actions.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.message});

  /// Why the request could not be read; null while it is being read.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
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
            const SizedBox(height: 32),
            if (message == null)
              Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: context.palette.primary,
                  ),
                ),
              )
            else
              Text(
                message,
                style: AppTypography.supporting.copyWith(
                  color: context.palette.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
