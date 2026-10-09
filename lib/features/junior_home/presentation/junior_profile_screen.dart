import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme_controller.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../auth/data/http_current_user_repository.dart';
import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/auth_session_store.dart';
import '../../auth/domain/current_user_repository.dart';
import '../../auth/presentation/reset_password_screen.dart';
import '../../certificates/domain/certificate_list_repository.dart';
import '../../certificates/presentation/certificate_screen.dart';
import '../../course_learning/domain/course_learning_repository.dart';
import '../../auth/presentation/sign_out.dart';
import '../../auth/presentation/widgets/sign_out_confirmation_dialog.dart';
import '../../auth/presentation/student_tabs.dart';
import '../../profile/presentation/profile_controller.dart';
import '../../profile/presentation/profile_strings.dart';
import '../../profile/presentation/widgets/profile_parts.dart';
import 'junior_profile_strings.dart';
import 'widgets/junior_bottom_nav.dart';

// Measured off the Junior Profile frame at 1:1 (393 wide, a 44pt status-bar
// inset).

/// The white header under the status bar, down to its rule.
const double _headerHeight = 63;

/// The hero band: the avatar 32 below the rule above it, 31 above the one
/// under it.
const double _avatarSize = 72;
const double _heroTop = 32;
const double _heroBottom = 31;

/// A settings row, and the caption band above each group — the caption's
/// line 16 below the band's top.
const double _rowHeight = 55;
const double _captionBand = 40;
const double _captionTop = 16;

/// The MN/EN control — see [_LanguageToggle].
const double _toggleHeight = 35;
const double _toggleInset = 4;
const double _capsuleWidth = 44;
const double _otherSegmentWidth = 41;

/// Rounded rectangles, not full pills: fitted off the frame's corners, the
/// outline curves at 12 and the capsule at 8.
const double _toggleRadius = 12;
const double _capsuleRadius = 8;

/// The contact rows, which the frame runs without rules between them.
const double _contactRowHeight = 56;

/// A row's icon box and its gap to the label.
const double _rowIcon = 20;
const double _iconToLabel = 9;

/// The junior student's profile and settings — the Figma "Kids - Profile"
/// frame.
///
/// Its own screen rather than the adult `ProfileScreen`-with-options: the
/// frame differs from the adult one in nearly every band — a larger title and
/// avatar, no edit control, a fourth Account row ("Payment receipt"), no
/// "1/2" counter on E-Contract, its own MN/EN control and switch, rows
/// without a chevron on a grey page, and a full-width log-out pill.
///
/// **Dark mode** (Issues #284, #288) is not in the frame: added at the product
/// owner's request so a junior is never left in a theme they cannot leave,
/// in the Adult row's place, from this frame's own row and switch. It shows
/// and writes the app's one [AppThemeController] preference — on is Dark,
/// off is Light — exactly as the Adult row does (`PRODUCT DECISION`: design
/// to confirm placement).
///
/// **Reuse.** The name loads from `GET /auth/me` through the adult Profile's
/// own [ProfileController] and `CurrentUserRepository`; while it loads or
/// after a failure the name line stays empty, never another person's name.
/// As on the adult Profile, **no invented account data is drawn** (Issue
/// #223): the frame's join date, E-Contract status pill and version line
/// have no source, so they are left off. The row icons are
/// the adult Profile's exported SVGs ([ProfileIcons]) — the same artwork the
/// junior frame draws — plus the junior frame's own "Payment receipt" SVG
/// ([JuniorProfileIcons]). Change password pushes the same [ResetPasswordScreen]
/// the adult row does, and Certificate opens the same Certificate screen
/// (Issue #155).
///
/// **Gaps.** No confirmed response carries an avatar URL, so the avatar is
/// a placeholder disc, as on the adult Profile — the frame's photo is design
/// content, not app data. Every other row and the toggles have no
/// destination yet, as on the adult Profile; the toggles hold local state
/// that nothing reads. Log out signs out for real through the same
/// [signOutToLogin] the adult Profile uses.
class JuniorProfileScreen extends StatefulWidget {
  const JuniorProfileScreen({
    super.key,
    this.repository,
    this.authRepository,
    this.sessionStore,
    this.showBottomNav = true,
    this.certificateRepository,
    this.courseLearningRepository,
    this.themeController,
  });

  /// Defaults to the real API with the app-wide session. Injected in tests.
  final CurrentUserRepository? repository;

  /// Where "Гарах" revokes the session, and the session it clears — both
  /// default to the app's own (see [signOutToLogin]). Injected in tests.
  final AuthRepository? authRepository;
  final AuthSessionStore? sessionStore;

