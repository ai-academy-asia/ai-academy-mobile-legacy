import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../domain/teacher_class.dart';
import '../domain/teacher_gradebook_repository.dart';
import '../domain/teacher_submission.dart';
import 'gradebook_student_screen.dart';
import 'teacher_gradebook_strings.dart';
import 'widgets/gradebook_widgets.dart';

/// A class's student list (Issue #233), built against the
/// `angiin-students-list` reference: the course title over the Бүгд /
/// Хүлээгдэж буй / Дүгнэгдсэн filters and one card per student's
/// submission; a tap opens the student.
///
/// The filters read the confirmed submission `status` ([matchesFilter]).
///
/// **Blocked by a BACKEND GAP.** No verified response lists a class's
/// students (`GET /teacher/cohorts/{id}/students`), its assignments
/// (`GET /teacher/cohorts/{id}/assignments`) or a submission row's student
/// name, assignment title and status (`GET /teacher/assignments/{id}/
/// submissions`). With no [rows] — the only case the app has — the list
/// says so instead of drawing invented students.
class GradebookClassScreen extends StatefulWidget {
  const GradebookClassScreen({
    required this.teacherClass,
    required this.repository,
    super.key,
    this.rows = const [],
  });

  final TeacherClass teacherClass;
  final TeacherGradebookRepository repository;
  final List<GradebookRow> rows;

  @override
  State<GradebookClassScreen> createState() => _GradebookClassScreenState();
}

class _GradebookClassScreenState extends State<GradebookClassScreen> {
  GradebookFilter _filter = GradebookFilter.all;

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
            for (final r in widget.rows)
              if (r.studentId == row.studentId) r,
          ],
          repository: widget.repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final row in widget.rows)
        if (matchesFilter(row.status, _filter)) row,
    ];

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
            child: widget.rows.isEmpty
                ? const Align(
                    alignment: Alignment.topCenter,
                    child: GradebookNotice(
                      TeacherGradebookStrings.studentsUnavailable,
                    ),
                  )
                : visible.isEmpty
                ? const Align(
                    alignment: Alignment.topCenter,
                    child: GradebookNotice(TeacherGradebookStrings.noRows),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.screenPadding,
                      16,
                      AppDimens.screenPadding,
                      24,
                    ),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (_, index) => GradebookRowCard(
                      row: visible[index],
                      onTap: () => _open(visible[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
