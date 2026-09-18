import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_button.dart';
import '../../auth/data/http_current_user_repository.dart';
import '../../auth/domain/current_user_repository.dart';
import 'profile_controller.dart';
import 'profile_strings.dart';

/// The student's profile and app settings.
///
/// Reuses the established system rather than restating it: the same
/// [AppTypography] scale, the same [AppDimens.screenPadding] gutters and
/// [AppDimens.maxContentWidth] cap, the same heading style, the same
/// [AppButton] for the one action on screen, and the same [AppBottomNav]
/// `CohortListScreen` already carries.
///
/// **Every row but the header is UI only.** E-Contract, Certificate,
/// Transaction history, edit profile, Change password, Help center, Term of
/// Service and Privacy Policy have no destination yet, and the language,
/// light-mode and notification controls hold local state that nothing else
/// reads — there is no locale mechanism, no dark palette and no
/// notification-preference endpoint in the app to hand them to. Each is a
/// separate issue; this one is the layout.
///
/// The header's name loads from `GET /auth/me` through [ProfileController],
/// the same way `CohortListScreen` loads `EnrolledCohortsController` —
/// falling back to [ProfileStrings.name] while that fetch is loading or has
/// failed. The join date stays the design's placeholder copy: the confirmed
/// `/auth/me` response carries no join date. See [ProfileStrings].
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.repository});

  /// Defaults to the real API with the app-wide session. Injected in tests.
  final CurrentUserRepository? repository;

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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surfaceSubtle,
        bottomNavigationBar: AppBottomNav(
          currentIndex: 2,
          items: [
            const AppBottomNavItem(
              icon: AppIcons.house,
              label: ProfileStrings.navHome,
              // No Home dashboard screen exists yet to navigate to.
            ),
            AppBottomNavItem(
              icon: AppIcons.bookOpenText,
              label: ProfileStrings.navCourses,
              // Profile is pushed on top of the courses flow, so returning to
              // "Хичээл" is the same pop every other screen's tab performs.
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const AppBottomNavItem(
              icon: AppIcons.user,
              label: ProfileStrings.navProfile,
              // Already here.
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimens.maxContentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ColoredBox(
                    color: AppColors.surface,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimens.screenPadding,
                        AppDimens.resetHeadingTop,
                        AppDimens.screenPadding,
                        AppDimens.headingToForm,
                      ),
                      child: Text(
                        ProfileStrings.heading,
                        style: AppTypography.heading,
                      ),
                    ),
                  ),
                  const _Divider(),
                  Expanded(child: _buildBody()),
                ],
              ),
            ),
          ),
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
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListenableBuilder(
            listenable: _profile,
            builder: (context, _) =>
                _Header(name: _profile.user?.displayName ?? ProfileStrings.name),
          ),
          const _Divider(),

          const _SectionLabel(ProfileStrings.accountSection),
          _SettingsGroup(
            rows: [
              _SettingsRow(
                icon: ProfileIcons.eContract,
                label: ProfileStrings.eContract,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _StatusBadge(ProfileStrings.eContractStatus),
                    const SizedBox(width: 12),
                    Text(
                      ProfileStrings.eContractCount,
                      style: AppTypography.catalogSectionValue,
                    ),
                  ],
                ),
              ),
              const _SettingsRow(
                icon: ProfileIcons.certificate,
                label: ProfileStrings.certificate,
              ),
              const _SettingsRow(
                icon: ProfileIcons.transactionHistory,
                label: ProfileStrings.transactionHistory,
              ),
            ],
          ),

          const _SectionLabel(ProfileStrings.appSettingsSection),
          _SettingsGroup(
            rows: [
              _SettingsRow(
                icon: ProfileIcons.language,
                label: ProfileStrings.language,
                trailing: _LanguageToggle(
                  english: _english,
                  onChanged: (value) => setState(() => _english = value),
                ),
              ),
              _SettingsRow(
                icon: ProfileIcons.lightMode,
                label: ProfileStrings.lightMode,
                trailing: _Toggle(
                  value: _lightMode,
                  onChanged: (value) => setState(() => _lightMode = value),
                  semanticLabel: ProfileStrings.lightMode,
                ),
              ),
              const _SettingsRow(
                icon: ProfileIcons.changePassword,
                label: ProfileStrings.changePassword,
              ),
            ],
          ),

          const _SectionLabel(ProfileStrings.notificationSection),
          _SettingsGroup(
            rows: [
              _SettingsRow(
                icon: ProfileIcons.notification,
                label: ProfileStrings.notification,
                trailing: _Toggle(
                  value: _notifications,
                  onChanged: (value) => setState(() => _notifications = value),
                  semanticLabel: ProfileStrings.notification,
                ),
              ),
            ],
          ),

          const _SectionLabel(ProfileStrings.contactSection),
          const _SettingsGroup(
            rows: [
              _SettingsRow(
                icon: ProfileIcons.helpCenter,
                label: ProfileStrings.helpCenter,
              ),
              _SettingsRow(
                icon: ProfileIcons.termsOfService,
                label: ProfileStrings.termsOfService,
              ),
              _SettingsRow(
                icon: ProfileIcons.privacyPolicy,
                label: ProfileStrings.privacyPolicy,
              ),
            ],
          ),

          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.logOutInset,
            ),
            child: AppButton(
              label: ProfileStrings.logOut,
              variant: AppButtonVariant.outlined,
              // Signing out is its own issue. The button is deliberately
              // given an empty callback rather than null: null renders
              // `AppButton`'s disabled treatment — grey label, grey border —
              // and the reference draws it in full contrast.
              onPressed: () {},
            ),
          ),
          const SizedBox(height: 12),
          Text(
            ProfileStrings.version,
            style: AppTypography.cardSupporting,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The avatar, name and join date, with the edit control at the trailing
/// edge. The avatar is a generic glyph rather than an image: no avatar URL
/// exists on any confirmed response to load one from.
class _Header extends StatelessWidget {
  const _Header({required this.name});

  /// The fetched `CurrentUser.displayName`, or [ProfileStrings.name] while
  /// loading or on failure — see [ProfileController].
  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.screenPadding,
        vertical: 10,
      ),
      child: Row(
        children: [
          Container(
            width: AppDimens.avatarSize,
            height: AppDimens.avatarSize,
            decoration: const BoxDecoration(
              color: AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              size: 24,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: AppTypography.profileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  ProfileStrings.joinedDate,
                  style: AppTypography.profileJoinedDate,
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

class _EditButton extends StatelessWidget {
  const _EditButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: ProfileStrings.editProfile,
      child: Container(
        width: AppDimens.avatarEditSize,
        height: AppDimens.avatarEditSize,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.border,
            width: AppDimens.borderWidth,
          ),
        ),
        child: Center(
          child: SvgPicture.asset(ProfileIcons.edit, width: 18, height: 18),
        ),
      ),
    );
  }
}

/// A grey caption over a group of rows, sitting on the page rather than on
/// the white the rows themselves use.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        12,
        AppDimens.screenPadding,
        4,
      ),
      child: Text(label, style: AppTypography.catalogSectionLabel),
    );
  }
}

