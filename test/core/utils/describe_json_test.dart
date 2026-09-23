import 'package:aia_mobile/core/utils/describe_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('describeJsonLines', () {
    test('null is nothing to show', () {
      expect(describeJsonLines(null), isEmpty);
    });

    test('an empty or blank string is nothing to show', () {
      expect(describeJsonLines(''), isEmpty);
      expect(describeJsonLines('   '), isEmpty);
    });

    test('a plain string is one line', () {
      expect(describeJsonLines('Basic computer literacy'), ['Basic computer literacy']);
    });

    test('a string is trimmed', () {
      expect(describeJsonLines('  spaced  '), ['spaced']);
    });

    test('a number or boolean becomes its text form', () {
      expect(describeJsonLines(24), ['24']);
      expect(describeJsonLines(3.5), ['3.5']);
      expect(describeJsonLines(true), ['true']);
    });

    test('a flat list of strings is one line per string, in order', () {
      expect(describeJsonLines(['Laptop', 'Course materials', 'Certificate']), [
        'Laptop',
        'Course materials',
        'Certificate',
      ]);
    });

    test('an empty list is nothing to show', () {
      expect(describeJsonLines([]), isEmpty);
    });

    test('a null or blank item inside a list is skipped, not a blank line', () {
      expect(describeJsonLines(['a', null, '', 'b']), ['a', 'b']);
    });

    test('a flat map renders each entry as "key: value"', () {
      expect(describeJsonLines({'name': 'Bat', 'title': 'Lead instructor'}), [
        'name: Bat',
        'title: Lead instructor',
      ]);
    });

    test('an empty map is nothing to show', () {
      expect(describeJsonLines(<String, Object?>{}), isEmpty);
    });

    test('a list of maps renders every entry of every map, in order', () {
      final value = [
        {'name': 'Bat', 'title': 'Lead'},
        {'name': 'Sara', 'title': 'Assistant'},
      ];
      expect(describeJsonLines(value), [
        'name: Bat',
        'title: Lead',
        'name: Sara',
        'title: Assistant',
      ]);
    });

    test('nesting flattens instead of losing inner values', () {
      final value = {
        'week1': {'topic': 'Intro', 'hours': 4},
      };
      expect(describeJsonLines(value), ['topic: Intro', 'hours: 4']);
    });

    test('a null value inside a map contributes no line, key included', () {
      expect(describeJsonLines({'a': 'x', 'b': null}), ['a: x']);
    });
  });

  group('preferMongolianText', () {
    test('returns the Mongolian value when present', () {
      expect(
        preferMongolianText({'en': 'Hello', 'mn': 'Сайн байна уу'}),
        'Сайн байна уу',
      );
    });

    test('falls back to English when Mongolian is null or blank', () {
      expect(preferMongolianText({'en': 'Hello', 'mn': null}), 'Hello');
      expect(preferMongolianText({'en': 'Hello', 'mn': '   '}), 'Hello');
    });

    test('returns null when neither is a non-empty string', () {
      expect(preferMongolianText({'en': null, 'mn': null}), isNull);
      expect(preferMongolianText(<String, Object?>{}), isNull);
    });

    test('returns null for anything that is not a map', () {
      expect(preferMongolianText('A hands-on bootcamp'), isNull);
      expect(preferMongolianText(['a', 'b']), isNull);
      expect(preferMongolianText(null), isNull);
    });
  });
}
