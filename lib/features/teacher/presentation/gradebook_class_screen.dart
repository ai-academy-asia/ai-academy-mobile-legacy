import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/content_column.dart';
import '../domain/teacher_class.dart';
import '../domain/teacher_gradebook_repository.dart';
import 'gradebook_class_controller.dart';
import 'gradebook_student_screen.dart';
import 'manual_attendance_screen.dart' show StudentInitialsAvatar;
import 'teacher_gradebook_strings.dart';
import 'teacher_home_strings.dart';
import 'widgets/program_widgets.dart';

/// "Сурагчдын мэдээлэл" — a class's students (Issues #233, #390), built
/// against `Sign in - 34`: the back control with the cohort over the course,
/// "Сурагчид", then one row per enrolled student — their initials avatar,
/// name, a red badge with how many of their submissions wait for review,
/// and a chevron; a tap opens the student.
///
/// The rows are the real roster (`GET /teacher/cohorts/{id}/students`), so
/// a student who has submitted nothing is listed too, with no badge. The
/// former filter chips are gone, as the frame draws none.
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
  late final GradebookClassController _controller = GradebookClassController(
    repository: widget.repository,
    cohortId: widget.teacherClass.cohort.id,
  )..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _courseTitle {
    final course = widget.teacherClass.cohort.course;
    return course.title.preferred ?? course.slug;
  }

  void _open(CohortStudent student) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GradebookStudentScreen(
          student: student,
          classController: _controller,
          repository: widget.repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Its own style: the page below stops painting once covered,
      // and its style would stay (Issue #400).
      value: AppSystemUi.page(
        context,
        navigationBar: context.palette.surfaceSubtle,
      ),
      child: Scaffold(
        backgroundColor: context.palette.surfaceSubtle,
        body: SafeArea(
          bottom: false,
          child: ContentColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProgramPageHeader(
                  caption: widget.teacherClass.cohort.name,
                  title: _courseTitle,
                ),
                Expanded(
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => _body(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final palette = context.palette;
    final students = _controller.students;
    if (students == null) {
      final error = _controller.errorMessage;
      if (error == null) {
        return Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: palette.primary,
            ),
          ),
        );
      }
      return Center(
        child: ProgramNotice(
          message: error,
          action: AppButton(
            label: TeacherHomeStrings.retry,
            variant: AppButtonVariant.outlined,
            onPressed: _controller.load,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _controller.load,
      color: palette.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: AppDimens.pageContentTop,
          bottom: AppDimens.pageBottom + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.screenPadding,
              0,
              AppDimens.screenPadding,
              12,
            ),
            child: Semantics(
              header: true,
              child: Text(
                TeacherGradebookStrings.studentsHeading,
                style: AppTypography.sectionTitle.copyWith(
                  color: palette.textPrimary,
                ),
              ),
            ),
          ),
          if (students.isEmpty)
            const ProgramNotice(message: TeacherGradebookStrings.noStudents),
          for (final student in students)
            ProgramStudentRow(
              student: student,
              pending: _controller.pendingOf(student.id),
              onTap: () => _open(student),
            ),
        ],
      ),
    );
  }
}

/// A student on the list: a 40 initials avatar, the name, the badge when
/// anything waits for review, and a chevron — 72 tall at the default size,
/// a full-width rule under it, as `Sign in - 34` draws it.
class ProgramStudentRow extends StatelessWidget {
  const ProgramStudentRow({
    required this.student,
    required this.pending,
    required this.onTap,
    super.key,
  });

  final CohortStudent student;
  final int pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.outlineFaint)),
      ),
      child: Semantics(
        button: true,
        label:
            '${student.name}'
            '${pending > 0 ? ', ${TeacherGradebookStrings.pendingLabel(pending)}' : ''}',
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.screenPadding,
              vertical: 16,
            ),
            child: Row(
              children: [
                StudentInitialsAvatar(
                  name: student.name,
                  studentId: student.id,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    student.name,
                    style: AppTypography.body.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                if (pending > 0) ...[
                  const SizedBox(width: 8),
                  PendingBadge(count: pending),
                ],
                const SizedBox(width: 12),
                Icon(AppIcons.caretRight, size: 20, color: palette.textStrong),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A centred grey message, and an action under it — the empty and failure
/// states no frame draws.
class ProgramNotice extends StatelessWidget {
  const ProgramNotice({required this.message, super.key, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.screenPadding),
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
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
