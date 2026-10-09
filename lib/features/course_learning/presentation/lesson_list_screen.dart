import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/app_button.dart';
import '../data/course_module_visuals.dart';
import '../data/http_course_learning_repository.dart';
import '../domain/course_learning_repository.dart';
import '../domain/lesson.dart';
import 'course_exercise_detail_screen.dart';
import 'course_learning_strings.dart';
import 'lesson_list_controller.dart';
import 'widgets/course_learning_back_button.dart';
import 'widgets/lesson_list_item.dart';

/// The Lesson List — one module's lessons, from
/// `GET /me/modules/{module_id}/lessons`.
///
/// Opened by an unlocked module card on `CourseModuleListScreen` and by a
/// completed Junior Home node. A module card knows only its module and the
/// contract names no lesson for one, so this screen is where the student
/// picks the lesson instead of the client inventing a rule for it.
/// "Continue learning" still skips it, opening the server's
/// `continue.lesson_id` directly.
///
/// Drawn to the Figma level-detail reference (Issue #215): a hero in the
/// module's own accent with its own artwork — exactly what that module's
/// Course Detail card draws, picked by [moduleOrder] through
/// [moduleVisualsFor] — then the module caption and title, then the lesson
/// cards ([LessonListItem]) joined by a centred rule. The reference's
/// progress row and "Continue learning" are left off on purpose: Course
/// Detail already shows both (a product decision in the request), and
/// §2.2's `module` carries no description, so none is drawn under the title.
/// The loading, empty and error states sit under the same header.
///
/// An unlocked lesson opens `CourseExerciseDetailScreen` for that lesson's
/// own `Lesson.id`.
class LessonListScreen extends StatefulWidget {
  const LessonListScreen({
    required this.moduleId,
    required this.moduleOrder,
    required this.moduleTitle,
    super.key,
    this.repository,
  });

  /// `CourseModule.id` — which module's lessons to load.
  final int moduleId;

  /// `CourseModule.order` — §2.1's `module.order`, the same value Course
  /// Detail picks this module's artwork and accent with. Drives the hero
  /// and the "Modules N" caption.
  final int moduleOrder;

  /// `CourseModule.title` — shown as this screen's own heading. Passed in
  /// rather than re-fetched: `CourseModuleListScreen` already has it, and
  /// there is no separate "module detail" endpoint to ask for it again.
  final String moduleTitle;

  /// Defaults to `HttpCourseLearningRepository` —
  /// `GET /me/modules/{module_id}/lessons` against the signed-in student's
  /// token. Injected in tests.
  final CourseLearningRepository? repository;

  @override
  State<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
  late final CourseLearningRepository _repository =
      widget.repository ?? HttpCourseLearningRepository();
  late final LessonListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LessonListController(
      repository: _repository,
      moduleId: widget.moduleId,
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
      value: AppSystemUi.page(
        context,
        navigationBar: context.palette.pageBackground,
      ),
      // No `SafeArea`: the hero runs up under the status bar, as the
      // reference draws it, and places its own back control at the inset.
      child: Scaffold(
        backgroundColor: context.palette.pageBackground,
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimens.maxContentWidth,
              ),
              child: _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final header = _ModuleHeader(
      moduleOrder: widget.moduleOrder,
      moduleTitle: widget.moduleTitle,
    );
    if (_controller.errorMessage case final message?) {
      return _HeaderOver(
        header: header,
        child: _ErrorView(message: message, onRetry: () => _controller.load()),
      );
    }
    if (_controller.loading && _controller.lessons.isEmpty) {
      return _HeaderOver(header: header, child: const _LoadingView());
    }
    if (_controller.isEmpty) {
      return _HeaderOver(header: header, child: const _EmptyView());
    }
    return _LessonListBody(
      header: header,
      lessons: _controller.lessons,
      repository: _repository,
    );
  }
}

/// The hero tile's height below the safe-area inset, and its artwork's box.
///
/// Measured off the reference at 1:1 with the project's 44pt inset: the hero
/// ends at 244, so 200 below the inset, and the artwork's ink is 102 square,
/// centred in that 200. Every `module_*.svg` carries its own margin inside
/// its 361 viewBox (see `CourseModuleCard`), so the box is larger than the
/// ink it draws.
const double _heroHeight = 200;
const double _artworkBox = 144;

/// `CourseModuleCard`'s own tile tint, so the hero and that module's card on
/// Course Detail read as the same colour. The reference's hero for module 2
/// is #FAEED2; this gives #FFF1D1, a few steps lighter, but it follows every
/// module's accent rather than one sampled value.
const double _heroTintOpacity = 0.24;

/// The reference's space from the header block to the first card.
const double _headerToCards = 28;

