import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/app_button.dart';
import '../../home/presentation/widgets/home_header.dart';
import '../../home/presentation/widgets/home_palette.dart';
import '../data/http_teacher_home_repository.dart';
import '../domain/teacher_class.dart';
import '../domain/teacher_home_repository.dart';
import 'teacher_home_controller.dart';
import 'teacher_home_strings.dart';
import 'widgets/teacher_bottom_nav.dart';
import 'widgets/teacher_class_card.dart';

/// The teacher's Home — where a `user_type: "teacher"` account lands after
/// sign-in (Issue #229).
///
/// Built against the `teacher-homepage` reference: the student Home's brand
/// header and rule, "Өнөөдрийн хичээл", then one card per class that meets
/// today, earliest first. The classes are the teacher's own
/// `GET /teachers/{actor_id}/schedule`; "today" is the meeting rule the
/// student dashboards already apply to the same cohort fields.
///
/// Same shell and states as the student `HomeScreen`: a spinner on the
/// first load, the empty line when no class meets today, the failure's
/// message with a retry, and pull-to-refresh — which the header logo also
/// drives. The reference draws none of the non-success states, so they
/// follow the student Home's.
class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({
    super.key,
    this.repository,
    this.clock,
    this.showBottomNav = true,
  });

  /// Defaults to the real API. Injected in tests.
  final TeacherHomeRepository? repository;

  /// Decides which day is "today". Injected in tests.
  final DateTime Function()? clock;

  /// Whether this screen draws its tab bar itself. False inside
  /// `TeacherShell`, which owns the one persistent bar (Issue #241).
  final bool showBottomNav;

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  late final TeacherHomeController _controller;

  /// The list's pull-to-refresh, which the header logo also drives.
  final _refreshIndicator = GlobalKey<RefreshIndicatorState>();

  /// A tap on the header logo: the list's own pull-to-refresh when the list
  /// is on screen, otherwise the same [load] the retry uses.
  void _refreshFromLogo() {
    final indicator = _refreshIndicator.currentState;
    if (indicator != null) {
      indicator.show();
    } else {
      _controller.load();
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = TeacherHomeController(
      repository: widget.repository ?? HttpTeacherHomeRepository(),
      clock: widget.clock,
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
        backgroundColor: AppColors.surfaceSubtle,
        bottomNavigationBar: widget.showBottomNav
            ? const TeacherBottomNav()
            : null,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // White behind the status bar, as the reference draws it.
            ColoredBox(
              color: AppColors.surface,
              child: SizedBox(height: MediaQuery.paddingOf(context).top),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: SafeArea(
                  bottom: false,
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppDimens.maxContentWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            HomeHeader(onLogoTap: _refreshFromLogo),
                            Container(
                              height: AppDimens.borderWidth,
                              color: HomePalette.headerRule,
                            ),
                            Expanded(child: _buildBody()),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final classes = _controller.classes;

    if (_controller.loading && classes == null) return const _LoadingView();

    if (_controller.errorMessage case final message?) {
      return _ErrorView(message: message, onRetry: _controller.load);
    }

    return _ClassesView(
      classes: _controller.todaysClasses,
      onRefresh: _controller.load,
      refreshIndicatorKey: _refreshIndicator,
    );
  }
}

/// The title and today's cards — or the empty line under the title, still
/// pull-to-refresh, when no class meets today.
class _ClassesView extends StatelessWidget {
  const _ClassesView({
    required this.classes,
    required this.onRefresh,
    required this.refreshIndicatorKey,
  });

  final List<TeacherClass> classes;
  final Future<void> Function() onRefresh;
  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      Text(TeacherHomeStrings.title, style: _titleStyle),
      if (classes.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Text(
            TeacherHomeStrings.empty,
            style: AppTypography.cardSupporting,
            textAlign: TextAlign.center,
          ),
        )
      else
        for (final (index, teacherClass) in classes.indexed)
          Padding(
            padding: EdgeInsets.only(
              top: index == 0 ? _titleToFirstCard : _cardGap,
            ),
            child: TeacherClassCard(teacherClass: teacherClass),
          ),
    ];

    return RefreshIndicator(
      key: refreshIndicatorKey,
      onRefresh: onRefresh,
      color: AppColors.blue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          _titleTop,
          AppDimens.screenPadding,
          24,
        ),
        // Always scrollable, so pull-to-refresh works on a short day too.
        physics: const AlwaysScrollableScrollPhysics(),
        children: items,
      ),
    );
  }
}

/// From the header rule to the title's line box.
const double _titleTop = 14;

/// From the title's 34pt line box to the first card: the reference's card
/// top at 165, 58 below the header rule.
const double _titleToFirstCard = 9;

/// Between cards: 16 in the reference.
const double _cardGap = 16;

final TextStyle _titleStyle = AppTypography.heading.copyWith(
  color: TeacherHomeColors.ink,
);

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.blue,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
              style: AppTypography.cardSupporting,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: TeacherHomeStrings.retry,
              variant: AppButtonVariant.outlined,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
