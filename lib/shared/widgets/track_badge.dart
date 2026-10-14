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
/// [CardPattern] (Issue #404). Shared rather than copied, so the
/// cards cannot drift apart. Moved here from
/// `home/presentation/widgets/home_badges.dart` (Issue #329), with
/// `HomeCapsule` renamed [CardCapsule]: other features draw them, so they do
/// not belong to Home.
const double trackBadgeHeight = 32;

/// Whether [track] — a student's `ui_mode` or a course's `level` — is one of
/// the younger tracks: what draws the junior mark and tints the card's
/// pattern orange.
bool isJuniorTrack(String? track) {
  final mode = track?.toLowerCase();
  return mode == 'junior' || mode == 'kids';
}

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
    final isJunior = isJuniorTrack(track);

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
/// the right, **hung from the badge's top edge** — every Figma frame that
/// draws the pair does so (Home Page1, Course Catalog, e-contract1 and the
/// schedule sheet: the capsule's top on the badge's, its centre 4 above the
/// badge's). At least the badge's 32 tall; where a larger text size leaves no
/// room for both on one line, the capsule wraps under the badge rather than
/// overlapping or clipping it (Issue #351). With no [track], [trailing] keeps
/// the row's top-right corner; with neither, nothing is drawn.
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
          crossAxisAlignment: WrapCrossAlignment.start,
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

/// The card family's block pattern — on every program/cohort card, Teacher
/// Programs and the schedule session card included (Issue #408) — as every
/// Figma frame that draws it on a student card draws it (Issue #404): the
/// one artwork at 1:1 from the card's top-left, at full strength, on the
/// card's white `surface` — Home Page1,
/// Course Catalog (a taller card included) and e-contract1 are pixel-identical
/// there. A 12% blue tint with the white blocks cut out of it, which also
/// shades the card from near-white at the leading edge to pale blue at the
/// trailing one; beyond its 361 × 208 the card stays white. [asset] is the
/// Course Catalog card's own export (`cohort_background.svg`) unchanged but
/// for a 208-tall viewBox, so a taller card shows more of the same pattern
/// rather than a scaled-up one. Fills its parent: put it first in the card's
/// [Stack].
class CardPattern extends StatelessWidget {
  const CardPattern({super.key, this.track});

  static const String asset = 'assets/icons/program_card_background.svg';

  /// The card's track, as [TrackBadge] takes it. A junior track draws the
  /// same shapes in [AppPalette.programJuniorTint], the Junior mark's orange
  /// (no Junior export exists — Issue #390); any other, or none, the
  /// artwork's own blue. Decided here, so no card tints it on its own.
  final String? track;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: SvgPicture.asset(
        asset,
        fit: BoxFit.none,
        alignment: Alignment.topLeft,
        colorFilter: isJuniorTrack(track)
            ? ColorFilter.mode(
                context.palette.programJuniorTint,
                BlendMode.srcIn,
              )
            : null,
      ),
    );
  }
}

const TextStyle _badgeLabelStyle = AppTypography.trackLabel;

const TextStyle _capsuleStyle = AppTypography.badge;

String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
