import '../../../core/locale/l10n.dart';

/// Every word on the sign-out confirmation, shared by the adult and Junior
/// Profiles. No Figma frame exists for it; this is the copy the task set.
///
/// In the selected language (Issue #503): the copy lives in
/// `lib/l10n/app_*.arb` and is read through [L10n.current]. The title and
/// message have no approved English yet, so English shows them in Mongolian.
abstract final class SignOutStrings {
  static String get title => L10n.current.signOutTitle;
  static String get message => L10n.current.signOutMessage;
  static String get cancel => L10n.current.signOutCancel;
  static String get confirm => L10n.current.signOutConfirm;
}
