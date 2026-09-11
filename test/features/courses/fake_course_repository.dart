import 'dart:async';

import 'package:aia_mobile/core/api/api_failure.dart';
import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:aia_mobile/features/courses/domain/course.dart';
import 'package:aia_mobile/features/courses/domain/course_repository.dart';

/// A repository the tests drive by hand.
///
/// Same shape as `FakeAuthRepository`: either completes with [courses],
/// throws a chosen [ApiFailure], or — when [hold] is set — waits for
/// [release], which is how the loading state gets observed while the request
/// is still in flight.
class FakeCourseRepository implements CourseRepository {
  FakeCourseRepository({this.courses = const [], this.failure, this.hold = false});

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
}

/// A minimal, valid course matching the confirmed `GET /courses` example —
/// every required field filled, every nullable one left null — so a test only
/// has to override what it actually cares about.
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
);
