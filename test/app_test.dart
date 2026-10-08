import 'package:aia_mobile/app.dart';
import 'package:aia_mobile/features/auth/presentation/student_tabs.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_screen.dart';
import 'package:aia_mobile/features/home/presentation/adult_student_shell.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_student_shell.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_shell.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('registers the cohort list as the /cohorts route', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(393, 852) * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AiAcademyApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final builder = app.routes?['/cohorts'];

    expect(builder, isNotNull);
    // Built, not pumped: the real screen would reach for the real API.
    expect(
      builder!(tester.element(find.byType(MaterialApp))),
      isA<CohortListScreen>(),
    );
  });

  testWidgets('registers the adult Хичээл and Профайл tabs as the shell, on '
      'their own tab (Issue #237)', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(393, 852) * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AiAcademyApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final context = tester.element(find.byType(MaterialApp));

    // Built, not pumped: the real screens would reach for the real API.
    for (final (route, tab) in [
      ('/my-cohorts', StudentTab.progress),
      ('/profile', StudentTab.profile),
    ]) {
      final screen = app.routes?[route]?.call(context);
      expect(screen, isA<AdultStudentShell>(), reason: route);
      expect((screen as AdultStudentShell).initialTab, tab, reason: route);
    }
  });

  testWidgets('registers both homes sign-in can land on', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(393, 852) * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AiAcademyApp());

    // `homeRouteFor` picks between these two by `user_type`. The
    // `/dev/junior-home` preview door of Issue #98 stays removed.
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final context = tester.element(find.byType(MaterialApp));
    final home = app.routes?['/home'];
    final juniorHome = app.routes?['/junior-home'];

    expect(home, isNotNull);
    // Built, not pumped: the real screens would reach for the real API.
    final adultHome = home!(context);
    expect(adultHome, isA<AdultStudentShell>());
    expect((adultHome as AdultStudentShell).initialTab, StudentTab.home);
    expect(juniorHome, isNotNull);
    final junior = juniorHome!(context);
    expect(junior, isA<JuniorStudentShell>());
    expect((junior as JuniorStudentShell).initialTab, StudentTab.home);
    final teacher = app.routes?['/teacher-home']?.call(context);
    expect(teacher, isA<TeacherShell>());
    expect((teacher as TeacherShell).initialTab, TeacherTab.home);
    expect(app.routes, isNot(contains('/dev/junior-home')));
  });

  testWidgets('registers the junior and teacher tabs as their shells, on '
      'their own tab (Issue #241)', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(393, 852) * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AiAcademyApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final context = tester.element(find.byType(MaterialApp));

    // Built, not pumped: the real screens would reach for the real API.
    for (final (route, tab) in [
      ('/junior-progress', StudentTab.progress),
      ('/junior-profile', StudentTab.profile),
    ]) {
      final screen = app.routes?[route]?.call(context);
      expect(screen, isA<JuniorStudentShell>(), reason: route);
      expect((screen as JuniorStudentShell).initialTab, tab, reason: route);
    }
    for (final (route, tab) in [
      ('/teacher-schedule', TeacherTab.schedule),
      ('/teacher-gradebook', TeacherTab.grades),
    ]) {
      final screen = app.routes?[route]?.call(context);
      expect(screen, isA<TeacherShell>(), reason: route);
      expect((screen as TeacherShell).initialTab, tab, reason: route);
    }
    // No teacher Профайл route: the tab stays inert (Issue #241).
    expect(app.routes, isNot(contains('/teacher-profile')));
  });

  testWidgets('registers no Exercise Detail preview route', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(393, 852) * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AiAcademyApp());

    // Issue #148: Exercise Detail is reached through Module List → Lesson
    // List, so the sample-backed `/dev/course-exercise-preview` door is gone.
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.routes, isNot(contains('/dev/course-exercise-preview')));
  });
}