/// Rows with a hairline between each, and one closing the group off from the
/// caption below it.
///
/// No rule between a caption and its own first row: the reference runs the
/// caption straight into the group it names, and only separates one group
/// from the next.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const _Divider(),
          rows[i],
        ],
        const _Divider(),
      ],
    );
  }
}

/// One row: a leading icon, a label, and an optional trailing control.
///
/// No chevron: the reference draws none on any row, including the ones that
/// will eventually open a screen of their own.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.icon, required this.label, this.trailing});

  /// Path to the row's exported SVG — see [ProfileIcons].
  final String icon;

  final String label;

  /// The row's trailing control, where the row has one.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppDimens.settingsRowHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.screenPadding,
          vertical: 4,
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              icon,
              width: AppDimens.settingsRowIconSize,
              height: AppDimens.settingsRowIconSize,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTypography.settingsRowLabel,
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
  }
}

/// The amber pill on the E-Contract row.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.4),
          width: AppDimens.borderWidth,
        ),
      ),
      child: Text(
        label,
        style: AppTypography.catalogStatusLabel.copyWith(
          color: AppColors.warning,
        ),
      ),
    );
  }
}

/// The MN/EN segmented control: a blue capsule with the selected half
/// picked out in white.
class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.english, required this.onChanged});

  final bool english;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(999),
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
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: AppTypography.segmentLabel.copyWith(
              color: selected ? AppColors.blue : AppColors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// A row's on/off control. Flutter's own [Switch], recoloured to the
/// palette — the design draws a stock switch, so this is not hand-rolled the
/// way `RememberMeCheckbox` had to be.
class _Toggle extends StatelessWidget {
  const _Toggle({
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
      label: semanticLabel,
      child: Transform.scale(
        scale: 0.9,
        child: Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          thumbColor: const WidgetStatePropertyAll(AppColors.onPrimary),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.blue
                : AppColors.disabled,
          ),
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(height: AppDimens.borderWidth, color: AppColors.border);
  }
}
