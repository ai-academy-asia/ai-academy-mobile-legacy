import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../data/sample_course_learning_repository.dart';
import '../domain/course_learning_path.dart';
import '../domain/course_learning_repository.dart';
import '../domain/course_module.dart';
import 'course_learning_controller.dart';
import 'course_learning_strings.dart';
import 'lesson_list_screen.dart';
import 'widgets/course_learning_back_button.dart';
import 'widgets/course_module_card.dart';

/// The Course Learning overview — reached from `CourseDetailScreen`'s
/// "Continue learning" entry point.
///
/// Built strictly against the Figma screenshots provided for this screen —
/// see the deviations called out on individual widgets below for the few
/// spots where no existing app-wide pattern covered what the reference draws
/// at all (the card shadows, the hero's tint).
///
/// An unlocked module card opens `LessonListScreen`. Locked modules stay
/// genuinely inert (`onTap: null`). Both "Continue learning" buttons open the
/// same screen, for whichever module [_continueLearningTarget] picks — see
/// that function's own doc comment for what the rule is and, importantly,
/// what it is not.
class CourseModuleListScreen extends StatefulWidget {
  const CourseModuleListScreen({
    required this.courseSlug,
    super.key,
    this.repository,
  });

  /// `Course.slug` — which course's learning path to load.
  final String courseSlug;

  /// Defaults to the sample data. Injected in tests.
  final CourseLearningRepository? repository;

  @override
  State<CourseModuleListScreen> createState() => _CourseModuleListScreenState();
}

class _CourseModuleListScreenState extends State<CourseModuleListScreen> {
  late final CourseLearningRepository _repository =
      widget.repository ?? SampleCourseLearningRepository();
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
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.background,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        // The reference's tint sits in the page background itself, not on a
        // shape behind the hero's content: no radius, no edges, no card. A
        // second pass here wrapped `_Hero` in its own rounded, tinted box,
        // which read as a floating card rather than a page tint — this
        // instead paints a plain, edge-to-edge, un-rounded gradient behind
        // the whole `SafeArea`, faded out well before the progress row so it
        // reads as "upper page background", not "the whole screen is blue".
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x0D296CFF), AppColors.background],
              stops: [0.0, 0.22],
            ),
          ),
          child: SafeArea(
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
                      const CourseLearningBackButton(),
                      Expanded(child: _buildBody()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final path = _controller.path;
    if (_controller.loading && path == null) {
      return const _LoadingView();
    }
    return _CourseLearningBody(path: path!, repository: _repository);
  }
}

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

/// The module "Continue learning" should open.
///
/// **A frontend placeholder, not a confirmed backend rule.**
/// `course_learning_api_requirements_v1.md` explicitly defers "which rule
/// selects the module/lesson" to backend confirmation — this exists only so
/// the button has *somewhere* real to go against today's sample data, not as
/// a claim about what the eventual rule will be.
///
/// The rule: the first module that is neither completed nor locked — the
/// "in progress, pick up here" case a real rule would presumably also pick.
/// Today's sample data has no module in that state (see `CourseModule.
/// locked`'s own doc comment on why), so this falls back to the most
/// recently completed module instead, which is still a defensible "continue
/// where you left off" reading. Null only if every module is locked, which
/// the sample data never produces.
CourseModule? _continueLearningTarget(List<CourseModule> modules) {
  for (final module in modules) {
    if (!module.completed && !module.locked) return module;
  }
  for (final module in modules.reversed) {
    if (module.completed) return module;
  }
  return null;
}

void _openLessonList(
  BuildContext context,
  CourseModule module,
  CourseLearningRepository repository,
) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => LessonListScreen(
        moduleId: module.id,
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
        8,
        AppDimens.screenPadding,
        AppDimens.screenPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(path: path),
          const SizedBox(height: 20),
          _ProgressCtaRow(
            percentComplete: path.percentComplete,
            modules: path.modules,
            repository: repository,
          ),
          const SizedBox(height: 24),
          _ModuleList(modules: path.modules, repository: repository),
          const SizedBox(height: 24),
          _CertificationSection(
            percentComplete: path.percentComplete,
            modules: path.modules,
            repository: repository,
          ),
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
              Text(path.courseTitle, style: AppTypography.heading),
              const SizedBox(height: AppDimens.titleToSupporting),
              Text(path.description, style: AppTypography.statLabel),
            ],
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 94,
          height: 82,
          child: SvgPicture.asset(path.illustrationAsset, fit: BoxFit.contain),
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
    required this.percentComplete,
    required this.modules,
    required this.repository,
  });

  final int percentComplete;
  final List<CourseModule> modules;
  final CourseLearningRepository repository;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: percentComplete / 100,
                    minHeight: AppDimens.progressBarHeight,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.blue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                CourseLearningStrings.percentComplete(percentComplete),
                style: AppTypography.catalogSectionValue,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _ContinueLearningButton(modules: modules, repository: repository),
      ],
    );
  }
}

