import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../course_learning_strings.dart';

/// Which of the tab card's tabs is showing — declared in the order the card
/// draws them, the learning workflow's order (Issue #219): take notes,
/// review the materials, then do the assignment. The same for Adult and
/// Junior.
enum ExerciseTab { note, materials, assignment }

/// The Note / Course materials / Assignment tab header — 49 tall, a thin
/// divider underneath, and the active tab's own blue underline.
///
/// The reference's blue here is `#2970FF` (`AppPalette.accent`), not Login's
/// `#296CFF` (`primary`). The active label is text (`accentText`) and its
/// underline a fill (`accent`): one blue in light mode, two roles.
///
/// Plain tappable labels in a `Row`, not a segmented control: the reference
/// draws left-aligned text with an underline under the active one, not the
/// pill/equal-width look `CupertinoSegmentedControl`/`ToggleButtons` give.
///
/// The row still scrolls horizontally (`SingleChildScrollView`) even though
/// three labels comfortably fit the ~361pt card at every normal text scale —
/// kept rather than removed so a longer label or a larger accessibility text
/// scale never reintroduces the overflow this once had, without needing a
/// fixed-padding retune to fix it again.
class ExerciseTabs extends StatelessWidget {
  const ExerciseTabs({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final ExerciseTab selected;
  final ValueChanged<ExerciseTab> onSelected;

  /// Every tab, in [ExerciseTab]'s order.
  static const List<ExerciseTab> tabs = ExerciseTab.values;

  static String _label(ExerciseTab tab) => switch (tab) {
    ExerciseTab.assignment => CourseLearningStrings.assignmentTab,
    ExerciseTab.materials => CourseLearningStrings.courseMaterialsTab,
    ExerciseTab.note => CourseLearningStrings.noteTab,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 47,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _TabLabel(
                    label: _label(tabs[i]),
                    selected: selected == tabs[i],
                    onTap: () => onSelected(tabs[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
        Divider(height: 1, color: context.palette.divider),
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
                            ? context.palette.accentText
                            : context.palette.textPrimary,
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 2,
                  width: double.infinity,
                  color: selected ? context.palette.accent : Colors.transparent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
