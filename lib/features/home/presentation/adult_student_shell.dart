import 'package:flutter/material.dart';

import '../../auth/presentation/student_tabs.dart';
import '../../cohorts/presentation/cohort_list_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import 'home_screen.dart';
import 'widgets/adult_bottom_nav.dart';

/// The Adult Student app's three tabs — Нүүр, Хичээл, Профайл — under one
/// persistent [AdultBottomNav] (Issue #237).
///
/// Each tab used to be its own route whose screen drew its own bar, so every
/// switch ran a page transition that slid the bar along with the page, and
/// showed two bars while it ran. Here the bar belongs to this one [Scaffold]
/// and a switch is a [setState]: the content above it changes, the bar stays
/// where it is, and only its selected item moves.
///
/// The tab screens are built the first time they are opened and then kept
/// (an [IndexedStack]), so returning to a tab finds it as it was left — its
/// scroll position and loaded content — without loading it again. An
/// unvisited tab is not built, so opening Home still loads only Home. The
/// hidden tabs' tickers are paused.
///
/// Anything deeper — Course detail, attendance, payment, a Profile row — is
/// pushed on the app's navigator as before, over this whole shell, bar
/// included.
///
/// System back on Хичээл or Профайл returns to Нүүр, as popping back to the
/// Home route did; on Нүүр it leaves the app as before.
class AdultStudentShell extends StatefulWidget {
  const AdultStudentShell({
    super.key,
    this.initialTab = StudentTab.home,
    this.home,
    this.progress,
    this.profile,
  });

  /// The tab shown first.
  final StudentTab initialTab;

  /// The three tab screens, each drawn without its own bar. Default to the
  /// real ones; injected in tests.
  final Widget? home;
  final Widget? progress;
  final Widget? profile;

  @override
  State<AdultStudentShell> createState() => _AdultStudentShellState();
}

class _AdultStudentShellState extends State<AdultStudentShell> {
  late StudentTab _current = widget.initialTab;

  /// The tabs opened so far — the only ones built.
  late final Set<StudentTab> _opened = {widget.initialTab};

  void _select(StudentTab tab) {
    if (tab == _current) return;
    setState(() {
      _current = tab;
      _opened.add(tab);
    });
  }

  Widget _screenFor(StudentTab tab) => switch (tab) {
    StudentTab.home => widget.home ?? const HomeScreen(showBottomNav: false),
    StudentTab.progress =>
      widget.progress ??
          const CohortListScreen(enrolledOnly: true, showBottomNav: false),
    StudentTab.profile =>
      widget.profile ?? const ProfileScreen(showBottomNav: false),
  };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _current == StudentTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(StudentTab.home);
      },
      child: Scaffold(
        bottomNavigationBar: AdultBottomNav(
          current: _current,
          onSelect: _select,
        ),
        body: IndexedStack(
          index: _current.index,
          children: [
            for (final tab in StudentTab.values)
              _opened.contains(tab)
                  ? TickerMode(enabled: tab == _current, child: _screenFor(tab))
                  : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
