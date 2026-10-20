import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Keeps a focused text field — and, inside a [KeyboardRevealArea], the
/// form's primary action under it — above the keyboard (Issues #459, #461,
/// #463).
///
/// On focus, and as the keyboard opens, `EditableText` asks the page's
/// scroll view to show only its caret plus `scrollPadding`: in a textarea,
/// the first line, which leaves the rest of the box and the action under it
/// behind the keyboard. This widens that request to the largest of these
/// that fits the scroll view:
///
///  1. the whole field, with [scrollPadding] around it, down through the
///     enclosing [KeyboardRevealArea]'s last child (its action) — or the
///     whole field alone outside one;
///  2. tight, with no padding: the caret line down to that action's bottom
///     edge — the field's own text scrolls inside the box above it;
///  3. the caret and its `scrollPadding` alone, as `EditableText` asked — so
///     typing is never hidden.
///
/// Flutter's own `showOnScreen` still does the scrolling, the least it can
/// to show that rect: no animation of its own, no spacer, no inset padding,
/// and a rect already on screen — while typing — moves nothing. Use it on a
/// page whose `Scaffold` resizes for the keyboard (the default) or in a
/// sheet that lifts above it, with one scrolling parent; on a page that lets
/// the keyboard cover it, nothing on screen is "hidden" to reveal.
///
/// **[scrollPadding] must be the wrapped field's own** (`TextField`'s
/// default unless it sets one): tier 2 subtracts its top from the caret
/// rect `EditableText` hands over.
class KeyboardRevealField extends SingleChildRenderObjectWidget {
  const KeyboardRevealField({
    required super.child,
    super.key,
    this.scrollPadding = const EdgeInsets.all(20),
  });

  final EdgeInsets scrollPadding;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderKeyboardRevealField(scrollPadding);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderKeyboardRevealField).scrollPadding = scrollPadding;
  }
}

/// The block of a form that ends with its primary action — the field(s)
/// above it down to "Submit". A focused [KeyboardRevealField] inside it
/// reveals itself down to this block's end, so the action is not left
/// behind the keyboard.
///
/// Draws nothing and changes no layout, hit testing or semantics. **Its
/// last child must be the action**: its bottom edge is what the reveal
/// reaches, so anything after the action (a spinner, a footer) belongs
/// outside the area.
class KeyboardRevealArea extends SingleChildRenderObjectWidget {
  const KeyboardRevealArea({required super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderKeyboardRevealArea();
}

class _RenderKeyboardRevealArea extends RenderProxyBox {}

class _RenderKeyboardRevealField extends RenderProxyBox {
  _RenderKeyboardRevealField(this.scrollPadding);

  EdgeInsets scrollPadding;

  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    final viewport = RenderAbstractViewport.maybeOf(this);
    final area = _enclosingArea(viewport);
    // Every rect in [target]'s own coordinates.
    final RenderBox target = area ?? this;
    final field = MatrixUtils.transformRect(
      getTransformTo(target),
      scrollPadding.inflateRect(Offset.zero & size),
    );
    final asked = rect == null
        ? field
        : MatrixUtils.transformRect(
            (descendant ?? this).getTransformTo(target),
            rect,
          );
    // The action's bottom edge, or the field's own outside an area.
    final end = area?.size.height ?? field.bottom - scrollPadding.bottom;
    final extent = viewport?.paintBounds.height ?? double.infinity;

    Rect span(double top, double bottom) =>
        Rect.fromLTRB(field.left, top, field.right, bottom);
    final reveal = [
      span(field.top, math.max(field.bottom, end + scrollPadding.bottom)),
      // [asked] is the caret inflated by [scrollPadding]; its top is the
      // caret line's own plus that padding.
      span(asked.top + scrollPadding.top, end),
    ].firstWhere((r) => r.height <= extent, orElse: () => asked);

    if (area == null) {
      super.showOnScreen(rect: reveal, duration: duration, curve: curve);
    } else {
      area.showOnScreen(rect: reveal, duration: duration, curve: curve);
    }
  }

  /// The nearest [KeyboardRevealArea] around this field, looking up no
  /// further than the scroll view that will do the revealing; null outside
  /// one.
  _RenderKeyboardRevealArea? _enclosingArea(RenderAbstractViewport? viewport) {
    for (var node = parent; node != null && node != viewport;) {
      if (node is _RenderKeyboardRevealArea) return node;
      node = node.parent;
    }
    return null;
  }
}
