import 'dart:async';

import 'package:aia_mobile/core/api/api_failure.dart';
import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:aia_mobile/features/courses/domain/course.dart';
import 'package:aia_mobile/features/courses/domain/course_repository.dart';

/// A repository the tests drive by hand.
///
/// Same shape as `FakeAuthRepository`: either completes, throws a chosen
/// [ApiFailure], or — when [hold]/[holdDetail] is set — waits for
/// [release]/[releaseDetail], which is how the loading state gets observed
/// while a request is still in flight.
///
/// [getCourses] and [getCourseDetail] are tracked independently — separate
/// results, failures, holds and call counts — so a test exercising navigation
/// from the catalog into a detail screen can script both calls on the same
/// fake without one interfering with the other.
class FakeCourseRepository implements CourseRepository {
  FakeCourseRepository({
    this.courses = const [],
    this.failure,
    this.hold = false,
    this.courseDetail,
    this.detailFailure,
    this.holdDetail = false,
  });

  // --- getCourses --------------------------------------------------------

  /// Returned on success.
  List<Course> courses;

  /// Thrown instead of returning, when set.
  ApiFailure? failure;

  /// When true, [getCourses] blocks until [release] is called.
  bool hold;

  /// How many times [getCourses] has been called — so a test can assert a
  /// retry or a pull-to-refresh actually asked again.
  int callCount = 0;

  Completer<void>? _gate;

  /// Lets a held [getCourses] finish.
  void release() {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<List<Course>> getCourses() async {
    callCount++;

    if (hold) {
      _gate = Completer<void>();
      await _gate!.future;
    }

    final failure = this.failure;
    if (failure != null) throw failure;

    return courses;
  }

  // --- getCourseDetail -----------------------------------------------------

  /// Returned on success. Defaults to a minimal valid course if unset.
  Course? courseDetail;

  /// Thrown instead of returning, when set.
  ApiFailure? detailFailure;

  /// When true, [getCourseDetail] blocks until [releaseDetail] is called.
  bool holdDetail;

  /// Every slug [getCourseDetail] was called with, in order.
  final List<String> detailCalls = [];

  Completer<void>? _detailGate;

  /// Lets a held [getCourseDetail] finish.
  void releaseDetail() {
    final gate = _detailGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<Course> getCourseDetail(String slug) async {
    detailCalls.add(slug);

    if (holdDetail) {
      _detailGate = Completer<void>();
      await _detailGate!.future;
    }

    final failure = detailFailure;
    if (failure != null) throw failure;

    return courseDetail ?? sampleCourse(slug: slug);
  }
}

/// A minimal, valid course matching the confirmed `GET /courses` example —
/// every required field filled, every nullable one left null — so a test only
/// has to override what it actually cares about.
///
/// The detail-only fields (everything from [attendanceMethod] on) default to
/// null, matching a course as the *list* endpoint returns it. Pass them to
/// build a course as `getCourseDetail` would return it instead.
Course sampleCourse({
  int id = 4,
  String slug = 'summer-bootcamp',
  LocalizedText title = const LocalizedText(
    en: 'Summer Bootcamp',
    mn: 'Зуны бүтээлч кэмп',
  ),
  LocalizedText tagline = const LocalizedText(mn: '3 долоо хоногийн эрчимжүүлсэн'),
  String category = 'bootcamp',
  String level = 'junior',
  String format = 'in_person',
  String status = 'open',
  int ageMin = 10,
  int ageMax = 18,
  int durationWeeks = 3,
  String startDate = '2026-06-01',
  String endDate = '2026-06-21',
  double priceAmount = 1200000.0,
  double finalPriceAmount = 960000.0,
  int discountPercent = 20,
  String currency = 'MNT',
  String? durationLabel,
  String? bannerImageUrl,
  String? icon,
  int? sortOrder,
  String? targetAudience,
  String? attendanceMethod,
  int? capacity,
  String? certTemplateName,
  String? contractTemplateName,
  String? createdAt,
  Object? curriculum,
  Object? description,
  String? finalProjectType,
  String? googleClassroomUrl,
  bool? hasAttendance,
  bool? hasCertTemplate,
  bool? hasContractTemplate,
  bool? hasExam,
  bool? hasFinalProject,
  Object? instructors,
  Object? prerequisites,
  String? updatedAt,
  Object? whatsIncluded,
}) => Course(
  id: id,
  slug: slug,
  title: title,
  tagline: tagline,
  category: category,
  level: level,
  format: format,
  status: status,
  ageMin: ageMin,
  ageMax: ageMax,
  durationWeeks: durationWeeks,
  startDate: startDate,
  endDate: endDate,
  priceAmount: priceAmount,
  finalPriceAmount: finalPriceAmount,
  discountPercent: discountPercent,
  currency: currency,
  durationLabel: durationLabel,
  bannerImageUrl: bannerImageUrl,
  icon: icon,
  sortOrder: sortOrder,
  targetAudience: targetAudience,
  attendanceMethod: attendanceMethod,
  capacity: capacity,
  certTemplateName: certTemplateName,
  contractTemplateName: contractTemplateName,
  createdAt: createdAt,
  curriculum: curriculum,
  description: description,
  finalProjectType: finalProjectType,
  googleClassroomUrl: googleClassroomUrl,
  hasAttendance: hasAttendance,
  hasCertTemplate: hasCertTemplate,
  hasContractTemplate: hasContractTemplate,
  hasExam: hasExam,
  hasFinalProject: hasFinalProject,
  instructors: instructors,
  prerequisites: prerequisites,
  updatedAt: updatedAt,
  whatsIncluded: whatsIncluded,
);
