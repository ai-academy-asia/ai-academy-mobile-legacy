import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/app_button.dart';
import '../data/http_course_learning_repository.dart';
import '../domain/course_learning_path.dart';
import '../domain/course_learning_repository.dart';
import '../domain/course_module.dart';
import 'course_exercise_detail_screen.dart';
import 'course_learning_controller.dart';
import 'course_learning_strings.dart';
import 'lesson_list_screen.dart';
import 'widgets/certificate_preview.dart';
import 'widgets/course_learning_back_button.dart';
import 'widgets/course_progress_cta_row.dart';
import 'widgets/course_module_card.dart';

/// Everything below is measured off the Figma reference frame at 1:1 — a
/// 393 x 1391 page with a 44pt status-bar inset — rather than taken from the
/// shared tokens, which are sampled from the Login/Home/Catalog frames and do
/// not match this one. `test/features/course_learning/
/// course_module_list_screenshot_test.dart` captures the screen at that exact
/// frame so these can be re-checked against the PNG.

/// The wash behind the hero (`AppPalette.learningHeroTint`) clears to the
/// page colour (`surface`) 75 down from the top of the safe area.
const double _heroTintHeight = 75;

/// The illustration's box. Larger than the 86 x 75 the frame measures because
/// `how_ai_works.svg` carries roughly 9% of empty margin inside its own
/// viewBox, and `BoxFit.contain` fits the viewBox, not the artwork: at a box
/// of exactly 86 x 75 the drawing came out 78 x 69. These are the sizes that
/// put the *drawn* illustration on the reference's bounds.
const double _illustrationWidth = 95;
const double _illustrationHeight = 82;

/// The reference starts the illustration above the text column's first line.
/// Applied as a paint-time offset so it does not also make the hero row taller,
/// which would push the progress row down.
const double _illustrationRise = -6;

/// The "Continue learning" button's width in each placement of the shared
/// `CourseProgressCtaRow` — the hero (a 361-wide container) and the
/// certification card (329 wide) — which keeps it on the frame's x213 in
/// both.
const double _heroCtaWidth = 164;
const double _certificationCtaWidth = 148;

/// Module cards: an 86-tall box every 102, so 16 of layout gap between boxes —
/// 4 of which the card's own band fills, leaving the reference's 12 of white.
const double _moduleGap = 16;
const double _connectorHeight = 12;
const double _connectorWidth = 2;

/// The Course Learning overview — reached directly from a Home/Cohort course
/// card, or from `CourseDetailScreen`'s own "Continue learning" entry point.
///
/// Built strictly against the Figma screenshots provided for this screen —
/// see the deviations called out on individual widgets below for the few
/// spots where no existing app-wide pattern covered what the reference draws
/// at all (the card shadows, the hero's tint).
///
/// Both "Continue learning" buttons open `CourseExerciseDetailScreen` for the
/// lesson the server selected — `continue.lesson_id`, see
/// [_continueLessonId] — loaded from `GET /me/lessons/{lesson_id}`.
///
/// An unlocked module card opens `LessonListScreen` for that module — see
/// [_openLessonList] — and a lesson there opens `CourseExerciseDetailScreen`.
/// The Figma flow draws no Lesson List step, but Exercise Detail is keyed by
/// lesson, a module card knows only its module, and the contract names no
/// lesson for one; picking one on the client would be inventing a rule, so
/// the student picks it from the module's own lessons instead. Locked modules
/// stay genuinely inert (`onTap: null`).
class CourseModuleListScreen extends StatefulWidget {
  const CourseModuleListScreen({
    required this.courseSlug,
    super.key,
    this.repository,
  });

  /// `Course.slug` — which course's learning path to load.
  final String courseSlug;

  /// Defaults to `HttpCourseLearningRepository` —
  /// `GET /me/courses/{course_slug}/learning` against the signed-in student's
  /// token. Injected in tests.
  final CourseLearningRepository? repository;

