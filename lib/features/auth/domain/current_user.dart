import 'user_type.dart';

/// The signed-in user's own account, as the confirmed `GET /auth/me` response
/// carries it:
///
///     {
///       "actor_id": 5,
///       "actor_type": "student",
///       "email": "crud-test-student-20260909@example.mn",
///       "id": 9,
///       "is_active": true,
///       "must_change_password": true,
///       "profile": {
///         "first_name": "CRUD",
///         "id": 5,
///         "last_name": "TestStudent",
///         "phone": "99123456",
///         "ui_mode": "kids"
///       },
///       "role": "student",
///       "user_type": "child"
///     }
///
/// `user_type` is `mobile_api_v1_1.md` §1's addition to that response.
class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.actorId,
    required this.actorType,
    required this.email,
    required this.role,
    required this.isActive,
    required this.mustChangePassword,
    required this.profile,
    this.userType = UserType.unknown,
  });

  final int id;
  final int actorId;
  final String actorType;
  final String email;
  final String role;
  final bool isActive;
  final bool mustChangePassword;
  final UserProfile profile;

  /// Which app experience this account opens. [UserType.unknown] when the
  /// response carried none.
  final UserType userType;

  /// The name the profile header shows: first and last name, space-joined.
  String get displayName => '${profile.firstName} ${profile.lastName}'.trim();
}

/// The `profile` object nested in the `/auth/me` response.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.uiMode,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String phone;

  /// Null when the account has none — production sends `"ui_mode": null`
  /// for some adult accounts (Issue #168).
  final String? uiMode;
}
