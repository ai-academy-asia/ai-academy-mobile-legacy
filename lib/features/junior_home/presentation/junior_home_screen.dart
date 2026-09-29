import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_button.dart';
import '../../home/presentation/widgets/home_header.dart';
import '../data/api_junior_home_repository.dart';
import '../domain/junior_home_repository.dart';
import 'junior_home_controller.dart';
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
/// **Data.** The map is loaded from `GET /me/courses/{course_slug}/learning`
/// through [ApiJuniorHomeRepository], which resolves the student's own course
/// slug from the existing enrolled-cohort architecture. Loading, empty and
/// failure states follow `HomeScreen`'s; the map's own visuals are unchanged.
///
/// **Not in this issue.** No route registration and no adult/junior
/// selection. The two inactive tabs are inert for the reason
/// [AppBottomNavItem.onTap] documents — a Junior progress screen does not
/// exist yet.
class JuniorHomeScreen extends StatefulWidget {
  const JuniorHomeScreen({super.key, this.repository});

  /// Defaults to the real API. Injected in tests.
  final JuniorHomeRepository? repository;

  @override
  State<JuniorHomeScreen> createState() => _JuniorHomeScreenState();
}

class _JuniorHomeScreenState extends State<JuniorHomeScreen> {
  late final JuniorHomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = JuniorHomeController(
      repository: widget.repository ?? ApiJuniorHomeRepository(),
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => _buildBody(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Loading, failure, empty, then the map — the order `HomeScreen` checks
  /// them in. The success branch is the unchanged
  /// [JuniorLearningMapView]: no visual on the map itself moved for this
  /// integration.
  Widget _buildBody() {
    if (_controller.errorMessage case final message?) {
      return _MapMessage(message: message, onRetry: () => _controller.load());
    }
    if (_controller.isEmpty) {
      return const _MapMessage(message: JuniorHomeStrings.empty);
    }
    final map = _controller.map;
    if (map == null) {
      return const _MapLoading();
    }
    return Semantics(
      label: JuniorHomeStrings.learningMap,
      container: true,
      child: JuniorLearningMapView(map: map),
    );
  }
}

/// The spinner, over the map's own sky so the band does not flash white
/// before the scenery arrives.
class _MapLoading extends StatelessWidget {
  const _MapLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
      ),
    );
  }
}

/// A line of copy over the map, with a retry when there is something to
/// retry.
///
/// The Figma pack draws no loading, empty or error state for Junior Home, so
/// nothing here is measured off a reference the way the map is. It is
/// `CohortListScreen._ErrorView`'s shape — centred message, 16 of air, an
/// outlined `AppButton` — on the blue field instead of the page grey, which
/// is the only change the darker background calls for.
class _MapMessage extends StatelessWidget {
  const _MapMessage({required this.message, this.onRetry});

  final String message;

  /// Null for the empty state: there is nothing to retry when the student is
  /// simply enrolled in nothing.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.screenPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: AppTypography.cardSupporting.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              AppButton(
                label: JuniorHomeStrings.retry,
                variant: AppButtonVariant.outlined,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
