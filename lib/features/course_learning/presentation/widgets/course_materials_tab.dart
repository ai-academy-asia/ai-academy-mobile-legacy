import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course_exercise.dart';
import 'course_material_card.dart';

/// The Course materials tab: a stack of [CourseMaterialCard] rows, each
/// centred in the tab card's own padding the way the Assignment/Note tabs'
/// content is.
///
/// With an [onDownload], each row's download is the caller's (see
/// `CourseMaterialCard`), and a row's failure is shown under it in the Login
/// screen's own `fieldError` treatment — the Figma pack has no error state
/// for this tab. Without one, every row keeps its local sample toggle.
class CourseMaterialsTab extends StatelessWidget {
  const CourseMaterialsTab({
    required this.materials,
    super.key,
    this.onDownload,
    this.isDownloading = _no,
    this.isDownloaded = _no,
    this.errorMessageFor = _none,
  });

  final List<CourseExerciseMaterial> materials;

  /// Called with a material's id when its download button is tapped.
  final ValueChanged<int>? onDownload;

  final bool Function(int materialId) isDownloading;
  final bool Function(int materialId) isDownloaded;
  final String? Function(int materialId) errorMessageFor;

  static bool _no(int _) => false;
  static String? _none(int _) => null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < materials.length; i++) ...[
              if (i != 0) const SizedBox(height: 12),
              _row(context, materials[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, CourseExerciseMaterial material) {
    final onDownload = this.onDownload;
    if (onDownload == null) return CourseMaterialCard(material: material);

    final error = errorMessageFor(material.id);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CourseMaterialCard(
          material: material,
          onDownload: () => onDownload(material.id),
          downloading: isDownloading(material.id),
          downloaded: isDownloaded(material.id),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          // Held to the card's width, so the line starts at its edge.
          SizedBox(
            width: 329,
            child: Text(
              error,
              style: AppTypography.fieldError.copyWith(
                color: context.palette.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
