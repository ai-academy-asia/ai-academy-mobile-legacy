import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';

/// The reference's border colour for every field/card on this screen — a
/// cooler, lighter grey than [AppColors.border]. Nothing in the shared
/// palette matches it; see the same constant's note in
/// `CourseLearningBackButton`.
const Color exerciseBorderColor = Color(0xFFD6DBE1);

/// One bordered input box on the Exercise Detail screen — the link field, the
/// assignment description, and the note textarea all use this, sized to each
/// one's own exact Figma measurement via [height].
///
/// Not `AppTextField`: that widget is a single-line field fixed at a 56pt
/// height by its own contentPadding math (see its doc comment), with no
/// `maxLines`/multiline support at all — a hard blocker for the description
/// and note fields, which need to be 104pt/118pt textareas. Rebuilding it
/// locally, at each field's own measured size, is smaller than adding
/// multiline support to a widget three other screens depend on for one
/// single-line use here.
///
/// [floatingLabel] mirrors the reference: the link field has none (its
/// placeholder sits plainly inside the box), while the description and note
/// fields keep a permanently-floated label ("Тайлбар") in the border notch —
/// `FloatingLabelBehavior.always`, not the rising-on-focus behaviour
/// `AppTextField` uses, since the reference never shows it resting inside the
/// box.
class ExerciseTextField extends StatelessWidget {
  const ExerciseTextField({
    required this.controller,
    required this.placeholder,
    required this.height,
    super.key,
    this.floatingLabel,
    this.multiline = false,
  });

  final TextEditingController controller;
  final String placeholder;
  final String? floatingLabel;
  final double height;

  /// True for the description/note textareas; false for the single-line
  /// link field.
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final label = floatingLabel;

    // Not `expands: true`: that code path is what triggers a real Flutter
    // framework semantics bug in this SDK build the moment a field using it
    // is disposed (e.g. switching tabs away from one) —
    // `_RenderObjectSemantics.debugCheckForParentData`: `!semantics
    // .parentDataDirty' is not true`, reproduced on every such disposal.
    // A fixed, generous `maxLines` inside the same outer `SizedBox` gets the
    // identical box height (the outer `SizedBox`'s tight constraint forces
    // it regardless of how many lines are actually typed) through the
    // ordinary bounded-`TextField` code path instead.
    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        maxLines: multiline ? 6 : 1,
        textAlignVertical: TextAlignVertical.top,
        style: AppTypography.fieldValue,
        cursorColor: AppColors.borderFocused,
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: AppTypography.fieldPlaceholder,
          labelText: label,
          labelStyle: AppTypography.fieldPlaceholder,
          floatingLabelStyle: AppTypography.fieldFloatingLabel.copyWith(
            color: AppColors.textSecondary,
          ),
          floatingLabelBehavior: label == null
              ? FloatingLabelBehavior.never
              : FloatingLabelBehavior.always,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: _border(),
          enabledBorder: _border(),
          focusedBorder: _border(color: AppColors.borderFocused),
        ),
      ),
    );
  }

  OutlineInputBorder _border({Color color = exerciseBorderColor}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
        borderSide: BorderSide(color: color, width: AppDimens.borderWidth),
      );
}
