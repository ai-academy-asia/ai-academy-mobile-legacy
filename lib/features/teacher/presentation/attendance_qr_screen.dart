import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/content_column.dart';
import '../data/http_teacher_attendance_repository.dart';
import '../domain/teacher_attendance.dart';
import 'attendance_qr_controller.dart';
import 'manual_attendance_screen.dart';
import 'teacher_attendance_strings.dart';
import 'teacher_home_strings.dart';
import 'widgets/attendance_tally.dart';
import 'widgets/teacher_pill_button.dart';

/// "Ирц бүртгэх" (Issue #374), opened from a session sheet on the session's
/// date: the code students scan, the live "14 / 24", and "Гар аргаар
/// бүртгэх" for marking by hand. Built against the QR attendance reference.
///
/// The teacher's phone only shows a code — nothing is scanned here, and no
/// camera is used. The token comes from `POST /teacher/sessions/{id}/qr`
/// and is re-issued every 4 minutes, before its 5 run out; the counts are
/// re-read every 15 seconds while the screen is open
/// ([AttendanceQrController]).
///
/// The code is the issued token itself, raw (Issue #380) — what the
/// student's check-in sends back as `{"token"}`. No success is shown for a
/// request alone: the code appears only once a token has arrived, and
/// loading, failure (with a retry), `session_not_today` and expiry each
/// have their own state.
class AttendanceQrScreen extends StatefulWidget {
  const AttendanceQrScreen({
    required this.sessionId,
    super.key,
    this.repository,
    this.refreshEvery = const Duration(minutes: 4),
    this.pollEvery = const Duration(seconds: 15),
  });

  final int sessionId;

  /// Defaults to the HTTP repository.
  final TeacherAttendanceRepository? repository;

  final Duration refreshEvery;
  final Duration pollEvery;

  @override
  State<AttendanceQrScreen> createState() => _AttendanceQrScreenState();
}

class _AttendanceQrScreenState extends State<AttendanceQrScreen> {
  late final TeacherAttendanceRepository _repository =
      widget.repository ?? HttpTeacherAttendanceRepository();
  late final AttendanceQrController _controller = AttendanceQrController(
    repository: _repository,
    sessionId: widget.sessionId,
    refreshEvery: widget.refreshEvery,
    pollEvery: widget.pollEvery,
  )..start();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openManual() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ManualAttendanceScreen(
          sessionId: widget.sessionId,
          repository: _repository,
        ),
      ),
    );
    // Marks made by hand show in the count at once, not at the next poll.
    if (mounted) _controller.refreshCounts();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.surface,
      body: SafeArea(
        bottom: false,
        child: ContentColumn(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppBackButton(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.screenPadding,
                      _headerToTitle,
                      AppDimens.screenPadding,
                      AppDimens.pageBottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            TeacherAttendanceStrings.qrTitle,
                            style: AppTypography.screenTitle.copyWith(
                              color: palette.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: _titleToCode),
                        Center(child: _CodeArea(controller: _controller)),
                        if (_controller.phase == AttendanceQrPhase.showing) ...[
                          const SizedBox(height: _codeToHint),
                          Text(
                            TeacherAttendanceStrings.qrHint,
                            style: AppTypography.body.copyWith(
                              color: palette.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: _hintToTally),
                        _Tally(controller: _controller),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppDimens.screenPadding,
                    0,
                    AppDimens.screenPadding,
                    AppDimens.screenPadding +
                        MediaQuery.paddingOf(context).bottom,
                  ),
                  child: TeacherPillButton(
                    label: TeacherAttendanceStrings.manualEntry,
                    variant: TeacherPillVariant.filled,
                    wrapLabel: true,
                    onPressed: _openManual,
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

/// The reference's spacing: the title 28 under the back button's row, the
/// code 28 under the title, the hint 28 under the code, the tally 24 under
/// the hint.
const double _headerToTitle = 28;
const double _titleToCode = 28;
const double _codeToHint = 28;
const double _hintToTally = 24;

/// The code: 235 square, as the reference draws it.
const double _codeSize = 235;

/// The code, or what stands in its place.
class _CodeArea extends StatelessWidget {
  const _CodeArea({required this.controller});

  final AttendanceQrController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final data = controller.qrData;
    if (data != null) {
      return AttendanceQrCode(
        // A new token is a new picture, never a repaint of the last — keyed
        // by its count, never by the token, which a key would print.
        key: ValueKey(controller.tokenGeneration),
        data: data,
      );
    }

    if (controller.phase == AttendanceQrPhase.loading) {
      return SizedBox.square(
        dimension: _codeSize,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: palette.primary,
            ),
          ),
        ),
      );
    }

    final (message, canRetry) = switch (controller.phase) {
      AttendanceQrPhase.notToday => (
        TeacherAttendanceStrings.qrNotToday,
        false,
      ),
      AttendanceQrPhase.expired => (TeacherAttendanceStrings.qrExpired, true),
      AttendanceQrPhase.failed ||
      AttendanceQrPhase.loading ||
      AttendanceQrPhase.showing => (
        controller.qrError ?? TeacherAttendanceStrings.qrExpired,
        true,
      ),
    };
    // A placeholder the code's size at least, growing with large text.
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _codeSize,
        maxWidth: _codeSize,
        minHeight: _codeSize,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surfaceSubtle,
          borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
          border: Border.all(color: palette.outlineFaint),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.cardPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.qrCode, size: 40, color: palette.textMuted),
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  style: AppTypography.supporting.copyWith(
                    color: palette.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (canRetry) ...[
                const SizedBox(height: 12),
                TeacherPillButton(
                  label: TeacherHomeStrings.retry,
                  wrapLabel: true,
                  onPressed: controller.issue,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The live count, its spinner, or why it could not be read.
class _Tally extends StatelessWidget {
  const _Tally({required this.controller});

  final AttendanceQrController controller;

  @override
  Widget build(BuildContext context) {
    final counts = controller.counts;
    if (counts != null) {
      return AttendanceTally(
        counts: counts,
        caption: TeacherAttendanceStrings.qrCountCaption,
      );
    }
    final error = controller.countsError;
    if (error != null) {
      return Column(
        children: [
          Text(
            error,
            style: AppTypography.supporting.copyWith(
              color: context.palette.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TeacherPillButton(
            label: TeacherHomeStrings.retry,
            wrapLabel: true,
            onPressed: controller.refreshCounts,
          ),
        ],
      );
    }
    return SizedBox(
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
}

/// The attendance code: [data] — the raw token — drawn 235 square, black on
/// white in either theme (a scanner needs the contrast), read out as
/// "Ирцийн QR код" and never as its content.
///
/// [data] is a live check-in credential: nothing here prints it — no key,
/// no diagnostics property, no semantics label.
class AttendanceQrCode extends StatelessWidget {
  const AttendanceQrCode({required this.data, super.key});

  final String data;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: TeacherAttendanceStrings.qrLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: _codeSize,
        child: QrImageView(
          data: data,
          size: _codeSize,
          padding: EdgeInsets.zero,
          backgroundColor: palette.qrBackground,
          eyeStyle: QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: palette.qrInk,
          ),
          dataModuleStyle: QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: palette.qrInk,
          ),
        ),
      ),
    );
  }
}
