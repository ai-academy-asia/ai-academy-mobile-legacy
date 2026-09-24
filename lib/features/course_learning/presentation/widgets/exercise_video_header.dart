import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import 'exercise_text_field.dart' show exerciseBorderColor;

/// The reference's dark navy video placeholder — no thumbnail, no player,
/// just the badge/play/duration chrome around it. There is no video asset or
/// playback to wire up yet, so the play button is inert, same reasoning as
/// `CourseModuleListScreen`'s own not-yet-wired actions.
const Color _videoBackground = Color(0xFF080F35);

/// 393 x 196: back button, "Live Classroom Recording" badge, a centred play
/// button, and the duration in the bottom-right corner.
///
/// The back button here is a second copy of `CourseLearningBackButton`'s
/// visual (white circle, [exerciseBorderColor] outline, soft shadow), not
/// that widget reused directly: `CourseLearningBackButton` lays itself out as
/// a standalone row above the page (`Padding` + `Align`, vertically centred
/// in whatever space it is given), whereas here it has to sit at a fixed
/// `Positioned` spot overlaid on the video, with the recording badge
/// deliberately drawn first so the button overlaps its leading edge — exactly
/// as the reference shows the badge's own text partly hidden behind it.
///
/// **The back button and badge are offset by the device's own top inset**
/// (`MediaQuery.paddingOf(context).top`), not wrapped in a `SafeArea` — this
/// screen has no `SafeArea` around its scroll content at all (unlike
/// `CourseModuleListScreen`/`LessonListScreen`, both of which wrap their
/// whole body in one), because the video background is meant to run
/// genuinely full-bleed under the status bar/notch, matching the reference.
/// Without this offset, the button's fixed `top: 16` sits inside the status
/// bar/notch's own reserved area on a real phone: it still paints there and
/// looks tappable, but iOS's own status-bar touch handling — present because
/// this screen scrolls (`SingleChildScrollView`) — claims taps in that zone
/// before Flutter's gesture arena ever sees them, so `onTap` silently never
/// fires. A widget test's fake window has no real status bar to do that
/// interception, which is why `tester.tap` on this button passed even while
/// it did nothing on a real device. The play button and duration label need
/// no such offset: neither sits inside the unsafe top strip.
class ExerciseVideoHeader extends StatelessWidget {
  const ExerciseVideoHeader({
    required this.durationLabel,
    required this.recordingBadgeLabel,
    super.key,
  });

  final String durationLabel;
  final String recordingBadgeLabel;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: 196,
      child: ColoredBox(
        color: _videoBackground,
        child: Stack(
          children: [
            Positioned(
              top: topInset + 24,
              left: AppDimens.screenPadding,
              child: _RecordingBadge(label: recordingBadgeLabel),
            ),
            Positioned(
              top: topInset + AppDimens.screenPadding,
              left: AppDimens.screenPadding,
              child: const _VideoBackButton(),
            ),
            const Center(child: _PlayButton()),
            Positioned(
              right: AppDimens.screenPadding,
              bottom: 16,
              child: Text(
                durationLabel,
                style: AppTypography.buttonLabel.copyWith(
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingBadge extends StatelessWidget {
  const _RecordingBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.badgeLabel.copyWith(color: AppColors.onPrimary),
      ),
    );
  }
}

class _VideoBackButton extends StatelessWidget {
  const _VideoBackButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(side: BorderSide(color: exerciseBorderColor)),
        shadowColor: Colors.black.withValues(alpha: 0.2),
        elevation: 2,
        child: InkWell(
          onTap: () => Navigator.of(context).maybePop(),
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              AppIcons.caretLeft,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Play',
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        shadowColor: Colors.black.withValues(alpha: 0.3),
        elevation: 4,
        child: InkWell(
          // Playback is not implemented — see the class doc above.
          onTap: () {},
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Center(
              child: SizedBox(width: 22, height: 22, child: _PlayIcon()),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayIcon extends StatelessWidget {
  const _PlayIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset('assets/images/course_learning/exercise_play.svg');
  }
}
