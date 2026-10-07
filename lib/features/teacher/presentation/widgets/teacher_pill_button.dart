import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../home/presentation/widgets/home_palette.dart';

/// How a [TeacherPillButton] is painted — the three treatments the
/// `tsag-solih` reference draws, which the session sheet's "Цаг солих"
/// shares.
enum TeacherPillVariant {
  /// Blue fill, white label — "Хүлээгдэж байна".
  filled,

  /// White, a hairline grey outline and a soft drop, dark label —
  /// "Хүсэлт илгээх", "Цаг солих".
  outlined,

  /// White, red outline and label — "Татгалзсан".
  danger,
}

/// A rounded pill with a centred label, as the Teacher Schedule references
/// draw their buttons (Issue #231).
///
/// Not [AppButton]: that is the Login frame's 12pt-label button, and these
/// references set their labels larger, with the cooler [HomePalette.border]
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
  });

  final String label;

  /// Null leaves the pill inert, drawn exactly the same.
  final VoidCallback? onPressed;

  final TeacherPillVariant variant;
  final double height;
  final double fontSize;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final (fill, outline, ink) = switch (variant) {
      TeacherPillVariant.filled => (
        HomePalette.accent,
        HomePalette.accent,
        AppColors.onPrimary,
      ),
      TeacherPillVariant.outlined => (
        AppColors.surface,
        HomePalette.border,
        TeacherPillColors.ink,
      ),
      TeacherPillVariant.danger => (
        AppColors.surface,
        HomePalette.overdueInk,
        HomePalette.overdueInk,
      ),
    };
    final radius = BorderRadius.circular(height / 2);

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: variant == TeacherPillVariant.outlined
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
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
            onTap: onPressed,
            customBorder: RoundedRectangleBorder(borderRadius: radius),
            child: Container(
              height: height,
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              // Hugs the label under loose constraints (a row's trailing
              // pill); fills a stretched parent (the sheet's full width).
              child: Align(
                widthFactor: 1,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.programTitle.copyWith(
                    fontSize: fontSize,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
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

/// The references' near-black label ink, sampled at `#1A1A1A`.
abstract final class TeacherPillColors {
  static const Color ink = Color(0xFF1A1A1A);
}
