import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_palette.dart';
import '../../domain/home_dashboard.dart';

// Measured off the Figma Home frames at 1:1 — the tiles in frames 2–4 and the
// full-width rows in frames 1–2 share every value here.

/// Content sits 12 in from the card's outer edge on every side.
const double _padding = 12;

/// The icon's box. Outlined on a row, bare on a tile.
const double _iconBox = 40;
const double _iconSize = 24;

/// A row's icon box to its figures.
const double _iconToText = 16;

/// Caption to value, and the figures (or a tile's icon) to what follows.
const double _lineGap = 4;
const double _groupGap = 24;

/// Every action on a statistic card is 36 tall.
const double statActionHeight = 36;

/// The two shapes a statistic card takes — see [HomeStatLayout].
///
/// Holds everything the payment and attendance cards share, so each of those
/// only decides its colours, its figures and its action.
class HomeStatCard extends StatelessWidget {
  const HomeStatCard({
    required this.layout,
    required this.icon,
    required this.label,
    required this.value,
    required this.action,
    super.key,
    this.fill,
    this.gradient,
    this.outline,
    this.iconColor,
    this.labelColor,
    this.valueColor,
  });

  final HomeStatLayout layout;
  final IconData icon;
  final String label;
  final String value;
  final Widget action;

  /// Null is [AppPalette.surface] (Dark Mode Phase 5: defaults resolve from
  /// the theme in [build], as a default parameter value cannot).
  final Color? fill;

  /// Painted over [fill] when set — the attendance tile's.
  final Gradient? gradient;

  /// Null is the theme's `outline`, `accent`, `textStatLabel`, `accent`.
  final Color? outline;
  final Color? iconColor;
  final Color? labelColor;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fill = this.fill ?? palette.surface;
    final outline = this.outline ?? palette.outline;
    final iconColor = this.iconColor ?? palette.accent;
    final labelColor = this.labelColor ?? palette.textStatLabel;
    final valueColor = this.valueColor ?? palette.accent;
    final isTile = layout == HomeStatLayout.tile;

    final figures = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: _labelStyle.copyWith(color: labelColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: _lineGap),
        Text(
          value,
          style: _valueStyle.copyWith(color: valueColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    final iconBox = Container(
      width: _iconBox,
      height: _iconBox,
      alignment: Alignment.center,
      decoration: isTile
          ? null
          : BoxDecoration(
              color: context.palette.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.palette.outline),
            ),
      child: Icon(icon, size: _iconSize, color: iconColor),
    );

    return Container(
      padding: const EdgeInsets.all(_padding - AppDimens.borderWidth),
      decoration: BoxDecoration(
        color: gradient == null ? fill : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
        border: Border.all(color: outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isTile) ...[
            Align(alignment: Alignment.centerLeft, child: iconBox),
            const SizedBox(height: _groupGap),
            figures,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                iconBox,
                const SizedBox(width: _iconToText),
                Expanded(child: figures),
              ],
            ),
          const SizedBox(height: _groupGap),
          action,
        ],
      ),
    );
  }
}

/// "Дараанийн төлөлт" — 14 on a 20 line.
const TextStyle _labelStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w500,
  leadingDistribution: TextLeadingDistribution.even,
);

/// "3 хоног дутуу", "1/20  · 10%" — the same size, bold.
const TextStyle _valueStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w700,
  leadingDistribution: TextLeadingDistribution.even,
);
