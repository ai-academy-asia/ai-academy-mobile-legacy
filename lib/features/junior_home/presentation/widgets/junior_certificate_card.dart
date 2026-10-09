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
    // The map's not-yet-reached grey (`juniorMutedFill`) in the `outline`,
    // as a locked node is drawn.
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: JuniorMapGeometry.certificatePadding * scale,
        vertical: JuniorMapGeometry.certificateVerticalPadding * scale,
      ),
      decoration: BoxDecoration(
        color: palette.juniorMutedFill,
        borderRadius: BorderRadius.circular(
          JuniorMapGeometry.certificateRadius * scale,
        ),
        border: Border.all(color: palette.outline, width: 1 * scale),
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
            style: AppTypography.heading.copyWith(
              fontSize: 18 * scale,
              height: 1.1,
              color: palette.accentText,
            ),
          ),
          SizedBox(height: 21.2 * scale),
          Text(
            certificate.description,
            textAlign: TextAlign.center,
            style: AppTypography.heading.copyWith(
              fontSize: 18 * scale,
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
    return Container(
      height: JuniorMapGeometry.certificatePillHeight * scale,
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
            style: AppTypography.heading.copyWith(
              fontSize: 14 * scale,
              height: 1.1,
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
