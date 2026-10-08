import 'package:flutter/material.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import '../../../auth/presentation/student_tabs.dart';
import '../junior_home_strings.dart';

/// The current Нүүр tab's glyph: Phosphor "House" Fill, the filled weight of
/// the outline house beside it — the same export `AdultBottomNav` draws.
const String _homeSelectedAsset = 'assets/icons/nav_home_selected.svg';

/// The current Профайл tab's glyph: Phosphor "User" Fill, exported from the
/// Junior Profile frame — the same export `AdultBottomNav` draws.
const String _profileSelectedAsset = 'assets/icons/nav_profile_selected.svg';

/// The junior tab bar, as Junior Home, Junior "Сурлагын явц" and Junior
/// Profile all draw it: the app-wide [AppBottomNav] — the junior frames
/// match its height and rule — with the junior labels and glyphs, and every
/// tab switched through [openStudentTab] on the junior track.
///
/// **The same bar as the adult one** (Issue #190): [AppBottomNav]'s shared
/// defaults with no overrides — 24pt icons, 12pt labels, the tabs inset 16pt
/// from both edges, `#2970FF` for the current tab — so the two tracks' bars
/// share one scale, spacing and alignment. The junior frames drew 10pt
/// labels; the requester moved them to the adult bar's 12.
///
/// Each tab has an outline glyph, gray, and the same glyph filled, blue, for
/// when it is the current tab:
///
///   * Нүүр — Phosphor's outline house; its Phosphor Fill
///     ([_homeSelectedAsset]) when current.
///   * Сурлагын явц — Material's `event_available`, outline and filled. The
///     bundled `Phosphor.ttf` carries the outline weight only and the repo
///     has no Phosphor "CalendarCheck" Fill export, so this tab keeps the
///     Material pair — `DEVELOPMENT_RULES.md` §6's fallback — rather than an
///     outline from one family and a fill from another.
///   * Профайл — Phosphor's outline user; its Phosphor Fill
///     ([_profileSelectedAsset]) when current.
///
/// Filled exports go through [AppBottomNavItem.selectedAsset], which the bar
/// scales and tints exactly as it does on the adult bar.
///
/// Inside `JuniorStudentShell` the bar is drawn once, by the shell, with
/// [onSelect] switching the shell's tab in place (Issue #241); a screen drawn
/// on its own leaves [onSelect] null and switches routes through
/// [openStudentTab].
class JuniorBottomNav extends StatelessWidget {
  const JuniorBottomNav({required this.current, super.key, this.onSelect});

  /// The tab whose screen this is. Drawn selected, and inert — already here.
  final StudentTab current;

  /// Switches to another tab without navigating. Null routes the switch
  /// through [openStudentTab].
  final ValueChanged<StudentTab>? onSelect;

  @override
  Widget build(BuildContext context) {
    AppBottomNavItem item(
      StudentTab tab, {
      required IconData icon,
      IconData? selectedIcon,
      required String label,
      String? selectedAsset,
    }) {
      final selected = tab == current;
      return AppBottomNavItem(
        icon: selected ? selectedIcon ?? icon : icon,
        selectedAsset: selectedAsset,
        label: label,
        onTap: selected
            ? null
            : onSelect != null
            ? () => onSelect!(tab)
            : () => openStudentTab(context, StudentTrack.junior, tab),
      );
    }

    return AppBottomNav(
      currentIndex: current.index,
      items: [
        item(
          StudentTab.home,
          icon: AppIcons.house,
          selectedAsset: _homeSelectedAsset,
          label: JuniorHomeStrings.navHome,
        ),
        item(
          StudentTab.progress,
          icon: Icons.event_available_outlined,
          selectedIcon: Icons.event_available,
          label: JuniorHomeStrings.navProgress,
        ),
        item(
          StudentTab.profile,
          icon: AppIcons.user,
          selectedAsset: _profileSelectedAsset,
          label: JuniorHomeStrings.navProfile,
        ),
      ],
    );
  }
}
