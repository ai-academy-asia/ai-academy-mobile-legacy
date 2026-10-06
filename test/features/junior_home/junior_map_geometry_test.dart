import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_map_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

/// The route sized to the student's own modules (Issue #202).
void main() {
  Matcher near(Offset o) => isA<Offset>()
      .having((v) => v.dx, 'dx', closeTo(o.dx, 1e-9))
      .having((v) => v.dy, 'dy', closeTo(o.dy, 1e-9));

  void expectConnector(JuniorConnector actual, JuniorConnector expected) {
    expect(actual.from, near(expected.from));
    expect(actual.corner, near(expected.corner));
    expect(actual.to, near(expected.to));
    expect(actual.active, expected.active);
  }

  test('the first five nodes are the frame\'s own', () {
    for (var i = 0; i < 5; i++) {
      expect(JuniorMapGeometry.nodeAt(i), near(JuniorMapGeometry.nodes[i]));
    }
  });

  test('the frame\'s states give back the frame\'s route, card and height', () {
    final route = JuniorMapGeometry.route([true, true, false, false, false]);
    expect(route, hasLength(5));
    for (var i = 0; i < 5; i++) {
      expectConnector(route[i], JuniorMapGeometry.connectors[i]);
    }
    expect(
      JuniorMapGeometry.certificateFor(5).top,
      closeTo(JuniorMapGeometry.certificateCard.top, 1e-9),
    );
    expect(
      JuniorMapGeometry.mapHeightFor(5),
      closeTo(JuniorMapGeometry.mapHeight, 1e-9),
    );
  });

  test('beyond five, the route keeps the frame\'s zig-zag', () {
    expect(JuniorMapGeometry.nodeAt(5), near(const Offset(277, 702.7)));
    expect(JuniorMapGeometry.nodeAt(6), near(const Offset(154.7, 811)));
    expect(JuniorMapGeometry.nodeAt(7), near(const Offset(32, 919.7)));
    expect(JuniorMapGeometry.nodeAt(8), near(const Offset(154.7, 1028)));
    // Each node is lower than the one before.
    for (var i = 1; i < 12; i++) {
      expect(
        JuniorMapGeometry.nodeAt(i).dy,
        greaterThan(JuniorMapGeometry.nodeAt(i - 1).dy),
      );
    }
  });

  group('no line past the student\'s own stops', () {
    for (final count in [1, 2, 3, 4, 5, 6, 7, 9]) {
      test('$count node${count == 1 ? '' : 's'}', () {
        final route = JuniorMapGeometry.route(List.filled(count, false));
        expect(route, hasLength(count));
        final card = JuniorMapGeometry.certificateFor(count);
        final lastNode = JuniorMapGeometry.nodeAt(count - 1);

        // Every connector but the last starts and ends on a node; the last
        // starts on the last node and stops just above the card.
        for (final c in route) {
          expect(c.to.dy, lessThanOrEqualTo(card.top));
        }
        expect(route.last.to.dy, closeTo(card.top - 3.7, 1e-9));
        expect(route.last.from.dy, greaterThanOrEqualTo(lastNode.dy));
        expect(card.top, closeTo(lastNode.dy + 111.7, 1e-9));
        expect(
          JuniorMapGeometry.mapHeightFor(count),
          closeTo(card.bottom + 147.3, 1e-9),
        );
      });
    }
  });

  test('a side node drops straight into the card', () {
    // Four nodes: the last is in the left column.
    final last = JuniorMapGeometry.route(List.filled(4, false)).last;
    expect(last.from, near(const Offset(74, 569.7)));
    expect(last.to.dx, closeTo(74, 1e-9));
    expect(last.corner, near(last.to));
  });

  test('a stretch is blue once both of its nodes are completed', () {
    expect(
      [
        for (final c in JuniorMapGeometry.route([true, true, true])) c.active,
      ],
      [true, true, true],
    );
    expect(
      [
        for (final c in JuniorMapGeometry.route([true, true, false])) c.active,
      ],
      [true, false, false],
    );
    expect(
      [
        for (final c in JuniorMapGeometry.route([true, false, true])) c.active,
      ],
      [false, false, false],
    );
  });

  test('no nodes, no route; the card takes the first node\'s place', () {
    expect(JuniorMapGeometry.route(const []), isEmpty);
    expect(
      JuniorMapGeometry.certificateFor(0).top,
      JuniorMapGeometry.nodes.first.dy,
    );
  });
}
