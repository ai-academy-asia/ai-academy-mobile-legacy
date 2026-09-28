/// Every word on the splash screen.
///
/// The wordmark is drawn from [SplashAssets.wordmark] (outlined vector paths,
/// exactly as the Figma frame constructs it) rather than as live text, so
/// these two lines no longer render directly. They are kept because the
/// artwork still has to *say* something to a screen reader — see
/// [wordmarkSemanticsLabel], which is what the splash passes to the SVG.
abstract final class SplashStrings {
  static const String wordmarkLine1 = 'AI academy';
  static const String wordmarkLine2 = 'Asia';

  /// Announced in place of the wordmark artwork. One line rather than two:
  /// the line break is a typographic choice in the artwork, not a pause.
  static const String wordmarkSemanticsLabel = '$wordmarkLine1 $wordmarkLine2';
}

/// The splash screen's own assets, both exported from the Figma Splash frame.
abstract final class SplashAssets {
  /// The gradient "A" mark with its sparkle.
  ///
  /// A PNG, not an SVG, and deliberately so: the mark's own SVG export from
  /// Figma carries the artwork as a `<pattern>` wrapping an embedded raster
  /// rather than as vector paths, and `flutter_svg` silently paints nothing
  /// for that construction — it reports the correct intrinsic size and draws
  /// zero pixels. This 440 x 388 export is 4x the rendered 96pt height, so it
  /// is not upscaled at 3x or 4x device density.
  static const String mark = 'assets/images/splash_mark.png';

  /// "AI academy / Asia", as outlined vector paths filled `#14053D` — the
  /// same value as `AppColors.navy`. Genuine vector, unlike [mark].
  static const String wordmark = 'assets/images/splash_wordmark.svg';
}
