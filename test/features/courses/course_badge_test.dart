import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/courses/presentation/widgets/course_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_course_repository.dart';

/// The course detail's classifying pills (Issue #426): category is optional,
/// so a course without one draws level, format and status — never an empty or
/// "null" pill.
void main() {
  Future<void> pumpBadges(WidgetTester tester, {required String? category}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: CourseBadges(course: sampleCourse(category: category)),
          ),
        ),
      );

  List<String> labels(WidgetTester tester) => tester
      .widgetList<CourseBadge>(find.byType(CourseBadge))
      .map((badge) => badge.label)
      .toList();

  testWidgets('a course with a category draws all four, category first', (
    tester,
  ) async {
    await pumpBadges(tester, category: 'bootcamp');

    expect(labels(tester), ['bootcamp', 'junior', 'in_person', 'open']);
  });

  testWidgets('no category: level, format and status only', (tester) async {
    await pumpBadges(tester, category: null);

    expect(labels(tester), ['junior', 'in_person', 'open']);
    expect(find.textContaining('null'), findsNothing);
  });

  testWidgets('a blank category draws no empty pill', (tester) async {
    for (final blank in ['', '   ']) {
      await pumpBadges(tester, category: blank);

      expect(labels(tester), [
        'junior',
        'in_person',
        'open',
      ], reason: '"$blank"');
    }
  });

  testWidgets('a category is shown verbatim, not trimmed or mapped', (
    tester,
  ) async {
    await pumpBadges(tester, category: ' Summer camp ');

    expect(labels(tester).first, ' Summer camp ');
  });
}
