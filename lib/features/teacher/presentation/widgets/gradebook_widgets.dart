import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../course_learning/presentation/widgets/course_learning_back_button.dart';
import '../../../home/presentation/widgets/home_badges.dart';
import '../../domain/teacher_submission.dart';
import '../teacher_gradebook_strings.dart';
import 'teacher_pill_button.dart';

/// One student's submission as the Gradebook lists it (Issue #233): a
/// confirmed submission — which carries its student — and the title of the
/// assignment it answers.
class GradebookRow {
  const GradebookRow({required this.submission, required this.assignmentTitle});

  final TeacherSubmission submission;
  final String assignmentTitle;

  int get submissionId => submission.id;

  /// A list entry always carries its student; the detail need not.
  int get studentId => submission.student?.id ?? -1;
  String get studentName => submission.student?.name ?? '';
  String? get initials => submission.student?.initials;
  String get status => submission.status;
}

/// The white band the drill-down references open with: the back control and
/// the class's course title centred on it.
class GradebookBackHeader extends StatelessWidget {
  const GradebookBackHeader({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.palette.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          // The back control's 12 + 40, and 12 under it to the grey body.
          height: 64,
          child: Stack(
            children: [
              const CourseLearningBackButton(icon: AppIcons.arrowLeft),
              Padding(
                padding: const EdgeInsets.fromLTRB(64, 12, 64, 12),
                child: Center(
                  child: Text(
                    title,
                    style: gradebookTitleStyle.copyWith(
                      color: context.palette.textStrong,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Бүгд / Хүлээгдэж буй / Дүгнэгдсэн — the reference's pills, the selected
/// one blue.
class GradebookFilterBar extends StatelessWidget {
  const GradebookFilterBar({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final GradebookFilter selected;
  final ValueChanged<GradebookFilter> onChanged;

  static String label(GradebookFilter filter) => switch (filter) {
    GradebookFilter.all => TeacherGradebookStrings.filterAll,
    GradebookFilter.pending => TeacherGradebookStrings.filterPending,
    GradebookFilter.graded => TeacherGradebookStrings.filterGraded,
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.screenPadding),
      child: Row(
        children: [
          for (final (index, filter) in GradebookFilter.values.indexed) ...[
            if (index > 0) const SizedBox(width: 8),
            Semantics(
              selected: filter == selected,
              child: TeacherPillButton(
                label: label(filter),
                variant: filter == selected
                    ? TeacherPillVariant.filled
                    : TeacherPillVariant.outlined,
                height: 36,
                fontSize: 15,
                onPressed: () => onChanged(filter),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A row card: the student's name over the assignment's title, led by the
/// avatar on the student list. No photo field is known, so the avatar is a
/// neutral placeholder.
class GradebookRowCard extends StatelessWidget {
  const GradebookRowCard({
    required this.row,
    required this.onTap,
    super.key,
    this.showAvatar = true,
  });

  final GradebookRow row;
  final VoidCallback onTap;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${row.studentName}, ${row.assignmentTitle}',
      excludeSemantics: true,
      child: Material(
        color: context.palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: context.palette.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.cardPadding),
            child: Row(
              children: [
                if (showAvatar) ...[
                  GradebookAvatar(initials: row.initials),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: GradebookIdentity(
                    name: row.studentName,
                    title: row.assignmentTitle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The grey name over the dark title.
class GradebookIdentity extends StatelessWidget {
  const GradebookIdentity({required this.name, required this.title, super.key});

  final String name;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: _nameStyle.copyWith(color: context.palette.textMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: _rowTitleStyle.copyWith(color: context.palette.textStrong),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// The 48pt student avatar. No photo URL is in any confirmed response, so it
/// shows the student's confirmed `initials` — or a person glyph without
/// them — on a fill a step darker than the page grey, so it reads on either
/// surface.
class GradebookAvatar extends StatelessWidget {
  const GradebookAvatar({super.key, this.initials});

  final String? initials;

  @override
  Widget build(BuildContext context) {
    final letters = initials;
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.palette.avatarPlaceholder,
        shape: BoxShape.circle,
      ),
      child: letters == null || letters.isEmpty
          ? Icon(
              AppIcons.user,
              size: 22,
              color: context.palette.avatarPlaceholderInk,
            )
          : ExcludeSemantics(
              child: Text(
                letters,
                style: _initialsStyle.copyWith(
                  color: context.palette.textMuted,
                ),
              ),
            ),
    );
  }
}

/// Хичээлийн ирц / Шалгалтын дүн: a heading over a blue capsule.
class GradebookStatCard extends StatelessWidget {
  const GradebookStatCard({
    required this.title,
    required this.value,
    super.key,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // A card's faint edge (`outlineFaint`); the capsule is the live blue set
    // — `infoInk` at 30 % round an `infoFill`, the figure in `accentText`.
    return Container(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: palette.outlineFaint,
          width: AppDimens.borderWidthEmphasis,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _statTitleStyle.copyWith(color: palette.textStrong),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              HomeCapsule(
                label: value,
                outline: palette.infoInk.withValues(alpha: 0.3),
                fill: palette.infoFill,
                ink: palette.accentText,
                horizontalPadding: 11,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A centred grey line — the empty and BACKEND GAP states.
class GradebookNotice extends StatelessWidget {
  const GradebookNotice(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.screenPadding,
        vertical: 32,
      ),
      child: Text(
        message,
        style: AppTypography.cardSupporting.copyWith(
          color: context.palette.textSecondary,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

final TextStyle gradebookTitleStyle = AppTypography.programTitle.copyWith(
  fontSize: 20,
  height: 28 / 20,
  fontWeight: FontWeight.w700,
);

final TextStyle _nameStyle = AppTypography.programTitle.copyWith(
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w600,
);

final TextStyle _rowTitleStyle = AppTypography.programTitle.copyWith(
  fontSize: 17,
  height: 24 / 17,
  fontWeight: FontWeight.w600,
);

final TextStyle _initialsStyle = AppTypography.programTitle.copyWith(
  fontSize: 16,
  height: 1.2,
  fontWeight: FontWeight.w700,
);

final TextStyle _statTitleStyle = AppTypography.programTitle.copyWith(
  fontSize: 16,
  height: 24 / 16,
  fontWeight: FontWeight.w700,
);
