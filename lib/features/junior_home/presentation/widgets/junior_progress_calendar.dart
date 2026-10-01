import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/junior_progress.dart';
import '../junior_progress_strings.dart';
import 'junior_home_palette.dart';

// Measured off the Junior Learning Progress frame at 1:1.

/// A day cell: 44 wide in the 393 frame — the width is what is left of the
/// row once the gaps are taken, so it tracks the screen — and always 58 tall.
const double _cellHeight = 58;
const double _cellRadius = 8;

/// Between two cells, across and down.
const double _cellGap = 6;

/// The day's disc, 4 from the cell's top edge, with the number's line
/// directly under it.
const double _discSize = 32;
const double _discTop = 4;
const double _discToNumber = 1;

/// The weekday letters' row: their line, then 12 to the first row of cells.
const double _weekdayToGrid = 12;

/// The month as a grid of day cells under a row of weekday letters, Sunday
/// first.
///
/// Laid out from the date itself — the leading blanks are the weekday the
/// month starts on, and there are as many cells as the month has days — so
/// it is correct for any month. The frame's own drawing is not a real August
/// 2026 (it starts the month on a Monday, repeats a 7 and stops at 30); the
/// real calendar is what this draws, with the frame's marks on the frame's
/// day numbers.
///
/// The selected day's weekday letter is drawn in blue, as the frame draws the
/// letter over its selected day.
class JuniorProgressCalendar extends StatelessWidget {
  const JuniorProgressCalendar({
    required this.month,
    required this.selectedDay,
    required this.days,
    super.key,
  });

  /// Only its year and month are read.
  final DateTime month;
  final int selectedDay;
  final Map<int, JuniorDayStatus> days;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final dayCount = DateUtils.getDaysInMonth(month.year, month.month);
    // `DateTime.weekday` runs Monday = 1 … Sunday = 7; the grid runs Sunday
    // first, so Sunday is column 0.
    final lead = first.weekday % DateTime.daysPerWeek;
    final selectedColumn =
        DateTime(month.year, month.month, selectedDay).weekday %
        DateTime.daysPerWeek;
    final rowCount = ((lead + dayCount) / DateTime.daysPerWeek).ceil();

    Widget row(List<Widget> cells) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const SizedBox(width: _cellGap),
          Expanded(child: cells[i]),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row([
          for (var c = 0; c < DateTime.daysPerWeek; c++)
            Text(
              JuniorProgressStrings.weekdays[c],
              textAlign: TextAlign.center,
              style: _weekdayStyle.copyWith(
                color: c == selectedColumn
                    ? JuniorPalette.accent
                    : AppColors.textSecondary,
              ),
            ),
        ]),
        const SizedBox(height: _weekdayToGrid),
        for (var r = 0; r < rowCount; r++) ...[
          if (r > 0) const SizedBox(height: _cellGap),
          row([
            for (var c = 0; c < DateTime.daysPerWeek; c++)
              _cellAt(r * DateTime.daysPerWeek + c - lead + 1, dayCount),
          ]),
        ],
      ],
    );
  }

  Widget _cellAt(int day, int dayCount) {
    if (day < 1 || day > dayCount) return const SizedBox(height: _cellHeight);
    return _DayCell(day: day, status: days[day], selected: day == selectedDay);
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.status,
    required this.selected,
  });

  final int day;
  final JuniorDayStatus? status;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _cellHeight,
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(_cellRadius),
      ),
      // In the foreground, so the outline takes no layout space and the
      // selected day's disc and number sit exactly where every other day's do.
      foregroundDecoration: selected
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(_cellRadius),
              border: Border.all(
                color: JuniorPalette.accent,
                width: AppDimens.borderWidthEmphasis,
              ),
            )
          : null,
      child: Column(
        children: [
          const SizedBox(height: _discTop),
          JuniorDayMark(status: status, size: _discSize),
          const SizedBox(height: _discToNumber),
          Text(
            '$day',
            style: _dayStyle.copyWith(
              color: selected ? JuniorPalette.accent : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A day's mark: the design's SVG on its tinted disc, or a flat grey disc
/// for an unmarked day.
///
/// The SVGs are drawn at their own 17 x 16, centred, on the 32 disc in the
/// calendar and the 24 disc in the legend alike — the frame does not scale
/// the artwork between the two.
///
/// **"Хичээлдээ суусан" has no artwork.** Its SVG was not supplied and
/// nothing in the repository matches it, so an attended day draws an empty
/// slot of the same size — not a substitute glyph, and not the grey disc,
/// which would claim the day is unmarked. It carries its label for a screen
/// reader either way.
class JuniorDayMark extends StatelessWidget {
  const JuniorDayMark({required this.status, required this.size, super.key});

  /// Null for an unmarked day.
  final JuniorDayStatus? status;

  final double size;

  @override
  Widget build(BuildContext context) {
    final (Color? disc, String? asset, String? label) = switch (status) {
      null => (JuniorPalette.dayNeutral, null, null),
      JuniorDayStatus.lesson => (
        JuniorPalette.dayLesson,
        JuniorProgressIcons.lessonDay,
        JuniorProgressStrings.lessonDay,
      ),
      JuniorDayStatus.missed => (
        JuniorPalette.dayMissed,
        JuniorProgressIcons.lessonMissed,
        JuniorProgressStrings.lessonMissed,
      ),
      JuniorDayStatus.attended => (
        null,
        null,
        JuniorProgressStrings.lessonAttended,
      ),
    };

    final mark = SizedBox.square(
      dimension: size,
      child: disc == null
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(color: disc, shape: BoxShape.circle),
              child: asset == null
                  ? null
                  : Center(child: SvgPicture.asset(asset)),
            ),
    );

    return label == null ? mark : Semantics(label: label, child: mark);
  }
}

/// S M T W T F S — 13 semibold.
const TextStyle _weekdayStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 13,
  height: 16 / 13,
  fontWeight: FontWeight.w600,
  leadingDistribution: TextLeadingDistribution.even,
);

/// The day number under its disc — 13 medium.
const TextStyle _dayStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 13,
  height: 16 / 13,
  fontWeight: FontWeight.w500,
  leadingDistribution: TextLeadingDistribution.even,
);
