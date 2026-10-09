import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../course_learning_strings.dart';

/// The reference's dark navy video placeholder (`AppPalette.videoSurface`)
/// — no thumbnail, no player, just the badge/play/duration chrome around it.
/// There is no video asset or playback to wire up yet, so the play button is
/// inert, same reasoning as `CourseModuleListScreen`'s own not-yet-wired
/// actions.
///
/// Everything on it reads the media roles, not the page's: the video stays
/// dark in every theme, so its discs (`mediaControl`), the back disc's ring
/// (`mediaControlOutline`), their glyphs (`onMediaControl`) and its text
/// (`onMedia`) must not follow the page's surface, outline and text.

/// 393 x 196: back button, "Live Classroom Recording" badge, a centred play
/// button, and the duration in the bottom-right corner.
///
/// The back button here is a second copy of `CourseLearningBackButton`'s
/// visual (white circle, grey ring, soft shadow), not
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
    this.hasVideo = true,
  });

  final String durationLabel;
  final String recordingBadgeLabel;

  /// False draws the reference's "no recording yet" state: the same navy
  /// area and back button, but one centred pill instead of the badge, the
  /// play control and the duration.
  final bool hasVideo;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final palette = context.palette;

    return SizedBox(
      height: 196,
      child: ColoredBox(
        color: palette.videoSurface,
        child: Stack(
          children: [
            if (hasVideo) ...[
              // A lesson type with no badge copy draws no badge, rather than
              // an empty pill.
              if (recordingBadgeLabel.isNotEmpty)
                Positioned(
                  top: topInset + 24,
                  left: AppDimens.screenPadding,
                  child: _RecordingBadge(label: recordingBadgeLabel),
                ),
              const Center(child: _PlayButton()),
              Positioned(
                right: AppDimens.screenPadding,
                bottom: 16,
                child: Text(
                  durationLabel,
                  style: AppTypography.buttonLabel.copyWith(
                    color: palette.onMedia,
                  ),
                ),
              ),
            ] else
              const Center(
                child: _RecordingBadge(
                  label: CourseLearningStrings.videoUnavailable,
                ),
              ),
            Positioned(
              top: topInset + AppDimens.screenPadding,
              left: AppDimens.screenPadding,
              child: const _VideoBackButton(),
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
    final onMedia = context.palette.onMedia;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: onMedia.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.badgeLabel.copyWith(color: onMedia),
      ),
    );
  }
}

class _VideoBackButton extends StatelessWidget {
  const _VideoBackButton();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: 'Back',
      child: Material(
        color: palette.mediaControl,
        shape: CircleBorder(
          side: BorderSide(color: palette.mediaControlOutline),
        ),
        // Black @ 20 %, exactly as before: `shadowSubtle`'s hue at this
        // control's own strength, as `CourseLearningBackButton` does.
        shadowColor: palette.shadowSubtle.withValues(alpha: 0.2),
        elevation: 2,
        child: InkWell(
          onTap: () => Navigator.of(context).maybePop(),
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            // A full left arrow with a shaft, not `AppIcons.caretLeft`'s
            // bare chevron — the reference draws the arrow on this screen.
            child: Icon(
              Icons.arrow_back,
              size: 20,
              color: palette.onMediaControl,
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
        color: context.palette.mediaControl,
        shape: const CircleBorder(),
        // Black @ 30 %: `shadow`'s hue at the play disc's own strength.
        shadowColor: context.palette.shadow.withValues(alpha: 0.3),
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
    // The design's own glyph, in its authored colour: not tinted, since a
    // same-colour tint still moves edge pixels (see `AppSvgIcon`).
    return SvgPicture.asset('assets/images/course_learning/exercise_play.svg');
  }
}
