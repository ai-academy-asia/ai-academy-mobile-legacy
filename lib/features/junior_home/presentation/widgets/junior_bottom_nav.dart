import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import '../../../auth/presentation/student_tabs.dart';
import '../junior_home_strings.dart';
import 'junior_home_palette.dart';

/// The tab labels' size — see the class doc on [JuniorBottomNav].
const double _labelSize = 10;

/// The junior tab bar, as Junior Home, Junior "Сурлагын явц" and Junior
/// Profile all draw it: the app-wide [AppBottomNav] — the junior frames
/// match its height, rule and icon size — with the junior labels and glyphs,
/// and every tab switched through [openStudentTab] on the junior track.
///
/// Three things differ from the adult bar, and both junior reference frames
/// agree on them: the labels ink at 10pt where the adult bar's are 12 (a
/// "Сурлагын явц" 68 wide, not 85); the tab centres sit at 76, 196.5 and
/// 317 — three equal tabs inside the screen's 16pt gutter rather than across
/// its full width; and the selected tab is the junior frames' own
/// [JuniorPalette.accent] (`#2970FF`), not the adult bar's `#296CFF`.
///
/// Each tab has an outline glyph and a solid one for when it is the current
/// tab, as the three frames draw them. The bundled `Phosphor.ttf` carries one
/// (outline) weight only, so each solid glyph — and the calendar, which has
/// no confirmed Phosphor codepoint — is the Material fallback
/// `DEVELOPMENT_RULES.md` §6 asks for in place of a guessed codepoint:
///
///   * Нүүр — Phosphor's outline house; a solid house when current.
///   * Сурлагын явц — a calendar with a tick, outline and solid.
///   * Профайл — Phosphor's outline user; a solid person when current.
class JuniorBottomNav extends StatelessWidget {
  const JuniorBottomNav({required this.current, super.key});

  /// The tab whose screen this is. Drawn selected, and inert — already here.
  final StudentTab current;

  @override
  Widget build(BuildContext context) {
    AppBottomNavItem item(
      StudentTab tab, {
      required IconData icon,
      required IconData selectedIcon,
      required String label,
    }) {
      final selected = tab == current;
      return AppBottomNavItem(
        icon: selected ? selectedIcon : icon,
        label: label,
        onTap: selected
            ? null
            : () => openStudentTab(context, StudentTrack.junior, tab),
      );
    }

    return AppBottomNav(
      currentIndex: current.index,
      labelSize: _labelSize,
      horizontalPadding: AppDimens.screenPadding,
      selectedColor: JuniorPalette.accent,
      items: [
        item(
          StudentTab.home,
          icon: AppIcons.house,
          selectedIcon: Icons.home,
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
          selectedIcon: Icons.person,
          label: JuniorHomeStrings.navProfile,
        ),
      ],
    );
  }
}
