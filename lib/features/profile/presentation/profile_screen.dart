import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/data/http_current_user_repository.dart';
import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/auth_session_store.dart';
import '../../auth/domain/current_user_repository.dart';
import '../../auth/presentation/reset_password_screen.dart';
import '../../auth/presentation/sign_out.dart';
import '../../auth/presentation/widgets/sign_out_confirmation_dialog.dart';
import '../../auth/presentation/student_tabs.dart';
import '../../home/presentation/widgets/adult_bottom_nav.dart';
import '../../home/presentation/widgets/home_palette.dart';
import 'profile_controller.dart';
import 'profile_strings.dart';

// Measured off the Figma "Adults - Profile" frame at 1:1 (393 wide, a 44pt
// status-bar inset). Where the frame shares a component with the Junior
// Profile frame, the values match `JuniorProfileScreen`'s own measurements —
// the two frames are drawn from the same parts.

/// The white header under the status bar, down to its rule.
const double _headerHeight = 63;

/// The hero band: the avatar 32 below the rule above it, 31 above the one
/// under it, and the edit control centred on the same line.
const double _avatarSize = 72;
const double _heroTop = 32;
const double _heroBottom = 31;
const double _avatarToName = 11;
const double _editSize = 48;

/// The edit glyph's box — the exported SVG's own 20, whose pencil inks the
/// frame's 16.
const double _editGlyph = 20;

/// A settings row, and the caption band above each group — the caption's
/// line 16 below the band's top.
const double _rowHeight = 55;
const double _captionBand = 40;
const double _captionTop = 16;

/// The contact rows, which the frame runs without rules between them.
const double _contactRowHeight = 56;

/// A row's icon box and its gap to the label — 8 on this frame, a point
/// tighter than the junior frame's 9.
const double _rowIcon = 20;
const double _iconToLabel = 8;

/// The E-Contract pill — a full 32-tall pill here, taller than the junior
/// frame's — and the gap from it to the "1/2" count.
const double _badgeHeight = 32;
const double _badgePadding = 12;
const double _badgeToCount = 8;

/// The MN/EN control — see [_LanguageToggle].
const double _toggleHeight = 35;
const double _toggleInset = 4;
const double _capsuleWidth = 44;
const double _otherSegmentWidth = 41;
const double _toggleRadius = 12;
const double _capsuleRadius = 8;

/// The footer: Log out 32 below the last contact row, the version 18 below
/// it, and 32 of page under the version.
const double _contactToLogOut = 32;
const double _logOutToVersion = 18;
const double _bottomPadding = 32;

