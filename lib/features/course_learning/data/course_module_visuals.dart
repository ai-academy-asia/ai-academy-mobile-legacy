import 'package:flutter/widgets.dart';

/// The icon and accent colour one module card draws, picked by the module's
/// 1-based `order`.
///
/// **Client-side by contract, not by omission.**
/// `course_learning_api_contract_v1.md` §2.1 states the backend sends *no*
/// icon, image or colour for a module and that "the client maps `order` onto
/// its bundled icon/accent palette" — so there is no wire field to read here
/// and never will be. `banner_image_url` on the course is the only real image
/// the response carries, and the Figma design does not draw it.
///
/// The five entries are the ones `SampleCourseLearningRepository` transcribed
/// from the Figma reference frame, moved here so the sample path and the real
/// API path cannot drift apart: the reference's five cards are what the
/// design confirms, and a course with more modules than that repeats them
/// rather than inventing a sixth accent nothing has specified.
class CourseModuleVisuals {
  const CourseModuleVisuals({
    required this.iconAsset,
    required this.accentColor,
  });

  /// One of `assets/images/course_learning/module_*.svg`.
  final String iconAsset;

  /// Sampled from [iconAsset]'s own fill — see `CourseModule.accentColor`.
  final Color accentColor;
}

const List<CourseModuleVisuals> _palette = [
  CourseModuleVisuals(
    iconAsset: 'assets/images/course_learning/module_ai.svg',
    accentColor: Color(0xFF408CFF),
  ),
  CourseModuleVisuals(
    iconAsset: 'assets/images/course_learning/module_training.svg',
    accentColor: Color(0xFFFFC640),
  ),
  CourseModuleVisuals(
    iconAsset: 'assets/images/course_learning/module_neural_network.svg',
    accentColor: Color(0xFFBF40FF),
  ),
  CourseModuleVisuals(
    iconAsset: 'assets/images/course_learning/module_brain.svg',
    accentColor: Color(0xFFFF409C),
  ),
  CourseModuleVisuals(
    iconAsset: 'assets/images/course_learning/module_image.svg',
    accentColor: Color(0xFF40FFA3),
  ),
];

/// The palette entry for a 1-based module [order], wrapping past the fifth.
///
/// Dart's `%` never returns a negative for a positive divisor, so an `order`
/// the API sends as 0 or below still lands on a real entry rather than
/// throwing — a bad `order` is a design-data problem, not a reason to fail
/// the whole screen's parse.
CourseModuleVisuals moduleVisualsFor(int order) =>
    _palette[(order - 1) % _palette.length];
