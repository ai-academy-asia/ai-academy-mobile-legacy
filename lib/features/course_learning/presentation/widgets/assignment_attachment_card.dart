import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course_exercise.dart';
import '../course_learning_strings.dart';
import 'assignment_upload_dropzone.dart';

/// The completed file row's leading tile, sampled at 1:1 — the same flat grey
/// square (`AppPalette.surfaceTile`) `CourseMaterialCard` uses, with the tick
/// in the primary ink.
const double _completeTileSize = 32;

enum _DownloadStage { idle, downloading, complete }

/// The Assignment tab's own attached reference file (e.g. a starter
/// template). Three distinctly-shaped states, one per Figma frame: an idle
/// row matching `CourseMaterialCard`'s own bordered-row language, a taller
/// card with a progress bar and a "Cancel" pill while (simulated-)
/// downloading, and a completed row with a "Remove" control that drops back
/// to idle.
///
/// **Sample/local state only.** The "download" is a [Timer] incrementing a
/// progress value; nothing is fetched over the network — there is no file to
/// actually fetch, the same reasoning `CourseMaterialCard`'s own doc comment
/// gives for why its download button does nothing real either. Kept as its
/// own widget rather than a variant of `CourseMaterialCard` so that widget's
/// existing, simpler behaviour (an instant checked state, no progress,
/// cancel or remove) stays exactly as it is on the Course materials tab.
class AssignmentAttachmentCard extends StatefulWidget {
  const AssignmentAttachmentCard({
    required this.attachment,
    required this.onDownloaded,
    required this.onRemoved,
    super.key,
  });

  final CourseExerciseMaterial attachment;

  /// Called once the simulated download reaches 100% — `AssignmentTab` uses
  /// this to know the attachment is ready, one of the pieces of "required
  /// sample content" it gates Submit on.
  final VoidCallback onDownloaded;

  /// Called when the completed file is removed, dropping back to idle —
  /// `AssignmentTab` un-gates Submit again the same way.
  final VoidCallback onRemoved;

  @override
  State<AssignmentAttachmentCard> createState() =>
      _AssignmentAttachmentCardState();
}

class _AssignmentAttachmentCardState extends State<AssignmentAttachmentCard> {
  static const _tickInterval = Duration(milliseconds: 150);
  static const _steps = 10; // ~1.5s total, ticking one tenth at a time.

  _DownloadStage _stage = _DownloadStage.idle;

  /// How many ticks have fired, 0 to [_steps]. An integer count, not an
  /// accumulating `double`: ten additions of `0.1` do not reliably sum to
  /// exactly `1.0` in floating point, which would leave [_progress] a hair
  /// short forever and the timer never cancelling itself.
  int _ticksElapsed = 0;
  Timer? _timer;

  double get _progress => _ticksElapsed / _steps;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _stage = _DownloadStage.downloading;
      _ticksElapsed = 0;
    });
    _timer = Timer.periodic(_tickInterval, (timer) {
      setState(() => _ticksElapsed += 1);
      if (_ticksElapsed >= _steps) {
        timer.cancel();
        setState(() => _stage = _DownloadStage.complete);
        widget.onDownloaded();
      }
    });
  }

  void _cancel() {
    _timer?.cancel();
    setState(() {
      _stage = _DownloadStage.idle;
      _ticksElapsed = 0;
    });
  }

  void _remove() {
    setState(() => _stage = _DownloadStage.idle);
    widget.onRemoved();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      // The reference's empty state is the dashed drop area, not a row for
      // the attached file — tapping it begins the same simulated transfer the
      // download row used to start, which is what the next two frames show.
      _DownloadStage.idle => AssignmentUploadDropzone(onTap: _start),
      _DownloadStage.downloading => _DownloadingCard(
        heading: CourseLearningStrings.downloadStarted,
        title: CourseLearningStrings.downloadingAttachment,
        cancelLabel: CourseLearningStrings.cancelDownload,
        amountLabel: _downloadedLabel(widget.attachment.sizeLabel, _progress),
        progress: _progress,
        onCancel: _cancel,
      ),
      _DownloadStage.complete => _CompleteRow(
        subtitle: CourseLearningStrings.attachmentTypeLabel(
          widget.attachment.sizeLabel,
        ),
        onRemove: _remove,
      ),
    };
  }
}

/// The same three-state file area, for a file the student really uploads —
/// a backend assignment's. Stateless: the pick, the upload and the stored
/// file live on `CourseExerciseDetailController`, so they survive a tab
/// switch, and this draws whichever state it is handed.
///
/// A separate widget from [AssignmentAttachmentCard] rather than a mode of
/// it, so that one's timer-driven simulation — which the Figma states and
/// the goldens were built against — stays exactly as it is. Both draw the
/// same private pieces below.
///
/// **No real progress.** `CourseLearningRepository.uploadFile` answers once,
/// when the upload is done, so the reference's filling bar and "129 KB /
/// 1 MB" count have nothing to read: both indicators run indeterminate and
/// the line under "Uploading..." is the file's total size alone.
///
/// **Its own wording.** The reference words this card for a download; here
/// it says upload — see `CourseLearningStrings.uploadStarted`.
class AssignmentFileUploadCard extends StatelessWidget {
  const AssignmentFileUploadCard({
    required this.uploadSizeLabel,
    required this.uploadedFileLabel,
    required this.onPick,
    required this.onCancel,
    required this.onRemove,
    super.key,
  });

