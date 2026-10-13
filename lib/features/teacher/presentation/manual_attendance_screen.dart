import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/back_title_header.dart';
import '../../../shared/widgets/content_column.dart';
import '../domain/teacher_attendance.dart';
import 'manual_attendance_controller.dart';
import 'teacher_attendance_strings.dart';
import 'teacher_home_strings.dart';
import 'widgets/teacher_confirmation_card.dart';
import 'widgets/teacher_pill_button.dart';
import 'widgets/teacher_request_parts.dart';

/// "Гар аргаар бүртгэх" (Issue #374): the session's real roster under
/// "Сурагчид", each student's status, and "Баталгаажуулах". Built against
/// the manual attendance reference.
///
/// The round control toggles a student between present and absent, as the
/// reference draws it; tapping the row opens all four statuses. A `late`
/// or `excused` record is drawn as itself and never toggled away silently —
/// its control opens the four as well. Only rows the teacher changed are
/// sent ([ManualAttendanceController]); the success card shows only once
/// every one of them is stored, and its "Ойлголоо" returns to the QR
/// screen.
class ManualAttendanceScreen extends StatefulWidget {
  const ManualAttendanceScreen({
    required this.sessionId,
    required this.repository,
    super.key,
  });

  final int sessionId;
  final TeacherAttendanceRepository repository;

  @override
  State<ManualAttendanceScreen> createState() => _ManualAttendanceScreenState();
}

class _ManualAttendanceScreenState extends State<ManualAttendanceScreen> {
  late final ManualAttendanceController _controller =
      ManualAttendanceController(
        repository: widget.repository,
        sessionId: widget.sessionId,
      )..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final result = await _controller.submit();
    if (!mounted || result != AttendanceSubmitResult.allSaved) return;
    await showAttendanceSavedCard(context);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickStatus(AttendanceRow row) async {
    final chosen = await showModalBottomSheet<AttendanceStatus>(
      context: context,
      backgroundColor: context.palette.surfaceElevated,
      barrierColor: context.palette.barrier,
      constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => AttendanceStatusPicker(current: row.current),
    );
    if (chosen != null) _controller.choose(row, chosen);
  }

  void _toggle(AttendanceRow row) {
    switch (row.current) {
      case AttendanceStatus.present:
        _controller.choose(row, AttendanceStatus.absent);
      case AttendanceStatus.absent:
        _controller.choose(row, AttendanceStatus.present);
      case AttendanceStatus.late || AttendanceStatus.excused:
        // Never flipped to present/absent unseen: choose explicitly.
        _pickStatus(row);
    }
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
            builder: (context, _) {
              final rows = _controller.rows;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BackTitleHeader(
                    title: TeacherAttendanceStrings.manualTitle,
                  ),
                  Expanded(child: _body(context, rows)),
                  if (rows != null && rows.isNotEmpty) _footer(context),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, List<AttendanceRow>? rows) {
    final palette = context.palette;
    if (rows == null) {
      final error = _controller.errorMessage;
      if (error == null) {
        return Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: palette.primary,
            ),
          ),
        );
      }
      return _Message(
        text: error,
        action: TeacherPillButton(
          label: TeacherHomeStrings.retry,
          wrapLabel: true,
          onPressed: _controller.load,
        ),
      );
    }
    if (rows.isEmpty) {
      return const _Message(text: TeacherAttendanceStrings.noStudents);
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: AppDimens.pageContentTop),
      itemCount: rows.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.screenPadding,
              0,
              AppDimens.screenPadding,
              _headingToRows,
            ),
            child: Semantics(
              header: true,
              child: Text(
                TeacherAttendanceStrings.studentsHeading,
                style: AppTypography.sectionTitle.copyWith(
                  color: palette.textPrimary,
                ),
              ),
            ),
          );
        }
        final row = rows[index - 1];
        return AttendanceStudentRow(
          row: row,
          enabled: !_controller.submitting,
          onToggle: () => _toggle(row),
          onPick: () => _pickStatus(row),
        );
      },
    );
  }

  Widget _footer(BuildContext context) {
    final failed = _controller.failedCount;
    final canSend = _controller.hasChanges && !_controller.submitting;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        AppDimens.tileGap,
        AppDimens.screenPadding,
        AppDimens.screenPadding + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failed > 0 && !_controller.submitting) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                TeacherAttendanceStrings.failedRows(failed),
                style: AppTypography.supporting.copyWith(
                  color: context.palette.errorInk,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppDimens.tileGap),
          ],
          TeacherPillButton(
            label: TeacherAttendanceStrings.confirm,
            variant: canSend
                ? TeacherPillVariant.filled
                : TeacherPillVariant.disabled,
            wrapLabel: true,
            onPressed: canSend ? _confirm : null,
          ),
        ],
      ),
    );
  }
}

/// "Сурагчид" to the first row's top: with the row's own 16 above its
/// avatar, the reference's 28 from the heading to the first avatar.
const double _headingToRows = 12;

/// Shows the success card ("Амжилттай баталгаажлаа" / "Ойлголоо") at the
/// foot of the screen, and completes when it is dismissed. Call it only
/// after every write has been confirmed.
Future<void> showAttendanceSavedCard(BuildContext context) =>
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
            title: TeacherAttendanceStrings.successTitle,
            onDismiss: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      ),
    );

/// A student: the initials avatar, the name — with the status beneath it
/// when it is `late` or `excused`, or the write's state — and the round
/// status control. 72 tall at the default size, a full-width rule under it.
class AttendanceStudentRow extends StatelessWidget {
  const AttendanceStudentRow({
    required this.row,
    required this.enabled,
    required this.onToggle,
    required this.onPick,
    super.key,
  });

