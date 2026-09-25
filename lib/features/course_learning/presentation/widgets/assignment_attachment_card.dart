import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course_exercise.dart';
import '../course_learning_strings.dart';
import 'exercise_text_field.dart' show exerciseBorderColor;

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
      _DownloadStage.idle => _IdleRow(
        attachment: widget.attachment,
        onDownload: _start,
      ),
      _DownloadStage.downloading => _DownloadingCard(
        attachment: widget.attachment,
        progress: _progress,
        onCancel: _cancel,
      ),
      _DownloadStage.complete => _CompleteRow(
        attachment: widget.attachment,
        onRemove: _remove,
      ),
    };
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
    return Container(
      width: 329,
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: exerciseBorderColor,
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
                  style: AppTypography.cardHeading.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.cardSupporting),
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

class _IdleRow extends StatelessWidget {
  const _IdleRow({required this.attachment, required this.onDownload});

  final CourseExerciseMaterial attachment;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return _AttachmentRow(
      leading: SvgPicture.asset(
        'assets/images/course_learning/exercise_file.svg',
        width: 32,
        height: 32,
      ),
      title: attachment.name,
      subtitle: attachment.sizeLabel,
      trailing: _CircleIconButton(
        label: CourseLearningStrings.downloadAttachment,
        onTap: onDownload,
        child: SvgPicture.asset(
          'assets/images/course_learning/exercise_download.svg',
        ),
      ),
    );
  }
}

class _CompleteRow extends StatelessWidget {
  const _CompleteRow({required this.attachment, required this.onRemove});

  final CourseExerciseMaterial attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return _AttachmentRow(
      leading: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.check, size: 18, color: AppColors.success),
      ),
      title: CourseLearningStrings.attachmentComplete,
      subtitle: CourseLearningStrings.attachmentTypeLabel(
        attachment.sizeLabel,
      ),
      trailing: _CircleIconButton(
        label: CourseLearningStrings.removeAttachment,
        onTap: onRemove,
        child: const Icon(Icons.close, size: 20, color: AppColors.textPrimary),
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
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(side: BorderSide(color: exerciseBorderColor)),
        shadowColor: Colors.black.withValues(alpha: 0.06),
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

/// The downloading state: "Your download has started.", a progress row with
/// a Cancel pill, and a progress bar underneath — a taller card than the
/// idle/complete rows, since the reference draws this one with real
/// in-progress chrome rather than a single row.
class _DownloadingCard extends StatelessWidget {
  const _DownloadingCard({
    required this.attachment,
    required this.progress,
    required this.onCancel,
  });

  final CourseExerciseMaterial attachment;
  final double progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 329,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: exerciseBorderColor,
          width: AppDimens.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            CourseLearningStrings.downloadStarted,
            style: AppTypography.cardHeading.copyWith(fontSize: 13),
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
                  color: AppColors.blue,
                  backgroundColor: AppColors.border,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CourseLearningStrings.downloadingAttachment,
                      style: AppTypography.cardHeading.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _downloadedLabel(attachment.sizeLabel, progress),
                      style: AppTypography.cardSupporting,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _CancelButton(onTap: onCancel),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: AppColors.blue,
              backgroundColor: AppColors.border,
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: CourseLearningStrings.cancelDownload,
      child: Material(
        color: AppColors.surface,
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
                color: exerciseBorderColor,
                width: AppDimens.borderWidth,
              ),
            ),
            child: Text(
              CourseLearningStrings.cancelDownload,
              style: AppTypography.cardHeading.copyWith(fontSize: 13),
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
