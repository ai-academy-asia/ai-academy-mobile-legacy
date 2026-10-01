import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/data/http_current_user_repository.dart';
import '../../auth/domain/current_user_repository.dart';
import '../../auth/presentation/reset_password_screen.dart';
import '../../auth/presentation/student_tabs.dart';
import '../../home/presentation/widgets/home_palette.dart';
import '../../profile/presentation/profile_controller.dart';
import '../../profile/presentation/profile_strings.dart';
import 'junior_profile_strings.dart';
import 'widgets/junior_bottom_nav.dart';
import 'widgets/junior_home_palette.dart';

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
/// "1/2" counter on E-Contract, no light-mode row, its own MN/EN control and
/// switch, rows without a chevron on a grey page, and a full-width log-out
/// pill.
///
/// **Reuse.** The name loads from `GET /auth/me` through the adult Profile's
/// own [ProfileController] and `CurrentUserRepository`, falling back to
/// [JuniorProfileStrings.name] while loading or on failure. The row icons are
/// the adult Profile's exported SVGs ([ProfileIcons]) — the same artwork the
/// junior frame draws — plus the junior frame's own "Payment receipt" SVG
/// ([JuniorProfileIcons]). Change password pushes the same [ResetPasswordScreen]
/// the adult row does.
///
/// **Gaps.** No confirmed response carries an avatar URL, so the avatar is
/// a placeholder disc, as on the adult Profile — the frame's photo is design
/// content, not app data. Every other row, the toggles and Log
/// out have no destination yet, as on the adult Profile; the toggles hold
/// local state that nothing reads.
class JuniorProfileScreen extends StatefulWidget {
  const JuniorProfileScreen({super.key, this.repository});

  /// Defaults to the real API with the app-wide session. Injected in tests.
  final CurrentUserRepository? repository;

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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surfaceSubtle,
        bottomNavigationBar: const JuniorBottomNav(current: StudentTab.profile),
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
                          JuniorProfileStrings.heading,
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
              name: _profile.user?.displayName ?? JuniorProfileStrings.name,
            ),
          ),
          const _Rule(),

          const _Caption(JuniorProfileStrings.accountSection),
          const _Group(
            rows: [
              _Row(
                icon: _RowIcon(ProfileIcons.eContract),
                label: JuniorProfileStrings.eContract,
                trailing: _StatusBadge(JuniorProfileStrings.eContractStatus),
              ),
              _Row(
                icon: _RowIcon(ProfileIcons.certificate),
                label: JuniorProfileStrings.certificate,
              ),
              _Row(
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
                icon: const _RowIcon(ProfileIcons.changePassword),
                label: JuniorProfileStrings.changePassword,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ResetPasswordScreen(),
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
            // Signing out is its own issue, as on the adult Profile. An empty
            // callback rather than null keeps the frame's full contrast.
            child: _LogOutButton(onPressed: () {}),
          ),
          const SizedBox(height: 20),
          const Text(
            JuniorProfileStrings.version,
            style: _versionStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The avatar beside the name and join date, on the page grey.
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
          const SizedBox(width: 8),
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
                  JuniorProfileStrings.joinedDate,
                  style: _joinedStyle,
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
        child: Text(label, style: _captionStyle),
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

/// A row's leading icon: one of the exported SVGs.
class _RowIcon extends StatelessWidget {
  const _RowIcon(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(asset, width: _rowIcon, height: _rowIcon);
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
                style: _rowLabelStyle,
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
/// amber, with a softer outline.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HomePalette.contractFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _badgeOutline),
      ),
      child: Text(label, style: _badgeStyle, maxLines: 1),
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
        color: JuniorPalette.accent,
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
            color: value ? JuniorPalette.accent : JuniorPalette.muted,
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
      label: JuniorProfileStrings.logOut,
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
              child: Text(JuniorProfileStrings.logOut, style: _logOutStyle),
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
      color: JuniorPalette.mutedFill,
    );
  }
}

// --- Colour and type ---------------------------------------------------------
//
// Sampled and measured off the frame at 1:1; sizes from cap heights (Manrope's
// cap height is 0.72 em).

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

const TextStyle _captionStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 12,
  height: 16 / 12,
  fontWeight: FontWeight.w700,
  color: AppColors.textSecondary,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _rowLabelStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 16,
  height: 24 / 16,
  fontWeight: FontWeight.w400,
  color: AppColors.textPrimary,
  leadingDistribution: TextLeadingDistribution.even,
);

const TextStyle _badgeStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: 11,
  height: 16 / 11,
  fontWeight: FontWeight.w500,
  color: _badgeInk,
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
