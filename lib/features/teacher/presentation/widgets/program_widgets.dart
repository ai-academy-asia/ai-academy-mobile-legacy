import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/pill_button.dart';
import '../../../../shared/widgets/track_badge.dart';
import '../../domain/teacher_class.dart';
import '../../domain/teacher_submission.dart';
import '../teacher_gradebook_strings.dart';
import 'teacher_request_parts.dart';

/// Teacher Programs' shared pieces (Issue #390), measured off the updated
/// Figma frames `Sign in - 33/34/35/40`, `Contract(2)` and `Close(1)`.

// ---------------------------------------------------------------------------
// Program card (`Sign in - 33`)
// ---------------------------------------------------------------------------

/// A class on Хөтөлбөрүүд: the track badge, the cohort over the course, the
/// enrolled count at the trailing edge, and "Дэлгэрэнгүй" across the foot —
/// on the track's own wash and block pattern.
class TeacherProgramCard extends StatelessWidget {
  const TeacherProgramCard({
    required this.teacherClass,
    required this.onDetails,
    super.key,
  });

  final TeacherClass teacherClass;

  /// "Дэлгэрэнгүй" — opens the class's actions.
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cohort = teacherClass.cohort;
    final track = teacherClass.track;
    final title = cohort.course.title.preferred ?? cohort.course.slug;
    final radius = BorderRadius.circular(AppDimens.homeCardRadius);

    // A `Container`, as the family's other cards: its border takes the 1pt
    // [programCardPadding] gives up, so the content sits 16 / 24 in.
    return Container(
      decoration: BoxDecoration(
        // White under the family's pattern, as every card in it (Issue #408).
        color: palette.surface,
        borderRadius: radius,
        border: Border.all(color: palette.outline),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // The family's pattern, orange for Junior (Issue #408).
            CardPattern(track: track),
            Padding(
              // The family's inset: 16 at the sides, 24 at the top and bottom
              // (Issue #404; was 16 all round).
              padding: programCardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CardBadgeRow(track: track),
                  const SizedBox(height: 16),
                  _TitleAndCount(
                    cohortName: cohort.name,
                    title: title,
                    count: cohort.enrolledCount,
                  ),
                  const SizedBox(height: 24),
                  PillButton(
                    label: TeacherGradebookStrings.details,
                    variant: PillButtonVariant.secondary,
                    height: 36,
                    onPressed: onDetails,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The cohort over the course on the left and "Нийт сурагч" over the count
/// on the right, as `Sign in - 33` draws them — side by side whatever the
/// title's length: the title takes the room left and wraps, the count keeps
/// its own width at the right edge, the label level with the cohort's name
/// and the count with the title's first line (Issue #408). Only where the
/// count would need more than half the row — a large system text size —
/// does it go under the title, still at the right, never over it.
///
/// It was a `Wrap`, which measures the title unwrapped: a title too long to
/// share one line with the count sent the whole count under it, to the
/// left — at the default size on a 393-wide iPhone.
class _TitleAndCount extends StatelessWidget {
  const _TitleAndCount({
    required this.cohortName,
    required this.title,
    required this.count,
  });

  final String cohortName;
  final String title;
  final int count;

  static const TextStyle _captionStyle = AppTypography.body;
  static const TextStyle _valueStyle = AppTypography.cardTitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final caption = _captionStyle.copyWith(color: palette.textSecondary);
    final value = _valueStyle.copyWith(color: palette.teacherTitle);

    final names = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(cohortName, style: caption),
        const SizedBox(height: 2),
        Text(title, style: value),
      ],
    );
    final total = Semantics(
      label: '${TeacherGradebookStrings.totalStudents}: $count',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(TeacherGradebookStrings.totalStudents, style: caption),
          const SizedBox(height: 2),
          Text('$count', style: value),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (_totalWidth(context) <= constraints.maxWidth / 2) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: names),
              const SizedBox(width: 12),
              total,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            names,
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: total),
          ],
        );
      },
    );
  }

  /// The count block's own width at the current text size — the wider of
  /// its label and its number.
  double _totalWidth(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    double widthOf(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    return math.max(
      widthOf(TeacherGradebookStrings.totalStudents, _captionStyle),
      widthOf('$count', _valueStyle),
    );
  }
}

