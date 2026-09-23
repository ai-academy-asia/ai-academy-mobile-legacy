import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';

/// One titled block of content on the detail screen — description,
/// curriculum, prerequisites, what's included. All four share this shape
/// because all four are the same kind of thing: a heading plus however many
/// lines [describeJsonLines] (or `preferMongolianText`) produced from a field
/// whose actual shape is not confirmed.
///
/// Renders nothing at all when [lines] is empty, so a course whose response
/// omitted a field — or sent it in a shape this code did not anticipate —
/// simply has one fewer section, never an empty heading over blank space.
class CourseDetailSection extends StatelessWidget {
  const CourseDetailSection({required this.title, required this.lines, super.key});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();

    // A single line reads as one paragraph; more than one reads as a list —
    // a lone bullet in front of the only point looks like a mistake.
    final bulleted = lines.length > 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.cardHeading),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                bulleted ? '•  $line' : line,
                style: AppTypography.cardSupporting,
              ),
            ),
        ],
      ),
    );
  }
}
