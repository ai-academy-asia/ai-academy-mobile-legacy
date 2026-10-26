import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/keyboard_reveal.dart';

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
///
/// Its type is `AppTextField`'s: [AppTypography.fieldText] typed and resting,
/// [AppTypography.fieldLabel] floated.
///
/// **The whole box, and the Submit under it, scroll into view with the
/// keyboard (Issues #459, #461).** It is a [KeyboardRevealField]; the Note
/// and Assignment forms wrap their fields and Submit in a
/// [KeyboardRevealArea].

/// How many lines a single-line field's placeholder may take (Issue #540):
/// the link field's "Link оруулна уу" takes 3 at 3.0× text on a 320pt
/// phone, 2 at 2.0×, and 1 at the default size.
const int _singleLineHintMaxLines = 3;

class ExerciseTextField extends StatelessWidget {
  const ExerciseTextField({
    required this.controller,
    required this.placeholder,
    required this.height,
    super.key,
    this.floatingLabel,
    this.multiline = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String placeholder;
  final String? floatingLabel;
  final double height;

  /// True for the description/note textareas; false for the single-line
  /// link field.
  final bool multiline;

  /// False once the Assignment tab's submission is no longer editable
  /// (pending review, or accepted) — `TextField`'s own disabled treatment,
  /// nothing custom.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final label = floatingLabel;
    final palette = context.palette;

    // Not `expands: true`: that code path is what triggers a real Flutter
    // framework semantics bug in this SDK build the moment a field using it
    // is disposed (e.g. switching tabs away from one) —
    // `_RenderObjectSemantics.debugCheckForParentData`: `!semantics
    // .parentDataDirty' is not true`, reproduced on every such disposal.
    // A fixed, generous `maxLines` inside the same outer `SizedBox` gets the
    // identical box height (the outer `SizedBox`'s tight constraint forces
    // it regardless of how many lines are actually typed) through the
    // ordinary bounded-`TextField` code path instead.
    final field = TextField(
      controller: controller,
      enabled: enabled,
      maxLines: multiline ? 6 : 1,
      textAlignVertical: TextAlignVertical.top,
      style: AppTypography.fieldText.copyWith(color: palette.textPrimary),
      cursorColor: palette.borderFocused,
      decoration: InputDecoration(
        hintText: placeholder,
        // A single-line field's placeholder may wrap rather than be cut
        // short at large text (Issue #540); the input itself stays one
        // line. A multiline field's follows its own lines, as before.
        hintMaxLines: multiline ? null : _singleLineHintMaxLines,
        hintStyle: AppTypography.fieldText.copyWith(
          color: palette.textSecondary,
        ),
        labelText: label,
        labelStyle: AppTypography.fieldText.copyWith(
          color: palette.textSecondary,
        ),
        floatingLabelStyle: AppTypography.fieldLabel.copyWith(
          color: palette.textSecondary,
        ),
        floatingLabelBehavior: label == null
            ? FloatingLabelBehavior.never
            : FloatingLabelBehavior.always,
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: _border(palette.outline),
        enabledBorder: _border(palette.outline),
        focusedBorder: _border(palette.borderFocused),
      ),
    );
    return KeyboardRevealField(
      // The multiline fields keep their exact box (see above). The
      // single-line link field is [height] at least, growing only when
      // larger text needs the room (Issue #540).
      child: multiline
          ? SizedBox(height: height, child: field)
          : ConstrainedBox(
              constraints: BoxConstraints(minHeight: height),
              child: field,
            ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
    borderSide: BorderSide(color: color, width: AppDimens.borderWidth),
  );
}
