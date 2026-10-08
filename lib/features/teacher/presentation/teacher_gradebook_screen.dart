import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/app_button.dart';
import '../../home/presentation/widgets/home_palette.dart';
import '../data/http_teacher_gradebook_repository.dart';
import '../domain/teacher_class.dart';
import '../domain/teacher_gradebook_repository.dart';
import 'gradebook_class_screen.dart';
import 'teacher_gradebook_strings.dart';
import 'teacher_home_controller.dart';
import 'teacher_home_strings.dart';
import 'widgets/teacher_bottom_nav.dart';
import 'widgets/teacher_class_card.dart';
import 'widgets/teacher_tabs.dart';

/// The teacher's Дүнгийн хуудас tab (Issue #233), built against the
/// `dungiin-huudas` reference: the title on a white band, then one card per
/// class the teacher teaches; a tap opens that class's student list.
///
/// The classes are Teacher Home's own read, loaded by the same
/// [TeacherHomeController] — here every class, not only today's. Each card
/// is Teacher Home's [TeacherClassCard] without its room and time, as the
/// reference draws it. The reference's "12/24 Даалгавар илгээсэн" capsule is
/// not drawn: no verified response says how many students submitted
/// (BACKEND GAP); the class's student count sits in its place.
///
/// Spinner, empty line, error + retry and pull-to-refresh follow Teacher
/// Home; the reference draws none of them.
class TeacherGradebookScreen extends StatefulWidget {
  const TeacherGradebookScreen({
    super.key,
    this.repository,
    this.showBottomNav = true,
  });

  /// Defaults to the real API. Injected in tests.
  final TeacherGradebookRepository? repository;

  /// Whether this screen draws its tab bar itself. False inside
  /// `TeacherShell`, which owns the one persistent bar (Issue #241).
  final bool showBottomNav;

  @override
  State<TeacherGradebookScreen> createState() => _TeacherGradebookScreenState();
}

class _TeacherGradebookScreenState extends State<TeacherGradebookScreen> {
  late final TeacherGradebookRepository _repository;
  late final TeacherHomeController _controller;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? HttpTeacherGradebookRepository();
    _controller = TeacherHomeController(repository: _repository)..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(TeacherClass teacherClass) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GradebookClassScreen(
          teacherClass: teacherClass,
          repository: _repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.page(context, navigationBar: context.palette.surface),
      child: Scaffold(
        backgroundColor: AppColors.surfaceSubtle,
        bottomNavigationBar: widget.showBottomNav
            ? const TeacherBottomNav(current: TeacherTab.grades)
            : null,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: AppColors.surface,
              child: SafeArea(
                bottom: false,
                child: Container(
                  height: 63,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.screenPadding,
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    TeacherGradebookStrings.title,
                    style: _titleStyle,
                  ),
                ),
              ),
            ),
            Container(
              height: AppDimens.borderWidth,
              color: HomePalette.headerRule,
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final classes = _controller.classes;

    if (_controller.loading && classes == null) {
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

    if (_controller.errorMessage case final message?) {
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
                onPressed: _controller.load,
              ),
            ],
          ),
        ),
      );
    }

    final list = classes ?? const <TeacherClass>[];
    return RefreshIndicator(
      onRefresh: _controller.load,
      color: AppColors.blue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          16,
          AppDimens.screenPadding,
          24,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                TeacherGradebookStrings.empty,
                style: AppTypography.cardSupporting,
                textAlign: TextAlign.center,
              ),
            ),
          for (final (index, teacherClass) in list.indexed)
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 16),
              child: Semantics(
                button: true,
                child: GestureDetector(
                  onTap: () => _open(teacherClass),
                  behavior: HitTestBehavior.opaque,
                  child: TeacherClassCard(
                    teacherClass: teacherClass,
                    showDetails: false,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The tab's title, sampled off the reference: 24 bold on the white band.
final TextStyle _titleStyle = AppTypography.heading.copyWith(
  fontSize: 24,
  height: 32 / 24,
  color: TeacherHomeColors.ink,
);