  /// Whether this screen draws its tab bar itself. False inside
  /// `JuniorStudentShell`, which owns the one persistent bar (Issue #241).
  final bool showBottomNav;

  /// What the Certificate row's screen reads (Issue #155) — the same
  /// Certificate screen the Adult Profile opens. Default to the real API;
  /// injected in tests.
  final CertificateListRepository? certificateRepository;
  final CourseLearningRepository? courseLearningRepository;

  /// The app's one theme state, which the Dark mode row shows and writes.
  /// Defaults to [AppThemeController.instance]; injected in tests.
  final AppThemeController? themeController;

  @override
  State<JuniorProfileScreen> createState() => _JuniorProfileScreenState();
}

class _JuniorProfileScreenState extends State<JuniorProfileScreen> {
  // UI-only state — see the class doc.
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
            ? const JuniorBottomNav(current: StudentTab.profile)
            : null,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // White behind the status bar as well as the title, as the frame
            // draws it.
            ColoredBox(
              color: context.palette.surface,
              child: SafeArea(
                bottom: false,
                child: _constrained(
                  SizedBox(
                    height: _headerHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.screenPadding,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          JuniorProfileStrings.heading,
                          style: _headingStyle.copyWith(
                            color: context.palette.textPrimary,
                          ),
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
    final theme = widget.themeController ?? AppThemeController.instance;
    // A `SingleChildScrollView`, for the reason the adult Profile gives: a
    // fixed, fully-known set of rows whose exact extent one fling must reach.
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListenableBuilder(
            listenable: _profile,
            builder: (context, _) => _Hero(
              // Empty, never a placeholder person, until `/auth/me` answers.
              name: _profile.user?.displayName ?? '',
            ),
          ),
          const _Rule(),

          const _Caption(JuniorProfileStrings.accountSection),
          _Group(
            rows: [
              // No contract status: no endpoint reports one.
              const _Row(
                icon: _RowIcon(ProfileIcons.eContract),
                label: JuniorProfileStrings.eContract,
              ),
              // The student's certificates, one per course (Issue #155).
              _Row(
                icon: const _RowIcon(ProfileIcons.certificate),
                label: JuniorProfileStrings.certificate,
                onTap: () => CertificateScreen.open(
                  context,
                  repository: widget.certificateRepository,
                  courseLearning: widget.courseLearningRepository,
                ),
              ),
              const _Row(
                icon: _RowIcon(ProfileIcons.transactionHistory),
                label: JuniorProfileStrings.transactionHistory,
              ),
              _Row(
                icon: _RowIcon(JuniorProfileIcons.paymentReceipt),
                label: JuniorProfileStrings.paymentReceipt,
              ),
            ],
          ),

          const _Caption(JuniorProfileStrings.appSettingsSection),
          _Group(
            rows: [
              _Row(
                icon: const _RowIcon(ProfileIcons.language),
                label: JuniorProfileStrings.language,
                trailing: _LanguageToggle(
                  english: _english,
                  onChanged: (value) => setState(() => _english = value),
                ),
              ),
              _Row(
                icon: const _RowIcon.glyph(AppIcons.moon),
                label: JuniorProfileStrings.darkMode,
                trailing: ListenableBuilder(
                  listenable: theme,
                  builder: (context, _) => _Switch(
                    value: theme.darkModeOn,
                    onChanged: theme.setDarkMode,
                    semanticLabel: JuniorProfileStrings.darkMode,
                  ),
                ),
              ),
              _Row(
                icon: const _RowIcon(ProfileIcons.changePassword),
                label: JuniorProfileStrings.changePassword,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const ResetPasswordScreen(showBackButton: true),
                  ),
                ),
              ),
            ],
          ),

          const _Caption(JuniorProfileStrings.notificationSection),
          _Group(
            rows: [
              _Row(
                icon: const _RowIcon(ProfileIcons.notification),
                label: JuniorProfileStrings.notification,
                trailing: _Switch(
                  value: _notifications,
                  onChanged: (value) => setState(() => _notifications = value),
                  semanticLabel: JuniorProfileStrings.notification,
                ),
              ),
            ],
          ),

          const _Caption(JuniorProfileStrings.contactSection),
          for (final (icon, label) in const [
            (ProfileIcons.helpCenter, JuniorProfileStrings.helpCenter),
            (ProfileIcons.termsOfService, JuniorProfileStrings.termsOfService),
            (ProfileIcons.privacyPolicy, JuniorProfileStrings.privacyPolicy),
          ])
            _Row(icon: _RowIcon(icon), label: label, height: _contactRowHeight),

          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.screenPadding,
            ),
            child: _LogOutButton(onPressed: _signOut),
          ),
        ],
      ),
    );
  }
}

