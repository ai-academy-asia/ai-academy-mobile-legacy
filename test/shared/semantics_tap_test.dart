import 'dart:io';

import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/profile/presentation/widgets/profile_parts.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_pill_button.dart';
import 'package:aia_mobile/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// A control whose `Semantics` excludes its children must carry their tap
/// itself, or a screen reader announces a button it cannot activate
/// (Issues #359, #402).
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    ),
  );

  SemanticsData dataOf(WidgetTester tester, Finder finder) =>
      tester.getSemantics(finder).getSemanticsData();

  /// What a screen reader's activate gesture does: the node's own tap action.
  void activate(WidgetTester tester, Finder finder) {
    final node = tester.getSemantics(finder);
    node.owner!.performAction(node.id, SemanticsAction.tap);
  }

  group('PillButton', () {
    testWidgets('activated through the semantics tree, it runs its action', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pump(
        tester,
        PillButton(label: 'Ирц бүртгэх', onPressed: () => taps++),
      );
      final pill = find.byType(PillButton);
      expect(dataOf(tester, pill).hasAction(SemanticsAction.tap), isTrue);
      activate(tester, pill);
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('disabled, it offers no action', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        const PillButton(label: 'Ирц бүртгэх', onPressed: null),
      );
      expect(
        dataOf(tester, find.byType(PillButton)).hasAction(SemanticsAction.tap),
        isFalse,
      );
      semantics.dispose();
    });
  });

  group('TeacherPillButton', () {
    testWidgets('activated through the semantics tree, it runs its action', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pump(
        tester,
        TeacherPillButton(label: 'Баталгаажуулах', onPressed: () => taps++),
      );
      final pill = find.byType(TeacherPillButton);
      expect(dataOf(tester, pill).hasAction(SemanticsAction.tap), isTrue);
      activate(tester, pill);
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('the disabled variant offers no action, even with a callback', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pump(
        tester,
        TeacherPillButton(
          label: 'Ирц бүртгэх',
          onPressed: () => taps++,
          variant: TeacherPillVariant.disabled,
        ),
      );
      expect(
        dataOf(
          tester,
          find.byType(TeacherPillButton),
        ).hasAction(SemanticsAction.tap),
        isFalse,
      );
      expect(taps, 0);
      semantics.dispose();
    });
  });

  testWidgets('ProfileSwitch: activated, it flips; inert, it offers nothing', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    bool? flippedTo;
    await pump(
      tester,
      ProfileSwitch(
        value: false,
        onChanged: (v) => flippedTo = v,
        semanticLabel: 'Dark mode',
      ),
    );
    final toggle = find.byType(ProfileSwitch);
    activate(tester, toggle);
    expect(flippedTo, isTrue);

    await pump(
      tester,
      const ProfileSwitch(
        value: false,
        onChanged: null,
        semanticLabel: 'Notification',
      ),
    );
    expect(dataOf(tester, toggle).hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });

  test('every button or switch that excludes its children carries onTap', () {
    // `Semantics(button: true | toggled: …, excludeSemantics: true)` drops
    // the child's tap with its semantics; the node must declare `onTap:`
    // itself — null for a control that is off.
    final semantics = RegExp(r'Semantics\(');
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final match in semantics.allMatches(source)) {
        final child = source.indexOf('child:', match.end);
        if (child < 0) continue;
        final head = source.substring(match.end, child);
        final control =
            head.contains('button: true') || head.contains('toggled:');
        if (control &&
            head.contains('excludeSemantics: true') &&
            !head.contains('onTap:')) {
          final line = '\n'.allMatches(source.substring(0, match.start)).length;
          offenders.add('${file.path}:${line + 1}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
