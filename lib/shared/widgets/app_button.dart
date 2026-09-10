import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';

/// Which of the two buttons in `Sign in - 1` this is.
enum AppButtonVariant {
  /// The upper button: solid brand blue.
  filled,

  /// The lower button: white, with a thin light border.
  outlined,
}

/// A 44pt full-width button.
///
/// Handles the three states the screen needs: pressable, disabled (flat fill,
/// no ripple), and loading (spinner in place of the label, width unchanged so
/// the layout does not jump).
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = AppButtonVariant.filled,
    this.loading = false,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  final AppButtonVariant variant;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    // Tappable right now.
    final enabled = onPressed != null && !loading;

    // Loading is not the same as disabled: the button is working, so it keeps
    // its active colours. Only a button that cannot be pressed at all goes
    // flat — otherwise a request in flight reads as a dead control.
    final active = loading || onPressed != null;

    final isFilled = variant == AppButtonVariant.filled;

    final Color background;
    final Color foreground;
    final Color? borderColor;

    if (isFilled) {
      background = active ? AppColors.blue : AppColors.disabled;
      foreground = AppColors.onPrimary;
      borderColor = null;
    } else {
      background = AppColors.surface;
      foreground = active ? AppColors.textPrimary : AppColors.disabled;
      borderColor = active ? AppColors.border : AppColors.disabled;
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppDimens.buttonRadius),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AppDimens.buttonRadius),
          splashColor: isFilled ? Colors.white24 : null,
          highlightColor: isFilled ? Colors.white10 : null,
          child: Ink(
            height: AppDimens.buttonHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimens.buttonRadius),
              border: borderColor == null
                  ? null
                  : Border.all(color: borderColor, width: AppDimens.borderWidth),
            ),
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(foreground),
                      ),
                    )
                  : Text(
                      label,
                      style: AppTypography.buttonLabel.copyWith(color: foreground),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
