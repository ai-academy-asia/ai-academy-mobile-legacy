import 'package:flutter/widgets.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import '../../../auth/presentation/student_tabs.dart';
import '../home_strings.dart';

/// The adult tab bar, as Home, the cohort list and Profile all draw it: the
/// app-wide [AppBottomNav] with its defaults, the adult labels and glyphs,
/// and every tab switched through [openStudentTab] on the adult track. The
/// junior counterpart is `JuniorBottomNav`.
///
/// **One item list for all three screens** (Issue #188). Each screen used to
/// declare its own items and give only its own tab a solid
/// [AppBottomNavItem.selectedAsset], so a destination looked different
/// depending on which screen was showing — Хичээл's solid export was a
/// different drawing from its outline book altogether. Every tab now draws
/// its one outline Phosphor glyph in both states — Нүүр [AppIcons.house],
/// Хичээл [AppIcons.bookOpenText], Профайл [AppIcons.user] — and selection
/// changes only the colour.
class AdultBottomNav extends StatelessWidget {
  const AdultBottomNav({required this.current, super.key, this.onCurrentTap});

  /// The tab whose screen this is. Drawn selected.
  final StudentTab current;

  /// What tapping [current] does. Null — the usual case — leaves it inert,
  /// since the student is already there. The cohort list passes a pop when it
  /// was pushed from the course catalog rather than opened as the tab.
  final VoidCallback? onCurrentTap;

  @override
  Widget build(BuildContext context) {
    AppBottomNavItem item(
      StudentTab tab, {
      required IconData icon,
      required String label,
    }) {
      return AppBottomNavItem(
        icon: icon,
        label: label,
        onTap: tab == current
            ? onCurrentTap
            : () => openStudentTab(context, StudentTrack.adult, tab),
      );
    }

    return AppBottomNav(
      currentIndex: current.index,
      items: [
        item(StudentTab.home, icon: AppIcons.house, label: HomeStrings.navHome),
        item(
          StudentTab.progress,
          icon: AppIcons.bookOpenText,
          label: HomeStrings.navCourses,
        ),
        item(
          StudentTab.profile,
          icon: AppIcons.user,
          label: HomeStrings.navProfile,
        ),
      ],
    );
  }
}
