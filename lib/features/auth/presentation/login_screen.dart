import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../data/http_auth_repository.dart';
import '../data/http_current_user_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session_store.dart';
import '../domain/current_user_repository.dart';
import 'home_route.dart';
import 'login_controller.dart';
import 'login_strings.dart';
import 'widgets/contact_manager_card.dart';
import 'widgets/manager_contact_sheet.dart';
import 'widgets/remember_me_checkbox.dart';

/// Sign in.
///
/// Reproduces the Adult login flow — Figma `Sign in - 1` … `5` (node
/// `31019:13426` and siblings, section "Login", page "📱 - App UI"). The
/// vertical rhythm is the design's own, read from the frame geometry and kept
/// in [AppDimens]: 88 to the heading, 24 to the form, 12 between fields, 40 to
/// the buttons, 12 between them, and an 80pt card at the bottom.
///
/// There is no logo on this screen — the design leaves the 88pt band above the
/// heading empty.
///
/// The design frame is a fixed 393 x 852 artboard. Here the content stretches
/// to the device width behind fixed 16pt gutters, and the band between the form
/// and the bottom card flexes, so the card sits at the bottom of a taller phone
/// and the screen scrolls on a shorter one.
///
/// **Colour note.** The page uses [AppColors.surfaceSubtle] (`#F9FAFB`) — the
/// reference's own fill — rather than [AppColors.background] (`#F4F5F7`).
/// Three further reference values still differ from their shared tokens
/// (border `#D6DBE1` vs [AppColors.border], error `#EF4444` vs
/// [AppColors.error], primary `#2970FF` vs [AppColors.blue], the last
/// imperceptibly). Those live inside `AppTextField`/`AppButton` and are used
/// by every other screen, so correcting them is a design-system change rather
/// than a Login one, and is deliberately not done here.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.repository,
    this.sessionStore,
    this.currentUserRepository,
    this.onSignedIn,
    this.onResetPassword,
    this.openUrl,
  });

  /// Defaults to the real API. Injected in tests.
  final AuthRepository? repository;

  /// Where the issued token is kept. Defaults to the app-wide store.
  final AuthSessionStore? sessionStore;

  /// Reads the signed-in account's `must_change_password` (Issue #182).
  /// Defaults to the real `GET /auth/me` over [sessionStore]. Injected in
  /// tests.
  final CurrentUserRepository? currentUserRepository;

  /// Where to go after a successful sign-in. Defaults to the route the
  /// session's `user_type` selects — see [homeRouteFor]. An account that must
  /// change its password goes to "Нууц үгээ тохируулах" first, and only then
  /// here — see [openSignedIn].
  final VoidCallback? onSignedIn;

  /// What the "Нууц үг сэргээх" button does. Defaults to the change-password
  /// screen (`/reset-password`) while a live session is held — the only case
  /// its authenticated `POST /auth/change-password` can succeed in — and,
  /// signed out, to the same contact sheet the bottom card opens
  /// ([chooseManagerContact], Issues #184, #186): the frame's own card says
  /// that is where a forgotten password goes.
  final VoidCallback? onResetPassword;

  /// Opens the manager contact's `tel:`/`mailto:` link. Defaults to
  /// `openExternalUrl`; injected in tests, which must not reach the platform.
  final Future<bool> Function(Uri url)? openUrl;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginController _controller;
  final FocusNode _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = LoginController(
      repository: widget.repository ?? HttpAuthRepository(),
      currentUserRepository:
          widget.currentUserRepository ??
          HttpCurrentUserRepository(
            sessionStore: widget.sessionStore ?? AuthSessionStore.instance,
          ),
      openUrl: widget.openUrl,
    );
  }

  @override
  void dispose() {
    _passwordFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final session = await _controller.submit();
    if (session == null) return;

    // Hold the session before navigating: it is the only copy of the access
    // and refresh tokens, so losing it here means signing in again.
    (widget.sessionStore ?? AuthSessionStore.instance).save(session);

    // Asked with the session just saved, before anything is shown.
    final mustChangePassword = await _controller.passwordChangeRequired();
    if (!mounted) return;

    final onSignedIn = widget.onSignedIn;
    openSignedIn(
      context,
      homeRoute: homeRouteFor(session.userType),
      mustChangePassword: mustChangePassword,
      openHome: onSignedIn == null ? null : (_) => onSignedIn(),
    );
  }

  void _openResetPassword() {
    FocusScope.of(context).unfocus();
    if (widget.onResetPassword != null) {
      widget.onResetPassword!();
      return;
    }
    final store = widget.sessionStore ?? AuthSessionStore.instance;
    if (store.isSignedIn && !store.isExpired()) {
      Navigator.of(context).pushNamed('/reset-password');
    } else {
      // Signed out, changing a password is impossible — the request needs the
      // session. The frame sends a forgotten password to the manager instead.
      _contactManager();
    }
  }

  /// Lets the student choose call or email, then opens that one. Closing the
  /// sheet any other way opens nothing and leaves Login as it was.
  Future<void> _contactManager() async {
    FocusScope.of(context).unfocus();
    final contact = await chooseManagerContact(context);
    if (contact == null || !mounted) return;
    await _controller.openContact(contact);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surfaceSubtle,
      ),
      child: Scaffold(
        // The Figma frame's own page fill (#F9FAFB), which `surfaceSubtle`
        // already holds exactly — not `background` (#F4F5F7), which is a
        // slightly darker approximation. See this screen's own doc comment.
        backgroundColor: AppColors.surfaceSubtle,
        // The keyboard overlays the screen instead of shrinking it. In the
        // reference the form does not move when the keypad appears — it simply
        // covers the bottom card — and resizing would jerk that card up to meet
        // it. The scroll padding below keeps everything reachable regardless.
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
          // Tapping the background dismisses the keyboard.
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  // Grows the scrollable extent by the height of the keyboard so
                  // a short screen can still scroll a covered field into view,
                  // without the layout itself resizing.
                  padding: EdgeInsets.only(bottom: keyboardInset),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppDimens.maxContentWidth,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.screenPadding,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: AppDimens.headingTop),

                                Text(
                                  LoginStrings.heading,
                                  style: AppTypography.heading,
                                ),
                                const SizedBox(height: AppDimens.headingToForm),

                                _buildForm(),

                                // Flexes so the card sits at the bottom of a
                                // tall screen and collapses on a short one.
                                const Spacer(),
                                const SizedBox(height: 24),

                                ContactManagerCard(
                                  supportingText:
                                      LoginStrings.contactSupporting,
                                  title: LoginStrings.contactManager,
                                  onTap: _controller.submitting
                                      ? null
                                      : _contactManager,
                                ),
                                const SizedBox(height: AppDimens.cardPadding),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final busy = _controller.submitting;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _controller.identifier,
            placeholder: LoginStrings.identifierPlaceholder,
            floatingLabel: _controller.identifierLabel,
            errorText: _controller.identifierError,
            enabled: !busy,
            // The email keyboard, not the phone pad `Sign in - 2` draws: the
            // field takes "Утасны дугаар / Email хаяг" and `/auth/login` signs
            // in by `email`, but iOS's phone pad has no letter keys, so an
            // address could not be typed at all (Issue #142). The email
            // keyboard still reaches digits through its number row.
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            // iOS reads only the first hint, as the field's content type: email,
            // so it is never offered as a phone-number field (Issue #144). No
            // telephone hint at all — Android reads every hint. `username`
            // stays listed because Flutter turns autocorrect off on iOS when
            // any hint is password-related; the password field below still
            // makes the group a login form for password AutoFill.
            autofillHints: const [AutofillHints.email, AutofillHints.username],
            onSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          const SizedBox(height: AppDimens.fieldGap),

          AppTextField(
            controller: _controller.password,
            focusNode: _passwordFocus,
            placeholder: LoginStrings.passwordLabel,
            errorText: _controller.passwordError,
            enabled: !busy,
            obscureText: _controller.obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            suffix: _buildPasswordToggle(enabled: !busy),
          ),
          const SizedBox(height: AppDimens.fieldsToCheckbox),

          RememberMeCheckbox(
            value: _controller.rememberMe,
            label: LoginStrings.rememberMe,
            onChanged: busy
                ? null
                : (value) => _controller.setRememberMe(value: value),
          ),

          _buildMessageBand(),

          AppButton(
            // Live even with the fields empty — the reference draws it in full
            // brand blue in the resting state. Pressing an empty form is what
            // surfaces the field errors, which is the point of Sign in - 4/5.
            label: LoginStrings.signIn,
            loading: busy,
            onPressed: busy ? null : _submit,
          ),
          const SizedBox(height: AppDimens.buttonGap),

          AppButton(
            label: LoginStrings.resetPassword,
            variant: AppButtonVariant.outlined,
            onPressed: busy ? null : _openResetPassword,
          ),
        ],
      ),
    );
  }

  /// The 40pt gap the design leaves between the checkbox and the buttons,
  /// doubling as the slot for the one line of red text.
  ///
  /// Putting the message *inside* the existing gap rather than adding a row of
  /// its own is what keeps the error states aligned with the reference: the
  /// buttons do not shift and no banner appears. The field's own red border and
  /// red label say which input is at fault; this says why.
  Widget _buildMessageBand() {
    final message = _controller.message;

    return SizedBox(
      height: AppDimens.formToButtons,
      child: message == null
          ? null
          : Align(
              alignment: Alignment.centerLeft,
              child: Text(
                message,
                style: AppTypography.fieldError,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
    );
  }

  Widget _buildPasswordToggle({required bool enabled}) {
    final hidden = _controller.obscurePassword;
    return Semantics(
      button: true,
      label: hidden ? LoginStrings.showPassword : LoginStrings.hidePassword,
      child: InkWell(
        onTap: enabled ? _controller.toggleObscurePassword : null,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(
            // Hidden shows the closed eye, matching the reference.
            hidden ? AppIcons.eyeClosed : AppIcons.eye,
            size: 20,
            color: enabled ? AppColors.textSecondary : AppColors.disabled,
          ),
        ),
      ),
    );
  }
}
