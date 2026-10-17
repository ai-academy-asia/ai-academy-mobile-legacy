import 'package:aia_mobile/features/attendance/domain/continue_attendance.dart';
import 'package:aia_mobile/features/attendance/domain/course_attendance.dart';
import 'package:flutter_test/flutter_test.dart';

/// The one rule that confirms Junior's lesson to continue with (Issue #443):
/// the most recent session dated today or earlier, in Ulaanbaatar, is
/// `present` or `late`. Clocks are real instants, in UTC: Ulaanbaatar is
/// UTC+8, so `DateTime.utc(2026, 10, 6, 4)` is 12:00 on 6 October there.
void main() {
  CourseAttendance sessions(List<(DateTime, String?, String?)> list) =>
      CourseAttendance(
        attended: 0,
        totalPast: 0,
        percent: 0,
        sessions: [
          for (final (date, status, start) in list)
            AttendanceSession(date: date, status: status, startTime: start),
        ],
      );

  // A class on 6 Oct, 09:00–11:00, and the next one on 13 Oct.
  final classDay = DateTime(2026, 10, 6);
  final nextClassDay = DateTime(2026, 10, 13);

  bool confirmed(CourseAttendance? attendance, DateTime now) =>
      continueAttendanceConfirmedBy(attendance, now: now);

  group('after the class has ended, the same day', () {
    // 14:00 in Ulaanbaatar: the class (09:00–11:00) is over, and the
    // dashboard's next lesson has already moved on to 13 Oct.
    final afterClass = DateTime.utc(2026, 10, 6, 6);

    test('present keeps the lesson open', () {
      expect(
        confirmed(
          sessions([
            (classDay, 'present', '09:00'),
            (nextClassDay, null, '09:00'),
          ]),
          afterClass,
        ),
        isTrue,
      );
    });

    test('late keeps it open too', () {
      expect(
        confirmed(
          sessions([
            (classDay, 'late', '09:00'),
            (nextClassDay, null, '09:00'),
          ]),
          afterClass,
        ),
        isTrue,
      );
    });

    test('absent or excused never opens it', () {
      for (final status in ['absent', 'excused']) {
        expect(
          confirmed(sessions([(classDay, status, '09:00')]), afterClass),
          isFalse,
          reason: status,
        );
      }
    });
  });

  test('the days in between keep the last class\'s answer', () {
    // 9 Oct, between the two classes.
    final between = DateTime.utc(2026, 10, 9, 4);
    expect(
      confirmed(
        sessions([
          (classDay, 'present', '09:00'),
          (nextClassDay, null, '09:00'),
        ]),
        between,
      ),
      isTrue,
    );
  });

  test('a new class day locks it again until the student checks in: the '
      'backend reports the new session absent from midnight', () {
    // 07:00 on 13 Oct, before the class: last week's present no longer
    // counts — today's session is the most recent, and it reads absent.
    final morning = DateTime.utc(2026, 10, 12, 23);
    final attendance = sessions([
      (classDay, 'present', '09:00'),
      (nextClassDay, 'absent', '09:00'),
    ]);
    expect(confirmed(attendance, morning), isFalse);

    // Checked in: today's session is present.
    expect(
      confirmed(
        sessions([
          (classDay, 'present', '09:00'),
          (nextClassDay, 'present', '09:00'),
        ]),
        morning,
      ),
      isTrue,
    );
  });

  test('a finished cohort: its last class, attended, still opens it', () {
    final weeksLater = DateTime.utc(2026, 11, 20, 4);
    expect(
      confirmed(
        sessions([
          (DateTime(2026, 9, 29), 'absent', '09:00'),
          (classDay, 'late', '09:00'),
        ]),
        weeksLater,
      ),
      isTrue,
    );
  });

  test('two sessions on one day: the later start is the most recent, '
      'whatever order they arrive in', () {
    final evening = DateTime.utc(2026, 10, 6, 12);
    expect(
      confirmed(
        sessions([
          (classDay, 'present', '18:00'),
          (classDay, 'absent', '09:00'),
        ]),
        evening,
      ),
      isTrue,
    );
    expect(
      confirmed(
        sessions([
          (classDay, 'present', '09:00'),
          (classDay, 'absent', '18:00'),
        ]),
        evening,
      ),
      isFalse,
    );
  });

  test('"today" is Ulaanbaatar\'s date, not the phone\'s', () {
    // 17:00 UTC on 5 Oct is already 01:00 on 6 Oct in Ulaanbaatar: the
    // 6 Oct session counts as today's.
    final lateUtc = DateTime.utc(2026, 10, 5, 17);
    expect(
      confirmed(
        sessions([
          (DateTime(2026, 9, 29), 'present', '09:00'),
          (classDay, 'absent', '09:00'),
        ]),
        lateUtc,
      ),
      isFalse,
    );
  });

  test('missing or unknown attendance fails closed', () {
    final now = DateTime.utc(2026, 10, 6, 4);
    expect(confirmed(null, now), isFalse);
    expect(confirmed(sessions(const []), now), isFalse);
    // Only future sessions listed.
    expect(confirmed(sessions([(nextClassDay, null, '09:00')]), now), isFalse);
  });
}
