import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course_exercise.dart';

/// One row in the Course materials tab: file icon, name and size, a download
/// button.
///
/// Two modes, one look. With no [onDownload] — the sample exercise — tapping
/// flips the button to a downloaded/checked state, purely as local widget
/// state. With one — a lesson from the backend — the tap is the caller's:
/// the button draws [downloading] as a spinner in place of its glyph while
/// the download link is fetched and opened, and [downloaded] as the same
/// check. The Figma pack draws only the idle and checked states; the spinner
/// is the app's existing small blue progress indicator, not a new design.
///
/// A `link` material (`CourseExerciseMaterial.isLink`) uses this same row:
/// the Figma pack draws no link variant, so rather than invent one it keeps
/// the file glyph and the download button, with no size line (a link has
/// none). Tapping it opens the link — see
/// `CourseExerciseDetailController.downloadMaterial`.
/// Solved from the reference frame at 1:1 — the glyph sits on a 32 tile
/// (`AppPalette.surfaceTile`) and the row's two lines are a size apart, both
/// lighter than the shared `cardHeading`/`cardSupporting` this screen
/// inherits them from.
const double _tileSize = 32;
const double _glyphSize = 20;
const double _titleSize = 14;
const double _sizeLabelSize = 13;

class CourseMaterialCard extends StatelessWidget {
  const CourseMaterialCard({
    required this.material,
    super.key,
    this.onDownload,
    this.downloading = false,
    this.downloaded = false,
  });

  final CourseExerciseMaterial material;

  /// Called when the idle download button is tapped. Null keeps the local,
  /// sample-only toggle — see the class doc.
  final VoidCallback? onDownload;

  /// Only read with an [onDownload]: the link is being fetched or opened.
  final bool downloading;

  /// Only read with an [onDownload]: the link has been opened.
  final bool downloaded;

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
          // The reference sets the file glyph on its own flat tile rather
          // than on the card surface directly.
          Container(
            width: _tileSize,
            height: _tileSize,
            decoration: BoxDecoration(
              color: palette.surfaceTile,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              'assets/images/course_learning/exercise_file.svg',
              width: _glyphSize,
              height: _glyphSize,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material.name,
                  style: AppTypography.cardHeading.copyWith(
                    fontSize: _titleSize,
                    fontWeight: FontWeight.w500,
                    color: palette.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  material.sizeLabel,
                  style: AppTypography.cardSupporting.copyWith(
                    fontSize: _sizeLabelSize,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _DownloadButton(
            onDownload: onDownload,
            downloading: downloading,
            downloaded: downloaded,
          ),
        ],
      ),
    );
  }
}

/// Download glyph → a filled check once downloaded, then inert. Without an
/// [onDownload] that happens on tap, as a local stand-in; with one, it
/// follows [downloading]/[downloaded] — see `CourseMaterialCard`.
class _DownloadButton extends StatefulWidget {
  const _DownloadButton({
    required this.onDownload,
    required this.downloading,
    required this.downloaded,
  });

  final VoidCallback? onDownload;
  final bool downloading;
  final bool downloaded;

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  /// The local toggle's state — only used without an `onDownload`.
  bool _downloaded = false;

  @override
  Widget build(BuildContext context) {
    final onDownload = widget.onDownload;
    final controlled = onDownload != null;
    final downloaded = controlled ? widget.downloaded : _downloaded;
    final downloading = controlled && widget.downloading && !downloaded;
    final palette = context.palette;

    final VoidCallback? onTap;
    if (downloaded || downloading) {
      onTap = null;
    } else if (controlled) {
      onTap = onDownload;
    } else {
      onTap = () => setState(() => _downloaded = true);
    }

    return Semantics(
      button: true,
      label: downloaded
          ? 'Downloaded'
          : downloading
          ? 'Downloading'
          : 'Download',
      child: Material(
        // Downloaded: the `success` green, as ring and glyph and as a 12 %
        // wash of the same green — a tint of the role, so it follows it.
        color: downloaded
            ? palette.success.withValues(alpha: 0.12)
            : palette.surface,
        shape: CircleBorder(
          side: BorderSide(
            color: downloaded ? palette.success : palette.outline,
          ),
        ),
        // Black @ 6 %: `shadowSubtle`'s hue at this control's own strength.
        shadowColor: palette.shadowSubtle.withValues(alpha: 0.06),
        elevation: 1,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: downloaded
                  ? Icon(AppIcons.check, size: 20, color: palette.success)
                  : downloading
                  ? CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.primary,
                    )
                  : SvgPicture.asset(
                      'assets/images/course_learning/exercise_download.svg',
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