  @override
  State<CourseModuleListScreen> createState() => _CourseModuleListScreenState();
}

class _CourseModuleListScreenState extends State<CourseModuleListScreen> {
  late final CourseLearningRepository _repository =
      widget.repository ?? HttpCourseLearningRepository();
  late final CourseLearningController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CourseLearningController(
      repository: _repository,
      courseSlug: widget.courseSlug,
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
        backgroundColor: context.palette.surface,
        // The reference's wash is a fixed 75pt band at the top of the safe
        // area, not a fraction of the page: as a gradient over the whole body
        // it stretched with the viewport and tinted a third of a tall screen.
        // A fixed-height band behind the content keeps it the same 75
        // everywhere, which is what the frame measures.
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _heroTintHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        context.palette.learningHeroTint,
                        context.palette.surface,
                      ],
                    ),
                  ),
                ),
              ),
              ListenableBuilder(
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
                        const CourseLearningBackButton(),
                        Expanded(child: _buildBody()),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.errorMessage case final message?) {
      return _ErrorView(message: message, onRetry: () => _controller.load());
    }
    final path = _controller.path;
    // Null with no error means the request is still in flight — or has not
    // started, on the first frame before `initState`'s `load()` resolves.
    // Read as "no data yet" rather than force-unwrapped: now that the
    // repository is a real HTTP call, `path!` would be a crash path.
    if (path == null) {
      return const _LoadingView();
    }
    return _CourseLearningBody(path: path, repository: _repository);
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

/// Shown when the learning path could not be loaded.
///
/// The Figma pack has **no error state for this screen**, so nothing here is
/// measured off a reference the way the rest of this file is. Rather than
/// design one, this is `CohortListScreen._ErrorView` reproduced: the same
/// centred message in `cardSupporting`, the same 16 of air, the same outlined
/// `AppButton` retry. Reused as a shape rather than extracted into a shared
/// widget, which is the existing habit — `CourseCatalogScreen` and
/// `CohortListScreen` already keep their own copies of it.
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

/// The module the server's continue target is in: the one
/// `CourseLearningPath.continueModuleId` names, and nothing else.
///
/// `course_learning_api_contract_v1.md` §2.1 makes the selection
/// **server-side** — `continue.module_id` "replaces
/// `_continueLearningTarget()`" — so this only looks the server's choice up
/// among the modules, locked or not. It never picks one itself: the
/// contract sends `continue: null` exactly when nothing is unlocked, and a
/// client rule would contradict that. Null then, or when the id names no
/// listed module, which leaves both buttons drawn but inert.
CourseModule? _continueLearningTarget(CourseLearningPath path) {
  final serverChoice = path.continueModuleId;
  if (serverChoice == null) return null;
  for (final module in path.modules) {
    if (module.id == serverChoice) return module;
  }
  return null;
}

/// The lesson "Continue learning" opens: `continue.lesson_id`, exactly as the
/// server sent it — but only while its `continue.module_id` names a listed
/// module ([_continueLearningTarget]), so the two halves of the server's
/// answer agree. Null otherwise, which leaves both buttons drawn but inert;
/// no lesson is ever chosen on the client.
int? _continueLessonId(CourseLearningPath path) {
  if (_continueLearningTarget(path) == null) return null;
  return path.continueLessonId;
}

void _openExerciseDetail(
  BuildContext context,
  int lessonId,
  CourseLearningRepository repository,
) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CourseExerciseDetailScreen(
        lessonId: lessonId,
        repository: repository,
      ),
    ),
  );
}

/// Where an unlocked module card leads: that module's lessons, loaded from
/// `GET /me/modules/{module_id}/lessons` with the module's own id.
///
/// Through this screen's repository, as [_openExerciseDetail] is — HTTP in
/// production, the injected one in tests. The title is passed along rather
/// than re-fetched: `LessonListScreen` draws it as its heading, and this
/// screen already holds it.
void _openLessonList(
  BuildContext context,
  CourseModule module,
  CourseLearningRepository repository,
) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => LessonListScreen(
        moduleId: module.id,
        moduleOrder: module.order,
        moduleTitle: module.title,
        repository: repository,
      ),
    ),
  );
}

