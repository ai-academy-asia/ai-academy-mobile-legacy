import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/tab_title_bar.dart';
import '../data/http_teacher_gradebook_repository.dart';
import '../domain/teacher_class.dart';
import '../domain/teacher_gradebook_repository.dart';
import 'gradebook_class_screen.dart';
import 'teacher_gradebook_strings.dart';
import 'teacher_home_controller.dart';
import 'teacher_home_strings.dart';
import 'widgets/program_widgets.dart';
import 'widgets/teacher_bottom_nav.dart';
import 'widgets/teacher_tabs.dart';

/// The teacher's Хөтөлбөрүүд tab — formerly Дүнгийн хуудас (Issues #233,
/// #390), built against `Sign in - 33`: the title on a white band, then one
/// [TeacherProgramCard] per class the teacher teaches. "Дэлгэрэнгүй" opens
/// the class's actions (`Contract(2)`): "Сурагчдын мэдээлэл" opens its
/// students, "Зар тараах" the announcement composer — which sends nothing,
/// as no endpoint lets a teacher announce (BACKEND GAP).
///
/// The classes are Teacher Home's own read, loaded by the same
/// [TeacherHomeController] — here every class, not only today's.
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

  Future<void> _details(TeacherClass teacherClass) async {
    final action = await showCohortActionSheet(context);
    if (!mounted || action == null) return;
    switch (action) {
      case CohortAction.students:
        _open(teacherClass);
      case CohortAction.announce:
        await showAnnouncementSheet(context);
    }
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
        backgroundColor: context.palette.surfaceSubtle,
        bottomNavigationBar: widget.showBottomNav
            ? const TeacherBottomNav(current: TeacherTab.grades)
            : null,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The shared tab header (Issue #368), in the Teacher tabs' title
            // ink.
            TabTitleBar(
              title: TeacherGradebookStrings.title,
              titleColor: context.palette.teacherTitle,
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                // Capped at the content width, as every page is.
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
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final classes = _controller.classes;

    if (_controller.loading && classes == null) {
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
                style: AppTypography.supporting.copyWith(
                  color: context.palette.textSecondary,
                ),
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
      color: context.palette.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          AppDimens.tabContentTop,
          AppDimens.screenPadding,
          AppDimens.pageBottom,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                TeacherGradebookStrings.empty,
                style: AppTypography.supporting.copyWith(
                  color: context.palette.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          for (final (index, teacherClass) in list.indexed)
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : AppDimens.cardGap),
              child: TeacherProgramCard(
                teacherClass: teacherClass,
                onDetails: () => _details(teacherClass),
              ),
            ),
        ],
      ),
    );
  }
}
