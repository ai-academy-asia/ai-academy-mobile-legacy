import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../home/presentation/widgets/home_palette.dart';

/// The certificate artwork, framed by the exported gradient background — two
/// flat images layered, not redrawn with Flutter text/shapes. Drawn by
/// Course Module List's certification panel and by each card of the
/// Certificate screen (Issue #155), whose frame measures it the same 329:225.
///
/// The artwork is the same for every student: no confirmed response carries
/// a rendered certificate image, only an issued certificate's file behind its
/// download link.
///
/// Both source PNGs are lower resolution than where they end up drawn: at
/// this card's measured size on a 3x-density phone, `certificate.png` (305 x
/// 201 native) and `certificate_backround.png` (328 x 225 native) are each
/// upscaled roughly 3x by the renderer, which is what reads as blur/softness
/// on device — a genuine shortfall in the exported assets, not something a
/// widget property can fix. `FilterQuality.high` (`Image`'s own default is
/// `medium`) is the one improvement available without new art: Skia's best
/// resampling for that upscale, in place of its default. It measurably
/// softens the blur but cannot restore detail the source files never had —
/// the real fix is re-exporting both PNGs at a higher resolution (or as
/// proper `1.0x`/`2.0x`/`3.0x` variants).
///
/// The two frames inset the artwork differently: Module List's by 6, the
/// Certificate frame's by 12 — exactly the 305 x 201 `certificate.png` is
/// exported at inside the 329 x 225 background — with a 1pt
/// [HomePalette.border] outline round the whole. [inset] and [outlined]
/// carry that difference; the defaults are Module List's.
class CertificatePreview extends StatelessWidget {
  const CertificatePreview({super.key, this.inset = 6, this.outlined = false});

  /// The gradient background's width around the certificate.
  final double inset;

  /// Whether a 1pt outline frames the preview.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final preview = AspectRatio(
      aspectRatio: 329 / 225,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/certificate_backround.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
            Padding(
              padding: EdgeInsets.all(inset),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/certificate.png',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!outlined) return preview;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
        border: Border.all(
          color: HomePalette.border,
          width: AppDimens.borderWidth,
        ),
      ),
      child: preview,
    );
  }
}