/// The avatar beside the name, on the page grey. The frame's join date is not
/// drawn — see [JuniorProfileScreen].
class _Hero extends StatelessWidget {
  const _Hero({required this.name});

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
              color: context.palette.surfaceMuted,
              shape: BoxShape.circle,
              border: Border.all(color: context.palette.outline),
            ),
            child: Icon(
              Icons.person,
              size: 36,
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: _nameStyle.copyWith(
                    color: context.palette.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
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
        child: Text(
          label,
          style: _captionStyle.copyWith(color: context.palette.textSecondary),
        ),
      ),
    );
  }
}

/// Rows with a rule after each one, the last closing the group off.
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

/// A row's leading icon: one of the exported SVGs, or — for "Dark mode"'s
/// moon, which was not exported — the adult rows' [ProfileGlyph] (Issue #288).
class _RowIcon extends StatelessWidget {
  const _RowIcon(String this.asset) : glyph = null;

  const _RowIcon.glyph(IconData this.glyph) : asset = null;

  final String? asset;
  final IconData? glyph;

  @override
  Widget build(BuildContext context) {
    // Through AppSvgIcon so the black glyphs follow `iconInk` in dark
    // (Issue #282); untinted, as before, in light.
    if (asset case final asset?) return AppSvgIcon(asset, size: _rowIcon);
    return ProfileGlyph(glyph!);
  }
}

/// One row: icon, label, and an optional trailing control. No chevron — the
/// frame draws none.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.height = _rowHeight,
  });

  final _RowIcon icon;
  final String label;
  final Widget? trailing;

  /// Null for every row with no destination yet.
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
            icon,
            const SizedBox(width: _iconToLabel),
            Expanded(
              child: Text(
                label,
                style: _rowLabelStyle.copyWith(
                  color: context.palette.textPrimary,
                ),
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

/// The MN/EN control: a blue rounded rectangle with the selected language on
/// a white capsule inset 4 inside it.
///
/// Measured off the frame: 93 x 35 overall, the capsule 44 x 27. The halves
/// are not equal — the capsule is 44 wide and the other language centres in
/// the 41 left over — so whichever language is selected takes the wider
/// slot.
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
        color: context.palette.accent,
        borderRadius: BorderRadius.circular(_toggleRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            label: JuniorProfileStrings.languageMn,
            selected: !english,
            onTap: () => onChanged(false),
          ),
          _Segment(
            label: JuniorProfileStrings.languageEn,
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
            color: selected ? context.palette.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(_capsuleRadius),
          ),
          // "MN" on the white half is a deep indigo (`linkInk`), not the
          // capsule's blue; the other half is `onPrimary`.
          child: Text(
            label,
            style: _segmentStyle.copyWith(
              color: selected
                  ? context.palette.linkInk
                  : context.palette.onPrimary,
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
    final palette = context.palette;
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
            color: value ? palette.accent : palette.outline,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: palette.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: palette.shadow,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
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
      label: JuniorProfileStrings.logOut,
      excludeSemantics: true,
      child: Material(
        color: context.palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: context.palette.outline),
        ),
        child: InkWell(
          onTap: onPressed,
          customBorder: const RoundedRectangleBorder(borderRadius: radius),
          child: SizedBox(
            height: AppDimens.buttonHeight,
            child: Center(
              child: Text(
                JuniorProfileStrings.logOut,
                style: _logOutStyle.copyWith(
                  color: context.palette.textPrimary,
                ),
              ),
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
      color: context.palette.divider,
    );
  }
}

// --- Type --------------------------------------------------------------------
//
// Sampled and measured off the frame at 1:1; sizes from cap heights (Manrope's
// cap height is 0.72 em). None bakes a colour: each use supplies the palette's
// (Issue #272), the same roles Adult's `profile_parts` draws.

const TextStyle _headingStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 24,
  height: 32 / 24,
  fontWeight: FontWeight.w700,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _nameStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 18,
  height: 24 / 18,
  fontWeight: FontWeight.w700,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _captionStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 12,
  height: 16 / 12,
  fontWeight: FontWeight.w700,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _rowLabelStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 16,
  height: 24 / 16,
  fontWeight: FontWeight.w400,
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
  leadingDistribution: TextLeadingDistribution.even,
);
