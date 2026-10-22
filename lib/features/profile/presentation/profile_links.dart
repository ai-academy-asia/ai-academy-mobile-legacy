import 'package:flutter/material.dart';

import '../../../core/utils/open_external_url.dart';
import 'profile_strings.dart';

/// The published pages the Profile "Contact" rows open — on Adult, Junior
/// and Teacher Profile alike. The owner's confirmed URLs; nothing else in
/// the app links to them.
abstract final class ProfileLinks {
  /// "Privacy Policy".
  static final Uri privacyPolicy = Uri.parse(
    'https://ai-academy.asia/mn/privacy-policy',
  );

  /// "Term of Service".
  static final Uri termsOfService = Uri.parse(
    'https://ai-academy.asia/en/terms',
  );
}

/// Opens [url] outside the app through [openUrl] — [openExternalUrl]
/// unless a test injects one — and, when the OS opens nothing, says so in a
/// snack bar with the Profile's own generic error line: the same treatment
/// the Certificate screen gives a download link it could not open.
Future<void> openProfileLink(
  BuildContext context,
  Uri url, {
  Future<bool> Function(Uri url)? openUrl,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final opened = await (openUrl ?? openExternalUrl)(url);
  if (opened) return;
  messenger?.showSnackBar(
    SnackBar(content: Text(ProfileStrings.unexpectedError)),
  );
}
