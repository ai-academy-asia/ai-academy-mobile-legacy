import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_typography.dart';
import '../../core/theme/app_palette.dart';

/// The outlined track badge (32 tall) and the outlined capsule (24 tall) the
/// cards draw in their top row — Adult Home's `ProgramCard`, Teacher Home's
/// class card (Issue #229) and the gradebook, and the E-Contract card, whose
/// references draw the same two parts. Shared rather than copied, so the
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
      // 5 | 20 icon | 8 | label | 9.5, inside the 1pt outline.
      height: trackBadgeHeight,
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

/// A 24-tall outlined capsule with a 12pt bold label.
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
      height: cardCapsuleHeight,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(cardCapsuleHeight / 2),
        border: Border.all(color: outline),
      ),
      child: Text(label, style: _capsuleStyle.copyWith(color: ink)),
    );
  }
}

final TextStyle _badgeLabelStyle = AppTypography.catalogTrackLabel.copyWith(
  fontSize: 16,
  height: 1,
);

final TextStyle _capsuleStyle = AppTypography.catalogStatusLabel.copyWith(
  fontSize: 12,
  height: 16 / 12,
);

String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
