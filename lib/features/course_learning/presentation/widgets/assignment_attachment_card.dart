import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course_exercise.dart';
import '../course_learning_strings.dart';
import 'exercise_text_field.dart' show exerciseBorderColor;

enum _DownloadStage { idle, downloading, complete }

/// The Assignment tab's own attached reference file (e.g. a starter
/// template) — the same bordered-row visual language `CourseMaterialCard`
/// already uses (329 x 72, [exerciseBorderColor] border, `exercise_file.svg`)
/// but with a fuller state machine on its trailing control: idle → a real,
/// simulated download the student can cancel mid-way → complete.
///
/// **Sample/local state only.** The "download" is a [Timer] incrementing a
/// progress value; nothing is fetched over the network — there is no file to
/// actually fetch, the same reasoning `CourseMaterialCard`'s own doc comment
/// gives for why its download button does nothing real either. Kept as its
/// own widget rather than a variant of `CourseMaterialCard` so that widget's
/// existing, simpler behaviour (an instant checked state, no progress or
/// cancel) stays exactly as it is on the Course materials tab.
class AssignmentAttachmentCard extends StatefulWidget {
  const AssignmentAttachmentCard({
    required this.attachment,
    required this.onDownloaded,
    super.key,
  });

  final CourseExerciseMaterial attachment;

  /// Called once the simulated download reaches 100% — `AssignmentTab` uses
  /// this to know the attachment is ready, one of the pieces of "required
  /// sample content" it gates Submit on.
  final VoidCallback onDownloaded;

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
          SvgPicture.asset(
            'assets/images/course_learning/exercise_file.svg',
            width: 32,
            height: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.attachment.name,
                  style: AppTypography.cardHeading.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.attachment.sizeLabel,
                  style: AppTypography.cardSupporting,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _DownloadControl(
            stage: _stage,
            progress: _progress,
            onStart: _start,
            onCancel: _cancel,
          ),
        ],
      ),
    );
  }
}

class _DownloadControl extends StatelessWidget {
  const _DownloadControl({
    required this.stage,
    required this.progress,
    required this.onStart,
    required this.onCancel,
  });

  final _DownloadStage stage;
  final double progress;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final label = switch (stage) {
      _DownloadStage.idle => CourseLearningStrings.downloadAttachment,
      _DownloadStage.downloading => CourseLearningStrings.downloadingAttachment,
      _DownloadStage.complete => CourseLearningStrings.downloadedAttachment,
    };
    final onTap = switch (stage) {
      _DownloadStage.idle => onStart,
      _DownloadStage.downloading => onCancel,
      _DownloadStage.complete => null,
    };

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.surface,
        shape: CircleBorder(
          side: BorderSide(
            color: stage == _DownloadStage.complete
                ? AppColors.success
                : exerciseBorderColor,
          ),
        ),
        shadowColor: Colors.black.withValues(alpha: 0.06),
        elevation: 1,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: switch (stage) {
              _DownloadStage.idle => Padding(
                padding: const EdgeInsets.all(10),
                child: SvgPicture.asset(
                  'assets/images/course_learning/exercise_download.svg',
                ),
              ),
              _DownloadStage.downloading => Padding(
                padding: const EdgeInsets.all(9),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 2.5,
                      color: AppColors.blue,
                      backgroundColor: AppColors.border,
                    ),
                    const Icon(Icons.close, size: 12, color: AppColors.blue),
                  ],
                ),
              ),
              _DownloadStage.complete => const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(AppIcons.check, size: 20, color: AppColors.success),
              ),
            },
          ),
        ),
      ),
    );
  }
}
