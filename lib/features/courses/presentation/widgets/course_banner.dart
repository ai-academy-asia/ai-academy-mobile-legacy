import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';

/// A course's banner image, 16:9, with rounded corners matching the design
/// system's field radius. Caller supplies [url] only when
/// `course.bannerImageUrl` is non-null — an empty image slot for a course
/// without one is not this widget's decision to make.
class CourseBanner extends StatelessWidget {
  const CourseBanner({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : ColoredBox(color: context.palette.surfaceMuted),
          errorBuilder: (context, error, stackTrace) =>
              ColoredBox(color: context.palette.surfaceMuted),
        ),
      ),
    );
  }
}
