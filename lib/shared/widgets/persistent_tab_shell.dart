import 'package:flutter/material.dart';

/// A role's top-level tabs under one persistent tab bar (Issue #241).
///
/// One [Scaffold] owns the one bar, and a tab switch is a [setState]: the
/// content above the bar changes, the bar stays where it is, and only its
/// selected item moves. Tab switches never push a route, so no page
/// transition carries the bar along, and there is never a second one on
/// screen.
///
/// The tab screens are built the first time they are opened and then kept
/// (an [IndexedStack]), so returning to a tab finds it as it was left —
/// scroll position and loaded content — without loading it again. An
/// unvisited tab is not built. The hidden tabs' tickers are paused.
///
/// System back on any tab but [homeIndex] returns to it; on [homeIndex] it
/// leaves as before. Anything deeper is pushed on the app's navigator, over
/// the whole shell, bar included.
///
/// Junior (`JuniorStudentShell`) and Teacher (`TeacherShell`) are built on
/// this. The tab screens draw no bar of their own inside it.
class PersistentTabShell extends StatefulWidget {
  const PersistentTabShell({
    required this.tabCount,
    required this.tabBuilder,
    required this.barBuilder,
    super.key,
    this.initialIndex = 0,
    this.homeIndex = 0,
  }) : assert(initialIndex >= 0 && initialIndex < tabCount),
       assert(homeIndex >= 0 && homeIndex < tabCount);

  /// How many tabs have content. A bar item without content (an inert tab)
  /// is not counted and never selected.
  final int tabCount;

  /// The content of tab `index`, without a bar of its own.
  final Widget Function(int index) tabBuilder;

  /// The one bar, drawing `current` as selected and calling `select` to
  /// switch.
  final Widget Function(int current, ValueChanged<int> select) barBuilder;

  /// The tab shown first.
  final int initialIndex;

  /// Where system back returns to.
  final int homeIndex;

  @override
  State<PersistentTabShell> createState() => _PersistentTabShellState();
}

class _PersistentTabShellState extends State<PersistentTabShell> {
  late int _current = widget.initialIndex;

  /// The tabs opened so far — the only ones built.
  late final Set<int> _opened = {widget.initialIndex};

  void _select(int index) {
    if (index == _current || index < 0 || index >= widget.tabCount) return;
    setState(() {
      _current = index;
      _opened.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _current == widget.homeIndex,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(widget.homeIndex);
      },
      child: Scaffold(
        bottomNavigationBar: widget.barBuilder(_current, _select),
        body: IndexedStack(
          index: _current,
          children: [
            for (var i = 0; i < widget.tabCount; i++)
              _opened.contains(i)
                  ? TickerMode(
                      enabled: i == _current,
                      child: widget.tabBuilder(i),
                    )
                  : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
