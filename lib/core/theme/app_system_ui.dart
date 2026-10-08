import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The status-bar and Android navigation-bar styling every screen gives its
/// `AnnotatedRegion<SystemUiOverlayStyle>` (Dark Mode Phase 4, Issue #260).
///
/// System UI follows the same path as the app's colours: the one
/// `AppThemeController` sets `MaterialApp`'s `ThemeMode`, which decides the
/// active [Theme]; [page] reads that theme's brightness. A theme change
/// rebuilds the screens, their regions take the new style, and Flutter
/// pushes it to the platform — no screen keeps its own theme state.
///
/// Two treatments, and only two:
///
///  * [page] — a screen over the app's own ground. Dark icons on a light
///    theme, light icons on a dark one.
///  * [overDarkContent] — a screen whose status bar sits over content that
///    is dark in **every** theme: the attendance scanner's camera and scrim,
///    Teacher Schedule's blue header band. Light icons always.
///
/// **Light mode is exactly what it was.** [page] under a light theme is
/// `SystemUiOverlayStyle.dark.copyWith(statusBarColor: transparent,
/// systemNavigationBarColor: …)`, field for field, as the screens wrote it
/// before. That includes Flutter's `.dark` asking Android for *light*
/// navigation-bar icons (`systemNavigationBarIconBrightness:
/// Brightness.light`) over the white bar — a pre-existing quirk kept as is,
/// and flagged in `DARK_MODE_ARCHITECTURE_AUDIT.md` §8 rather than changed
/// here.
abstract final class AppSystemUi {
  /// A screen over the app's own ground. [navigationBar] is the colour at
  /// the screen's bottom edge — the palette role the page ends on.
  static SystemUiOverlayStyle page(
    BuildContext context, {
    required Color navigationBar,
  }) {
    final base = Theme.of(context).brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return base.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: navigationBar,
    );
  }

  /// A screen whose status bar sits over content that is dark in every
  /// theme. Null [navigationBar] keeps the base style's own (black), as the
  /// attendance scanner always has.
  static SystemUiOverlayStyle overDarkContent({Color? navigationBar}) =>
      SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: navigationBar,
      );
}
