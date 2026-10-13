import 'dart:io';

import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app's semantic type scale (Issue #366): one style per role, the same
/// on every screen, and no screen drifting back to sizes of its own.
void main() {
  const roles = <String, TextStyle>{
    'display': AppTypography.display,
    'screenTitle': AppTypography.screenTitle,
    'headerTitle': AppTypography.headerTitle,
    'cardTitle': AppTypography.cardTitle,
    'sectionTitle': AppTypography.sectionTitle,
    'itemTitle': AppTypography.itemTitle,
    'itemLabel': AppTypography.itemLabel,
    'body': AppTypography.body,
    'bodyStrong': AppTypography.bodyStrong,
    'supporting': AppTypography.supporting,
    'caption': AppTypography.caption,
    'dateTime': AppTypography.dateTime,
    'buttonLabel': AppTypography.buttonLabel,
    'buttonSmall': AppTypography.buttonSmall,
    'tabLabel': AppTypography.tabLabel,
    'navLabel': AppTypography.navLabel,
    'badge': AppTypography.badge,
    'fieldText': AppTypography.fieldText,
    'fieldLabel': AppTypography.fieldLabel,
    'fieldHelper': AppTypography.fieldHelper,
  };

  group('every role', () {
    for (final MapEntry(key: name, value: style) in roles.entries) {
      test('$name is Manrope with no baked colour, on the 2pt line grid', () {
        expect(style.fontFamily, 'Manrope');
        // Colour always comes from the palette at use.
        expect(style.color, isNull);
        expect(style.leadingDistribution, TextLeadingDistribution.even);
        final line = style.fontSize! * style.height!;
        expect(line, moreOrLessEquals(line.roundToDouble(), epsilon: 1e-9));
        expect(line.round() % 2, 0, reason: '$name: a $line line');
      });
    }
  });

  test('the hierarchy: titles over body over metadata', () {
    double size(TextStyle s) => s.fontSize!;
    expect(
      size(AppTypography.display),
      greaterThan(size(AppTypography.screenTitle)),
    );
    expect(
      size(AppTypography.screenTitle),
      greaterThan(size(AppTypography.cardTitle)),
    );
    expect(
      size(AppTypography.cardTitle),
      greaterThan(size(AppTypography.sectionTitle)),
    );
    expect(
      size(AppTypography.sectionTitle),
      greaterThan(size(AppTypography.itemTitle)),
    );
    expect(
      size(AppTypography.body),
      greaterThan(size(AppTypography.supporting)),
    );
    expect(
      size(AppTypography.supporting),
      greaterThan(size(AppTypography.caption)),
    );
    expect(
      size(AppTypography.caption),
      greaterThan(size(AppTypography.navLabel)),
    );
  });

  test('dates and times use tabular figures', () {
    expect(
      AppTypography.dateTime.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  test("the stock widgets' type is on the scale, light and dark", () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final text = theme.textTheme;
      // A snack bar's message, and a `TextButton`'s label.
      expect(text.bodyMedium!.fontSize, AppTypography.body.fontSize);
      expect(text.bodyMedium!.height, AppTypography.body.height);
      expect(text.labelLarge!.fontSize, AppTypography.buttonSmall.fontSize);
      expect(text.labelLarge!.fontWeight, AppTypography.buttonSmall.fontWeight);
      // The theme's own colours stay.
      expect(text.bodyMedium!.color, isNotNull);
    }
  });

  group('the migrated code stays on the scale', () {
    // Deliberately left unmigrated (`DESIGN_SYSTEM.md` §3, Legacy): the
    // Assignment-only widgets, screens nothing reaches, and the debug-only
    // payment preview.
    const unmigrated = [
      'lib/core/theme/app_typography.dart',
      'lib/features/course_learning/presentation/widgets/assignment_tab.dart',
      'lib/features/course_learning/presentation/widgets/assignment_attachment_card.dart',
      'lib/features/course_learning/presentation/widgets/assignment_upload_dropzone.dart',
      'lib/features/course_learning/presentation/widgets/mentor_feedback_card.dart',
      'lib/features/courses/presentation/',
      'lib/features/contracts/presentation/contract_form_screen.dart',
      'lib/features/contracts/presentation/contract_preview_screen.dart',
      'lib/features/contracts/presentation/widgets/contract_signature_pad.dart',
      'lib/features/contracts/presentation/widgets/contract_pdf_view.dart',
      'lib/features/payments/',
    ];

    Map<String, String> migrated() => {
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            !unmigrated.any((path) => file.path.startsWith(path)))
          file.path: file.readAsStringSync(),
    };

    bool isComment(String line) => line.trimLeft().startsWith('//');

    test('the scan finds the app', () {
      // A moved folder must fail here, not pass by scanning nothing.
      expect(
        migrated().keys,
        containsAll([
          'lib/features/home/presentation/widgets/program_card.dart',
          'lib/features/cohorts/presentation/widgets/cohort_card.dart',
          'lib/features/course_learning/presentation/course_module_list_screen.dart',
          'lib/shared/widgets/app_text_field.dart',
        ]),
      );
    });

    test('uses no legacy token', () {
      const legacy = [
        'heading',
        'checkboxLabel',
        'cardSupporting',
        'cardHeading',
        'badgeLabel',
        'catalogTitle',
        'catalogTrackLabel',
        'catalogStatusLabel',
        'catalogSectionLabel',
        'catalogSectionValue',
        'catalogPrice',
        'settingsRowLabel',
        'fieldError',
        'statLabel',
      ];
      final pattern = RegExp(r'AppTypography\.(' + legacy.join('|') + r')\b');
      final offenders = <String>[];
      for (final MapEntry(key: file, value: source) in migrated().entries) {
        final lines = source.split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (!isComment(lines[i]) && pattern.hasMatch(lines[i])) {
            offenders.add('$file:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('sets no size of its own outside the documented exceptions', () {
      // Each is documented where it is made, and in `DESIGN_SYSTEM.md` §3.
      const exceptions = {
        // Dense grids.
        'lib/features/junior_home/presentation/widgets/junior_progress_calendar.dart',
        'lib/features/teacher/presentation/teacher_schedule_screen.dart',
        'lib/features/teacher/presentation/widgets/teacher_week_grid.dart',
        // Sized to their container.
        'lib/features/teacher/presentation/widgets/teacher_session_sheet.dart',
        'lib/features/junior_home/presentation/widgets/junior_certificate_card.dart',
        // Four tabs where the student bars have three.
        'lib/features/teacher/presentation/widgets/teacher_bottom_nav.dart',
        // The incoming-request sheet's room and date/time on one line.
        'lib/features/teacher/presentation/widgets/teacher_class_card.dart',
      };
      // A size taken from a role (`AppTypography.x.fontSize!`, scaled or
      // not) or handed through a parameter is not a size of one's own.
      final ownSize = RegExp(r'fontSize:\s*(?!AppTypography\.)[0-9]');
      final ownParameterDefault = RegExp(
        r'this\.(?:fontSize|labelSize)\s*=\s*[0-9]',
      );
      final offenders = <String>[];
      for (final MapEntry(key: file, value: source) in migrated().entries) {
        if (exceptions.contains(file)) continue;
        final lines = source.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (isComment(line)) continue;
          if (ownSize.hasMatch(line) || ownParameterDefault.hasMatch(line)) {
            offenders.add('$file:${i + 1}: ${line.trim()}');
          }
        }
      }
      // The pill buttons' defaults are their role's size.
      expect(offenders, [
        for (final o in offenders)
          if (o.contains('this.labelSize = 16') ||
              o.contains('this.fontSize = 16'))
            o,
      ], reason: offenders.join('\n'));
    });
  });
}
