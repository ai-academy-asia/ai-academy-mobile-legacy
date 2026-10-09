import 'package:flutter/material.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../home/domain/home_dashboard.dart';
import '../../domain/junior_progress.dart';
import '../junior_progress_strings.dart';
import 'junior_progress_calendar.dart';

// The attendance panel's parts, shared by the Junior "Сурлагын явц" screen
// and the Adult attendance screen (Issue #172): the two Figma frames draw
// the same next-lesson lines, month header, legend and summary pill. Moved
// here unchanged from `JuniorProgressScreen`, so the Junior frame renders
// exactly as it did; measured off the Junior Learning Progress frame at 1:1.

/// The legend's discs, smaller than the calendar's.
const double _legendDisc = 24;

/// A `x/y · z%` (or `z%`) figure as a blue pill — the frame's summary badge:
/// `AppPalette.accentText` on an `accentSubtle` fill, ringed in
/// `accentSubtleOutline`.
class AttendancePill extends StatelessWidget {
  const AttendancePill(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Sized by its label: 2 + a 20 line + 2 is the frame's 24.
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: context.palette.accentSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.accentSubtleOutline),
      ),
      child: Text(
        label,
        style: _badgeStyle.copyWith(color: context.palette.accentText),
        maxLines: 1,
      ),
    );
  }
}

/// "Дараагийн хичээл:" over its blue date and hours.
class AttendanceNextLesson extends StatelessWidget {
  const AttendanceNextLesson(this.lesson, {super.key});

  final NextLesson lesson;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          JuniorProgressStrings.nextLesson,
          style: attendanceLabelStyle.copyWith(
            color: context.palette.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          JuniorProgressStrings.nextLessonTime(lesson.startsAt, lesson.endsAt),
          style: _timeStyle.copyWith(color: context.palette.accentText),
        ),
      ],
    );
  }
}

/// "Наймдугаар сар, 2026" with the previous/next arrows at the trailing
/// edge, centred on the label's line. A null [onPrevious] — the student's
/// cohort start month (Issue #200) — draws "<" muted and inert.
class AttendanceMonthHeader extends StatelessWidget {
  const AttendanceMonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  final DateTime month;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    // A bare GestureDetector rather than an InkWell: the frame draws no
    // pressed state, and the arrows must look exactly as they did inert.
    Widget arrow(IconData icon, String label, VoidCallback? onTap) => Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 36,
          height: 24,
          // The frame centres the carets 2 above the label's own centre.
          padding: const EdgeInsets.only(bottom: 4),
          // 19 inks the frame's 7 x 14 caret.
          // No frame draws a disabled arrow: the muted ink the app's
          // disabled pills use (`disabledInk`).
          child: Icon(
            icon,
            size: 19,
            color: onTap == null
                ? context.palette.disabledInk
                : context.palette.textPrimary,
          ),
        ),
      ),
    );

    return Row(
      children: [
        Expanded(
          child: Text(
            JuniorProgressStrings.monthLabel(month),
            style: _monthStyle.copyWith(color: context.palette.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        arrow(
          AppIcons.caretLeft,
          JuniorProgressStrings.previousMonth,
          onPrevious,
        ),
        arrow(AppIcons.caretRight, JuniorProgressStrings.nextMonth, onNext),
      ],
    );
  }
}

/// "Тайлбар:", its hint, and one row per mark.
///
/// [missedLabel] is the missed row's wording, which the two frames word
/// differently: Junior "Хичээлээ тасалсан", Adult "Хичээлдээ суугаагүй".
class AttendanceLegend extends StatelessWidget {
  const AttendanceLegend({
    super.key,
    this.missedLabel = JuniorProgressStrings.lessonMissed,
  });

  final String missedLabel;

  @override
  Widget build(BuildContext context) {
    Widget row(JuniorDayStatus status, String label) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          JuniorDayMark(status: status, size: _legendDisc),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: _legendLabelStyle.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          JuniorProgressStrings.legendTitle,
          style: attendanceLabelStyle.copyWith(
            color: context.palette.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          JuniorProgressStrings.legendHint,
          style: _hintStyle.copyWith(color: context.palette.textSecondary),
        ),
        const SizedBox(height: 7),
        row(JuniorDayStatus.lesson, JuniorProgressStrings.lessonDay),
        row(JuniorDayStatus.missed, missedLabel),
        row(JuniorDayStatus.attended, JuniorProgressStrings.lessonAttended),
      ],
    );
  }
}

// --- Type ------------------------------------------------------------------
//
// Sizes read off the frame's cap heights (Manrope's cap height is 0.72 em).
// None bakes a colour: each use supplies the palette's (Dark Mode Phase 7,
// Issue #272) — the two public styles are also drawn by Adult attendance.

/// The summary cards' titles — "Хичээлийн ирц", "Шалгалтын дүн". 16 bold,
/// `textPrimary` at use.
const TextStyle attendanceCardTitleStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 16,
  height: 24 / 16,
  fontWeight: FontWeight.w700,
  leadingDistribution: TextLeadingDistribution.even,
);

/// The smaller titles — "Дараанийн төлөлт:", "Дараагийн хичээл:",
/// "Тайлбар:". 14 semibold, `textPrimary` at use.
const TextStyle attendanceLabelStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w600,
  leadingDistribution: TextLeadingDistribution.even,
);

/// The summary badges. 14 medium, blue.
const TextStyle _badgeStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w500,
  leadingDistribution: TextLeadingDistribution.even,
);

/// "08/08 • 09:00 – 11:00". 15 regular, blue.
const TextStyle _timeStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 15,
  height: 22 / 15,
  fontWeight: FontWeight.w400,
  leadingDistribution: TextLeadingDistribution.even,
);

/// "Наймдугаар сар, 2026". 14 regular, grey.
const TextStyle _monthStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 22 / 14,
  fontWeight: FontWeight.w400,
  leadingDistribution: TextLeadingDistribution.even,
);

/// The legend's hint, two lines. 14 regular, grey.
const TextStyle _hintStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w400,
  leadingDistribution: TextLeadingDistribution.even,
);

/// A legend row's label. 14 regular, grey.
const TextStyle _legendLabelStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w400,
  leadingDistribution: TextLeadingDistribution.even,
);
