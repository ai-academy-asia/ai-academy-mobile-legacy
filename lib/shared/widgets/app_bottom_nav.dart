import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';

/// The bar's top rule — a lighter grey than the global [AppColors.border],
/// sampled off the reference frame at 1:1.
const Color _dividerColor = Color(0xFFEAEDF0);

/// The icon's nominal size, set so a Phosphor glyph inks the 21 the reference
/// draws. An [AppBottomNavItem.selectedAsset] is drawn at its own intrinsic
/// size instead and ignores this.
const double _iconSize = 24;

/// The box between the icon and the label. The reference's 9 of clear space
/// between their ink is partly the label's own leading, so this is the
/// remainder — set by measuring the render, not by arithmetic on the spec.
const double _iconToLabelGap = 3;

/// The label size. The Adult Home reference inks its labels at 10pt; the
/// adult bar keeps 12 — two up from [AppTypography.badgeLabel]'s 10 — so the
/// shell reads at the same scale as the page content (a product decision,
/// Issue #188). The style is shared with three other widgets, so the size is
/// overridden here rather than on the token.
const double _labelSize = 12;

/// The selected tab's icon and label — the Adult Home and Profile frames'
/// `#2970FF`, the same blue the selected-tab SVGs carry. Not [AppColors.blue]
/// (`#296CFF`), which is close but sampled from a different capture.
const Color _selectedColor = Color(0xFF2970FF);

/// One tab of [AppBottomNav].
class AppBottomNavItem {
  const AppBottomNavItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.selectedAsset,
  });

  final IconData icon;
  final String label;

  /// An SVG to draw in place of [icon] while this tab is the selected one, for
  /// a tab whose active glyph the design ships as its own artwork rather than
  /// as a weight of the icon font. The asset carries its own colour, so it is
  /// not tinted. Null keeps [icon] in both states, which is what every tab
  /// without a bespoke active asset does.
  final String? selectedAsset;

  /// Null renders the tab inert — no destination exists for it yet.
  final VoidCallback? onTap;
}

/// The app-wide bottom tab bar: an icon and label per tab, the selected one
/// in the frames' `#2970FF`.
///
/// Home, the cohort list and Profile all draw this one bar with its defaults
/// and no overrides, so its geometry — [AppDimens.bottomNavHeight], the tabs
/// inset [AppDimens.screenPadding] from both edges (tab centres at 76, 196.5
/// and 317 on a 393pt screen, as the Adult Home reference places them) and
/// the sizes above — is identical on all three (Issue #188). The junior
/// frames draw the same bar with a smaller label, which [labelSize] carries.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.items,
    required this.currentIndex,
    super.key,
    this.labelSize = _labelSize,
    this.horizontalPadding = AppDimens.screenPadding,
    this.selectedColor = _selectedColor,
  });

  final List<AppBottomNavItem> items;
  final int currentIndex;

  /// The tab labels' font size.
  final double labelSize;

  /// Insets the row of tabs from both edges; the tabs share what is left
  /// equally.
  final double horizontalPadding;

  /// The selected tab's icon and label.
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: _dividerColor, width: AppDimens.borderWidth),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: AppDimens.bottomNavHeight,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    selected: i == currentIndex,
                    labelSize: labelSize,
                    selectedColor: selectedColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.labelSize,
    required this.selectedColor,
  });

  final AppBottomNavItem item;
  final bool selected;
  final double labelSize;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : AppColors.textSecondary;
    final selectedAsset = selected ? item.selectedAsset : null;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: item.onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The asset is drawn at its own intrinsic size but inside a box as
            // tall as a font glyph's, so a tab with one is exactly as tall as
            // its neighbours and every label in the row stays on one line.
            SizedBox(
              height: _iconSize,
              child: selectedAsset == null
                  ? Icon(item.icon, size: _iconSize, color: color)
                  : Center(child: SvgPicture.asset(selectedAsset)),
            ),
            const SizedBox(height: _iconToLabelGap),
            Text(
              item.label,
              style: AppTypography.badgeLabel.copyWith(
                color: color,
                fontSize: labelSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
