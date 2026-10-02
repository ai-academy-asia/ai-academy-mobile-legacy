import 'package:flutter/material.dart';

import 'app.dart';
import 'features/auth/data/session_refresher.dart';
import 'features/auth/presentation/sign_out.dart';

void main() {
  // A session that cannot be renewed ends on Login (Issue #176).
  returnToLoginWhenSessionEnds(SessionRefresher.instance, appNavigatorKey);
  runApp(const AiAcademyApp());
}
