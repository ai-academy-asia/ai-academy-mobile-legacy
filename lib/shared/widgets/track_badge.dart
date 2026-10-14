import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_typography.dart';

/// The outlined track badge (32 tall) and the outlined capsule (24 tall) the
/// cards draw in their top row — Adult Home's `ProgramCard`, the Courses
/// tab's `CohortCard`, Teacher Home's class card (Issue #229) and Teacher
/// Programs, and the E-Contract card, whose references draw the same two
/// parts — with the family's [CardBadgeRow], [programCardPadding] and
/// [CohortCardPattern] (Issue #404). Shared rather than copied, so the
/// cards cannot drift apart. Moved here from
/// `home/presentation/widgets/home_badges.dart` (Issue #329), with
/// `HomeCapsule` renamed [CardCapsule]: other features draw them, so they do
/// not belong to Home.
const double trackBadgeHeight = 32;
const double cardCapsuleHeight = 24;

/// A track, as the outlined badge in a card's top-left: the junior mark for
/// the younger tracks, the adult mark otherwise, beside the capitalised
/// label. [track] is a wire value — a student's `ui_mode`, or a course's
/// `level` — and only the glyph branches on it.
class TrackBadge extends StatelessWidget {
  const TrackBadge(this.track, {super.key});

  /// The adult and junior marks — SVG exports, drawn as artwork.
  /// `HomeIcons.adult` / `HomeIcons.junior` are these, so `shared/` reads no
  /// feature's constants.
  static const String adultGlyph = 'assets/icons/adult.svg';
  static const String juniorGlyph = 'assets/icons/junior.svg';

  final String track;

  @override
  Widget build(BuildContext context) {
    final mode = track.toLowerCase();
    final isJunior = mode == 'junior' || mode == 'kids';

    return Container(
      // 5 | 20 icon | 8 | label | 9.5, inside the 1pt outline. 32 tall at
      // least: a larger system text size grows it with its label rather
      // than clipping the label (Issue #351). At the default size it is
      // exactly 32.
      constraints: const BoxConstraints(minHeight: trackBadgeHeight),
      padding: const EdgeInsets.only(left: 5, right: 9.5),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border.all(color: context.palette.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            isJunior ? juniorGlyph : adultGlyph,
            width: 20,
            height: 20,
          ),
          const SizedBox(width: 8),
          Text(
            _capitalize(track),
            style: _badgeLabelStyle.copyWith(
              color: context.palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// An outlined capsule with a 12pt bold label, 24 tall — at least: a larger
/// system text size grows it with its label rather than clipping the label
/// (Issue #351). At the default size it is exactly 24.
class CardCapsule extends StatelessWidget {
  const CardCapsule({
    required this.label,
    required this.outline,
    required this.fill,
    required this.ink,
    required this.horizontalPadding,
    super.key,
  });

  final String label;
  final Color outline;
  final Color fill;
  final Color ink;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: cardCapsuleHeight),
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        color: fill,
        // A pill at any height: at 24 this is the 12 it always was.
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: outline),
      ),
      // Centred as before, but only as large as the label: an `alignment`
      // on the box itself would stretch it to whatever its parent offers —
      // the full height once that is no longer fixed, the full width in a
      // `Wrap`.
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(label, style: _capsuleStyle.copyWith(color: ink)),
      ),
    );
  }
}

/// The program/cohort card family's top row (Issue #404) — Adult Home's
/// `ProgramCard`, the Courses tab's `CohortCard`, Teacher Schedule's
/// `TeacherClassCard` and Teacher Programs' `TeacherProgramCard`: the
/// [TrackBadge] on the left and the card's status or count [CardCapsule] on
/// the right, the capsule centred on the badge. At least the badge's 32 tall;
/// where a larger text size leaves no room for both on one line, the capsule
/// wraps under the badge rather than overlapping or clipping it
/// (Issue #351). With no [track], [trailing] keeps the row's right end; with
/// neither, nothing is drawn.
class CardBadgeRow extends StatelessWidget {
  const CardBadgeRow({super.key, this.track, this.trailing});

  /// A wire track value, as [TrackBadge] takes it; null draws no badge.
  final String? track;

  /// The status or count capsule at the row's right end.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final track = this.track;
    final trailing = this.trailing;
    if (track == null && trailing == null) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: trackBadgeHeight),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: track == null
              ? WrapAlignment.end
              : WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          // A lone capsule is centred in the 32 the badge would take.
          runAlignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [if (track != null) TrackBadge(track), ?trailing],
        ),
      ),
    );
  }
}

/// The program/cohort card family's inset (Issue #404): 16 from the side
/// edges, 24 from the top and bottom, measured from the card's outer edge —
/// so each side gives up the 1pt outline the card draws itself.
const EdgeInsets programCardPadding = EdgeInsets.fromLTRB(
  AppDimens.cardPadding - AppDimens.borderWidth,
  programCardVerticalInset - AppDimens.borderWidth,
  AppDimens.cardPadding - AppDimens.borderWidth,
  programCardVerticalInset - AppDimens.borderWidth,
);

/// The family's top and bottom inset, outline included.
const double programCardVerticalInset = 24;

/// The block pattern behind the Courses tab's and Teacher Programs' cards —
/// the Course Catalog frame's own asset, at 80%, covering the card (Issue
/// #404: shared rather than copied). [tint] recolours its shapes (Teacher
/// Programs' Junior card, which has no export of its own). Fills its parent:
/// put it first in the card's [Stack].
class CohortCardPattern extends StatelessWidget {
  const CohortCardPattern({super.key, this.tint});

  static const String asset = 'assets/icons/cohort_background.svg';

  /// How strongly the pattern shows through.
  static const double opacity = 0.8;

  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final tint = this.tint;
    return Positioned.fill(
      child: Opacity(
        opacity: opacity,
        child: SvgPicture.asset(
          asset,
          fit: BoxFit.cover,
          colorFilter: tint == null
              ? null
              : ColorFilter.mode(tint, BlendMode.srcIn),
        ),
      ),
    );
  }
}

const TextStyle _badgeLabelStyle = AppTypography.trackLabel;

const TextStyle _capsuleStyle = AppTypography.badge;

String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
