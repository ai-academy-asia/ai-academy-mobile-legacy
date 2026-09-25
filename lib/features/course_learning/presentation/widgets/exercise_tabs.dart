import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../course_learning_strings.dart';

/// Which of the tab card's tabs is showing.
enum ExerciseTab { assignment, materials, note, quiz }

/// The reference's own primary blue for this screen — close to, but not
/// identical to, [AppColors.blue] (`#296CFF` vs. this screen's `#2970FF`).
/// Kept as its own local constant rather than silently treated as the same
/// colour: the two were evidently sampled from two different Figma captures,
/// and only this screen's own reference confirms this exact value.
const Color exercisePrimaryColor = Color(0xFF2970FF);

/// The Assignment / Course materials / Note / Quiz tab header — 49 tall, a
/// thin divider underneath, and the active tab's own blue underline.
///
/// Plain tappable labels in a `Row`, not a segmented control: the reference
/// draws left-aligned text with an underline under the active one, not the
/// pill/equal-width look `CupertinoSegmentedControl`/`ToggleButtons` give.
///
/// The row scrolls horizontally rather than trying to fit every label at a
/// fixed width: four labels' own intrinsic widths (see `_TabLabel`'s
/// `IntrinsicWidth` doc comment) no longer reliably fit the ~361pt card on
/// every device/text-scale combination the way three did, and a scrollable
/// row is the standard, robust fix for "more tabs than comfortably fit" —
/// the same trade-off Material's own `TabBar(isScrollable: true)` makes —
/// rather than re-tuning fixed paddings again for whatever tab count comes
/// next.
class ExerciseTabs extends StatelessWidget {
  const ExerciseTabs({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final ExerciseTab selected;
  final ValueChanged<ExerciseTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 49,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TabLabel(
                  label: CourseLearningStrings.assignmentTab,
                  selected: selected == ExerciseTab.assignment,
                  onTap: () => onSelected(ExerciseTab.assignment),
                ),
                const SizedBox(width: 8),
                _TabLabel(
                  label: CourseLearningStrings.courseMaterialsTab,
                  selected: selected == ExerciseTab.materials,
                  onTap: () => onSelected(ExerciseTab.materials),
                ),
                const SizedBox(width: 8),
                _TabLabel(
                  label: CourseLearningStrings.noteTab,
                  selected: selected == ExerciseTab.note,
                  onTap: () => onSelected(ExerciseTab.note),
                ),
                const SizedBox(width: 8),
                _TabLabel(
                  label: CourseLearningStrings.quizTab,
                  selected: selected == ExerciseTab.quiz,
                  onTap: () => onSelected(ExerciseTab.quiz),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
      ],
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          // `IntrinsicWidth`, not a bare `Column`: the underline below sizes
          // itself to `double.infinity` to match the label's own width, and
          // that only resolves to a real number when something in the
          // ancestry provides the intrinsic-width layout protocol — a plain
          // `Column` inside a `Row` gives its child loose/unbounded width
          // instead, which is a genuine constraint-resolution bug (confirmed
          // by isolating it to exactly this shape: reproducible with nothing
          // but three such two-child `Column`s in a `Row`, no `Semantics` or
          // `InkWell` involved at all) — it surfaces as a confusing semantics
          // assertion instead of the usual clear "infinite width" layout
          // error, which is what made it look framework-level at first.
          child: IntrinsicWidth(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: AppTypography.cardHeading.copyWith(
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected
                            ? exercisePrimaryColor
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 2,
                  width: double.infinity,
                  color: selected ? exercisePrimaryColor : Colors.transparent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
