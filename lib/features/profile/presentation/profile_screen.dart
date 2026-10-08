import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_palette.dart';
import '../../auth/data/http_current_user_repository.dart';
import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/auth_session_store.dart';
import '../../auth/domain/current_user_repository.dart';
import '../../auth/presentation/reset_password_screen.dart';
import '../../auth/presentation/sign_out.dart';
import '../../auth/presentation/widgets/sign_out_confirmation_dialog.dart';
import '../../auth/presentation/student_tabs.dart';
import '../../certificates/domain/certificate_list_repository.dart';
import '../../certificates/presentation/certificate_screen.dart';
import '../../course_learning/domain/course_learning_repository.dart';
import '../../home/presentation/widgets/adult_bottom_nav.dart';
import 'profile_controller.dart';
import 'profile_strings.dart';
import 'widgets/profile_parts.dart';

export 'widgets/profile_parts.dart' show captionStyle, rowLabelStyle;

// Measured off the Figma "Adults - Profile" frame at 1:1 (393 wide, a 44pt
// status-bar inset). The parts it shares with the Teacher Profile frame —
// header, hero, caption bands, rows, MN/EN control, switch and log-out pill —
// live in `widgets/profile_parts.dart` (Issue #243); only this frame's own
// measurements are here.

/// The name's gap to the avatar, and the edit control centred on the hero.
const double _avatarToName = 11;
const double _editSize = 48;

/// The edit glyph's box — the exported SVG's own 20, whose pencil inks the
/// frame's 16.
const double _editGlyph = 20;

