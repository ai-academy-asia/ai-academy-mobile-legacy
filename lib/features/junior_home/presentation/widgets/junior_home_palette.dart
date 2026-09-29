import 'package:flutter/painting.dart';

/// The Junior map's colours, sampled from the reference frame at 1:1.
///
/// Screen-local rather than added to [AppColors], for the reason the design
/// system already gives for screen-local tokens: these are one frame's
/// palette. The three neutrals below (`#D6DBE1`, `#EAEDF0`, `#F9FAFB`) are
/// already in the app — the first two as `CourseModuleListScreen`'s own
/// constants, the third as `AppColors.surfaceSubtle` — so nothing new is
/// introduced here beyond the pale-blue field the Junior world is drawn on.
abstract final class JuniorPalette {
  /// The pale blue field. Only ever seen where the backdrop image does not
  /// reach, so it is [Scaffold]'s colour behind the artwork rather than a
  /// fill anything paints.
  static const Color mapField = Color(0xFFBFD9F8);

  /// The Junior frames' own blue. Four points off [AppColors.blue]
  /// (`#296CFF`) and kept separate for the same reason
  /// `CourseModuleListScreen` keeps its own `#2970FF`: the shared token is
  /// sampled from the Login frame, and moving it to match this screen would
  /// repaint every other one.
  static const Color accent = Color(0xFF2970FF);

  /// The course card, and a completed node's fill.
  static const Color cardFill = Color(0xFFEFF4FF);
  static const Color cardBorder = Color(0xFFD1D3F5);

  /// The ring's untravelled arc, the locked half of the route, and every
  /// node outline that is not the active blue.
  static const Color muted = Color(0xFFD6DBE1);

  /// A locked node's fill, and the certificate panel's.
  static const Color mutedFill = Color(0xFFEAEDF0);

  /// The "Junior" pill.
  static const Color pillFill = Color(0xFFF9FAFB);

  /// A node's lift off the map.
  ///
  /// Not a blurred shadow: measured down the centre of all three states, the
  /// frame draws exactly 9 of the node's *own outline colour* below it — 3 of
  /// border and a flat 6 band under that, with no gradient. So this is a
  /// zero-blur shadow of the node's own rounded square, offset down, which is
  /// the same depth idiom `CourseModuleCard` and `ExerciseSubmitButton`
  /// already use.
  ///
  /// The colour is the node's border, so it is passed in rather than fixed
  /// here — blue under a completed node, grey under the other two.
  ///
  /// The node must keep an opaque fill on the same decoration: a zero-blur
  /// shadow paints the whole silhouette, so without one it covers the node.
  static List<BoxShadow> nodeDepth(Color border, double offset) => [
    BoxShadow(color: border, offset: Offset(0, offset)),
  ];
}
