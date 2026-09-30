import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hands [url] to the OS to open outside the app — the browser, or whichever
/// app the platform picks for the file behind it — and answers whether it
/// did.
///
/// The one place this app calls `url_launcher`. Callers take it as an
/// injectable `Future<bool> Function(Uri)` so widget and controller tests
/// never reach the platform channel. A launch the platform refuses — no app
/// can open it, or the channel itself fails — is `false`, not a throw: the
/// caller shows its own copy for it.
Future<bool> openExternalUrl(Uri url) async {
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } on PlatformException {
    return false;
  }
}
