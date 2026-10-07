import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../domain/teacher_class.dart';
import '../domain/teacher_gradebook_repository.dart';
import '../domain/teacher_submission.dart';
import 'gradebook_class_controller.dart';
import 'gradebook_student_screen.dart';
import 'teacher_gradebook_strings.dart';
import 'teacher_home_strings.dart';
import 'widgets/gradebook_widgets.dart';

/// A class's student list (Issue #233), built against the
/// `angiin-students-list` reference: the course title over the Бүгд /
/// Хүлээгдэж буй / Дүгнэгдсэн filters and one card per submitted
/// assignment — the student's initials, name and the assignment's title; a
/// tap opens the student.
///
/// The rows are real submissions ([GradebookClassController]); the filters
/// read their confirmed `status` ([matchesFilter]). Spinner, empty line,
/// error + retry and pull-to-refresh follow the Gradebook tab.
class GradebookClassScreen extends StatefulWidget {
  const GradebookClassScreen({
    required this.teacherClass,
    required this.repository,
    super.key,
  });

  final TeacherClass teacherClass;
  final TeacherGradebookRepository repository;

  @override
  State<GradebookClassScreen> createState() => _GradebookClassScreenState();
}

class _GradebookClassScreenState extends State<GradebookClassScreen> {
  late final GradebookClassController _controller;
  GradebookFilter _filter = GradebookFilter.all;

  @override
  void initState() {
    super.initState();
    _controller = GradebookClassController(
      repository: widget.repository,
      cohortId: widget.teacherClass.cohort.id,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _courseTitle {
    final course = widget.teacherClass.cohort.course;
    return course.title.preferred ?? course.slug;
  }

  void _open(GradebookRow row) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GradebookStudentScreen(
          courseTitle: _courseTitle,
          student: row,
          submissions: [
            for (final r in _controller.rows ?? const <GradebookRow>[])
              if (r.studentId == row.studentId) r,
          ],
          repository: widget.repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradebookBackHeader(title: _courseTitle),
          const SizedBox(height: 16),
          GradebookFilterBar(
            selected: _filter,
            onChanged: (filter) => setState(() => _filter = filter),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final rows = _controller.rows;

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

    if (rows == null) {
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

    final visible = filterRows(rows, _filter);
    return RefreshIndicator(
      onRefresh: _controller.load,
      color: AppColors.blue,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          16,
          AppDimens.screenPadding,
          24,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: visible.isEmpty ? 1 : visible.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (_, index) => visible.isEmpty
            ? const GradebookNotice(TeacherGradebookStrings.noRows)
            : GradebookRowCard(
                row: visible[index],
                onTap: () => _open(visible[index]),
              ),
      ),
    );
  }
}
