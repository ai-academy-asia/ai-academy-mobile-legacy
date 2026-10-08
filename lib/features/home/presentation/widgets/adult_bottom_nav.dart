import 'package:flutter/widgets.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import '../../../auth/presentation/student_tabs.dart';
import '../home_strings.dart';

/// Phosphor "House" Fill.
const String _homeFilled = 'assets/icons/nav_home_selected.svg';

/// [AppIcons.bookOpenText] itself, filled — generated from the font glyph's
/// own contours (its two page holes dropped, the three text lines kept as
/// cut-outs), so active and inactive are one book, not Phosphor's separately
/// drawn "BookOpenText" Fill (Issue #237).
const String _coursesFilled = 'assets/icons/nav_courses_active.svg';

/// Phosphor "User" Fill — the same export `JuniorBottomNav` draws.
const String _profileFilled = 'assets/icons/nav_profile_selected.svg';

/// The adult tab bar, as Home, the cohort list and Profile all draw it: the
/// app-wide [AppBottomNav] with its defaults, the adult labels and glyphs,
/// and every tab switched through [openStudentTab] on the adult track. The
/// junior counterpart is `JuniorBottomNav`.
///
/// **One item list for all three screens** (Issue #188). Each screen used to
/// declare its own items and give only its own tab a filled
/// [AppBottomNavItem.selectedAsset], so the same destination drew filled on
/// its own screen and outline elsewhere. Now every destination has one glyph
/// in two weights, on every screen: the gray Phosphor outline from the font
/// when inactive, and the same glyph's Phosphor *Fill* weight in the bar's
/// blue when active — Нүүр [AppIcons.house] / [_homeFilled], Хичээл
/// [AppIcons.bookOpenText] / [_coursesFilled], Профайл [AppIcons.user] /
/// [_profileFilled]. The font carries the outline weight only, so the filled
/// ones are the Figma exports.
///
/// Inside `AdultStudentShell` the bar is drawn once, by the shell, with
/// [onSelect] switching the shell's tab in place (Issue #237); a screen drawn
/// on its own leaves [onSelect] null and switches routes through
/// [openStudentTab].
class AdultBottomNav extends StatelessWidget {
  const AdultBottomNav({
    required this.current,
    super.key,
    this.onCurrentTap,
    this.onSelect,
  });

  /// The tab whose screen this is. Drawn selected.
  final StudentTab current;

  /// What tapping [current] does. Null — the usual case — leaves it inert,
  /// since the student is already there. The cohort list passes a pop when it
  /// was pushed from the course catalog rather than opened as the tab.
  final VoidCallback? onCurrentTap;

  /// Switches to another tab without navigating. Null routes the switch
  /// through [openStudentTab].
  final ValueChanged<StudentTab>? onSelect;

  @override
  Widget build(BuildContext context) {
    AppBottomNavItem item(
      StudentTab tab, {
      required IconData icon,
      required String filled,
      required String label,
    }) {
      return AppBottomNavItem(
        icon: icon,
        selectedAsset: filled,
        label: label,
        onTap: tab == current
            ? onCurrentTap
            : onSelect != null
            ? () => onSelect!(tab)
            : () => openStudentTab(context, StudentTrack.adult, tab),
      );
    }

    return AppBottomNav(
      currentIndex: current.index,
      items: [
        item(
          StudentTab.home,
          icon: AppIcons.house,
          filled: _homeFilled,
          label: HomeStrings.navHome,
        ),
        item(
          StudentTab.progress,
          icon: AppIcons.bookOpenText,
          filled: _coursesFilled,
          label: HomeStrings.navCourses,
        ),
        item(
          StudentTab.profile,
          icon: AppIcons.user,
          filled: _profileFilled,
          label: HomeStrings.navProfile,
        ),
      ],
    );
  }
}
