import 'dart:io';

import 'package:aia_mobile/core/theme/app_colors.dart';
import 'package:aia_mobile/core/theme/app_system_ui.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/core/theme/app_theme_controller.dart';
import 'package:aia_mobile/features/courses/presentation/course_catalog_screen.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_center.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/gradebook_class_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/manual_attendance_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_request_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/courses/fake_course_repository.dart';
import '../../features/notifications/fake_notification_repository.dart';
import '../../features/teacher/fake_teacher_attendance_repository.dart';
import '../../features/teacher/fake_teacher_gradebook_repository.dart';
import '../../features/teacher/teacher_home_screen_test.dart' show sampleClass;

/// Dark Mode Phase 4 (Issue #260): system UI follows the global theme, and
/// light mode's overlay styles are exactly what every screen set before.
void main() {
  /// What the 23 light pages wrote by hand before Phase 4.
  SystemUiOverlayStyle legacyPage(Color navigationBar) =>
      SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: navigationBar,
      );

  /// A dark *brightness* only — no dark colours exist or are invented here.
  final darkBrightness = AppTheme.light.copyWith(brightness: Brightness.dark);

  Future<SystemUiOverlayStyle> pageStyleUnder(
    WidgetTester tester,
    ThemeData theme,
    Color navigationBar,
  ) async {
    late SystemUiOverlayStyle style;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) {
            style = AppSystemUi.page(context, navigationBar: navigationBar);
            return const SizedBox();
          },
        ),
      ),
    );
    return style;
  }

  SystemUiOverlayStyle regionValue(WidgetTester tester, Finder within) => tester
      .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find
            .descendant(
              of: within,
              matching: find.byWidgetPredicate(
                (w) => w is AnnotatedRegion<SystemUiOverlayStyle>,
              ),
            )
            .first,
      )
      .value;

  group('page', () {
    testWidgets('light theme: exactly the legacy style, for each nav-bar '
        'ground the screens use', (tester) async {
      for (final ground in [
        AppColors.surface,
        AppColors.surfaceSubtle,
        AppColors.background,
      ]) {
        expect(
          await pageStyleUnder(tester, AppTheme.light, ground),
          legacyPage(ground),
          reason: '$ground',
        );
      }
    });

    testWidgets('light theme keeps Flutter .dark\'s light nav-bar icons — '
        'pre-existing, flagged, not changed', (tester) async {
      final style = await pageStyleUnder(
        tester,
        AppTheme.light,
        AppColors.surface,
      );
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.statusBarBrightness, Brightness.light);
      expect(style.systemNavigationBarIconBrightness, Brightness.light);
    });

    testWidgets('a dark theme flips the icons to light', (tester) async {
      final style = await pageStyleUnder(
        tester,
        darkBrightness,
        AppColors.surface,
      );
      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.statusBarBrightness, Brightness.dark);
      expect(style.systemNavigationBarIconBrightness, Brightness.light);
      expect(style.statusBarColor, Colors.transparent);
      expect(style.systemNavigationBarColor, AppColors.surface);
    });
  });

  group('overDarkContent — the two intentional exceptions', () {
    test('scanner: light icons, nav bar left at the base black', () {
      expect(
        AppSystemUi.overDarkContent(),
        SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      );
      expect(
        AppSystemUi.overDarkContent().systemNavigationBarColor,
        const Color(0xFF000000),
      );
    });

    test('Teacher Schedule: light icons over the blue band, white nav bar', () {
      expect(
        AppSystemUi.overDarkContent(navigationBar: AppColors.surface),
        SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppColors.surface,
        ),
      );
    });
  });

  testWidgets('follows a theme-mode change from the one controller', (
    tester,
  ) async {
    final controller = AppThemeController();
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: controller,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          darkTheme: darkBrightness,
          themeMode: controller.mode,
          home: Builder(
            builder: (context) => AnnotatedRegion<SystemUiOverlayStyle>(
              value: AppSystemUi.page(
                context,
                navigationBar: AppColors.surface,
              ),
              child: const SizedBox(),
            ),
          ),
        ),
      ),
    );
    final app = find.byType(MaterialApp);
    expect(regionValue(tester, app), legacyPage(AppColors.surface));

    controller.setMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(regionValue(tester, app).statusBarIconBrightness, Brightness.light);

    controller.setMode(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(regionValue(tester, app), legacyPage(AppColors.surface));
  });

  group('real screens keep their style', () {
    testWidgets('Notification Center: surface nav bar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: NotificationScreen(
            center: NotificationCenter(
              repository: FakeNotificationRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        regionValue(tester, find.byType(NotificationScreen)),
        legacyPage(AppColors.surface),
      );
    });

    testWidgets('Course catalog: background nav bar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CourseCatalogScreen(repository: FakeCourseRepository()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        regionValue(tester, find.byType(CourseCatalogScreen)),
        legacyPage(AppColors.background),
      );
    });
  });

  /// Pushes [page] over a light-icon page — Teacher Schedule's style — and
  /// answers the style the framework then sends to the platform.
  Future<SystemUiOverlayStyle?> styleAfterPushing(
    WidgetTester tester,
    Widget page,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        navigatorKey: navigatorKey,
        home: AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppSystemUi.overDarkContent(navigationBar: AppColors.surface),
          child: const Scaffold(body: SizedBox()),
        ),
      ),
    );
    await tester.pump();
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
    await tester.pumpAndSettle();
    return SystemChrome.latestStyle;
  }

  group(
    'a pushed page sends its own style, not the one below (Issue #400)',
    () {
      testWidgets('"Багш нар": dark icons, surface nav bar', (tester) async {
        final style = await styleAfterPushing(
          tester,
          const TeacherRequestScreen(),
        );
        expect(style?.statusBarIconBrightness, Brightness.dark);
        expect(style?.systemNavigationBarColor, AppColors.surface);
      });

      testWidgets('manual attendance: dark icons, surface nav bar', (
        tester,
      ) async {
        final style = await styleAfterPushing(
          tester,
          ManualAttendanceScreen(
            sessionId: 41,
            repository: FakeTeacherAttendanceRepository(),
          ),
        );
        expect(style?.statusBarIconBrightness, Brightness.dark);
        expect(style?.systemNavigationBarColor, AppColors.surface);
      });

      testWidgets('a Program\'s students: dark icons, surfaceSubtle nav bar', (
        tester,
      ) async {
        final style = await styleAfterPushing(
          tester,
          GradebookClassScreen(
            teacherClass: sampleClass(),
            repository: FakeTeacherGradebookRepository(),
          ),
        );
        expect(style?.statusBarIconBrightness, Brightness.dark);
        expect(style?.systemNavigationBarColor, AppColors.surfaceSubtle);
      });
    },
  );

  test('every screen declares its own status-bar style (Issue #400)', () {
    // The page below stops painting once a screen covers it, so a screen
    // without its own region keeps whatever style came before.
    const allowed = {
      // Shells: each tab screen inside declares its own.
      'lib/features/home/presentation/adult_student_shell.dart',
      'lib/shared/widgets/persistent_tab_shell.dart',
      // TEMPORARY design-review previews, never in release builds (#196).
      'lib/features/payments/presentation/payment_flow/payment_amount_screen.dart',
      'lib/features/payments/presentation/payment_flow/payment_method_screen.dart',
      'lib/features/payments/presentation/payment_flow/ebarimt_receipt_screen.dart',
    };
    final missing = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (allowed.contains(file.path)) continue;
      final source = file.readAsStringSync();
      if (source.contains('Scaffold(') &&
          !source.contains('AnnotatedRegion<SystemUiOverlayStyle>')) {
        missing.add(file.path);
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('no screen writes a raw SystemUiOverlayStyle.dark/.light', () {
    final raw = RegExp(r'SystemUiOverlayStyle\.(dark|light)\b');
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.endsWith('core/theme/app_system_ui.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue;
        if (raw.hasMatch(line)) offenders.add('${file.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
