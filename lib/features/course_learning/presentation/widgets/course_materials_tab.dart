import 'package:flutter/material.dart';

import '../../domain/course_exercise.dart';
import 'course_material_card.dart';

/// The Course materials tab: a stack of [CourseMaterialCard] rows, each
/// centred in the tab card's own padding the way the Assignment/Note tabs'
/// content is.
class CourseMaterialsTab extends StatelessWidget {
  const CourseMaterialsTab({required this.materials, super.key});

  final List<CourseExerciseMaterial> materials;

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
              CourseMaterialCard(material: materials[i]),
            ],
          ],
        ),
      ),
    );
  }
}