/// The student's profile and app settings — the Figma "Adults - Profile"
/// frame.
///
/// **Not the Junior Profile.** `JuniorProfileScreen` is its own screen for
/// the "Kids - Profile" frame; this one keeps the adult frame's differences —
/// the edit control, the "1/2" count on E-Contract, the Light mode row and
/// no "Payment receipt" — while sharing its measured parts (the header,
/// avatar, caption bands, rows, MN/EN control, switch and log-out pill).
///
/// **Every row but the header and Change password is UI only.** E-Contract,
/// Certificate, Transaction history, edit profile, Help center, Term of
/// Service and Privacy Policy have no destination yet, and the language,
/// light-mode and notification controls hold local state that nothing else
/// reads — there is no locale mechanism, no dark palette and no
/// notification-preference endpoint in the app to hand them to.
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
/// The header's name loads from `GET /auth/me` through [ProfileController],
/// falling back to [ProfileStrings.name] while that fetch is loading or has
/// failed. The join date stays the design's placeholder copy: the confirmed
/// `/auth/me` response carries no join date. No confirmed response carries an
/// avatar URL either, so the avatar is a placeholder disc — the frame's photo
/// is design content, not app data.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.repository,
    this.authRepository,
    this.sessionStore,
  });

  /// Defaults to the real API with the app-wide session. Injected in tests.
  final CurrentUserRepository? repository;

  /// Where "Гарах" revokes the session, and the session it clears — both
  /// default to the app's own (see [signOutToLogin]). Injected in tests.
  final AuthRepository? authRepository;
  final AuthSessionStore? sessionStore;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // UI-only state. Deliberately not persisted and not read by anything else —
  // see the class doc above.
  bool _english = false;
  bool _lightMode = false;
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
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surfaceSubtle,
        bottomNavigationBar: const AdultBottomNav(current: StudentTab.profile),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // White behind the status bar as well as the title, as the frame
            // draws it.
            ColoredBox(
              color: AppColors.surface,
              child: SafeArea(
                bottom: false,
                child: _constrained(
                  const SizedBox(
                    height: _headerHeight,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppDimens.screenPadding,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          ProfileStrings.heading,
                          style: _headingStyle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const _Rule(),
            Expanded(child: _constrained(_buildBody())),
          ],
        ),
      ),
    );
  }

  /// Caps the column at [AppDimens.maxContentWidth], centred, as every other
  /// screen does on a wide window.
  Widget _constrained(Widget child) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
      child: child,
    ),
  );

  Widget _buildBody() {
    // A `SingleChildScrollView` rather than a `ListView`: the rows are a
    // fixed, fully-known set, and a lazily-built sliver only *estimates* its
    // scroll extent from the children it has laid out so far — which made a
    // single fling stop short of the Contact section instead of reaching the
    // end. Laying all of it out gives an exact extent, so one fling reaches
    // the bottom.
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: _bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListenableBuilder(
            listenable: _profile,
            builder: (context, _) => _Header(
              name: _profile.user?.displayName ?? ProfileStrings.name,
            ),
          ),
          const _Rule(),

          const _Caption(ProfileStrings.accountSection),
          const _Group(
            rows: [
              _Row(
                icon: ProfileIcons.eContract,
                label: ProfileStrings.eContract,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatusBadge(ProfileStrings.eContractStatus),
                    SizedBox(width: _badgeToCount),
                    _ContractCount(),
                  ],
                ),
              ),
              _Row(
                icon: ProfileIcons.certificate,
                label: ProfileStrings.certificate,
              ),
              _Row(
                icon: ProfileIcons.transactionHistory,
                label: ProfileStrings.transactionHistory,
              ),
            ],
          ),

          const _Caption(ProfileStrings.appSettingsSection),
          _Group(
            rows: [
              _Row(
                icon: ProfileIcons.language,
                label: ProfileStrings.language,
                trailing: _LanguageToggle(
                  english: _english,
                  onChanged: (value) => setState(() => _english = value),
                ),
              ),
              _Row(
                icon: ProfileIcons.lightMode,
                label: ProfileStrings.lightMode,
                trailing: _Switch(
                  value: _lightMode,
                  onChanged: (value) => setState(() => _lightMode = value),
                  semanticLabel: ProfileStrings.lightMode,
                ),
              ),
              _Row(
                icon: ProfileIcons.changePassword,
                label: ProfileStrings.changePassword,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ResetPasswordScreen(),
                  ),
                ),
              ),
            ],
          ),

          const _Caption(ProfileStrings.notificationSection),
          _Group(
            rows: [
              _Row(
                icon: ProfileIcons.notification,
                label: ProfileStrings.notification,
                trailing: _Switch(
                  value: _notifications,
                  onChanged: (value) => setState(() => _notifications = value),
                  semanticLabel: ProfileStrings.notification,
                ),
              ),
            ],
          ),

          const _Caption(ProfileStrings.contactSection),
          for (final (icon, label) in const [
            (ProfileIcons.helpCenter, ProfileStrings.helpCenter),
            (ProfileIcons.termsOfService, ProfileStrings.termsOfService),
            (ProfileIcons.privacyPolicy, ProfileStrings.privacyPolicy),
          ])
            _Row(icon: icon, label: label, height: _contactRowHeight),

          const SizedBox(height: _contactToLogOut),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.screenPadding,
            ),
            child: _LogOutButton(onPressed: _signOut),
          ),
          const SizedBox(height: _logOutToVersion),
          const Text(
            ProfileStrings.version,
            style: _versionStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The avatar, name and join date, with the edit control at the trailing
/// edge, on the page grey.
class _Header extends StatelessWidget {
  const _Header({required this.name});

  /// The fetched `CurrentUser.displayName`, or [ProfileStrings.name] while
  /// loading or on failure — see [ProfileController].
  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        _heroTop,
        AppDimens.screenPadding,
        _heroBottom,
      ),
      child: Row(
        children: [
          Container(
            width: _avatarSize,
            height: _avatarSize,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              shape: BoxShape.circle,
              border: Border.all(color: HomePalette.border),
            ),
            child: const Icon(
              Icons.person,
              size: 36,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: _avatarToName),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: _nameStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                const Text(
                  ProfileStrings.joinedDate,
                  style: _joinedStyle,
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
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: HomePalette.border),
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

/// A grey caption naming the group under it.
class _Caption extends StatelessWidget {
  const _Caption(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _captionBand,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          _captionTop,
          AppDimens.screenPadding,
          0,
        ),
        child: Text(label, style: captionStyle),
      ),
    );
  }
}

/// Rows with a rule after each one, the last closing the group off. No rule
/// between a caption and its own first row: the frame runs the caption
/// straight into the group it names.
class _Group extends StatelessWidget {
  const _Group({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in rows) ...[row, const _Rule()],
      ],
    );
  }
}

/// One row: icon, label, and an optional trailing control. No chevron — the
/// frame draws none on any row, including the ones that will eventually open
/// a screen of their own.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.height = _rowHeight,
  });

  /// Path to the row's exported SVG — see [ProfileIcons].
  final String icon;

  final String label;

  /// The row's trailing control, where the row has one.
  final Widget? trailing;

  /// Pushes the row's destination screen. `null` for every row with no
  /// destination yet — see the class doc on [ProfileScreen].
  final VoidCallback? onTap;

  final double height;

  @override
  Widget build(BuildContext context) {
    final row = SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.screenPadding,
        ),
        child: Row(
          children: [
            SvgPicture.asset(icon, width: _rowIcon, height: _rowIcon),
            const SizedBox(width: _iconToLabel),
            Expanded(
              child: Text(
                label,
                style: rowLabelStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing case final trailing?) ...[
              const SizedBox(width: 12),
              trailing,
            ],
          ],
        ),
      ),
    );

    final onTap = this.onTap;
    if (onTap == null) return row;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// The amber pill on the E-Contract row — the contract banner's own pale
