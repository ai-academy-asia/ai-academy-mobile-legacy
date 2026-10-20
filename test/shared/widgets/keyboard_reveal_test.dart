import 'package:aia_mobile/shared/widgets/keyboard_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [KeyboardRevealField] and [KeyboardRevealArea] (Issue #463) on a bare
/// page: a resizing `Scaffold`, one scroll view, a 118pt textarea and a
/// 48pt action 16 below it, with room above and below to scroll.
void main() {
  const actionKey = Key('action');
  const below = Key('below');

  /// [above] of empty page over the form; [withArea] wraps the field and
  /// the action in a [KeyboardRevealArea].
  Future<void> pumpPage(
    WidgetTester tester, {
    Size size = const Size(393, 852),
    double above = 400,
    bool withArea = true,
    EdgeInsets scrollPadding = const EdgeInsets.all(20),
    VoidCallback? onAction,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyboardRevealField(
          scrollPadding: scrollPadding,
          child: SizedBox(
            height: 118,
            child: TextField(maxLines: 6, scrollPadding: scrollPadding),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          key: actionKey,
          height: 48,
          child: TextButton(onPressed: onAction, child: const Text('Submit')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: above),
                if (withArea) KeyboardRevealArea(child: form) else form,
                const SizedBox(key: below, height: 600),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Finder field() => find.byType(KeyboardRevealField);
  Finder action() => find.byKey(actionKey);
  Finder text() => find.byType(EditableText);

  Future<void> focusWithKeyboard(WidgetTester tester, double keyboard) async {
    await tester.tap(field());
    await tester.pump();
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    await tester.pumpAndSettle();
  }

  void expectAbove(
    WidgetTester tester,
    Finder finder,
    double visibleBottom, {
    double clear = 0,
  }) {
    final rect = tester.getRect(finder);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(visibleBottom - clear));
  }

  testWidgets('room for both: the whole field and the action, with the '
      'padding clear', (tester) async {
    await pumpPage(tester);
    await focusWithKeyboard(tester, 336);

    expectAbove(tester, field(), 516, clear: 20);
    expectAbove(tester, action(), 516, clear: 20);
  });

  testWidgets('typing in a revealed field moves nothing', (tester) async {
    await pumpPage(tester);
    await focusWithKeyboard(tester, 336);
    final before = tester.getRect(action());

    await tester.enterText(find.byType(TextField), 'one\ntwo\nthree\nfour');
    await tester.pumpAndSettle();

    expect(tester.getRect(action()), before);
  });

  testWidgets('no room for both with padding: the caret line through the '
      'action, tight', (tester) async {
    // 213 above the keyboard: 118 + 16 + 48 fits only without the padding.
    await pumpPage(tester, size: const Size(852, 393), above: 300);
    await focusWithKeyboard(tester, 180);

    expectAbove(tester, action(), 213);
    expectAbove(tester, text(), 213);
  });

  testWidgets('no room even for that: the caret alone', (tester) async {
    await pumpPage(tester, size: const Size(852, 393), above: 300);
    await focusWithKeyboard(tester, 260);

    final caretLine = tester.getRect(text());
    expect(caretLine.top, greaterThanOrEqualTo(0));
    expect(caretLine.top, lessThan(393 - 260));
  });

  testWidgets('outside an area the field alone is revealed — the action '
      'below stays where it falls', (tester) async {
    await pumpPage(tester, withArea: false);
    await focusWithKeyboard(tester, 336);

    expectAbove(tester, field(), 516, clear: 20);
    expect(tester.getRect(action()).bottom, greaterThan(516));
  });

  testWidgets('the field\'s own scrollPadding is the margin kept', (
    tester,
  ) async {
    const padding = EdgeInsets.all(40);
    await pumpPage(tester, scrollPadding: padding);
    await focusWithKeyboard(tester, 336);

    expectAbove(tester, action(), 516, clear: 40);
  });

  testWidgets('keyboard closed: focusing a field already in view moves '
      'nothing', (tester) async {
    await pumpPage(tester, above: 100);
    final before = tester.getRect(field());

    await tester.tap(field());
    await tester.pumpAndSettle();

    expect(tester.getRect(field()), before);
  });

  testWidgets('the area changes no hit testing: the action still taps', (
    tester,
  ) async {
    var taps = 0;
    await pumpPage(tester, onAction: () => taps++);
    await focusWithKeyboard(tester, 336);

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(taps, 1);
  });
}
