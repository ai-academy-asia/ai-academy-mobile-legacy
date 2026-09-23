/// Every word on the splash screen.
///
/// Drawn as live text rather than read off the bundled logo image — see
/// [SplashAssets.logo]'s own doc comment for why — so it can carry its own
/// colour ([AppTypography.splashWordmark]) and fade in on its own schedule.
abstract final class SplashStrings {
  static const String wordmarkLine1 = 'AI academy';
  static const String wordmarkLine2 = 'Asia';
}

/// The splash screen's own assets.
abstract final class SplashAssets {
  /// The bundled brand lockup: the icon mark and the "AI academy Asia"
  /// wordmark, flattened into one exported PNG (320 x 97).
  ///
  /// `SplashScreen` shows only this image's icon — its opaque pixels run from
  /// column 1 to column 105, then a transparent gap runs to column 125
  /// before the wordmark starts — and draws the wordmark itself as text
  /// instead of the image's own baked-in copy, so the two can animate in on
  /// the storyboard's separate schedule: the icon first, alone and centred;
  /// the wordmark only once the icon has already moved aside for it.
  static const String logo = 'assets/images/ai_academy_logo.png';
}
