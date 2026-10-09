import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/app_button.dart';
import '../../attendance/presentation/attendance_scanner_screen.dart';
import '../../auth/presentation/student_tabs.dart';
import '../../course_learning/domain/course_learning_repository.dart';
import '../../course_learning/presentation/course_module_list_screen.dart';
import '../../course_learning/presentation/lesson_list_screen.dart';
import '../../home/presentation/widgets/home_header.dart';
import '../../notifications/presentation/notification_center.dart';
import '../data/api_junior_home_repository.dart';
import '../domain/junior_home_repository.dart';
import '../domain/junior_learning_map.dart';
import 'junior_home_controller.dart';
import 'junior_home_strings.dart';
import 'widgets/junior_bottom_nav.dart';
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
/// bar is the app-wide `AppBottomNav`; the middle tab's label differs from the
/// adult app's — see [JuniorHomeStrings.navProgress], which also records why
/// its spelling differs from the one Issue #98's text gives.
///
/// **Data.** The map is loaded from `GET /me/courses/{course_slug}/learning`
/// through [ApiJuniorHomeRepository], which resolves the student's own course
/// slug from the existing enrolled-cohort architecture. Loading, empty and
/// failure states follow `HomeScreen`'s; the map's own visuals are unchanged.
///
/// **Tabs.** [JuniorBottomNav], shared with the two other junior tab screens:
/// Сурлагын явц opens `JuniorProgressScreen` and Профайл `JuniorProfileScreen`
/// — the junior track's own screens, never the adult ones.
class JuniorHomeScreen extends StatefulWidget {
  const JuniorHomeScreen({
    super.key,
    this.repository,
    this.courseLearningRepository,
    this.clock,
    this.showBottomNav = true,
    this.notifications,
  });

  /// Defaults to the real API. Injected in tests.
  final JuniorHomeRepository? repository;

  /// The unread count the header's bell shows, refreshed with the screen's
  /// own data (Issue #291). Defaults to [NotificationCenter.instance];
  /// injected in tests.
  final NotificationCenter? notifications;

  /// What the course screens a node opens load through — the real API by
  /// default (those screens' own). Injected in tests.
  final CourseLearningRepository? courseLearningRepository;

  /// Now — what the check-in node's state is read against (Issue #202).
  /// Read when the map builds, as Adult Home reads its attendance action.
  /// Injected in tests.
  final DateTime Function()? clock;

  /// Whether this screen draws its tab bar itself. False inside
  /// `JuniorStudentShell`, which owns the one persistent bar (Issue #241).
  final bool showBottomNav;

  @override
  State<JuniorHomeScreen> createState() => _JuniorHomeScreenState();
}

class _JuniorHomeScreenState extends State<JuniorHomeScreen> {
  late final JuniorHomeController _controller;

  NotificationCenter get _notifications =>
      widget.notifications ?? NotificationCenter.instance;

  /// The map and the bell's unread count together (Issue #291): a refresh
  /// the student asks for should not leave the badge stale.
  Future<void> _refresh() async {
    await Future.wait([_controller.load(), _notifications.load()]);
  }

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
      value: AppSystemUi.page(context, navigationBar: context.palette.surface),
      child: Scaffold(
        // White, so the status-bar inset above the header reads as part of
        // the header rather than as the top of the blue map.
        backgroundColor: context.palette.surface,
        bottomNavigationBar: widget.showBottomNav
            ? const JuniorBottomNav(current: StudentTab.home)
            : null,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // The logo reloads the map through the screen's own load and
              // retry path (Issue #221). Junior Home has no refresh
              // indicator, so the map stays on screen until the new one
              // arrives. The bell's count refreshes with it (Issue #291).
              HomeHeader(
                onLogoTap: _refresh,
                notifications: widget.notifications,
              ),
              // A step darker than every other header rule (`divider`):
              // its own role, kept as shipped (Issue #272).
              Container(
                height: AppDimens.borderWidth,
                color: context.palette.juniorHeaderRule,
              ),
              Expanded(
                child: ColoredBox(
                  color: context.palette.juniorMapSky,
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
      child: JuniorLearningMapView(
        map: map,
        now: widget.clock?.call() ?? DateTime.now(),
        // Inert for content that is not a real course (the sample map).
        onNodeTap: map.courseSlug == null ? null : _openModule,
        onCheckIn: _openScanner,
        onCourseTap: switch (map.courseSlug) {
          final slug? => () => _openCourse(slug),
          null => null,
        },
      ),
    );
  }

  /// The attendance check-in scanner (Issue #202) — from the check-in node,
  /// only while a lesson is under way.
  void _openScanner() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AttendanceScannerScreen()),
    );
  }

  /// The existing Course Detail (Issues #174, #207): the Adult course screen
  /// on the same `GET /me/courses/{slug}/learning` data, with the same lesson
  /// tabs as Adult, Note included (Issue #219) — reached from the course
  /// card, while each completed node opens its own module.
  void _openCourse(String slug) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseModuleListScreen(
          courseSlug: slug,
          repository: widget.courseLearningRepository,
        ),
      ),
    );
  }

  /// The tapped node's own module (Issue #204): its lessons, from
  /// `GET /me/modules/{module_id}/lessons` — the screen an unlocked module
  /// card opens on the course screen (Issue #148), with the same lesson tabs
  /// as Adult (Issue #219). Each node opens the module it stands for, not the
  /// course as a whole.
  void _openModule(JuniorMapNode node) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LessonListScreen(
          moduleId: node.id,
          moduleOrder: node.order,
          moduleTitle: node.title,
          repository: widget.courseLearningRepository,
        ),
      ),
    );
  }
}

/// The spinner, over the map's own sky so the band does not flash white
/// before the scenery arrives.
class _MapLoading extends StatelessWidget {
  const _MapLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: context.palette.onJuniorMapSky,
        ),
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
                color: context.palette.textPrimary,
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
