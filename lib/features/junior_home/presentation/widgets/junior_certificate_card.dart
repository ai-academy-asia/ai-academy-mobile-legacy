import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/junior_learning_map.dart';
import 'junior_map_geometry.dart';

/// The panel at the foot of the map: the "Junior" pill, the certificate
/// artwork, the course name, and the line that says what the student earns.
///
/// The artwork is the app's existing pair — `certificate_backround.png`
/// behind `certificate.png` — which is the same two-layer treatment
/// `CourseModuleListScreen._CertificatePreview` already draws, and is where
/// the blue-violet glow around the certificate in the reference comes from.
/// Genuinely reused, not re-exported.
class JuniorCertificateCard extends StatelessWidget {
  const JuniorCertificateCard({
    required this.certificate,
    required this.scale,
    super.key,
  });

  final JuniorCertificate certificate;

  /// The map's design-space-to-pixels factor.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // The updated reference's white card (`surface`) in a 3pt band of the
    // map's light grey (`juniorMutedFill`), measured on
    // `junior-homepage-u[date.png` (Issue #410).
    // The insets were measured inside a 1pt edge; the 3pt edge takes its
    // extra 2 out of them, so nothing inside the card moves.
    const edge = JuniorMapGeometry.certificateBorder - 1;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: (JuniorMapGeometry.certificatePadding - edge) * scale,
        vertical: (JuniorMapGeometry.certificateVerticalPadding - edge) * scale,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(
          JuniorMapGeometry.certificateRadius * scale,
        ),
        border: Border.all(
          color: palette.juniorMutedFill,
          width: JuniorMapGeometry.certificateBorder * scale,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TrackPill(label: certificate.track, scale: scale),
          SizedBox(height: 14.3 * scale),
          SizedBox(
            height: JuniorMapGeometry.certificateImageHeight * scale,
            child: _CertificateArtwork(scale: scale),
          ),
          SizedBox(height: 15 * scale),
          Text(
            certificate.courseName,
            textAlign: TextAlign.center,
            // The course's name ([AppTypography.cardTitle]), scaled with the
            // map like everything on it; its line stays the card's tight 1.1.
            style: AppTypography.cardTitle.copyWith(
              fontSize: AppTypography.cardTitle.fontSize! * scale,
              height: 1.1,
              color: palette.accentText,
            ),
          ),
          // The frame's 21.2, less the 2.2 the name's line gained at
          // [AppTypography.cardTitle]'s 20 (Issue #366) — so the description
          // and the card's foot stay exactly where the frame puts them.
          SizedBox(height: 19 * scale),
          Text(
            certificate.description,
            textAlign: TextAlign.center,
            style: AppTypography.sectionTitle.copyWith(
              fontSize: AppTypography.sectionTitle.fontSize! * scale,
              height: 1.1,
              color: palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The white capsule at the top of the panel — the orange Junior mark beside
/// the track's name. The mark is `assets/icons/junior.svg`, the app's own,
/// already used by the Home track badge.
class _TrackPill extends StatelessWidget {
  const _TrackPill({required this.label, required this.scale});

  final String label;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // At least the frame's height, and taller when a larger system text
    // size needs it: a fixed height clipped "Junior" from 2.0× (Issue #345).
    // At the default size the label sits well inside it, centred as before.
    return Container(
      constraints: BoxConstraints(
        minHeight: JuniorMapGeometry.certificatePillHeight * scale,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: palette.outline, width: 1 * scale),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Junior's track glyph, in its authored orange: role identity,
          // kept as drawn (proposal §11).
          SvgPicture.asset(
            'assets/icons/junior.svg',
            width: 14 * scale,
            height: 14 * scale,
          ),
          SizedBox(width: 8 * scale),
          Text(
            label,
            // The track's name, sized to its pill as `TrackBadge`'s is — a
            // container-sized exception to the scale (`DESIGN_SYSTEM.md` §3).
            style: AppTypography.trackLabel.copyWith(
              fontSize: 14 * scale,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The certificate itself: the exported gradient frame with the certificate
/// sitting inside it, both drawn at [FilterQuality.high] for the same reason
/// `CourseModuleListScreen` gives — the source PNGs are smaller than where
/// they land, and high is the best resampling available without new art.
class _CertificateArtwork extends StatelessWidget {
  const _CertificateArtwork({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12 * scale),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/certificate_backround.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          Padding(
            padding: EdgeInsets.all(6 * scale),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8 * scale),
              child: Image.asset(
                'assets/images/certificate.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
