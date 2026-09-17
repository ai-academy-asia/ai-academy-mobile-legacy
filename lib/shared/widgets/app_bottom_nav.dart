import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';

/// One tab of [AppBottomNav].
class AppBottomNavItem {
  const AppBottomNavItem({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;

  /// Null renders the tab inert — no destination exists for it yet.
  final VoidCallback? onTap;
}

/// The app-wide bottom tab bar: an icon and label per tab, the selected one
/// in [AppColors.blue].
///
/// No bottom nav exists anywhere else in the app yet — this is the first
/// screen that needs one, so it lives in `shared/widgets` rather than as a
/// private widget of one screen, ready for the next screen that needs the
/// same bar instead of a second implementation.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({required this.items, required this.currentIndex, super.key});

  final List<AppBottomNavItem> items;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: AppDimens.borderWidth),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppDimens.bottomNavHeight,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(child: _NavButton(item: items[i], selected: i == currentIndex)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected});

  final AppBottomNavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.blue : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: item.onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(item.label, style: AppTypography.badgeLabel.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
