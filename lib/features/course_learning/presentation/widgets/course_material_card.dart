import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course_exercise.dart';
import 'exercise_text_field.dart' show exerciseBorderColor;

/// One row in the Course materials tab: file icon, name and size, a download
/// button. Tapping it flips the button to a downloaded/checked state, purely
/// as local widget state — there is no file to actually fetch and no backend
/// download endpoint; see `CourseExerciseDetailScreen`'s own doc comment on
/// what this issue defers.
class CourseMaterialCard extends StatelessWidget {
  const CourseMaterialCard({required this.material, super.key});

  final CourseExerciseMaterial material;

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
                  material.name,
                  style: AppTypography.cardHeading.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(material.sizeLabel, style: AppTypography.cardSupporting),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const _DownloadButton(),
        ],
      ),
    );
  }
}

/// Download glyph → a filled check once tapped, then inert. A frontend-only
/// stand-in for "downloaded", not a real transfer — there is nothing behind
/// it to actually fetch.
class _DownloadButton extends StatefulWidget {
  const _DownloadButton();

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  bool _downloaded = false;

  @override
  Widget build(BuildContext context) {
    final downloaded = _downloaded;

    return Semantics(
      button: true,
      label: downloaded ? 'Downloaded' : 'Download',
      child: Material(
        color: downloaded
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.surface,
        shape: CircleBorder(
          side: BorderSide(
            color: downloaded ? AppColors.success : exerciseBorderColor,
          ),
        ),
        shadowColor: Colors.black.withValues(alpha: 0.06),
        elevation: 1,
        child: InkWell(
          onTap: downloaded ? null : () => setState(() => _downloaded = true),
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: downloaded
                  ? const Icon(
                      AppIcons.check,
                      size: 20,
                      color: AppColors.success,
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