  /// The size of the file being uploaded, e.g. "1 MB" — non-null exactly
  /// while an upload is in flight.
  final String? uploadSizeLabel;

  /// The stored file's "1 MB, PDF" line — non-null once one is uploaded.
  final String? uploadedFileLabel;

  /// Each null draws its control unchanged but inert — the form is locked
  /// while a submit is in flight.
  final VoidCallback? onPick;
  final VoidCallback? onCancel;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    if (uploadSizeLabel case final sizeLabel?) {
      return _DownloadingCard(
        heading: CourseLearningStrings.uploadStarted,
        title: CourseLearningStrings.uploadingFile,
        cancelLabel: CourseLearningStrings.cancelUpload,
        amountLabel: sizeLabel,
        progress: null,
        onCancel: onCancel,
      );
    }
    if (uploadedFileLabel case final fileLabel?) {
      return _CompleteRow(subtitle: fileLabel, onRemove: onRemove);
    }
    return AssignmentUploadDropzone(onTap: onPick);
  }
}

/// A single bordered row, shared by the idle and complete states — same
/// 329 x 72 geometry as `CourseMaterialCard`, just with the leading icon,
/// two text lines and trailing control passed in.
class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 329,
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: palette.outline,
          width: AppDimens.borderWidth,
        ),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.cardHeading.copyWith(
                    fontSize: 14,
                    color: palette.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.cardSupporting.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _CompleteRow extends StatelessWidget {
  const _CompleteRow({required this.subtitle, required this.onRemove});

  /// The "1 MB, PDF" line under "Complete".
  final String subtitle;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _AttachmentRow(
      // The reference sets the tick on the same flat grey tile the course
      // material rows use, in the primary ink — not a green tile with a green
      // tick, which is what this drew before.
      leading: Container(
        width: _completeTileSize,
        height: _completeTileSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.surfaceTile,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.check, size: 18, color: palette.textPrimary),
      ),
      title: CourseLearningStrings.attachmentComplete,
      subtitle: subtitle,
      trailing: _CircleIconButton(
        label: CourseLearningStrings.removeAttachment,
        onTap: onRemove,
        child: Icon(Icons.close, size: 20, color: palette.textPrimary),
      ),
    );
  }
}

/// The 40 x 40 white, bordered, circular control shared by the idle
/// (download) and complete (remove) rows.
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: context.palette.surface,
        shape: CircleBorder(side: BorderSide(color: context.palette.outline)),
        // Black @ 6 %: `shadowSubtle`'s hue at this control's own strength.
        shadowColor: context.palette.shadowSubtle.withValues(alpha: 0.06),
        elevation: 1,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Padding(padding: const EdgeInsets.all(10), child: child),
          ),
        ),
      ),
    );
  }
}

/// The in-transfer state: a [heading] ("Your download has started."), a
/// progress row with a Cancel pill, and a progress bar underneath — a taller card than the
/// idle/complete rows, since the reference draws this one with real
/// in-progress chrome rather than a single row.
class _DownloadingCard extends StatelessWidget {
  const _DownloadingCard({
    required this.heading,
    required this.title,
    required this.cancelLabel,
    required this.amountLabel,
    required this.progress,
    required this.onCancel,
  });

  /// The card's first line, e.g. "Your download has started.".
  final String heading;

  /// The line beside the spinner, e.g. "Downloading...".
  final String title;

  final String cancelLabel;

  /// The line under [title], e.g. "129 KB / 1 MB".
  final String amountLabel;

  /// 0 to 1, or null when the transfer reports none — both indicators then
  /// run indeterminate.
  final double? progress;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 329,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: palette.outline,
          width: AppDimens.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: AppTypography.cardHeading.copyWith(
              fontSize: 13,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.5,
                  // The ring and the bar below run in the spinner blue
                  // (`primary`) on the `progressTrack`.
                  color: palette.primary,
                  backgroundColor: palette.progressTrack,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.cardHeading.copyWith(
                        fontSize: 14,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      amountLabel,
                      style: AppTypography.cardSupporting.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _CancelButton(label: cancelLabel, onTap: onCancel),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: palette.primary,
              backgroundColor: palette.progressTrack,
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 80,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: palette.outline,
                width: AppDimens.borderWidth,
              ),
            ),
            child: Text(
              label,
              style: AppTypography.cardHeading.copyWith(
                fontSize: 13,
                color: palette.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders e.g. "129 KB / 1 MB" for a "1 MB" [totalSizeLabel] at 13%
/// progress — parsed from the sample size string rather than a second,
/// separately-maintained byte count, so the two can never disagree.
String _downloadedLabel(String totalSizeLabel, double progress) {
  final match = RegExp(
    r'^([\d.]+)\s*(KB|MB|GB)$',
  ).firstMatch(totalSizeLabel.trim());
  if (match == null) return totalSizeLabel;

  final totalValue = double.parse(match.group(1)!);
  final unit = match.group(2)!;
  final downloaded = totalValue * progress;

  final downloadedLabel = unit == 'MB' && downloaded < 1
      ? '${(downloaded * 1024).round()} KB'
      : '${downloaded.toStringAsFixed(downloaded < 10 ? 1 : 0)} $unit';
  return '$downloadedLabel / $totalSizeLabel';
}