class _CourseLearningBody extends StatelessWidget {
  const _CourseLearningBody({required this.path, required this.repository});

  final CourseLearningPath path;
  final CourseLearningRepository repository;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        18,
        AppDimens.screenPadding,
        AppDimens.screenPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(path: path),
          const SizedBox(height: 10),
          _ProgressCtaRow(
            path: path,
            repository: repository,
            buttonWidth: _heroCtaWidth,
          ),
          const SizedBox(height: 48),
          _ModuleList(modules: path.modules, repository: repository),
          const SizedBox(height: 32),
          _CertificationSection(path: path, repository: repository),
        ],
      ),
    );
  }
}

/// The title, description and illustration. Figma measurement: a 251.02-wide
/// text column beside a 93.97 x 81.79 illustration — 251 + 94 + a 16pt gutter
/// lands almost exactly on the 361pt content width, so the split below is a
/// fixed-width illustration beside an `Expanded` text column rather than a
/// flex ratio guessed at.
///
/// The soft light-blue tint the reference draws here comes from the page
/// background behind this whole screen (see `CourseModuleListScreen.build`),
/// not from a decoration on this widget — an earlier pass painted it as a
/// rounded, tinted box behind just this content, which read as a floating
/// card rather than a page tint. This widget draws only its content.
class _Hero extends StatelessWidget {
  const _Hero({required this.path});