/// The rule between cards (`AppPalette.divider`): Course Detail's, 2 wide,
/// filling the 16 gap below the card's own 4pt band. Kept as this file's own
/// copy rather than extracted from Course Detail, whose constants are
/// private to that screen.
const double _cardGap = 16;
const double _connectorWidth = 2;
const double _connectorHeight = 12;

/// The hero and the caption/title block, drawn the same in every state.
class _ModuleHeader extends StatelessWidget {
  const _ModuleHeader({required this.moduleOrder, required this.moduleTitle});

  final int moduleOrder;
  final String moduleTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModuleHero(moduleOrder: moduleOrder),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.screenPadding,
            AppDimens.screenPadding,
            AppDimens.screenPadding,
            0,
          ),
          // Exercise Detail's caption and title styles, which the
          // reference's "Level 2" / title block measures to; the gap between
          // them is this reference's own 2, not Exercise Detail's 4.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${CourseLearningStrings.moduleCaption} $moduleOrder',
                style: AppTypography.catalogSectionLabel.copyWith(
                  fontSize: 12,
                  height: 16 / 12,
                  color: context.palette.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                moduleTitle,
                style: AppTypography.heading.copyWith(
                  fontSize: 18,
                  height: 26 / 18,
                  color: context.palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The module's accent and artwork, full width and running up under the
/// status bar, with the back control at the safe-area inset.
class _ModuleHero extends StatelessWidget {
  const _ModuleHero({required this.moduleOrder});

  final int moduleOrder;

  @override
  Widget build(BuildContext context) {
    final visuals = moduleVisualsFor(moduleOrder);
    final topInset = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: topInset + _heroHeight,
      child: ColoredBox(
        // Opaque, over white as `CourseModuleCard` lays its tile over the
        // white card — not over the grey page.
        color: Color.alphaBlend(
          visuals.accentColor.withValues(alpha: _heroTintOpacity),
          context.palette.surface,
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: topInset,
              bottom: 0,
              child: Center(
                child: SvgPicture.asset(
                  visuals.iconAsset,
                  width: _artworkBox,
                  height: _artworkBox,
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: topInset,
              // The reference draws the arrow here, as Exercise Detail and
              // the attendance screens do.
              child: const CourseLearningBackButton(icon: AppIcons.arrowLeft),
            ),
          ],
        ),
      ),
    );
  }
}

/// [header] with a state's own content filling the space under it.
class _HeaderOver extends StatelessWidget {
  const _HeaderOver({required this.header, required this.child});

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(child: child),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: context.palette.primary,
        ),
      ),
    );
  }
}

/// Shown when the lessons could not be loaded.
///
/// No design exists for this screen at all, so this is
/// `CourseModuleListScreen._ErrorView` reproduced: the same centred message
/// in `cardSupporting`, the same 16 of air, the same outlined `AppButton`
/// retry. Kept as its own copy rather than extracted, the existing habit —
/// `CourseCatalogScreen` and `CohortListScreen` keep theirs too.
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
              style: AppTypography.cardSupporting.copyWith(
                color: context.palette.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: CourseLearningStrings.retry,
              variant: AppButtonVariant.outlined,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonListBody extends StatelessWidget {
  const _LessonListBody({
    required this.header,
    required this.lessons,
    required this.repository,
  });

  final Widget header;
  final List<Lesson> lessons;
  final CourseLearningRepository repository;

  @override
  Widget build(BuildContext context) {
    // One scroll for the whole page, header included, as the reference is
    // one tall frame.
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: AppDimens.screenPadding + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.screenPadding,
              _headerToCards,
              AppDimens.screenPadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < lessons.length; i++) ...[
                  LessonListItem(
                    lesson: lessons[i],
                    onTap: lessons[i].locked
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CourseExerciseDetailScreen(
                                lessonId: lessons[i].id,
                                repository: repository,
                              ),
                            ),
                          ),
                  ),
                  if (i != lessons.length - 1) const _LessonConnector(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The rule between two lesson cards, down the centre of the page as the
/// reference draws it — Course Detail's `_ModuleConnector`, measured the
/// same: bottom-aligned in the gap, so it meets the band above and the next
/// card below.
class _LessonConnector extends StatelessWidget {
  const _LessonConnector();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _cardGap,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: _connectorWidth,
          height: _connectorHeight,
          child: ColoredBox(color: context.palette.divider),
        ),
      ),
    );
  }
}

/// No design exists for this screen at all, so this is
/// `CohortListScreen._EmptyView` reproduced: a centred message in
/// `cardSupporting` with the `screenPadding` gutter — kept as its own copy,
/// the existing habit (see [_ErrorView]).
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.screenPadding,
        ),
        child: Text(
          CourseLearningStrings.lessonsEmpty,
          style: AppTypography.cardSupporting.copyWith(
            color: context.palette.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