  final AttendanceRow row;
  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final status = row.current;
    final label = TeacherAttendanceStrings.statusLabel(status);
    final String? note = switch (row.write) {
      AttendanceWrite.saving => TeacherAttendanceStrings.saving,
      AttendanceWrite.failed => TeacherAttendanceStrings.saveFailed,
      AttendanceWrite.idle =>
        status == AttendanceStatus.late || status == AttendanceStatus.excused
            ? label
            : null,
    };
    final noteInk = row.write == AttendanceWrite.failed
        ? palette.errorInk
        : status == AttendanceStatus.late
        ? palette.warningInk
        : palette.textSecondary;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.outlineFaint)),
      ),
      child: Semantics(
        button: true,
        enabled: enabled,
        label:
            '${row.student.name}, $label'
            '${row.write == AttendanceWrite.failed ? ', ${TeacherAttendanceStrings.saveFailed}' : ''}',
        excludeSemantics: true,
        onTap: enabled ? onPick : null,
        child: InkWell(
          onTap: enabled ? onPick : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.screenPadding,
              vertical: _rowPadding,
            ),
            child: Row(
              children: [
                StudentInitialsAvatar(
                  name: row.student.name,
                  studentId: row.student.studentId,
                ),
                const SizedBox(width: _avatarToName),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.student.name,
                        style: AppTypography.body.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                      if (note != null)
                        Text(
                          note,
                          style: AppTypography.caption.copyWith(color: noteInk),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (row.write == AttendanceWrite.saving)
                  SizedBox.square(
                    dimension: _controlSize,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.primary,
                        ),
                      ),
                    ),
                  )
                else
                  AttendanceStatusControl(
                    status: status,
                    failed: row.write == AttendanceWrite.failed,
                    onTap: enabled ? onToggle : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The reference's row: a 40 avatar 16 inside the row top and bottom, the
/// name 16 after it.
const double _rowPadding = 16;
const double _avatarToName = 16;
const double _controlSize = 40;

/// The round control at a row's end — one look per status:
///
/// * `present` — the reference's filled `accent` disc with a white check;
/// * `absent` — the reference's white disc in `outlineFaint`, a dark check;
/// * `late` — a `warningFill` disc in `warningOutline`, a `warningInk`
///   clock;
/// * `excused` — a `surfaceSubtle` disc in `outline`, a muted dash.
///
/// A failed write draws the edge in `errorOutline`. Colour is never the
/// only sign: `late` and `excused` are named under the student's name.
class AttendanceStatusControl extends StatelessWidget {
  const AttendanceStatusControl({
    required this.status,
    required this.onTap,
    this.failed = false,
    super.key,
  });

  final AttendanceStatus status;
  final bool failed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (fill, edge, ink, icon) = switch (status) {
      AttendanceStatus.present => (
        palette.accent,
        palette.accent,
        palette.onPrimary,
        AppIcons.check,
      ),
      AttendanceStatus.absent => (
        palette.surface,
        palette.outlineFaint,
        palette.textStrong,
        AppIcons.check,
      ),
      AttendanceStatus.late => (
        palette.warningFill,
        palette.warningOutline,
        palette.warningInk,
        AppIcons.clock,
      ),
      AttendanceStatus.excused => (
        palette.surfaceSubtle,
        palette.outline,
        palette.textMuted,
        Icons.remove,
      ),
    };
    return Material(
      color: fill,
      shape: CircleBorder(
        side: BorderSide(color: failed ? palette.errorOutline : edge),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: _controlSize,
          child: Icon(icon, size: 20, color: ink),
        ),
      ),
    );
  }
}

/// A student's initials on one of the reference's three fills, picked by
/// the student's id so a student keeps a colour (`PRODUCT DECISION`: the
/// reference's own assignment follows no stated rule). The name beside it
/// is what assistive technology reads.
class StudentInitialsAvatar extends StatelessWidget {
  const StudentInitialsAvatar({
    required this.name,
    required this.studentId,
    super.key,
  });

  final String name;
  final int studentId;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fills = [
      palette.studentAvatarBlue,
      palette.studentAvatarRed,
      palette.studentAvatarTeal,
    ];
    return ExcludeSemantics(
      child: Container(
        width: _avatarSize,
        height: _avatarSize,
        decoration: BoxDecoration(
          color: fills[studentId % fills.length],
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(6),
        // The initials stay inside the disc at any text size.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            initialsOf(name),
            style: AppTypography.badge.copyWith(color: palette.onStudentAvatar),
          ),
        ),
      ),
    );
  }
}

const double _avatarSize = 40;

/// The first letter of the first two words of [name], upper-cased —
/// "Болд Батаа" → "ББ"; one word gives one letter.
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
}

/// The four statuses to choose from, the current one marked.
class AttendanceStatusPicker extends StatelessWidget {
  const AttendanceStatusPicker({required this.current, super.key});

  final AttendanceStatus current;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
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
            Semantics(
              header: true,
              child: Text(
                TeacherAttendanceStrings.chooseStatus,
                style: AppTypography.sectionTitle.copyWith(
                  color: palette.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final status in AttendanceStatus.values)
              Semantics(
                selected: status == current,
                button: true,
                label: TeacherAttendanceStrings.statusLabel(status),
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(status),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        AttendanceStatusControl(status: status, onTap: null),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            TeacherAttendanceStrings.statusLabel(status),
                            style: AppTypography.body.copyWith(
                              color: palette.textPrimary,
                            ),
                          ),
                        ),
                        if (status == current)
                          Icon(
                            AppIcons.check,
                            size: 20,
                            color: palette.accentText,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A centred message, and an action under it.
class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.screenPadding),
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
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
