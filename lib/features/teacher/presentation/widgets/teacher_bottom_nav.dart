import 'package:flutter/widgets.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import '../teacher_home_strings.dart';
import 'teacher_tabs.dart';

/// [AppIcons.calendar] itself, filled — generated from the font glyph's own
/// contours (its page holes dropped, the "12" kept as a cut-out), so active
/// and inactive are one calendar (Issue #241).
const String _scheduleFilled = 'assets/icons/nav_schedule_active.svg';

/// [AppIcons.exam] itself, filled — generated from the font glyph's own
/// contours (its sheet hole dropped, the "A+" kept as a cut-out), so active
/// and inactive are one sheet (Issue #241).
const String _gradesFilled = 'assets/icons/nav_grades_active.svg';

/// Phosphor "User" Fill — the export `AdultBottomNav` and `JuniorBottomNav`
/// draw for the same outline [AppIcons.user].
const String _profileFilled = 'assets/icons/nav_profile_selected.svg';

/// The teacher tab bar, as the redesigned Teacher Schedule reference draws
/// it (Issue #370): the app-wide [AppBottomNav] with its defaults and three
/// tabs — Хуваарь, Дүнгийн хуудас, Профайл; the former Нүүр tab is gone.
/// With the bar's 16pt insets the tab centres fall at 76, 196.5 and 317,
/// where the reference puts them.
///
/// The one override is [AppBottomNav.labelSize]: the reference sets its
/// labels at 10, not [AppTypography.navLabel]'s 12 — its "Дүнгийн хуудас"
/// measures 77 wide, 10pt's own width (93 at 12). A documented exception to
/// the type scale (Issue #366, `DESIGN_SYSTEM.md` §3).
///
/// Хуваарь (Issue #231) and Дүнгийн хуудас (Issue #233) switch through
/// [openTeacherTab]. Профайл (Issue #243) is a tab of `TeacherShell` only —
/// it has no route — so it switches only through [onSelect]; on a bar drawn
/// outside the shell it stays inert.
///
/// Every tab follows the student bars' treatment: its gray outline glyph when
/// inactive, and the same glyph filled in the bar's blue when active
/// ([AppBottomNavItem.selectedAsset]). Профайл uses the Phosphor Fill export
/// the student bars use; Хуваарь and Дүнгийн хуудас — whose references'
/// filled glyphs were never exported — use fills generated from the outline
/// glyphs themselves, so the shape never changes on selection (Issue #241).
///
/// Inside `TeacherShell` the bar is drawn once, by the shell, with [onSelect]
/// switching the shell's tab in place (Issue #241); a screen drawn on its own
/// leaves [onSelect] null and switches routes through [openTeacherTab].
class TeacherBottomNav extends StatelessWidget {
  const TeacherBottomNav({
    this.current = TeacherTab.schedule,
    super.key,
    this.onSelect,
  });

  /// The tab whose screen this is. Drawn selected, and inert.
  final TeacherTab current;

  /// Switches to another tab without navigating. Null routes the switch
  /// through [openTeacherTab].
  final ValueChanged<TeacherTab>? onSelect;

  @override
  Widget build(BuildContext context) {
    VoidCallback? open(TeacherTab tab) => tab == current
        ? null
        : onSelect != null
        ? () => onSelect!(tab)
        : () => openTeacherTab(context, tab);

    return AppBottomNav(
      currentIndex: current.index,
      labelSize: 10,
      items: [
        AppBottomNavItem(
          icon: AppIcons.calendar,
          selectedAsset: _scheduleFilled,
          label: TeacherHomeStrings.navSchedule,
          onTap: open(TeacherTab.schedule),
        ),
        AppBottomNavItem(
          icon: AppIcons.exam,
          selectedAsset: _gradesFilled,
          label: TeacherHomeStrings.navGrades,
          onTap: open(TeacherTab.grades),
        ),
        AppBottomNavItem(
          icon: AppIcons.user,
          selectedAsset: _profileFilled,
          label: TeacherHomeStrings.navProfile,
          // Shell-only: no route to switch to from a standalone bar.
          onTap: onSelect == null ? null : open(TeacherTab.profile),
        ),
      ],
    );
  }
}
