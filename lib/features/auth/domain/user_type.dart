/// Which app experience an account opens, as the backend decides it.
///
/// `mobile_api_v1_1.md` §1: `user_type` rides on `POST /auth/login`,
/// `POST /auth/refresh`, `GET /auth/me` and `PATCH /me/profile`, and is the
/// one field the app routes on. The backend has already folded the admin's
/// `ui_mode` override, the student's age and a junior-course enrollment into
/// it, so nothing here re-derives child/adult from those — that would only be
/// able to disagree with the server.
enum UserType {
  /// A student who is not a child.
  adult,

  /// A student in kids mode.
  child,

  /// A teacher.
  teacher,

  /// Back-office staff — not a mobile user.
  staff,

  /// Absent, or a value this build does not know. Routed the way the app
  /// behaved before `user_type` was read, rather than failing sign-in.
  unknown;

  /// Reads the wire value. Anything that is not one of the four documented
  /// strings is [unknown].
  static UserType fromApi(Object? value) => switch (value) {
    'adult' => adult,
    'child' => child,
    'teacher' => teacher,
    'staff' => staff,
    _ => unknown,
  };
}
