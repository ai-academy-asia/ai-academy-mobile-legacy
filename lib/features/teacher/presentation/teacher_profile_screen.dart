import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme_controller.dart';
import '../../auth/data/http_current_user_repository.dart';
import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/auth_session_store.dart';
import '../../auth/domain/current_user.dart';
import '../../auth/domain/current_user_repository.dart';
import '../../auth/presentation/reset_password_screen.dart';
import '../../auth/presentation/sign_out.dart';
import '../../auth/presentation/widgets/sign_out_confirmation_dialog.dart';
import '../../profile/presentation/profile_controller.dart';
import '../../profile/presentation/profile_strings.dart';
import '../../profile/presentation/widgets/profile_parts.dart';

/// The hero's text column: 8 after the avatar, as the frame inks the name
/// 9 in with its glyph's own bearing.
const double _avatarToText = 8;

/// The hero band on this frame: the avatar 33 below the rule above it and 32
/// above the one under it — a point more each side than the Adult frame's
/// [ProfileMetrics.heroTop] / [ProfileMetrics.heroBottom], measured off the
/// Teacher frame at 1:1.
const double _heroTop = 33;
const double _heroBottom = 32;

/// The avatar's left edge: 17 on this frame, a point in from the page's 16
/// margin.
const double _heroLeft = 17;

/// The gap the frame leaves between the name and the email under it. With
/// it the text column runs 3 past the avatar, so the band's bottom padding
/// gives those 3 back and the band stays the frame's 33 + 72 + 32.
const double _nameToDetails = 3;

/// The teacher's account and app settings — the Teacher "Profile" frame
/// (Issue #243), the fourth tab of `TeacherShell`. It draws no tab bar of
/// its own: the shell's persistent bar sits under it.
///
/// Drawn from the same measured parts as the Adult Profile
/// ([ProfileTitleBar], [ProfileCaption], [ProfileRow], …), which the two
/// frames share at 1:1. The frame's differences: no Account section and no
/// edit control, and the hero carries the email and phone under the name.
///
/// **Dark mode** (Issues #284, #288) is not in the frame: added at the product
/// owner's request so a teacher is never left in a theme they cannot leave,
/// in the Adult row's place and parts. It shows and writes the app's one
/// [AppThemeController] preference — on is Dark, off is Light — exactly as
/// the Adult row does (`PRODUCT DECISION`: design to confirm placement).
///
/// **Real and working:**
///
///  * the name (`profile.first_name` + `profile.last_name`), email and phone
///    come from `GET /auth/me` through [ProfileController], drawn exactly as
///    returned — the frame's masking is not applied (no confirmed rule, and
///    the phone's format is unconfirmed; a `PRODUCT DECISION`, #243). While
///    the fetch runs, or after it fails, the lines stay empty rather than
///    showing anyone's details;
///  * Change password pushes the shared [ResetPasswordScreen]
///    (`POST /auth/change-password`) over the whole shell;
///  * Log out confirms ([confirmSignOut]) and runs [signOutToLogin]: it
///    revokes the refresh token server-side when it can, always clears the
///    session — its persisted copy included — and lands on Login.
///
/// **Drawn as the frame draws them, but inert — no backing exists:**
///
///  * the avatar is the placeholder disc: `/auth/me` has no avatar field, and
///    the frame's photo is design content (`BACKEND GAP`);
///  * MN/EN shows MN, the app's one language, and ignores taps — there is no
///    locale mechanism to hand a choice to (`UNKNOWN`);
///  * the Notification switch shows off and ignores taps — no
///    notification-preference endpoint exists (`BACKEND GAP`);
///  * Help center, Term of Service and Privacy Policy have no destination
///    (`UNKNOWN`), so they are rows without a tap.
///
/// The frame's version line is left off: the app does not read its own
/// version, as on the Adult Profile (#223).
class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({
    super.key,
    this.repository,
    this.authRepository,
    this.sessionStore,
    this.themeController,
  });

  /// Defaults to the real `GET /auth/me` with the app-wide session. Injected
  /// in tests.
  final CurrentUserRepository? repository;

  /// The app's one theme state, which the Dark mode row shows and writes.
  /// Defaults to [AppThemeController.instance]; injected in tests.
  final AppThemeController? themeController;

  /// Where Log out revokes the session, and the session it clears — both
  /// default to the app's own (see [signOutToLogin]). Injected in tests.
  final AuthRepository? authRepository;
  final AuthSessionStore? sessionStore;

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  late final ProfileController _profile;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _profile = ProfileController(
      repository:
          widget.repository ??
          HttpCurrentUserRepository(sessionStore: widget.sessionStore),
    )..load();
  }

  @override
  void dispose() {
    _profile.dispose();
    super.dispose();
  }

  /// Log out — asks first, and only a confirmation signs out. A tap while a
  /// sign-out is already running does nothing.
  Future<void> _signOut() async {
    if (_signingOut) return;
    final confirmed = await confirmSignOut(context);
    if (!confirmed || !mounted || _signingOut) return;
    _signingOut = true;
    await signOutToLogin(
      Navigator.of(context),
      repository: widget.authRepository,
      sessionStore: widget.sessionStore,
    );
  }

  void _changePassword() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const ResetPasswordScreen(showBackButton: true),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.page(context, navigationBar: context.palette.surface),
      child: Scaffold(
        backgroundColor: context.palette.surfaceSubtle,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ProfileTitleBar(title: ProfileStrings.heading),
            const ProfileRule(),
            Expanded(child: profileConstrained(_buildBody())),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final theme = widget.themeController ?? AppThemeController.instance;
    // A `SingleChildScrollView`, as on the Adult Profile: a fixed, fully
    // known set of rows, laid out whole so one fling reaches the end.
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: ProfileMetrics.bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListenableBuilder(
            listenable: _profile,
            builder: (context, _) => _Hero(user: _profile.user),
          ),
          const ProfileRule(),

          const ProfileCaption(ProfileStrings.appSettingsSection),
          ProfileGroup(
            rows: [
              const ProfileRow(
                icon: ProfileIcons.language,
                label: ProfileStrings.language,
                trailing: ProfileLanguageToggle(
                  english: false,
                  onChanged: null,
                ),
              ),
              ProfileRow(
                glyph: AppIcons.moon,
                label: ProfileStrings.darkMode,
                trailing: ListenableBuilder(
                  listenable: theme,
                  builder: (context, _) => ProfileSwitch(
                    value: theme.darkModeOn,
                    onChanged: theme.setDarkMode,
                    semanticLabel: ProfileStrings.darkMode,
                  ),
                ),
              ),
              ProfileRow(
                icon: ProfileIcons.changePassword,
                label: ProfileStrings.changePassword,
                onTap: _changePassword,
              ),
            ],
          ),

          const ProfileCaption(ProfileStrings.notificationSection),
          const ProfileGroup(
            rows: [
              ProfileRow(
                icon: ProfileIcons.notification,
                label: ProfileStrings.notification,
                trailing: ProfileSwitch(
                  value: false,
                  onChanged: null,
                  semanticLabel: ProfileStrings.notification,
                ),
              ),
            ],
          ),

          const ProfileCaption(ProfileStrings.contactSection),
          for (final (icon, label) in const [
            (ProfileIcons.helpCenter, ProfileStrings.helpCenter),
            (ProfileIcons.termsOfService, ProfileStrings.termsOfService),
            (ProfileIcons.privacyPolicy, ProfileStrings.privacyPolicy),
          ])
            ProfileRow(
              icon: icon,
              label: label,
              height: ProfileMetrics.contactRowHeight,
            ),

          const SizedBox(height: ProfileMetrics.contactToLogOut),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.screenPadding,
            ),
            child: ProfileLogOutButton(onPressed: _signOut),
          ),
        ],
      ),
    );
  }
}

