import 'package:flutter/widgets.dart';

import '../../../auth/presentation/home_route.dart';

/// The teacher tab bar's destinations, in the order `TeacherBottomNav`
/// draws them. Хуваарь is first and the Teacher area's default (Issue #370:
/// the redesign drops the former Нүүр tab).
enum TeacherTab {
  /// Хуваарь — Teacher Schedule (Issue #231).
  schedule,

  /// Дүнгийн хуудас — Teacher Gradebook (Issue #233).
  grades,

  /// Профайл — Teacher Profile (Issue #243), a tab of `TeacherShell` only.
  profile,
}

/// The routes `AiAcademyApp` registers for the teacher tabs, besides the
/// Teacher area's landing route ([HomeRoutes.teacher], which opens on
/// Хуваарь).
abstract final class TeacherTabRoutes {
  static const String schedule = '/teacher-schedule';

  /// Teacher Gradebook (Issue #233).
  static const String gradebook = '/teacher-gradebook';
}

/// Switches the teacher tab bar to [tab] from a bar drawn outside
/// `TeacherShell`, the way `openStudentTab` switches the student bars: the
/// Teacher area's landing route — Хуваарь — is the root of the stack, reached
/// by popping back to it; Дүнгийн хуудас is pushed directly on top of it.
/// Профайл has no route, so it is never passed here.
void openTeacherTab(BuildContext context, TeacherTab tab) {
  final navigator = Navigator.of(context);
  switch (tab) {
    case TeacherTab.schedule:
      navigator.popUntil(_isTeacherRoot);
    case TeacherTab.grades:
      navigator.pushNamedAndRemoveUntil(
        TeacherTabRoutes.gradebook,
        _isTeacherRoot,
      );
    case TeacherTab.profile:
      break;
  }
}

/// The Teacher area's landing route, by name. `isFirst` is the fallback for a
/// stack that never carries a route named after it, so popping always
/// terminates.
bool _isTeacherRoot(Route<dynamic> route) =>
    route.isFirst || route.settings.name == HomeRoutes.teacher;
