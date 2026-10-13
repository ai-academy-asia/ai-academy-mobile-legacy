import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';

/// How a [TeacherPillButton] is painted — the three treatments the
/// `tsag-solih` reference draws, which the session sheet's "Цаг солих"
/// shares.
enum TeacherPillVariant {
  /// Blue fill, white label — "Хүлээгдэж байна".
  filled,

  /// White, a hairline grey outline and a soft drop, dark label —
  /// "Хүсэлт илгээх", "Цаг солих".
  outlined,

  /// White, red outline and label — "Татгалзсан", "Татгалзах".
  danger,

  /// An action that is not available yet (Issue #372): the app's muted
  /// treatment for a disabled action — `ExerciseSubmitButton`'s — a
  /// `surfaceSubtle` pill in `outline` with a `disabledInk` label, so it
  /// reads as unavailable rather than as a live blue action. Exposed to
  /// assistive technology as a disabled button.
  disabled,
}

/// A rounded pill with a centred label, as the Teacher Schedule references
/// draw their buttons (Issue #231).
///
/// Not [AppButton]: that is the Login frame's 12pt-label button, and these
/// references set their labels larger, with the cooler `AppPalette.outline`
/// outline and a soft shadow under the outlined pill. Label sizes match the
/// references' label *widths* (16 for "Цаг солих", 14 in a row): their
/// typeface runs narrower than Manrope at the same cap height.
class TeacherPillButton extends StatelessWidget {
  const TeacherPillButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = TeacherPillVariant.outlined,
    this.height = 44,
    this.fontSize = 16,
    this.horizontalPadding = 16,
    this.wrapLabel = false,
  });

  final String label;

  /// Null leaves the pill inert, drawn exactly the same.
  final VoidCallback? onPressed;

  final TeacherPillVariant variant;
  final double height;
  final double fontSize;
  final double horizontalPadding;

  /// Lets a label too long for one line wrap, the pill growing past
  /// [height] to hold it, instead of cutting it short (Issue #372) — for a
  /// pill given the full width it needs, as a sheet's actions are. Off, the
  /// pill stays [height] tall and a long label ends in an ellipsis, as a
  /// row's trailing pill must.
  final bool wrapLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Filled: an `accent` pill (its edge the same blue) with `onPrimary`.
    // Outlined: `surface` in `outline`, the near-black `textStrong` label.
    // Danger: `surface` in `dangerOutline`, an `errorInk` label — one red in
    // light mode, an edge and a label.
    final (fill, outline, ink) = switch (variant) {
      TeacherPillVariant.filled => (
        palette.accent,
        palette.accent,
        palette.onPrimary,
      ),
      TeacherPillVariant.outlined => (
        palette.surface,
        palette.outline,
        palette.textStrong,
      ),
      TeacherPillVariant.danger => (
        palette.surface,
        palette.dangerOutline,
        palette.errorInk,
      ),
      TeacherPillVariant.disabled => (
        palette.surfaceSubtle,
        palette.outline,
        palette.disabledInk,
      ),
    };
    final disabled = variant == TeacherPillVariant.disabled;
    final radius = BorderRadius.circular(height / 2);

    return Semantics(
      button: true,
      enabled: onPressed != null && !disabled,
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: variant == TeacherPillVariant.outlined
              ? [
                  BoxShadow(
                    color: palette.shadowSubtle,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: outline),
          ),
          child: InkWell(
            onTap: disabled ? null : onPressed,
            customBorder: RoundedRectangleBorder(borderRadius: radius),
            child: Container(
              height: wrapLabel ? null : height,
              constraints: wrapLabel ? BoxConstraints(minHeight: height) : null,
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: wrapLabel ? _wrapVerticalPadding : 0,
              ),
              // Hugs the label under loose constraints (a row's trailing
              // pill); fills a stretched parent (the sheet's full width).
              child: Align(
                widthFactor: 1,
                child: Text(
                  label,
                  maxLines: wrapLabel ? null : 1,
                  overflow: wrapLabel ? null : TextOverflow.ellipsis,
                  textAlign: wrapLabel ? TextAlign.center : null,
                  style: AppTypography.buttonLabel.copyWith(
                    fontSize: fontSize,
                    height: 1.2,
                    color: ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Above and below a wrapped label, inside the pill's edge.
const double _wrapVerticalPadding = 10;
