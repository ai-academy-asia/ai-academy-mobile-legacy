import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import 'app_locale_controller.dart';
import 'locale_preference.dart';

/// The app's own UI strings in the selected language (Issue #503), read
/// without a [BuildContext].
///
/// Generated from `lib/l10n/*.arb` (`flutter gen-l10n`, see `l10n.yaml`) and
/// read by each feature's `*_strings.dart`, so a screen, a repository or the
/// push handler reads `SignOutStrings.title` exactly as before. The language
/// is [AppLocaleController.instance]'s — the one the root `MaterialApp` is
/// given and every Profile MN/EN control writes — so there is no second
/// language state.
///
/// **A context-free read does not rebuild anything by itself.** A widget
/// that read a string draws it until it next builds; [L10nRebuildScope], at
/// the app root, rebuilds every mounted widget once when the language
/// changes, so the new strings are drawn at once. Text kept outside a build
/// — computed when data loads and stored — keeps the language it was made
/// in until it is computed again.
///
/// This is not where the API's bilingual `{"mn", "en"}` text is chosen: that
/// stays `preferredText` (`core/models/localized_text.dart`).
abstract final class L10n {
  /// The strings for the selected language.
  static AppLocalizations get current =>
      of(AppLocaleController.instance.preference);

  /// The strings for [preference] — one set per language, made once.
  static AppLocalizations of(LocalePreference preference) =>
      switch (preference) {
        LocalePreference.mongolian => _mongolian,
        LocalePreference.english => _english,
      };

  static final AppLocalizations _mongolian = lookupAppLocalizations(
    LocalePreference.mongolian.locale,
  );
  static final AppLocalizations _english = lookupAppLocalizations(
    LocalePreference.english.locale,
  );
}

/// Rebuilds everything below it once whenever [controller] changes language
/// (Issue #503), so text read through [L10n.current] is drawn in the new
/// language at once — on the visible screen, a route under it, a tab kept
/// alive in an `IndexedStack`, and an open dialog alike.
///
/// A rebuild, not a remount: every widget keeps its state — navigation,
/// scroll positions, text fields, controllers. Widgets read strings through
/// static getters and so register no dependency a language change could
/// notify; a theme or `Localizations` rebuild reaches only some of them,
/// which is why this does not rely on either. The cost is one full rebuild
/// per language change, which only a person tapping MN/EN causes.
class L10nRebuildScope extends StatefulWidget {
  const L10nRebuildScope({super.key, this.controller, required this.child});

  /// Defaults to [AppLocaleController.instance] — the controller
  /// [L10n.current] reads.
  final AppLocaleController? controller;

  final Widget child;

  @override
  State<L10nRebuildScope> createState() => _L10nRebuildScopeState();
}

class _L10nRebuildScopeState extends State<L10nRebuildScope> {
  late AppLocaleController _controller;

  AppLocaleController get _target =>
      widget.controller ?? AppLocaleController.instance;

  @override
  void initState() {
    super.initState();
    _controller = _target..addListener(_languageChanged);
  }

  @override
  void didUpdateWidget(L10nRebuildScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _target;
    if (identical(target, _controller)) return;
    _controller.removeListener(_languageChanged);
    _controller = target..addListener(_languageChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_languageChanged);
    super.dispose();
  }

  void _languageChanged() {
    // Elements cannot be walked while a frame is building them; a change
    // made then is applied once that frame is done.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _rebuildAll());
    } else {
      _rebuildAll();
    }
  }

  void _rebuildAll() {
    if (!mounted) return;
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
