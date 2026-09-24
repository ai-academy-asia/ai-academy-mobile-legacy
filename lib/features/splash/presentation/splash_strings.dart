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
  /// The bundled icon mark — the same image the Home header's brand lockup
  /// uses. The wordmark beside it is drawn as text ([SplashStrings]) rather
  /// than baked into an image, so the two can animate in on the storyboard's
  /// separate schedule: the icon first, alone and centred; the wordmark only
  /// once the icon has already moved aside for it.
  static const String icon = 'assets/images/ai_academy_app_icon.png';
}
