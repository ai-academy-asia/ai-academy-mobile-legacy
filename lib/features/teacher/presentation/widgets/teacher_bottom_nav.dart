import 'package:flutter/widgets.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import '../teacher_home_strings.dart';
import 'teacher_tabs.dart';

/// Phosphor "House" Fill — the export `AdultBottomNav` draws.
const String _homeFilled = 'assets/icons/nav_home_selected.svg';

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

/// The teacher tab bar, as the `teacher-homepage` and `huvaari` references
/// draw it: the app-wide [AppBottomNav] with its defaults and four tabs —
/// Нүүр, Хуваарь, Дүнгийн хуудас, Профайл. With the bar's 16pt insets the
/// tab centres fall at 61, 151, 242 and 332, where the references put them.
///
/// The one override is [AppBottomNav.labelSize]: the reference sets its
/// labels at 10, not the student bars' 12 — every label's ink measures 0.82
/// of the 12pt one, width and height alike — which is what keeps
/// "Дүнгийн хуудас" on one line in its 90pt tab.
///
/// Нүүр, Хуваарь (Issue #231) and Дүнгийн хуудас (Issue #233) switch
/// through [openTeacherTab]. Профайл (Issue #243) is a tab of `TeacherShell`
/// only — it has no route — so it switches only through [onSelect]; on a
/// bar drawn outside the shell it stays inert. The `dungiin-huudas`
/// reference draws a different bar (Хуваарь, Дүнгийн хуудас, Хөтөлбөр,
/// Профайл); the app keeps this one by instruction.
///
/// Every tab follows the student bars' treatment: its gray outline glyph when
/// inactive, and the same glyph filled in the bar's blue when active
/// ([AppBottomNavItem.selectedAsset]). Нүүр and Профайл use the Phosphor Fill
/// exports the student bars use; Хуваарь and Дүнгийн хуудас — whose
/// references' filled glyphs were never exported — use fills generated from
/// the outline glyphs themselves, so the shape never changes on selection
/// (Issue #241).
///
/// Inside `TeacherShell` the bar is drawn once, by the shell, with [onSelect]
/// switching the shell's tab in place (Issue #241); a screen drawn on its own
/// leaves [onSelect] null and switches routes through [openTeacherTab].
class TeacherBottomNav extends StatelessWidget {
  const TeacherBottomNav({
    this.current = TeacherTab.home,
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
          icon: AppIcons.house,
          selectedAsset: _homeFilled,
          label: TeacherHomeStrings.navHome,
          onTap: open(TeacherTab.home),
        ),
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
