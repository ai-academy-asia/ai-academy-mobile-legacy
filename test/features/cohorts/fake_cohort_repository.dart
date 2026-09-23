import 'dart:async';

import 'package:aia_mobile/core/api/api_failure.dart';
import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:aia_mobile/features/cohorts/domain/cohort.dart';
import 'package:aia_mobile/features/cohorts/domain/cohort_repository.dart';

/// A repository the tests drive by hand. Same shape as
/// `FakeCourseRepository`: either completes with [cohorts], throws a chosen
/// [ApiFailure], or — when [hold] is set — waits for [release], which is how
/// the loading state gets observed while the request is still in flight.
class FakeCohortRepository implements CohortRepository {
  FakeCohortRepository({this.cohorts = const [], this.failure, this.hold = false});

  /// Returned on success.
  List<Cohort> cohorts;

  /// Thrown instead of returning, when set.
  ApiFailure? failure;

  /// When true, [getCohorts] blocks until [release] is called.
  bool hold;

  /// How many times [getCohorts] has been called — so a test can assert a
  /// retry or a pull-to-refresh actually asked again.
  int callCount = 0;

  Completer<void>? _gate;

  /// Lets a held [getCohorts] finish.
  void release() {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<List<Cohort>> getCohorts() async {
    callCount++;

    if (hold) {
      _gate = Completer<void>();
      await _gate!.future;
    }

    final failure = this.failure;
    if (failure != null) throw failure;

    return cohorts;
  }
}

/// A minimal, valid cohort matching the confirmed `GET /cohorts` example —
/// every required field filled, every nullable one left null — so a test only
/// has to override what it actually cares about.
Cohort sampleCohort({
  int id = 1,
  String name = 'Corporate Leaders 2026-08',
  int courseId = 6,
  CohortCourse course = const CohortCourse(
    id: 6,
    slug: 'summer-bootcamp-2027',
    title: LocalizedText(en: 'Summer Bootcamp', mn: 'Зуны бүтээлч кэмп'),
  ),
  CohortClassroom classroom = const CohortClassroom(
    id: 1,
    name: 'Room 301',
    centerName: 'AI Academy Central',
  ),
  CohortTeacher teacher = const CohortTeacher(id: 2, name: 'Сараа Ганбат'),
  int capacity = 20,
  int enrolledCount = 0,
  int seatsAvailable = 20,
  String status = 'open',
  String startDate = '2026-08-06',
  String endDate = '2026-10-06',
  String startTime = '18:00',
  String endTime = '20:00',
  String graduationDate = '2026-10-10',
  List<String> meetingDays = const ['mon', 'wed'],
  int? parentCohortId,
  String? scheduleNote,
}) => Cohort(
  id: id,
  name: name,
  courseId: courseId,
  course: course,
  classroom: classroom,
  teacher: teacher,
  capacity: capacity,
  enrolledCount: enrolledCount,
  seatsAvailable: seatsAvailable,
  status: status,
  startDate: startDate,
  endDate: endDate,
  startTime: startTime,
  endTime: endTime,
  graduationDate: graduationDate,
  meetingDays: meetingDays,
  parentCohortId: parentCohortId,
  scheduleNote: scheduleNote,
);
