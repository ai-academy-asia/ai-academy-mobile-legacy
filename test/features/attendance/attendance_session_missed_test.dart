import 'package:aia_mobile/features/attendance/domain/course_attendance.dart';
import 'package:flutter_test/flutter_test.dart';

/// [AttendanceSession.missedAt] (Issue #475): `absent` is missed only once
/// the session has ended, in Ulaanbaatar. The backend reports today's
/// unrecorded session `absent` from midnight. Clocks here are UTC, so the
/// device's own time zone never matters; Ulaanbaatar is UTC+8.
void main() {
  AttendanceSession session({
    required DateTime date,
    String? status = 'absent',
    String? endTime = '12:00',
  }) => AttendanceSession(
    date: date,
    status: status,
    startTime: '09:00',
    endTime: endTime,
  );

  /// [hour]:[minute] on 20 October 2026 in Ulaanbaatar, as a UTC instant.
  DateTime ubAt(int hour, [int minute = 0]) => DateTime.utc(
    2026,
    10,
    20,
    hour,
    minute,
  ).subtract(const Duration(hours: 8));

  final today = DateTime(2026, 10, 20);

  test('today\'s absent: not before the class, not while it runs', () {
    final s = session(date: today);
    expect(s.missedAt(ubAt(0, 5)), isFalse);
    expect(s.missedAt(ubAt(8, 59)), isFalse);
    expect(s.missedAt(ubAt(10)), isFalse);
    expect(s.missedAt(ubAt(11, 59)), isFalse);
  });

  test('today\'s absent: missed from its end time', () {
    final s = session(date: today);
    expect(s.missedAt(ubAt(12)), isTrue);
    expect(s.missedAt(ubAt(23, 59)), isTrue);
  });

  test('an earlier day\'s absent is missed; a later day\'s never', () {
    expect(session(date: DateTime(2026, 10, 19)).missedAt(ubAt(0, 5)), isTrue);
    expect(
      session(date: DateTime(2026, 10, 21)).missedAt(ubAt(23, 59)),
      isFalse,
    );
  });

  test('today with no readable end time: not missed until the day is over', () {
    for (final endTime in [null, 'soon', '25:00']) {
      final s = session(date: today, endTime: endTime);
      expect(s.missedAt(ubAt(23, 59)), isFalse, reason: '$endTime');
      // The next Ulaanbaatar day, it is an earlier day's absent.
      expect(
        s.missedAt(DateTime.utc(2026, 10, 20, 16, 1)),
        isTrue,
        reason: '$endTime',
      );
    }
  });

  test('"today" is Ulaanbaatar\'s, whatever the device\'s zone', () {
    // 19 October 17:00 UTC is already 20 October 01:00 in Ulaanbaatar.
    final now = DateTime.utc(2026, 10, 19, 17);
    expect(
      session(date: DateTime(2026, 10, 19), endTime: '21:30').missedAt(now),
      isTrue,
    );
    expect(session(date: today).missedAt(now), isFalse);
  });

  test('only absent is ever missed', () {
    for (final status in ['present', 'late', 'excused', null, 'other']) {
      expect(
        session(
          date: DateTime(2026, 10, 19),
          status: status,
        ).missedAt(ubAt(12)),
        isFalse,
        reason: '$status',
      );
    }
  });
}
