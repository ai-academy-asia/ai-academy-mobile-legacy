import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme_controller.dart';
import '../../../shared/widgets/tab_title_bar.dart';
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
import '../../notifications/push/notification_permission_switch.dart';
import '../../notifications/push/push_notifications.dart';

/// The hero's text column: 8 after the avatar, as the frame inks the name
/// 9 in with its glyph's own bearing.
const double _avatarToText = 8;

/// The hero band: the Adult profile's own [ProfileMetrics.heroTop] /
/// [ProfileMetrics.heroBottom], the avatar on the page's
/// [AppDimens.screenPadding] gutter — the Teacher frame drew it a point
/// further each way, aligned with the Adult profile in Issue #368.
const double _heroTop = ProfileMetrics.heroTop;
const double _heroBottom = ProfileMetrics.heroBottom;
const double _heroLeft = AppDimens.screenPadding;

/// The gap the frame leaves between the name and the email under it. With
/// it the text column runs 3 past the avatar, so the band's bottom padding
/// gives those 3 back and the band stays the hero's own height.
const double _nameToDetails = 3;

/// The text's last line to the band's rule: the frame's 72 avatar + 31,
/// less the text column's 79 (the name's 28 line, 3, two 24 lines) — so at
/// the default size the rule sits where the frame draws it.
const double _textToRule = 24;

/// The teacher's account and app settings — the Teacher "Profile" frame
/// (Issue #243), the fourth tab of `TeacherShell`. It draws no tab bar of
/// its own: the shell's persistent bar sits under it.
///
/// Drawn from the same measured parts as the Adult Profile
/// ([TabTitleBar], [ProfileCaption], [ProfileRow], …), which the two
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
    this.push,
  });

  /// Defaults to the real `GET /auth/me` with the app-wide session. Injected
  /// in tests.
  final CurrentUserRepository? repository;

  /// The app's one theme state, which the Dark mode row shows and writes.
  /// Defaults to [AppThemeController.instance]; injected in tests.
  final AppThemeController? themeController;

  /// The OS notification permission the Notification switch shows and whose
  /// settings it opens (Issue #429). Defaults to
  /// [PushNotifications.instance]; injected in tests.
  final PushNotifications? push;

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
            const TabTitleBar(title: ProfileStrings.heading),
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
          ProfileGroup(
            rows: [
              ProfileRow(
                icon: ProfileIcons.notification,
                label: ProfileStrings.notification,
                // The OS notification permission, not a preference — none
                // exists (#291). A tap opens the OS settings (Issue #429).
                trailing: NotificationPermissionSwitch(
                  push: widget.push,
                  builder: (context, value, onChanged) => ProfileSwitch(
                    value: value,
                    onChanged: onChanged,
                    semanticLabel: ProfileStrings.notification,
                  ),
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
        0,
      ),
      // The band closes [_heroBottom] below the avatar, as the frame
      // measures — or [_textToRule] below the text, where a larger text size
      // makes the text the taller of the two (Issue #406). At the default
      // size both land on the same line.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: _heroBottom),
            child: ProfileAvatar(),
          ),
          const SizedBox(width: _avatarToText),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: _textToRule),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _line(
                    user?.displayName ?? '',
                    profileNameStyle.copyWith(
                      color: context.palette.textPrimary,
                    ),
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
          ),
        ],
      ),
    );
  }

  /// [_lineHeight] at least: the name's own 28 line, and any line at a
  /// larger text size, grows the box rather than being cut (DESIGN_SYSTEM
  /// §3, Issue #406).
  static Widget _line(String text, TextStyle style) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: _lineHeight),
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

/// The email and phone under the name, in the frame's cool grey
/// (`AppPalette.teacherDetailInk`) — the same grey Teacher Schedule's
/// attendance summary uses.
const TextStyle _detailStyle = AppTypography.body;
