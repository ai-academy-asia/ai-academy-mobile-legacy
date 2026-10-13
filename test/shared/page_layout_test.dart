import 'dart:io';

import 'package:aia_mobile/core/theme/app_dimens.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/core/theme/app_typography.dart';
import 'package:aia_mobile/shared/widgets/back_title_header.dart';
import 'package:aia_mobile/shared/widgets/content_column.dart';
import 'package:aia_mobile/shared/widgets/tab_title_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screenshot.dart';

/// The app's page layout standard (Issue #368): one header per kind of page,
/// one set of spacing tokens, and every screen of every role on them.
void main() {
  setUpAll(loadAppFonts);

  test('the layout tokens', () {
    expect(AppDimens.screenPadding, 16);
    expect(AppDimens.maxContentWidth, 480);
    expect(AppDimens.tabHeaderHeight, 63);
    expect(AppDimens.backButtonTop, 12);
    expect(AppDimens.backButtonSize, 40);
    expect(AppDimens.backHeaderHeight, 52);
    expect(AppDimens.tabContentTop, 16);
    expect(AppDimens.pageContentTop, 24);
    expect(AppDimens.cardGap, 16);
    expect(AppDimens.tileGap, 8);
    expect(AppDimens.pageBottom, 24);
  });

  Future<void> pumpHeader(
    WidgetTester tester,
    Widget header, {
    double width = 393,
    double scale = 1,
  }) async {
    useLogicalViewport(tester, Size(width, 852), padding: iPhonePadding);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: Column(children: [header])),
      ),
    );
  }

  group('TabTitleBar — every primary tab\'s header', () {
    testWidgets('a 63 band under the status bar, its rule, the title left '
        'on the gutter and centred in the band', (tester) async {
      await pumpHeader(tester, const TabTitleBar(title: 'Profile'));

      final bar = tester.getRect(find.byType(TabTitleBar));
      expect(bar.top, 0);
      expect(bar.height, 44 + AppDimens.tabHeaderHeight + 1);
      final title = tester.getRect(find.text('Profile'));
      expect(title.left, AppDimens.screenPadding);
      expect(
        title.center.dy,
        closeTo(44 + AppDimens.tabHeaderHeight / 2, 0.01),
      );
      final style = tester.widget<Text>(find.text('Profile')).style!;
      expect(style.fontSize, AppTypography.screenTitle.fontSize);
      expect(style.fontWeight, AppTypography.screenTitle.fontWeight);
      // Read as a heading.
      expect(
        tester.getSemantics(find.text('Profile')).flagsCollection.isHeader,
        isTrue,
      );
    });

    testWidgets('on a wide window the title stays on the column\'s left '
        'gutter', (tester) async {
      await pumpHeader(tester, const TabTitleBar(title: 'Courses'), width: 800);

      final column = (800 - AppDimens.maxContentWidth) / 2;
      expect(
        tester.getTopLeft(find.text('Courses')).dx,
        column + AppDimens.screenPadding,
      );
    });

    for (final width in [320.0, 393.0]) {
      testWidgets('${width.toInt()} wide, text ×3.0: a long title wraps and '
          'the band grows, nothing overflows', (tester) async {
        await pumpHeader(
          tester,
          const TabTitleBar(title: 'Дүнгийн хуудас'),
          width: width,
          scale: 3,
        );
        expect(tester.takeException(), isNull);
        final bar = tester.getRect(find.byType(TabTitleBar));
        final title = tester.getRect(find.text('Дүнгийн хуудас'));
        expect(bar.height, greaterThan(44 + AppDimens.tabHeaderHeight + 1));
        expect(title.bottom, lessThanOrEqualTo(bar.bottom - 1));
      });
    }
  });

  testWidgets('BackTitleHeader — every pushed page\'s header: the back '
      'button on the gutter 12 below the inset, the title centred on it', (
    tester,
  ) async {
    await pumpHeader(
      tester,
      const SafeArea(child: BackTitleHeader(title: 'Certificate')),
    );

    final header = tester.getRect(find.byType(BackTitleHeader));
    expect(header.height, AppDimens.backHeaderHeight);
    final button = tester.getRect(
      find.descendant(
        of: find.byType(BackTitleHeader),
        matching: find.byType(Material),
      ),
    );
    expect(button.left, AppDimens.screenPadding);
    expect(button.top, 44 + AppDimens.backButtonTop);
    expect(button.size, const Size.square(AppDimens.backButtonSize));
    final title = tester.getRect(find.text('Certificate'));
    expect(title.center.dx, closeTo(393 / 2, 0.5));
    expect(title.center.dy, closeTo(button.center.dy, 0.5));
  });

  testWidgets('ContentColumn caps a page at the content width, centred', (
    tester,
  ) async {
    useLogicalViewport(tester, const Size(800, 600));
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ContentColumn(child: SizedBox(height: 10, width: 2000)),
      ),
    );
    final box = tester.getRect(find.byType(SizedBox));
    expect(box.width, AppDimens.maxContentWidth);
    expect(box.left, (800 - AppDimens.maxContentWidth) / 2);
  });

  group('every role\'s screens use the shared headers', () {
    String source(String path) => File('lib/features/$path').readAsStringSync();

    // Primary tabs with a title, across Adult, Junior and Teacher.
    const tabs = [
      'cohorts/presentation/cohort_list_screen.dart',
      'profile/presentation/profile_screen.dart',
      'junior_home/presentation/junior_profile_screen.dart',
      'teacher/presentation/teacher_profile_screen.dart',
      'teacher/presentation/teacher_gradebook_screen.dart',
    ];
    for (final path in tabs) {
      test('$path draws TabTitleBar', () {
        expect(source(path), contains('TabTitleBar('));
      });
    }

    // Pushed pages with a titled header.
    const pages = [
      'contracts/presentation/contract_screen.dart',
      'certificates/presentation/certificate_screen.dart',
      'notifications/presentation/notification_screen.dart',
      'notifications/presentation/notification_detail_screen.dart',
      'auth/presentation/reset_password_screen.dart',
      'home/presentation/attendance_detail_screen.dart',
      'teacher/presentation/teacher_request_screen.dart',
    ];
    for (final path in pages) {
      test('$path draws BackTitleHeader', () {
        expect(source(path), contains('BackTitleHeader('));
      });
    }

    // A documented exception (SCREEN_PATTERNS.md §3, Issue #390): the
    // Programs frames set the cohort and title left-aligned beside the
    // back control, so these pages share ProgramPageHeader instead.
    const programPages = [
      'teacher/presentation/gradebook_class_screen.dart',
      'teacher/presentation/gradebook_student_screen.dart',
    ];
    for (final path in programPages) {
      test('$path draws ProgramPageHeader', () {
        expect(source(path), contains('ProgramPageHeader('));
      });
    }

    test('no screen keeps a copy of a header', () {
      final offenders = <String>[];
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final text = file.readAsStringSync();
        // The headers this standard replaced.
        for (final copy in [
          'class ProfileTitleBar',
          'class GradebookBackHeader',
        ]) {
          if (text.contains(copy)) offenders.add('${file.path}: $copy');
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });
}