/// amber, with the junior frame's softer outline.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _badgeHeight,
      padding: const EdgeInsets.symmetric(horizontal: _badgePadding),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HomePalette.contractFill,
        borderRadius: BorderRadius.circular(_badgeHeight / 2),
        border: Border.all(color: _badgeOutline),
      ),
      child: Text(label, style: _badgeStyle, maxLines: 1),
    );
  }
}

/// "1/2" — the frame inks the first figure dark and "/2" in the caption
/// grey.
class _ContractCount extends StatelessWidget {
  const _ContractCount();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      const TextSpan(
        text: ProfileStrings.eContractSigned,
        children: [
          TextSpan(
            text: ProfileStrings.eContractTotal,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
      style: _countStyle,
    );
  }
}

/// The MN/EN control: a blue rounded rectangle with the selected language on
/// a white capsule inset 4 inside it — 93 x 35 overall, the capsule 44 x 27,
/// as on the junior frame. The halves are not equal: the capsule is 44 wide
/// and the other language centres in the 41 left over.
class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.english, required this.onChanged});

  final bool english;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _toggleHeight,
      padding: const EdgeInsets.all(_toggleInset),
      decoration: BoxDecoration(
        color: HomePalette.accent,
        borderRadius: BorderRadius.circular(_toggleRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            label: ProfileStrings.languageMn,
            selected: !english,
            onTap: () => onChanged(false),
          ),
          _Segment(
            label: ProfileStrings.languageEn,
            selected: english,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: selected ? _capsuleWidth : _otherSegmentWidth,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(_capsuleRadius),
          ),
          child: Text(
            label,
            style: _segmentStyle.copyWith(
              color: selected ? _segmentInk : AppColors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The frame's switch: a 44 x 24 grey track with a white knob — smaller than
/// Flutter's own [Switch], so drawn here rather than scaled.
class _Switch extends StatelessWidget {
  const _Switch({
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 24,
          padding: const EdgeInsets.all(2),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? HomePalette.accent : HomePalette.border,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The full-width outlined pill.
class _LogOutButton extends StatelessWidget {
  const _LogOutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(AppDimens.buttonRadius));
    return Semantics(
      button: true,
      label: ProfileStrings.logOut,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: HomePalette.border),
        ),
        child: InkWell(
          onTap: onPressed,
          customBorder: const RoundedRectangleBorder(borderRadius: radius),
          child: const SizedBox(
            height: AppDimens.buttonHeight,
            child: Center(
              child: Text(ProfileStrings.logOut, style: _logOutStyle),
            ),
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimens.borderWidth,
      color: HomePalette.headerRule,
    );
  }
}

// --- Colour and type ---------------------------------------------------------
//
// Sampled and measured off the frame at 1:1; sizes from cap heights (Manrope's
// cap height is 0.72 em). The colours are the same ones `JuniorProfileScreen`
// sampled off the junior frame.

/// The E-Contract pill's outline.
const Color _badgeOutline = Color(0xFFFFE8A3);

/// The E-Contract pill's label.
const Color _badgeInk = Color(0xFFDD940E);

/// "MN" on the white half of the language control — a deep indigo, not the
/// capsule's blue.
const Color _segmentInk = Color(0xFF1501A6);

/// The join date's cool grey.
const Color _joinedInk = Color(0xFF9CA3AF);

/// The version line's slate.
const Color _versionInk = Color(0xFF4B5563);

const TextStyle _headingStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 24,
  height: 32 / 24,
  fontWeight: FontWeight.w700,
  color: AppColors.textPrimary,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _nameStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 18,
  height: 24 / 18,
  fontWeight: FontWeight.w700,
  color: AppColors.textPrimary,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _joinedStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w400,
  color: _joinedInk,
  leadingDistribution: TextLeadingDistribution.even,
);

/// A section caption's style. Public so the screen's tests can tell the
/// "Notification" caption from the "Notification" row.
@visibleForTesting
const TextStyle captionStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 12,
  height: 16 / 12,
  fontWeight: FontWeight.w700,
  color: AppColors.textSecondary,
  leadingDistribution: TextLeadingDistribution.even,
);

/// A settings row's label style — see [captionStyle].
@visibleForTesting
const TextStyle rowLabelStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 16,
  height: 24 / 16,
  fontWeight: FontWeight.w400,
  color: AppColors.textPrimary,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _badgeStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 12,
  height: 16 / 12,
  fontWeight: FontWeight.w600,
  color: _badgeInk,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _countStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w700,
  color: AppColors.textPrimary,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _segmentStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 12,
  height: 16 / 12,
  fontWeight: FontWeight.w700,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _logOutStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 16,
  height: 24 / 16,
  fontWeight: FontWeight.w700,
  color: AppColors.textPrimary,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _versionStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w400,
  color: _versionInk,
  leadingDistribution: TextLeadingDistribution.even,
);