class _ContinueLearningButton extends StatelessWidget {
  const _ContinueLearningButton({
    required this.modules,
    required this.repository,
  });

  final List<CourseModule> modules;
  final CourseLearningRepository repository;

  @override
  Widget build(BuildContext context) {
    final target = _continueLearningTarget(modules);

    return Semantics(
      button: true,
      label: CourseLearningStrings.continueLearning,
      child: DecoratedBox(
        // The Figma button reads visibly "lifted" — a soft, blue-toned shadow
        // under it, not the flat fill an unshadowed `Material` gives. Painted
        // on a wrapping `DecoratedBox` rather than raising `Material`'s own
        // `elevation`, whose default shadow is a neutral grey, not this
        // blue-tinted one, and which would also change the ink surface's
        // shape handling. The box adds no size of its own, so the button's
        // 164.5 x 40 footprint is unchanged; the shadow paints outside it.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.blue.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: AppColors.blue,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: target == null
                ? null
                : () => _openLessonList(context, target, repository),
            borderRadius: BorderRadius.circular(20),
            splashColor: Colors.white24,
            highlightColor: Colors.white10,
            child: const SizedBox(
              width: 164.5,
              height: 40,
              child: Center(
                child: Text(
                  CourseLearningStrings.continueLearning,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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

class _ModuleConnector extends StatelessWidget {
  const _ModuleConnector();

  @override
  Widget build(BuildContext context) {
    // Centred under the 56pt icon column, which sits `AppDimens.cardPadding`
    // in from the card's own edge.
    return Padding(
      padding: const EdgeInsets.only(left: AppDimens.cardPadding + 56 / 2 - 1),
      child: Container(width: 2, height: 16, color: AppColors.border),
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
  const _CertificationSection({
    required this.percentComplete,
    required this.modules,
    required this.repository,
  });

  final int percentComplete;
  final List<CourseModule> modules;
  final CourseLearningRepository repository;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
        border: Border.all(
          color: AppColors.border,
          width: AppDimens.borderWidth,
        ),
        // Its own tuning, not `CourseModuleCard`'s shadow reused verbatim:
        // a larger, quieter card reads right with a wider, fainter spread
        // rather than the module rows' tighter one.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
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
                      style: AppTypography.catalogSectionLabel,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CourseLearningStrings.certificationTitle,
                      style: AppTypography.catalogTitle,
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
          const _CertificatePreview(),
          const SizedBox(height: 20),
          _ProgressCtaRow(
            percentComplete: percentComplete,
            modules: modules,
            repository: repository,
          ),
        ],
      ),
    );
  }
}

/// The sample certificate image, framed by the exported gradient background —
/// two flat images layered, not redrawn with Flutter text/shapes.
///
/// Both source PNGs are lower resolution than where they end up drawn: at
/// this card's measured size on a 3x-density phone, `certificate.png` (305 x
/// 201 native) and `certificate_backround.png` (328 x 225 native) are each
/// upscaled roughly 3x by the renderer, which is what reads as blur/softness
/// on device — a genuine shortfall in the exported assets, not something a
/// widget property can fix. `FilterQuality.high` (`Image`'s own default is
/// `medium`) is the one improvement available without new art: Skia's best
/// resampling for that upscale, in place of its default. It measurably
/// softens the blur but cannot restore detail the source files never had —
/// the real fix is re-exporting both PNGs at a higher resolution (or as
/// proper `1.0x`/`2.0x`/`3.0x` variants).
class _CertificatePreview extends StatelessWidget {
  const _CertificatePreview();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 329 / 225,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/certificate_backround.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/certificate.png',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
