import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../home/presentation/widgets/home_header.dart';
import '../data/sample_junior_learning_map.dart';
import '../domain/junior_learning_map.dart';
import 'junior_home_strings.dart';
import 'widgets/junior_home_palette.dart';
import 'widgets/junior_learning_map_view.dart';

/// Home for a student in kids mode — the Figma "Junior Home" frame.
///
/// Three fixed bands: the white header, the learning map, the tab bar. Only
/// the middle one scrolls, because the map is 1214 tall in the design and no
/// phone shows that at once.
///
/// **Reuse.** The header is the adult dashboard's [HomeHeader] unchanged —
/// the Junior frame draws the same lockup, the same circular bell and the
/// same gutter, so a second copy would only be able to drift from it. The tab
/// bar is the app-wide [AppBottomNav]; the middle tab's label differs from the
/// adult app's — see [JuniorHomeStrings.navProgress], which also records why
/// its spelling differs from the one Issue #98's text gives.
///
/// **Not in this issue.** No repository, no route registration, and no
/// adult/junior selection: the map comes from [sampleJuniorLearningMap] and
/// the screen is constructed directly. The two inactive tabs are inert for
/// the reason [AppBottomNavItem.onTap] documents — a Junior progress screen
/// does not exist yet, and wiring these would be the routing this issue
/// excludes.
class JuniorHomeScreen extends StatelessWidget {
  const JuniorHomeScreen({super.key, this.map});

  /// Defaults to the sample map. Injected in tests.
  final JuniorLearningMap? map;

  @override
  Widget build(BuildContext context) {
    final map = this.map ?? sampleJuniorLearningMap();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
      ),
      child: Scaffold(
        // White, so the status-bar inset above the header reads as part of
        // the header rather than as the top of the blue map.
        backgroundColor: AppColors.surface,
        bottomNavigationBar: AppBottomNav(
          currentIndex: 0,
          items: const [
            AppBottomNavItem(
              // The frame draws the active Home tab as a *solid* house.
              // `AppIcons.house` is Phosphor's outline weight, and the
              // bundled `Phosphor.ttf` carries one weight only — there is no
              // fill variant in it to point at — so this is the Material
              // fallback `DEVELOPMENT_RULES.md` §6 asks for in place of a
              // guessed codepoint. It differs from the adult bar, which keeps
              // the outline house, because this frame is explicit about it.
              icon: Icons.home,
              label: JuniorHomeStrings.navHome,
              // Already here.
            ),
            AppBottomNavItem(
              // A Material glyph, not a Phosphor one: the frame draws a
              // calendar with a tick, and the bundled `Phosphor.ttf` exposes
              // its 1543 glyphs under `uniXXXX` names only, so no calendar
              // codepoint can be *confirmed* from it. `DEVELOPMENT_RULES.md`
              // §6 asks for a Material fallback with a comment rather than a
              // guessed codepoint, which is what this is.
              icon: Icons.event_available_outlined,
              label: JuniorHomeStrings.navProgress,
            ),
            AppBottomNavItem(
              icon: AppIcons.user,
              label: JuniorHomeStrings.navProfile,
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const HomeHeader(),
              Container(height: AppDimens.borderWidth, color: AppColors.border),
              Expanded(
                child: ColoredBox(
                  color: JuniorPalette.mapField,
                  child: Semantics(
                    label: JuniorHomeStrings.learningMap,
                    container: true,
                    child: JuniorLearningMapView(map: map),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
