import '../../cohorts/domain/cohort.dart';
import '../../home/domain/lesson_schedule.dart';

/// One class a teacher teaches — a cohort from the teacher's own
/// `GET /teachers/{teacher_id}/schedule`, plus its course's track.
///
/// [cohort] is the verified cohort shape (the same one `GET /cohorts`
/// returns). [track] is the course's `level` from the public
/// `GET /courses` catalog (`adult` / `junior`, verified), matched on
/// `cohort.course.id`; null when the catalog could not be read or does not
/// list the course, and then no track badge is drawn — none is guessed.
class TeacherClass {
  const TeacherClass({required this.cohort, this.track});

  final Cohort cohort;
  final String? track;
}

/// The classes that meet on [now]'s day, earliest start first — Teacher
/// Home's "Өнөөдрийн хичээл".
///
/// The meeting rule is the one the student dashboards already use
/// ([LessonSchedule]: a listed meeting day inside the cohort's start…end
/// dates), read from the same verified fields; nothing here is a new rule.
/// A class whose schedule cannot be parsed is left out rather than placed.
List<TeacherClass> classesMeetingOn(List<TeacherClass> classes, DateTime now) {
  final meeting = <(TeacherClass, LessonSchedule)>[
    for (final teacherClass in classes)
      if (LessonSchedule.of(teacherClass.cohort) case final schedule?)
        if (schedule.lessonDaysIn(now).contains(now.day))
          (teacherClass, schedule),
  ];
  meeting.sort((a, b) {
    final byHour = a.$2.start.$1.compareTo(b.$2.start.$1);
    return byHour != 0 ? byHour : a.$2.start.$2.compareTo(b.$2.start.$2);
  });
  return [for (final (teacherClass, _) in meeting) teacherClass];
}