/// The student's profile and app settings — the Figma "Adults - Profile"
/// frame.
///
/// **Not the Junior Profile.** `JuniorProfileScreen` is its own screen for
/// the "Kids - Profile" frame; this one keeps the adult frame's differences —
/// the edit control, the Light mode row and
/// no "Payment receipt" — while sharing its measured parts (the header,
/// avatar, caption bands, rows, MN/EN control, switch and log-out pill).
///
/// **Every row but the header, Certificate (Issue #155) and Change password
/// is UI only.** E-Contract, Transaction history, edit profile, Help center,
/// Term of Service and Privacy Policy have no destination yet, and the language
/// and notification controls hold local state that nothing else reads — there
/// is no locale mechanism and no notification-preference endpoint in the app
/// to hand them to.
///
/// **Light mode shows the app's real theme, and is inert** (Issue #252). It
/// reads the active theme's brightness — set by the one app-wide
/// `AppThemeController`, never a copy kept here — so it reads on in today's
/// light app, and ignores taps, as Teacher's inert switches do: no dark
/// palette exists to switch to. A working control here, on Junior and on
/// Teacher, all writing that one controller, is Dark Mode Phase 10
/// (`DARK_MODE_ARCHITECTURE_AUDIT.md` §9).
///
/// Log out signs out for real through [signOutToLogin]: it revokes the
/// session server-side when it can, always clears it locally, and lands on
/// Login.
///
/// Change password pushes [ResetPasswordScreen] rather than a screen of its
/// own: that screen already is this flow (three fields, [PasswordPolicy]
/// validation, `POST /auth/change-password` through the same
/// `PasswordRepository`, the same loading/error handling). Its default
/// [ResetPasswordScreen.onCompleted] (pop, with a success snackbar) lands
/// back here, since this row pushes it rather than replacing the route.
///
/// The header's name loads from `GET /auth/me` through [ProfileController];
/// while that fetch is loading or after it fails, the name line stays empty
/// rather than showing anyone else's name. **No invented account data is
/// drawn** (Issue #223): the frame's join date, the E-Contract status pill
/// and its count, and the version line have no source — the confirmed
/// `/auth/me` response carries no join date, no endpoint reports a contract,
/// and the build's version is not read — so they are left off until one
/// exists. No confirmed response carries an avatar URL either, so the avatar
/// is a placeholder disc — the frame's photo is design content, not app data.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.repository,
    this.authRepository,
    this.sessionStore,
    this.showBottomNav = true,
    this.certificateRepository,
    this.courseLearningRepository,
  });

  /// Defaults to the real API with the app-wide session. Injected in tests.
  final CurrentUserRepository? repository;

  /// Where "Гарах" revokes the session, and the session it clears — both
  /// default to the app's own (see [signOutToLogin]). Injected in tests.
  final AuthRepository? authRepository;
  final AuthSessionStore? sessionStore;

  /// What the Certificate row's screen reads (Issue #155). Default to the
  /// real API; injected in tests.
  final CertificateListRepository? certificateRepository;
  final CourseLearningRepository? courseLearningRepository;

  /// Whether this screen draws the adult tab bar itself. False inside
  /// `AdultStudentShell`, which owns the one persistent bar (Issue #237).
  final bool showBottomNav;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // UI-only state. Deliberately not persisted and not read by anything else —
  // see the class doc above.
  bool _english = false;
  bool _notifications = false;

  late final ProfileController _profile;

  @override
  void initState() {
    super.initState();
    _profile = ProfileController(
      repository: widget.repository ?? HttpCurrentUserRepository(),
    )..load();
  }

  @override
  void dispose() {
    _profile.dispose();
    super.dispose();
  }

  bool _signingOut = false;

  /// "Гарах" — asks first ([confirmSignOut]), and only a confirmation runs
  /// [signOutToLogin]. A tap while a sign-out is already running does nothing.
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.page(context, navigationBar: context.palette.surface),
      child: Scaffold(
        backgroundColor: context.palette.surfaceSubtle,
        bottomNavigationBar: widget.showBottomNav
            ? const AdultBottomNav(current: StudentTab.profile)
            : null,
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
    // A `SingleChildScrollView` rather than a `ListView`: the rows are a
    // fixed, fully-known set, and a lazily-built sliver only *estimates* its
    // scroll extent from the children it has laid out so far — which made a
    // single fling stop short of the Contact section instead of reaching the
    // end. Laying all of it out gives an exact extent, so one fling reaches
    // the bottom.
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: ProfileMetrics.bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListenableBuilder(
            listenable: _profile,
            builder: (context, _) => _Header(
              // Empty, never a placeholder person, until `/auth/me` answers.
              name: _profile.user?.displayName ?? '',
            ),
          ),
          const ProfileRule(),

          const ProfileCaption(ProfileStrings.accountSection),
          ProfileGroup(
            rows: [
              // No contract status or count: no endpoint reports either.
              const ProfileRow(
                icon: ProfileIcons.eContract,
                label: ProfileStrings.eContract,
              ),
              // The student's certificates, one per course (Issue #155).
              ProfileRow(
                icon: ProfileIcons.certificate,
                label: ProfileStrings.certificate,
                onTap: () => CertificateScreen.open(
                  context,
                  repository: widget.certificateRepository,
                  courseLearning: widget.courseLearningRepository,
                ),
              ),
              const ProfileRow(
                icon: ProfileIcons.transactionHistory,
                label: ProfileStrings.transactionHistory,
              ),
            ],
          ),

          const ProfileCaption(ProfileStrings.appSettingsSection),
          ProfileGroup(
            rows: [
              ProfileRow(
                icon: ProfileIcons.language,
                label: ProfileStrings.language,
                trailing: ProfileLanguageToggle(
                  english: _english,
                  onChanged: (value) => setState(() => _english = value),
                ),
              ),
              ProfileRow(
                icon: ProfileIcons.lightMode,
                label: ProfileStrings.lightMode,
                trailing: ProfileSwitch(
                  value: Theme.of(context).brightness == Brightness.light,
                  onChanged: null,
                  semanticLabel: ProfileStrings.lightMode,
                ),
              ),
              ProfileRow(
                icon: ProfileIcons.changePassword,
                label: ProfileStrings.changePassword,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const ResetPasswordScreen(showBackButton: true),
                  ),
                ),
              ),
            ],
          ),

          const ProfileCaption(ProfileStrings.notificationSection),
          ProfileGroup(
            rows: [
              ProfileRow(
                icon: ProfileIcons.notification,
                label: ProfileStrings.notification,
                trailing: ProfileSwitch(
                  value: _notifications,
                  onChanged: (value) => setState(() => _notifications = value),
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

/// The avatar and name, with the edit control at the trailing edge, on the
/// page grey. The frame's join date is not drawn — see [ProfileScreen].
class _Header extends StatelessWidget {
  const _Header({required this.name});

  /// The fetched `CurrentUser.displayName`, or empty while loading or on
  /// failure — see [ProfileController].
  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        ProfileMetrics.heroTop,
        AppDimens.screenPadding,
        ProfileMetrics.heroBottom,
      ),
      child: Row(
        children: [
          const ProfileAvatar(),
          const SizedBox(width: _avatarToName),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: profileNameStyle.copyWith(
                    color: context.palette.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const _EditButton(),
        ],
      ),
    );
  }
}

/// The frame's edit control: a white 48 circle in the border grey, the
/// pencil centred in it. No destination yet — see [ProfileScreen].
class _EditButton extends StatelessWidget {
  const _EditButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: ProfileStrings.editProfile,
      child: Container(
        width: _editSize,
        height: _editSize,
        decoration: BoxDecoration(
          color: context.palette.surface,
          shape: BoxShape.circle,
          border: Border.all(color: context.palette.outline),
        ),
        child: Center(
          child: SvgPicture.asset(
            ProfileIcons.edit,
            width: _editGlyph,
            height: _editGlyph,
          ),
        ),
      ),
    );
  }
}
