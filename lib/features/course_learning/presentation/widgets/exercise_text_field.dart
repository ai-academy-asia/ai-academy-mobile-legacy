import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';

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
/// **The whole box scrolls into view with the keyboard (Issue #459), and
/// the Submit under it too (Issue #461).** On focus, and as the keyboard
/// opens, `EditableText` asks the page's scroll view to show only its caret
/// plus `scrollPadding` — in a textarea, the first line — which left the
/// rest of the box, and the Submit under it, behind the keyboard.
/// [_RevealWholeField] widens that request: through the end of the
/// enclosing [ExerciseSubmitArea] when there is one, so the field and its
/// Submit land above the keyboard together. Once they are on screen, typing
/// inside the field does not scroll the page again.

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
    return _RevealWholeField(
      child: SizedBox(
        height: height,
        child: TextField(
          controller: controller,
          enabled: enabled,
          maxLines: multiline ? 6 : 1,
          textAlignVertical: TextAlignVertical.top,
          style: AppTypography.fieldText.copyWith(color: palette.textPrimary),
          cursorColor: palette.borderFocused,
          decoration: InputDecoration(
            hintText: placeholder,
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
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
    borderSide: BorderSide(color: color, width: AppDimens.borderWidth),
  );
}

/// The block of a tab's form that ends with its Submit button — the Note
/// textarea down to "Submit", the Assignment fields down to theirs
/// (Issue #461).
///
/// Draws nothing and changes no layout. A focused [ExerciseTextField] inside
/// it reveals itself down to this block's end, so the Submit under the field
/// is not left behind the keyboard. **Its last child must be the Submit
/// button**: its bottom edge is what the reveal reaches.
class ExerciseSubmitArea extends SingleChildRenderObjectWidget {
  const ExerciseSubmitArea({required super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSubmitArea();
}

class _RenderSubmitArea extends RenderProxyBox {}

/// Turns any request to show part of [child] on screen — the caret, as the
/// field is focused or the keyboard opens — into the largest of these that
/// fits the page's viewport, [_margin] clear (`TextField`'s default
/// `scrollPadding`):
///
///  1. the whole field, down through the enclosing [ExerciseSubmitArea]'s
///     Submit — or the whole field alone outside one;
///  2. tight, with no margin: the caret line down to that Submit's bottom
///     edge — the field's own text scrolls inside the box above it;
///  3. the part asked for (the caret and its `scrollPadding`) alone — so
///     typing is never hidden.
///
/// Whichever it is, `showOnScreen` scrolls the least it can to show it, so a
/// rect already on screen — while typing — moves nothing.
class _RevealWholeField extends SingleChildRenderObjectWidget {
  const _RevealWholeField({required super.child});

  static const double _margin = 20;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRevealWholeField();
}

class _RenderRevealWholeField extends RenderProxyBox {
  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    const margin = _RevealWholeField._margin;
    final viewport = RenderAbstractViewport.maybeOf(this);
    final area = _submitAreaBelow(viewport);
    // Every rect in [target]'s own coordinates, margin included.
    final RenderBox target = area ?? this;
    final field = MatrixUtils.transformRect(
      getTransformTo(target),
      (Offset.zero & size).inflate(margin),
    );
    final asked = rect == null
        ? field
        : MatrixUtils.transformRect(
            (descendant ?? this).getTransformTo(target),
            rect,
          );
    // Submit's bottom edge, or the field's own outside an area.
    final end = area?.size.height ?? field.bottom - margin;
    final extent = viewport?.paintBounds.height ?? double.infinity;

    Rect span(double top, double bottom) =>
        Rect.fromLTRB(field.left, top, field.right, bottom);
    final reveal = [
      span(field.top, math.max(field.bottom, end + margin)),
      // [asked] is the caret inflated by `scrollPadding`, which this field
      // leaves at `TextField`'s default — [margin] on every side.
      span(asked.top + margin, end),
    ].firstWhere((r) => r.height <= extent, orElse: () => asked);

    if (area == null) {
      super.showOnScreen(rect: reveal, duration: duration, curve: curve);
    } else {
      area.showOnScreen(rect: reveal, duration: duration, curve: curve);
    }
  }

  /// The nearest [ExerciseSubmitArea] holding this field, short of the
  /// page's scroll view; null outside one.
  _RenderSubmitArea? _submitAreaBelow(RenderAbstractViewport? viewport) {
    for (var node = parent; node != null && node != viewport;) {
      if (node is _RenderSubmitArea) return node;
      node = node.parent;
    }
    return null;
  }
}
