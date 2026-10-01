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
          JuniorDayMark(status: status, size: _discSize, ringed: true),
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

/// A day's mark: the design's SVG on its disc, or a flat grey disc for an
/// unmarked day.
///
/// Each SVG is drawn at one fixed size, centred, on the 32 disc in the
/// calendar and the 24 disc in the legend alike — the frame does not scale
/// the artwork between the two. The discs are layout, not artwork, so they
/// are drawn here; see `JuniorProgressIcons` for where each SVG comes from.
///
/// "Хичээлдээ суусан" is the one mark on a solid disc: the frame's white "A"
/// on [JuniorPalette.accent], lifted by a faint shadow. In the calendar
/// ([ringed]) the frame also rings it — a 1.5 blue outline, then 2 of white
/// — so the 32 slot holds a 25 disc; the legend draws the plain disc.
class JuniorDayMark extends StatelessWidget {
  const JuniorDayMark({
    required this.status,
    required this.size,
    this.ringed = false,
    super.key,
  });

  /// Null for an unmarked day.
  final JuniorDayStatus? status;

  final double size;

  /// Draws the attended mark's calendar ring. Ignored by the other marks.
  final bool ringed;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox.square(
      dimension: size,
      child: switch (status) {
        null => const _Disc(color: JuniorPalette.dayNeutral),
        JuniorDayStatus.lesson => const _Disc(
          color: JuniorPalette.dayLesson,
          asset: JuniorProgressIcons.lessonDay,
        ),
        JuniorDayStatus.missed => const _Disc(
          color: JuniorPalette.dayMissed,
          asset: JuniorProgressIcons.lessonMissed,
        ),
        JuniorDayStatus.attended => _AttendedDisc(ringed: ringed),
      },
    );

    final label = switch (status) {
      null => null,
      JuniorDayStatus.lesson => JuniorProgressStrings.lessonDay,
      JuniorDayStatus.missed => JuniorProgressStrings.lessonMissed,
      JuniorDayStatus.attended => JuniorProgressStrings.lessonAttended,
    };
    return label == null ? mark : Semantics(label: label, child: mark);
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.color, this.asset});

  final Color color;
  final String? asset;

  @override
  Widget build(BuildContext context) {
    final asset = this.asset;
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: asset == null ? null : Center(child: SvgPicture.asset(asset)),
    );
  }
}

/// The attended mark's solid blue disc — see [JuniorDayMark].
class _AttendedDisc extends StatelessWidget {
  const _AttendedDisc({required this.ringed});

  final bool ringed;

  /// The faint lift the frame draws around the mark, ringed or not.
  static const BoxShadow _lift = BoxShadow(
    color: Color(0x1F000000),
    blurRadius: 1.5,
  );

  @override
  Widget build(BuildContext context) {
    // 16 x 15, as the frame draws the mark — given explicitly, because
    // flutter_svg sizes a picture by its viewBox (17 x 16, the base icon's).
    final glyph = Center(
      child: SvgPicture.asset(
        JuniorProgressIcons.lessonAttended,
        width: 16,
        height: 15,
      ),
    );
    const disc = BoxDecoration(
      color: JuniorPalette.accent,
      shape: BoxShape.circle,
    );

    if (!ringed) {
      return DecoratedBox(
        decoration: disc.copyWith(boxShadow: const [_lift]),
        child: glyph,
      );
    }
    // The border is inside the box, so 1.5 of blue plus 2 of padding puts
    // the inner disc 3.5 in from the slot's edge.
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: JuniorPalette.accent,
          width: AppDimens.borderWidthEmphasis,
        ),
        boxShadow: const [_lift],
      ),
      child: DecoratedBox(decoration: disc, child: glyph),
    );
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
