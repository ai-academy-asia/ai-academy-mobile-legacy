import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../domain/teacher_gradebook_repository.dart';
import 'gradebook_submission_screen.dart';
import 'teacher_gradebook_strings.dart';
import 'widgets/gradebook_widgets.dart';

/// A student's detail (Issue #233), built against the `student-detail`
/// reference: the student and the assignment they were opened from, the
/// Хичээлийн ирц and Шалгалтын дүн cards, then the student's submissions;
/// a tap opens one.
///
/// Both figures are drawn as "—", never invented: no endpoint reports an
/// exam or assessment result (BACKEND GAP), and a per-student attendance
/// figure has no defined rule — the reference's "1/20 · 10%" does not say
/// what 20 counts (PRODUCT DECISION; the per-session attendance read would
/// also need one request per session). Reached from a [GradebookClassScreen]
/// row: the student, the assignment and the submissions are real.
class GradebookStudentScreen extends StatelessWidget {
  const GradebookStudentScreen({
    required this.courseTitle,
    required this.student,
    required this.submissions,
    required this.repository,
    super.key,
  });

  final String courseTitle;

  /// The row the student was opened from.
  final GradebookRow student;

  /// The student's submissions in this class.
  final List<GradebookRow> submissions;

  final TeacherGradebookRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.surfaceSubtle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradebookBackHeader(title: courseTitle),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.screenPadding,
                    21,
                    AppDimens.screenPadding,
                    24,
                  ),
                  child: Row(
                    children: [
                      GradebookAvatar(initials: student.initials),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GradebookIdentity(
                          name: student.studentName,
                          title: student.assignmentTitle,
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDimens.screenPadding,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GradebookStatCard(
                          title: TeacherGradebookStrings.attendance,
                          value: TeacherGradebookStrings.noFigure,
                        ),
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: GradebookStatCard(
                          title: TeacherGradebookStrings.examScore,
                          value: TeacherGradebookStrings.noFigure,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                Container(
                  height: AppDimens.borderWidth,
                  color: context.palette.divider,
                ),
                for (final submission in submissions)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.screenPadding,
                      14,
                      AppDimens.screenPadding,
                      0,
                    ),
                    child: GradebookRowCard(
                      row: submission,
                      showAvatar: false,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => GradebookSubmissionScreen(
                            courseTitle: courseTitle,
                            submissionId: submission.submissionId,
                            repository: repository,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