  final CourseLearningPath path;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                path.courseTitle,
                style: AppTypography.heading.copyWith(
                  fontSize: 18,
                  height: 26 / 18,
                  color: context.palette.textTitle,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                path.description,
                style: AppTypography.statLabel.copyWith(
                  fontSize: 12,
                  height: 18 / 12,
                  color: context.palette.textSupporting,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Transform.translate(
          offset: const Offset(0, _illustrationRise),
          child: SizedBox(
            width: _illustrationWidth,
            height: _illustrationHeight,
            child: SvgPicture.asset(
              path.illustrationAsset,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
}

/// A short progress bar beside "30% complete", beside "Continue learning" —
/// `[ bar ]  30% complete  [ Continue learning ]`, the same row shown twice
/// in the reference (hero and certification footer), so it is one widget
/// rather than two copies of the same layout.
///
/// An earlier pass stacked the percent text *above* the bar in a column
/// beside the button — the Figma reference instead runs the bar and its
/// label side by side, on one line, which is what the progress section's own
/// ~20pt height (a single text line, not a two-line stack) already implied.
///
/// The bar itself is the exact `ClipRRect` + `LinearProgressIndicator`
/// treatment `ProgramCard`/`CohortCard` already use — genuinely reused, not
/// redrawn. The button is not `AppButton`: that widget is fixed at a 44pt
/// *full-width* block (see its own doc comment), while the reference measures
/// this one at 164.5 x 40, sitting beside the progress section rather than
/// filling the row. Reusing `AppButton` here would mean changing a shared
/// widget's contract for one screen, so this is a small local button instead,
/// built from the same fill colour, label style and pill-radius idiom.
///
/// The bar is `Expanded` rather than fixed at the measured 164.5 for the
/// progress section as a whole: the reference calls that figure
/// "approximately" 164.5 (unlike the button's exact 164.5 x 40), and the two
/// placements of this row sit inside differently-padded containers (the
/// hero's own padding vs. the certification card's, whose border adds to its
/// padding on top of that) — pinning every segment to a literal width
/// overflowed by a couple of pixels in the narrower one. Flexing the one
/// approximate segment keeps the button's exact size exact everywhere.
class _ProgressCtaRow extends StatelessWidget {
  const _ProgressCtaRow({
    required this.path,
    required this.repository,
    required this.buttonWidth,
  });

  /// The whole path, not just its percentage: the button beside the bar needs
  /// `continueModuleId` as well, and splitting the two into separate
  /// parameters meant every caller passing both halves of the same object.
  final CourseLearningPath path;
  final CourseLearningRepository repository;

  /// The reference draws this row twice at different widths and keeps the
  /// button's *left* edge on x213 both times, so the button is what changes
  /// size between them, not the gaps.
  final double buttonWidth;

  @override
  Widget build(BuildContext context) {
    final lessonId = _continueLessonId(path);
    return CourseProgressCtaRow(
      percent: path.percentComplete,
      buttonWidth: buttonWidth,
      onContinue: lessonId == null
          ? null
          : () => _openExerciseDetail(context, lessonId, repository),
    );
  }
}

/// The five module cards, each connected to the next by a short vertical
/// rule — the Figma reference draws a thin line running down the card list,
/// centred under the icon column.
class _ModuleList extends StatelessWidget {
  const _ModuleList({required this.modules, required this.repository});

  final List<CourseModule> modules;
  final CourseLearningRepository repository;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < modules.length; i++) ...[
          CourseModuleCard(
            module: modules[i],
            onTap: modules[i].locked
                ? null
                : () => _openLessonList(context, modules[i], repository),
          ),
          if (i != modules.length - 1) const _ModuleConnector(),
        ],
      ],
    );
  }
}

/// The rule between two module cards.
///
/// It runs down the *centre of the page* — the reference puts it on x196.5,
/// the content column's own midpoint, not under the icon tile where an earlier
/// pass had it. The gap it sits in is [_moduleGap] tall, and the card above
/// fills the first 4 of that with its own band, so the rule is bottom-aligned
/// and [_connectorHeight] long: it meets the band above and the next card
/// below, with no white break at either end.
class _ModuleConnector extends StatelessWidget {
  const _ModuleConnector();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _moduleGap,
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

/// The certification panel: label, title and badge, the certificate preview,
/// then the same progress/CTA row repeated at the foot of the screen.
///
/// The Figma outer section runs the full 393pt device width; inside the
/// app's shared `maxContentWidth`-capped, edge-padded scroll body every other
/// screen uses, that would need a differently-padded scroll region just for
/// this one block. The smallest adjustment that keeps the rest of the
/// screen's structure intact is drawing this panel at the same 361pt content
/// width as everything above it, with its own padding standing in for the
/// reference's edge-to-edge bleed.
class _CertificationSection extends StatelessWidget {
  const _CertificationSection({required this.path, required this.repository});

  final CourseLearningPath path;
  final CourseLearningRepository repository;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      decoration: BoxDecoration(
        color: context.palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
        border: Border.all(
          color: context.palette.outlineFaint,
          width: AppDimens.borderWidth,
        ),
        // No shadow: unlike the module cards, the reference draws nothing
        // below this panel's bottom edge — the row under it is plain page.
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CourseLearningStrings.certificationLabel,
                      style: AppTypography.catalogSectionLabel.copyWith(
                        fontSize: 12,
                        height: 16 / 12,
                        color: context.palette.textSupporting,
                      ),
                    ),
                    // The label's and heading's line boxes sit all but flush
                    // in the reference; the air between their ink is the
                    // boxes' own leading.
                    const SizedBox(height: 1),
                    Text(
                      CourseLearningStrings.certificationTitle,
                      style: AppTypography.catalogTitle.copyWith(
                        fontSize: 18,
                        height: 26 / 18,
                        color: context.palette.textTitle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SvgPicture.asset(
                'assets/images/course_learning/certificate_badge.svg',
                width: 59.82,
                height: 55.04,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const CertificatePreview(),
          const SizedBox(height: 17),
          _ProgressCtaRow(
            path: path,
            repository: repository,
            buttonWidth: _certificationCtaWidth,
          ),
        ],
      ),
    );
  }
}