/// The avatar, with the name, email and phone beside it — three 24pt lines
/// from the avatar's top, the email and phone [_nameToDetails] under the
/// name, as the frame stacks them.
class _Hero extends StatelessWidget {
  const _Hero({required this.user});

  /// The fetched account, or null while loading or after a failure — when
  /// every line stays empty.
  final CurrentUser? user;

  @override
  Widget build(BuildContext context) {
    final user = this.user;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _heroLeft,
        _heroTop,
        AppDimens.screenPadding,
        _heroBottom - _nameToDetails,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProfileAvatar(),
          const SizedBox(width: _avatarToText),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _line(
                  user?.displayName ?? '',
                  profileNameStyle.copyWith(color: context.palette.textPrimary),
                ),
                const SizedBox(height: _nameToDetails),
                _line(
                  user?.email ?? '',
                  _detailStyle.copyWith(
                    color: context.palette.teacherDetailInk,
                  ),
                ),
                _line(
                  user?.profile.phone ?? '',
                  _detailStyle.copyWith(
                    color: context.palette.teacherDetailInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _line(String text, TextStyle style) => SizedBox(
    height: _lineHeight,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

/// One hero line's box.
const double _lineHeight = 24;

/// The email and phone under the name: 14pt regular in the frame's cool grey
/// (`AppPalette.teacherDetailInk`) — the same grey Teacher Schedule's
/// attendance summary uses.
const TextStyle _detailStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 24 / 14,
  fontWeight: FontWeight.w400,
  leadingDistribution: TextLeadingDistribution.even,
);