// ---------------------------------------------------------------------------
// Page header (`Sign in - 34`, `35`)
// ---------------------------------------------------------------------------

/// A pushed Programs page's header: the back control, then — beside it,
/// left-aligned as the frames draw it — an optional grey [caption] over the
/// [title], and a rule under the band.
class ProgramPageHeader extends StatelessWidget {
  const ProgramPageHeader({required this.title, super.key, this.caption});

  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const AppBackButton(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: AppDimens.screenPadding),
                child: Semantics(
                  header: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (caption case final caption?)
                        Text(
                          caption,
                          style: AppTypography.supporting.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      Text(
                        title,
                        style: AppTypography.headerTitle.copyWith(
                          color: palette.textTitle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Count badge
// ---------------------------------------------------------------------------

/// The frames' red count pill — "1", "9+": submissions awaiting the
/// teacher's review. Grows with large text.
class PendingBadge extends StatelessWidget {
  const PendingBadge({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: TeacherGradebookStrings.pendingLabel(count),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          TeacherGradebookStrings.badge(count),
          style: AppTypography.badge.copyWith(color: palette.onPrimary),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cohort action sheet (`Contract(2)`)
// ---------------------------------------------------------------------------

/// What the class's action sheet answers with.
enum CohortAction { announce, students }

/// Opens the class's actions — "Зар тараах" and "Сурагчдын мэдээлэл" — and
/// completes with the one chosen, or null when dismissed.
Future<CohortAction?> showCohortActionSheet(BuildContext context) =>
    showModalBottomSheet<CohortAction>(
      context: context,
      backgroundColor: context.palette.surfaceElevated,
      barrierColor: context.palette.barrier,
      constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const CohortActionSheet(),
    );

class CohortActionSheet extends StatelessWidget {
  const CohortActionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          8,
          AppDimens.screenPadding,
          AppDimens.screenPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TeacherSheetHandle(),
            const SizedBox(height: 16),
            SheetActionRow(
              icon: Icons.campaign_outlined,
              label: TeacherGradebookStrings.announce,
              onTap: () => Navigator.of(context).pop(CohortAction.announce),
            ),
            const SizedBox(height: AppDimens.tileGap),
            SheetActionRow(
              icon: Icons.groups_outlined,
              label: TeacherGradebookStrings.studentsInfo,
              onTap: () => Navigator.of(context).pop(CohortAction.students),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the action sheet's outlined pills: a leading glyph and its label.
/// The frame's megaphone and people glyphs have no Phosphor counterpart in
/// `AppIcons`, so Material's are drawn (`DESIGN_SYSTEM.md` §icons).
class SheetActionRow extends StatelessWidget {
  const SheetActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shape = StadiumBorder(side: BorderSide(color: palette.outline));
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: palette.surface,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, size: 24, color: palette.textStrong),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTypography.itemLabel.copyWith(
                        color: palette.textStrong,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Announcement composer (`Close(1)`)
// ---------------------------------------------------------------------------

/// Opens the class announcement composer.
Future<void> showAnnouncementSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.surfaceElevated,
      barrierColor: context.palette.barrier,
      constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const AnnouncementSheet(),
    );

/// "Зар тараах": the frame's hint, a 100-character counter, the field and
/// Submit. **Nothing is sent** — the only announcement endpoint is staff-
/// only and refuses a teacher (BACKEND GAP, Issue #390) — so Submit stays
/// off and the sheet says why, rather than faking a broadcast or sending
/// some other notification. Lifts above the keyboard.
class AnnouncementSheet extends StatefulWidget {
  const AnnouncementSheet({super.key});

  @override
  State<AnnouncementSheet> createState() => _AnnouncementSheetState();
}

class _AnnouncementSheetState extends State<AnnouncementSheet> {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const max = TeacherGradebookStrings.announceMaxLength;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.screenPadding,
            8,
            AppDimens.screenPadding,
            AppDimens.screenPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TeacherSheetHandle(),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  TeacherGradebookStrings.announce,
                  style: AppTypography.headerTitle.copyWith(
                    color: palette.textTitle,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      TeacherGradebookStrings.announceHint,
                      style: AppTypography.supporting.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    TeacherGradebookStrings.counter(_text.text.length, max),
                    style: AppTypography.supporting.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _text,
                maxLength: max,
                minLines: 3,
                maxLines: 5,
                style: AppTypography.fieldText.copyWith(
                  color: palette.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: TeacherGradebookStrings.announcePlaceholder,
                  hintStyle: AppTypography.fieldText.copyWith(
                    color: palette.textMuted,
                  ),
                  counterText: '',
                  contentPadding: const EdgeInsets.all(16),
                  enabledBorder: _fieldBorder(palette.outline),
                  focusedBorder: _fieldBorder(palette.borderFocused),
                  border: _fieldBorder(palette.outline),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  TeacherGradebookStrings.announceUnavailable,
                  style: AppTypography.supporting.copyWith(
                    color: palette.errorInk,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Off whatever is typed: no endpoint will take it.
              const PillButton(
                label: TeacherGradebookStrings.submit,
                height: 44,
                onPressed: null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
  borderSide: BorderSide(color: color),
);

// ---------------------------------------------------------------------------
// Assignment picker (`Sign in - 40`)
// ---------------------------------------------------------------------------

/// Opens the class's assignments for one student and completes with the
/// one picked, or null when dismissed.
Future<TeacherAssignment?> showAssignmentPicker(
  BuildContext context, {
  required List<TeacherAssignment> assignments,
  required TeacherAssignment selected,
  required int Function(TeacherAssignment) pendingFor,
}) => showModalBottomSheet<TeacherAssignment>(
  context: context,
  backgroundColor: context.palette.surfaceElevated,
  barrierColor: context.palette.barrier,
  constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (_) => AssignmentPickerSheet(
    assignments: assignments,
    selected: selected,
    pendingFor: pendingFor,
  ),
);

/// Every assignment of the class, one bordered list: the caption
/// ("Даалгавар N" — one simple list, not the frames' "Modules N": PRODUCT
/// DECISION, Issue #394) over the title, the student's awaiting-review
/// badge, and a radio — the selected one filled blue. Scrolls when long.
class AssignmentPickerSheet extends StatelessWidget {
  const AssignmentPickerSheet({
    required this.assignments,
    required this.selected,
    required this.pendingFor,
    super.key,
  });

  final List<TeacherAssignment> assignments;
  final TeacherAssignment selected;
  final int Function(TeacherAssignment) pendingFor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 16),
              child: TeacherSheetHandle(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  0,
                  AppDimens.screenPadding,
                  AppDimens.screenPadding,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(
                      AppDimens.homeCardRadius,
                    ),
                    border: Border.all(color: palette.outlineFaint),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppDimens.homeCardRadius,
                    ),
                    child: Column(
                      children: [
                        for (final (index, assignment) in assignments.indexed)
                          AssignmentOption(
                            number: index + 1,
                            assignment: assignment,
                            pending: pendingFor(assignment),
                            selected: assignment.id == selected.id,
                            last: index == assignments.length - 1,
                            onTap: () => Navigator.of(context).pop(assignment),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A picker row.
class AssignmentOption extends StatelessWidget {
  const AssignmentOption({
    required this.number,
    required this.assignment,
    required this.pending,
    required this.selected,
    required this.last,
    required this.onTap,
    super.key,
  });

  final int number;
  final TeacherAssignment assignment;
  final int pending;
  final bool selected;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${TeacherGradebookStrings.assignmentCaption(number)}, '
          '${assignment.displayTitle}'
          '${pending > 0 ? ', ${TeacherGradebookStrings.pendingLabel(pending)}' : ''}',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: last
                ? null
                : Border(bottom: BorderSide(color: palette.outlineFaint)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TeacherGradebookStrings.assignmentCaption(number),
                        style: AppTypography.supporting.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                      Text(
                        assignment.displayTitle,
                        style: AppTypography.itemTitle.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (pending > 0) ...[
                  const SizedBox(width: 8),
                  PendingBadge(count: pending),
                ],
                const SizedBox(width: 12),
                _Radio(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The frame's radio: a grey ring, or a blue disc with a white centre.
class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? palette.accent : palette.surface,
        border: Border.all(
          color: selected ? palette.accent : palette.outline,
          width: selected ? 1 : 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.onPrimary,
              ),
            )
          : null,
    );
  }
}

/// The caret on a selector — `AppIcons.caretDown`.
const IconData selectorCaret = AppIcons.caretDown;
